#import "LEBExporter.h"
#import "LEBConfiguration.h"
#import "LEBFrameComposer.h"

#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>

/// Pixel size of one LED in exported video. A multiple of 16 keeps both H.264 and
/// ProRes encoders happy for any row/column count.
static const CGFloat LEBVideoCellSize = 16.0;

@implementation LEBVideoExporter

- (instancetype)init {
    self = [super init];
    if (self) {
        _format = LEBExportFormatMP4;
    }
    return self;
}

- (void)exportToURL:(NSURL *)url completion:(LEBExportCompletionHandler)completion {
    LEBConfiguration *configuration = self.configuration;
    if (!configuration) {
        [self finishWithError:[self errorWithCode:LEBExporterErrorVideoSetup
                                      description:@"There is no banner configuration to export."]
                   completion:completion];
        return;
    }
    if (self.format != LEBExportFormatMP4 && self.format != LEBExportFormatMOV) {
        [self finishWithError:[self errorWithCode:LEBExporterErrorVideoSetup
                                      description:@"Unsupported video format."]
                   completion:completion];
        return;
    }

    [self removeFileAtURL:url];

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        [self runExportToURL:url configuration:configuration completion:completion];
    });
}

- (void)runExportToURL:(NSURL *)url
         configuration:(LEBConfiguration *)configuration
            completion:(LEBExportCompletionHandler)completion {
    BOOL wantsProRes = (self.format == LEBExportFormatMOV);
    NSUInteger fps = MAX(self.fps, (NSUInteger)1);
    NSUInteger totalFrames = [self frameCount];

    NSUInteger width = MAX(configuration.columns, (NSUInteger)1) * (NSUInteger)LEBVideoCellSize;
    NSUInteger height = MAX(configuration.rows, (NSUInteger)1) * (NSUInteger)LEBVideoCellSize;

    NSDictionary *h264Settings = @{
        AVVideoCodecKey: AVVideoCodecTypeH264,
        AVVideoWidthKey: @(width),
        AVVideoHeightKey: @(height),
        AVVideoCompressionPropertiesKey: @{
            AVVideoAverageBitRateKey: @((NSInteger)(width * height * fps * 0.12)),
            AVVideoMaxKeyFrameIntervalKey: @(MAX(fps * 2, (NSUInteger)30)),
            AVVideoProfileLevelKey: AVVideoProfileLevelH264MainAutoLevel
        }
    };

    NSDictionary *proResSettings = @{
        AVVideoCodecKey: AVVideoCodecTypeAppleProRes422,
        AVVideoWidthKey: @(width),
        AVVideoHeightKey: @(height)
    };

    AVFileType fileType = wantsProRes ? AVFileTypeQuickTimeMovie : AVFileTypeMPEG4;
    NSError *error = nil;
    AVAssetWriter *writer = [AVAssetWriter assetWriterWithURL:url fileType:fileType error:&error];
    if (!writer) {
        [self removeFileAtURL:url];
        [self finishWithError:error ?: [self errorWithCode:LEBExporterErrorVideoSetup
                                               description:@"Could not create the video writer."]
                   completion:completion];
        return;
    }

    NSDictionary *settings = h264Settings;
    if (wantsProRes) {
        if ([writer canApplyOutputSettings:proResSettings forMediaType:AVMediaTypeVideo]) {
            settings = proResSettings;
        } else {
            // Fall back to H.264 inside the .mov container on systems without ProRes.
            settings = h264Settings;
        }
    }

    AVAssetWriterInput *input = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo
                                                                  outputSettings:settings];
    input.expectsMediaDataInRealTime = NO;
    if (![writer canAddInput:input]) {
        [self removeFileAtURL:url];
        [self finishWithError:[self errorWithCode:LEBExporterErrorVideoSetup
                                      description:@"The video encoder rejected this banner size."]
                   completion:completion];
        return;
    }

    NSDictionary *pixelAttributes = @{
        (__bridge NSString *)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA),
        (__bridge NSString *)kCVPixelBufferWidthKey: @(width),
        (__bridge NSString *)kCVPixelBufferHeightKey: @(height),
        (__bridge NSString *)kCVPixelBufferCGImageCompatibilityKey: @YES,
        (__bridge NSString *)kCVPixelBufferCGBitmapContextCompatibilityKey: @YES
    };
    AVAssetWriterInputPixelBufferAdaptor *adaptor =
        [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:input
                                                                         sourcePixelBufferAttributes:pixelAttributes];

    [writer addInput:input];
    if (![writer startWriting]) {
        NSError *startError = writer.error ?: [self errorWithCode:LEBExporterErrorVideoSetup
                                                      description:@"The video writer could not start."];
        [self removeFileAtURL:url];
        [self finishWithError:startError completion:completion];
        return;
    }
    [writer startSessionAtSourceTime:kCMTimeZero];

    LEBFrameComposer *composer = [[LEBFrameComposer alloc] initWithConfiguration:configuration];
    CGColorSpaceRef colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    BOOL failed = NO;
    NSUInteger written = 0;

    for (NSUInteger frame = 0; frame < totalFrames; frame++) {
        if (self.isCancelled) {
            break;
        }
        while (!input.isReadyForMoreMediaData) {
            if (self.isCancelled) {
                break;
            }
            usleep(2000);
        }
        if (self.isCancelled) {
            break;
        }

        CVPixelBufferRef pixelBuffer = NULL;
        CVReturn result = kCVReturnError;
        if (adaptor.pixelBufferPool) {
            result = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault,
                                                        adaptor.pixelBufferPool,
                                                        &pixelBuffer);
        }
        if (result != kCVReturnSuccess || !pixelBuffer) {
            result = CVPixelBufferCreate(kCFAllocatorDefault, width, height,
                                         kCVPixelFormatType_32BGRA,
                                         (__bridge CFDictionaryRef)pixelAttributes,
                                         &pixelBuffer);
        }
        if (result != kCVReturnSuccess || !pixelBuffer) {
            failed = YES;
            break;
        }

        CVPixelBufferLockBaseAddress(pixelBuffer, 0);
        void *base = CVPixelBufferGetBaseAddress(pixelBuffer);
        size_t bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer);
        CGContextRef context = CGBitmapContextCreate(base, width, height, 8, bytesPerRow,
                                                     colorSpace,
                                                     kCGBitmapByteOrder32Little |
                                                     kCGImageAlphaPremultipliedFirst);
        if (!context) {
            CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
            CVPixelBufferRelease(pixelBuffer);
            failed = YES;
            break;
        }

        [composer drawFrameAtTime:(NSTimeInterval)frame / (NSTimeInterval)fps
                        inContext:context
                         cellSize:LEBVideoCellSize];
        CGContextRelease(context);
        CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);

        CMTime presentation = CMTimeMakeWithSeconds((NSTimeInterval)frame / (NSTimeInterval)fps, 600);
        BOOL appended = [adaptor appendPixelBuffer:pixelBuffer withPresentationTime:presentation];
        CVPixelBufferRelease(pixelBuffer);

        if (!appended) {
            failed = YES;
            break;
        }
        written++;

        if (frame % 2 == 0 || frame + 1 == totalFrames) {
            [self reportProgress:frame + 1 total:totalFrames];
        }
    }

    CGColorSpaceRelease(colorSpace);
    [input markAsFinished];

    if (self.isCancelled) {
        [writer cancelWriting];
        [self removeFileAtURL:url];
        [self finishWithError:[self errorWithCode:LEBExporterErrorCancelled
                                      description:@"Export cancelled."]
                   completion:completion];
        return;
    }

    if (failed) {
        NSError *writeError = writer.error ?: [self errorWithCode:LEBExporterErrorWriting
                                                      description:@"The video could not be encoded."];
        [writer cancelWriting];
        [self removeFileAtURL:url];
        [self finishWithError:writeError completion:completion];
        return;
    }

    if (written > 0) {
        [writer endSessionAtSourceTime:CMTimeMakeWithSeconds((NSTimeInterval)written / (NSTimeInterval)fps, 600)];
    }

    [writer finishWritingWithCompletionHandler:^{
        if (writer.status == AVAssetWriterStatusFailed) {
            [self removeFileAtURL:url];
            [self finishWithError:writer.error ?: [self errorWithCode:LEBExporterErrorWriting
                                                          description:@"The video could not be finalized."]
                       completion:completion];
        } else {
            [self reportProgress:totalFrames total:totalFrames];
            [self finishWithError:nil completion:completion];
        }
    }];
}

@end
