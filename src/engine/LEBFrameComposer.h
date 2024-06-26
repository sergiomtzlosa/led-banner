#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

@class LEBConfiguration;

/// Draws deterministic LED frames for a configuration at a given time.
/// The renderer never talks to AppKit UI and is safe to use on a background queue
/// as long as the configuration it holds is not mutated (exporters pass a copy).
@interface LEBFrameComposer : NSObject

@property (nonatomic, strong, readonly) LEBConfiguration *configuration;

- (instancetype)initWithConfiguration:(LEBConfiguration *)configuration NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

/// Seconds for one full scroll cycle, matching `LEBConfiguration.cycleDuration`.
- (NSTimeInterval)cycleDuration;

/// Draws a frame into an existing context. The context should be sized
/// `columns * cellSize` by `rows * cellSize` and ideally be BGRA.
- (void)drawFrameAtTime:(NSTimeInterval)time
              inContext:(CGContextRef)context
               cellSize:(CGFloat)cellSize;

/// Convenience: renders a new BGRA image. Caller owns the returned image.
- (CGImageRef)copyFrameAtTime:(NSTimeInterval)time
                     cellSize:(CGFloat)cellSize CF_RETURNS_RETAINED;

@end

NS_ASSUME_NONNULL_END
