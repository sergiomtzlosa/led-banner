#import "LEBExporter.h"
#import "LEBConfiguration.h"

NSString * const LEBExporterErrorDomain = @"LEBExporterErrorDomain";

@interface LEBExporter ()
@property (atomic, readwrite, getter=isCancelled) BOOL cancelled;
@end

@implementation LEBExporter

- (instancetype)init {
    self = [super init];
    if (self) {
        _fps = 30;
        _duration = 0;
    }
    return self;
}

- (void)cancel {
    self.cancelled = YES;
}

- (NSTimeInterval)effectiveDuration {
    if (self.duration > 0) {
        return self.duration;
    }
    return MAX([self.configuration cycleDuration], 0.1);
}

- (NSUInteger)frameCount {
    NSTimeInterval seconds = [self effectiveDuration];
    NSUInteger fps = MAX(self.fps, (NSUInteger)1);
    NSUInteger count = (NSUInteger)llround(seconds * fps);
    return MIN(MAX(count, (NSUInteger)1), (NSUInteger)9000);
}

- (void)reportProgress:(NSUInteger)completed total:(NSUInteger)total {
    LEBExportProgressHandler handler = self.progressHandler;
    if (!handler) {
        return;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        handler(completed, total);
    });
}

- (void)finishWithError:(NSError *)error completion:(LEBExportCompletionHandler)completion {
    if (!completion) {
        return;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        completion(error);
    });
}

- (NSError *)errorWithCode:(NSInteger)code description:(NSString *)description {
    return [NSError errorWithDomain:LEBExporterErrorDomain
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey: description ?: @"Export failed."}];
}

- (void)removeFileAtURL:(NSURL *)url {
    if (url.path.length > 0) {
        [[NSFileManager defaultManager] removeItemAtURL:url error:NULL];
    }
}

- (void)exportToURL:(NSURL *)url completion:(LEBExportCompletionHandler)completion {
    [self doesNotRecognizeSelector:_cmd];
}

@end
