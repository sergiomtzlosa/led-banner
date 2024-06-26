#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class LEBConfiguration;

extern NSString * const LEBExporterErrorDomain;

typedef NS_ENUM(NSInteger, LEBExporterErrorCode) {
    LEBExporterErrorCancelled = 1,
    LEBExporterErrorDestination,
    LEBExporterErrorWriting,
    LEBExporterErrorVideoSetup
};

typedef NS_ENUM(NSInteger, LEBExportFormat) {
    LEBExportFormatGIF = 0,
    LEBExportFormatMP4,
    LEBExportFormatMOV
};

typedef void (^LEBExportProgressHandler)(NSUInteger completedFrames, NSUInteger totalFrames);
typedef void (^LEBExportCompletionHandler)(NSError * _Nullable error);

@interface LEBExporter : NSObject

@property (nonatomic, copy) LEBConfiguration *configuration;
@property (nonatomic) NSUInteger fps;
/// Explicit duration in seconds. Values <= 0 mean "one automatic scroll cycle".
@property (nonatomic) NSTimeInterval duration;

@property (nonatomic, copy, nullable) LEBExportProgressHandler progressHandler;
@property (atomic, readonly, getter=isCancelled) BOOL cancelled;

- (void)cancel;

- (NSTimeInterval)effectiveDuration;
- (NSUInteger)frameCount;

/// Subclasses implement this. Completion is always called on the main thread.
- (void)exportToURL:(NSURL *)url completion:(LEBExportCompletionHandler)completion;

// Helpers for subclasses.
- (void)reportProgress:(NSUInteger)completed total:(NSUInteger)total;
- (void)finishWithError:(nullable NSError *)error
             completion:(LEBExportCompletionHandler)completion;
- (NSError *)errorWithCode:(NSInteger)code description:(NSString *)description;
- (void)removeFileAtURL:(NSURL *)url;

@end

@interface LEBGifExporter : LEBExporter
@end

@interface LEBVideoExporter : LEBExporter
/// Must be LEBExportFormatMP4 or LEBExportFormatMOV.
@property (nonatomic) LEBExportFormat format;
@end

NS_ASSUME_NONNULL_END
