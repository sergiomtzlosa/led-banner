#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <CoreGraphics/CoreGraphics.h>
#import <ImageIO/ImageIO.h>
#import <AVFoundation/AVFoundation.h>

#import "LEBConfiguration.h"
#import "LEBGlyphFont.h"
#import "LEBFrameComposer.h"
#import "LEBExporter.h"

static int gFailures = 0;

static void Check(BOOL condition, NSString *message) {
    if (condition) {
        fprintf(stdout, "  ok   %s\n", message.UTF8String);
    } else {
        gFailures++;
        fprintf(stderr, "  FAIL %s\n", message.UTF8String);
    }
}

static NSData *PixelDataFromImage(CGImageRef image) {
    size_t width = CGImageGetWidth(image);
    size_t height = CGImageGetHeight(image);
    NSMutableData *data = [NSMutableData dataWithLength:width * height * 4];
    CGColorSpaceRef colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGContextRef context = CGBitmapContextCreate(data.mutableBytes, width, height, 8, width * 4,
                                                 colorSpace,
                                                 kCGBitmapByteOrder32Little |
                                                 kCGImageAlphaPremultipliedFirst);
    CGColorSpaceRelease(colorSpace);
    if (!context) {
        return data;
    }
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), image);
    CGContextRelease(context);
    return data;
}

static NSUInteger CountLitPixels(NSData *data) {
    const uint8_t *bytes = data.bytes;
    NSUInteger count = 0;
    for (NSUInteger i = 0; i + 3 < data.length; i += 4) {
        if (bytes[i + 2] > 80) { // red channel in BGRA
            count++;
        }
    }
    return count;
}

static BOOL WaitForExport(LEBExporter *exporter, NSURL *url, NSError **outError) {
    __block BOOL done = NO;
    __block NSError *resultError = nil;
    [exporter exportToURL:url completion:^(NSError *error) {
        resultError = error;
        done = YES;
    }];

    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:60.0];
    while (!done && [deadline timeIntervalSinceNow] > 0.0) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                 beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];
    }
    if (outError) {
        *outError = resultError;
    }
    return done && resultError == nil;
}

