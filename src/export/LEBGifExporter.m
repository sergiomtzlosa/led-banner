#import "LEBExporter.h"
#import "LEBConfiguration.h"
#import "LEBFrameComposer.h"

#import <ImageIO/ImageIO.h>
#import <CoreServices/CoreServices.h>

/// Pixel size of one LED in exported GIFs.
static const CGFloat LEBGifCellSize = 12.0;

@implementation LEBGifExporter

- (void)exportToURL:(NSURL *)url completion:(LEBExportCompletionHandler)completion {
    LEBConfiguration *configuration = self.configuration;
    NSUInteger fps = MAX(self.fps, (NSUInteger)1);
    NSUInteger totalFrames = [self frameCount];

    if (!configuration) {
        [self finishWithError:[self errorWithCode:LEBExporterErrorDestination
                                      description:@"There is no banner configuration to export."]
                   completion:completion];
        return;
    }

    [self removeFileAtURL:url];

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSError *error = nil;

        CGImageDestinationRef destination = CGImageDestinationCreateWithURL(
            (__bridge CFURLRef)url, CFSTR("com.compuserve.gif"), (size_t)totalFrames, NULL);
        if (!destination) {
            error = [self errorWithCode:LEBExporterErrorDestination
                            description:@"Could not create the GIF file."];
            [self finishWithError:error completion:completion];
            return;
        }

        NSDictionary *fileProperties = @{
            (__bridge NSString *)kCGImagePropertyGIFDictionary: @{
                (__bridge NSString *)kCGImagePropertyGIFLoopCount: @0
            }
        };
        CGImageDestinationSetProperties(destination, (__bridge CFDictionaryRef)fileProperties);

        LEBFrameComposer *composer = [[LEBFrameComposer alloc] initWithConfiguration:configuration];
        NSTimeInterval delay = 1.0 / (NSTimeInterval)fps;
        NSDictionary *frameProperties = @{
            (__bridge NSString *)kCGImagePropertyGIFDictionary: @{
                (__bridge NSString *)kCGImagePropertyGIFDelayTime: @(delay),
                (__bridge NSString *)kCGImagePropertyGIFUnclampedDelayTime: @(delay)
            }
        };

        BOOL cancelled = NO;
        for (NSUInteger frame = 0; frame < totalFrames; frame++) {
            if (self.isCancelled) {
                cancelled = YES;
                break;
            }
            @autoreleasepool {
                CGImageRef image = [composer copyFrameAtTime:(NSTimeInterval)frame / (NSTimeInterval)fps
                                                   cellSize:LEBGifCellSize];
                if (image) {
                    CGImageDestinationAddImage(destination, image,
                                               (__bridge CFDictionaryRef)frameProperties);
                    CGImageRelease(image);
                }
            }
            if (frame % 2 == 0 || frame + 1 == totalFrames) {
                [self reportProgress:frame + 1 total:totalFrames];
            }
        }

        BOOL finalizeOK = NO;
        if (!cancelled) {
            finalizeOK = CGImageDestinationFinalize(destination);
        }
        CFRelease(destination);

        if (cancelled || self.isCancelled) {
            [self removeFileAtURL:url];
            error = [self errorWithCode:LEBExporterErrorCancelled description:@"Export cancelled."];
        } else if (!finalizeOK) {
            [self removeFileAtURL:url];
            error = [self errorWithCode:LEBExporterErrorWriting
                            description:@"The GIF could not be finalized."];
        }

        if (!error) {
            [self reportProgress:totalFrames total:totalFrames];
        }
        [self finishWithError:error completion:completion];
    });
}

@end
