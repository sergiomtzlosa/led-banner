#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@class LEBConfiguration;

/// Live preview. Renders the LED matrix into a layer-backed panel using a display timer.
@interface LEBCanvasView : NSView

@property (nonatomic, strong) LEBConfiguration *configuration;
/// Current animation time in seconds.
@property (nonatomic) NSTimeInterval currentTime;
@property (nonatomic, getter=isPlaying, readonly) BOOL playing;

/// Called whenever the rendered time changes (timer tick, seek, config change).
@property (nonatomic, copy, nullable) void (^timeDidChangeHandler)(NSTimeInterval time, NSTimeInterval cycle);

- (void)play;
- (void)pause;
- (void)togglePlayback;
/// One full scroll cycle in seconds.
- (NSTimeInterval)cycleDuration;
/// Re-render the current frame immediately.
- (void)refresh;

@end

NS_ASSUME_NONNULL_END