static NSURL *TemporaryFileURL(NSString *extension) {
    NSString *name = [NSString stringWithFormat:@"led-banner-test-%@.%@",
                      [[NSUUID UUID] UUIDString], extension];
    return [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:name]];
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        fprintf(stdout, "LED Banner tests\n");

        // Font sanity.
        uint8_t rows[7] = {0};
        Check([LEBGlyphFont getRows:rows forCharacter:'A'], @"glyph 'A' exists");
        Check(rows[0] == 0x0E && rows[3] == 0x1F, @"glyph 'A' has expected pattern");
        Check([LEBGlyphFont getRows:rows forCharacter:'a'], @"lowercase maps to uppercase");
        Check(rows[3] == 0x1F, @"lowercase pattern matches uppercase");
        Check([LEBGlyphFont getRows:rows forCharacter:' '], @"space glyph exists");
        for (int i = 0; i < 7; i++) {
            Check(rows[i] == 0, @"space glyph is blank");
        }

        // Configuration.
        LEBConfiguration *configuration = [[LEBConfiguration alloc] init];
        configuration.message = @"HELLO";
        configuration.rows = 16;
        configuration.columns = 64;
        LEBFrameComposer *composer = [[LEBFrameComposer alloc] initWithConfiguration:configuration];
        Check(configuration.messageColumns == 30, @"message width is 6 columns per character");
        Check([composer cycleDuration] > 1.0, @"cycle duration is sane");

        // Frame dimensions and content.
        CGImageRef frameA = [composer copyFrameAtTime:0.0 cellSize:6.0];
        Check(frameA != NULL, @"composer produces a frame");
        if (frameA) {
            Check(CGImageGetWidth(frameA) == 64 * 6, @"frame width matches columns");
            Check(CGImageGetHeight(frameA) == 16 * 6, @"frame height matches rows");
            NSData *pixelsA = PixelDataFromImage(frameA);
            NSUInteger litA = CountLitPixels(pixelsA);
            Check(litA > 0, @"frame contains lit LEDs at t=0");

            CGImageRef frameB = [composer copyFrameAtTime:0.4 cellSize:6.0];
            NSData *pixelsB = PixelDataFromImage(frameB);
            Check(![pixelsA isEqualToData:pixelsB], @"animation changes between frames");
            CGImageRelease(frameB);

            // Long gap between frames should normalize modulo the cycle and still render.
            CGImageRef frameC = [composer copyFrameAtTime:[composer cycleDuration] * 3.0 + 0.2
                                                 cellSize:6.0];
            Check(frameC != NULL, @"wrap-around time renders");
            CGImageRelease(frameC);
            CGImageRelease(frameA);

            // 2× font scaling.
            configuration.fontScale = 2;
            Check(configuration.messageColumns == 60, @"2× font doubles message width");
            CGImageRef bigFrame = [composer copyFrameAtTime:0.0 cellSize:6.0];
            NSData *bigPixels = PixelDataFromImage(bigFrame);
            NSUInteger bigLit = CountLitPixels(bigPixels);
            Check(bigLit > litA * 2, @"2× font covers more LEDs");
            CGImageRelease(bigFrame);
            configuration.fontScale = 1;
        }

        // Save a sample frame for visual inspection.
        configuration.message = @"HELLO LED";
        configuration.rows = 16;
        configuration.columns = 64;
        CGImageRef sample = [composer copyFrameAtTime:0.8 cellSize:12.0];
        if (sample) {
            NSURL *sampleURL = [NSURL fileURLWithPath:@"build/sample-frame.png"];
            CGImageDestinationRef sampleDestination = CGImageDestinationCreateWithURL(
                (__bridge CFURLRef)sampleURL, CFSTR("public.png"), 1, NULL);
            if (sampleDestination) {
                CGImageDestinationAddImage(sampleDestination, sample, NULL);
                CGImageDestinationFinalize(sampleDestination);
                CFRelease(sampleDestination);
                fprintf(stdout, "  --   wrote %s\n", sampleURL.path.UTF8String);
            }
            CGImageRelease(sample);
        }

        configuration.message = @"HELLO";
        configuration.fontScale = 2;
        CGImageRef sample2x = [composer copyFrameAtTime:0.0 cellSize:12.0];
        if (sample2x) {
            NSURL *sampleURL = [NSURL fileURLWithPath:@"build/sample-frame-2x.png"];
            CGImageDestinationRef sampleDestination = CGImageDestinationCreateWithURL(
                (__bridge CFURLRef)sampleURL, CFSTR("public.png"), 1, NULL);
            if (sampleDestination) {
                CGImageDestinationAddImage(sampleDestination, sample2x, NULL);
                CGImageDestinationFinalize(sampleDestination);
                CFRelease(sampleDestination);
                fprintf(stdout, "  --   wrote %s\n", sampleURL.path.UTF8String);
            }
            CGImageRelease(sample2x);
        }
        configuration.fontScale = 1;

        // GIF export.
        configuration.message = @"GIF TEST";
        configuration.rows = 8;
        configuration.columns = 32;
        configuration.scrollSpeed = 30.0;
        configuration.exportFPS = 15;
        configuration.exportDuration = 0.5;

        LEBGifExporter *gif = [[LEBGifExporter alloc] init];
        gif.configuration = [configuration copy];
        gif.fps = 15;
        gif.duration = 0.5;

        NSURL *gifURL = TemporaryFileURL(@"gif");
        NSError *exportError = nil;
        BOOL gifOK = WaitForExport(gif, gifURL, &exportError);
        Check(gifOK, [NSString stringWithFormat:@"GIF export completed (%@)", exportError.localizedDescription ?: @"no error"]);
        NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:gifURL.path
                                                                                   error:NULL];
        Check(attributes.fileSize > 1000, @"GIF file has content");
        if (attributes.fileSize > 0) {
            CGImageSourceRef source = CGImageSourceCreateWithURL((__bridge CFURLRef)gifURL, NULL);
            Check(source != NULL, @"GIF can be reopened");
            if (source) {
                size_t count = CGImageSourceGetCount(source);
                Check(count == 8, @"GIF frame count matches 15fps × 0.5s");
                NSDictionary *properties = CFBridgingRelease(CGImageSourceCopyPropertiesAtIndex(source, 0, NULL));
                NSDictionary *gifProperties = properties[(__bridge NSString *)kCGImagePropertyGIFDictionary];
                Check(gifProperties != nil, @"GIF frame metadata present");
                CFRelease(source);
            }
        }
        [[NSFileManager defaultManager] removeItemAtURL:gifURL error:NULL];

        // MP4 export.
        configuration.message = @"MP4";
        configuration.rows = 8;
        configuration.columns = 16;
        configuration.exportFPS = 15;
        configuration.exportDuration = 0.4;

        LEBVideoExporter *mp4 = [[LEBVideoExporter alloc] init];
        mp4.format = LEBExportFormatMP4;
        mp4.configuration = [configuration copy];
        mp4.fps = 15;
        mp4.duration = 0.4;

        NSURL *mp4URL = TemporaryFileURL(@"mp4");
        exportError = nil;
        BOOL mp4OK = WaitForExport(mp4, mp4URL, &exportError);
        Check(mp4OK, [NSString stringWithFormat:@"MP4 export completed (%@)", exportError.localizedDescription ?: @"no error"]);
        NSDictionary *mp4Attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:mp4URL.path
                                                                                       error:NULL];
        Check(mp4Attributes.fileSize > 1000, @"MP4 file has content");
        AVURLAsset *mp4Asset = [AVURLAsset URLAssetWithURL:mp4URL options:nil];
        Check(mp4Asset.tracks.count > 0, @"MP4 contains a video track");
        if (mp4Asset.tracks.count > 0) {
            AVAssetTrack *track = mp4Asset.tracks.firstObject;
            Check(track.naturalSize.width == 16 * 16, @"MP4 width matches columns × 16");
            Check(track.naturalSize.height == 8 * 16, @"MP4 height matches rows × 16");
        }
        [[NSFileManager defaultManager] removeItemAtURL:mp4URL error:NULL];

        // MOV / ProRes export.
        LEBVideoExporter *mov = [[LEBVideoExporter alloc] init];
        mov.format = LEBExportFormatMOV;
        mov.configuration = [configuration copy];
        mov.fps = 15;
        mov.duration = 0.4;

        NSURL *movURL = TemporaryFileURL(@"mov");
        exportError = nil;
        BOOL movOK = WaitForExport(mov, movURL, &exportError);
        Check(movOK, [NSString stringWithFormat:@"MOV export completed (%@)", exportError.localizedDescription ?: @"no error"]);
        NSDictionary *movAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:movURL.path
                                                                                       error:NULL];
        Check(movAttributes.fileSize > 1000, @"MOV file has content");
        [[NSFileManager defaultManager] removeItemAtURL:movURL error:NULL];

        fprintf(stdout, "\n%s (%d failure%s)\n",
                gFailures == 0 ? "PASS" : "FAIL",
                gFailures, gFailures == 1 ? "" : "s");
    }
    return gFailures == 0 ? 0 : 1;
}
