#import "LEBCanvasView.h"
#import "LEBConfiguration.h"
#import "LEBFrameComposer.h"

#import <QuartzCore/QuartzCore.h>

@interface LEBCanvasView ()
@property (nonatomic, strong) LEBFrameComposer *composer;
@property (nonatomic, strong) CALayer *panelLayer;
@property (nonatomic, strong) CALayer *ledLayer;
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, readwrite, getter=isPlaying) BOOL playing;
@property (nonatomic) NSTimeInterval lastTickTime;
@end

@implementation LEBCanvasView

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        self.wantsLayer = YES;
        self.layer.backgroundColor = [NSColor colorWithSRGBRed:0.09 green:0.09 blue:0.105 alpha:1.0].CGColor;

        _panelLayer = [CALayer layer];
        _panelLayer.backgroundColor = [NSColor blackColor].CGColor;
        _panelLayer.cornerRadius = 10.0;
        _panelLayer.borderWidth = 1.0;
        _panelLayer.borderColor = [NSColor colorWithSRGBRed:0.28 green:0.28 blue:0.31 alpha:1.0].CGColor;
        _panelLayer.masksToBounds = YES;
        _panelLayer.shadowColor = [NSColor blackColor].CGColor;
        _panelLayer.shadowOpacity = 0.55;
        _panelLayer.shadowRadius = 14.0;
        _panelLayer.shadowOffset = CGSizeMake(0, -4);
        [self.layer addSublayer:_panelLayer];

        _ledLayer = [CALayer layer];
        _ledLayer.contentsGravity = kCAGravityResize;
        _ledLayer.magnificationFilter = kCAFilterNearest;
        _ledLayer.minificationFilter = kCAFilterNearest;
        _ledLayer.backgroundColor = [NSColor blackColor].CGColor;
        [_panelLayer addSublayer:_ledLayer];

        _currentTime = 0;
        _playing = NO;

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(configurationChanged:)
                                                     name:LEBConfigurationDidChangeNotification
                                                   object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_timer invalidate];
}

- (void)setConfiguration:(LEBConfiguration *)configuration {
    _configuration = configuration;
    _composer = configuration ? [[LEBFrameComposer alloc] initWithConfiguration:configuration] : nil;
    _currentTime = 0;
    self.needsLayout = YES;
    [self refresh];
}

- (NSTimeInterval)cycleDuration {
    return self.composer ? [self.composer cycleDuration] : 1.0;
}

- (void)layout {
    [super layout];
    [self layoutPanel];
}

- (void)layoutPanel {
    if (!self.panelLayer || !self.configuration) {
        return;
    }
    CGFloat padding = 24.0;
    CGFloat availableWidth = MAX(self.bounds.size.width - padding * 2.0, 20.0);
    CGFloat availableHeight = MAX(self.bounds.size.height - padding * 2.0, 20.0);
    CGFloat aspect = (CGFloat)MAX(self.configuration.columns, (NSUInteger)1) /
                     (CGFloat)MAX(self.configuration.rows, (NSUInteger)1);

    CGFloat width = availableWidth;
    CGFloat height = width / aspect;
    if (height > availableHeight) {
        height = availableHeight;
        width = height * aspect;
    }

    CGRect panelFrame = CGRectMake(NSMidX(self.bounds) - width * 0.5,
                                   NSMidY(self.bounds) - height * 0.5,
                                   width, height);
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    self.panelLayer.frame = panelFrame;
    self.ledLayer.frame = self.panelLayer.bounds;
    [CATransaction commit];
}

- (NSUInteger)previewCellSize {
    NSUInteger columns = MAX(self.configuration.columns, (NSUInteger)1);
    NSInteger cell = (NSInteger)floor(1200.0 / (CGFloat)columns);
    return (NSUInteger)MIN(10, MAX(2, cell));
}

- (void)refresh {
    if (!self.composer || !self.ledLayer) {
        return;
    }
    NSUInteger cell = [self previewCellSize];
    CGImageRef image = [self.composer copyFrameAtTime:self.currentTime cellSize:cell];
    if (image) {
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        self.ledLayer.contents = (__bridge id)image;
        [CATransaction commit];
        CGImageRelease(image);
    }
    if (self.timeDidChangeHandler) {
        self.timeDidChangeHandler(self.currentTime, [self cycleDuration]);
    }
}

- (void)setCurrentTime:(NSTimeInterval)currentTime {
    NSTimeInterval cycle = MAX([self cycleDuration], 0.1);
    _currentTime = fmod(MAX(currentTime, 0.0), cycle);
    self.lastTickTime = CACurrentMediaTime();
    [self refresh];
}

- (void)play {
    if (self.playing || !self.composer) {
        return;
    }
    self.playing = YES;
    self.lastTickTime = CACurrentMediaTime();
    self.timer = [NSTimer timerWithTimeInterval:1.0 / 30.0
                                         target:self
                                       selector:@selector(tick:)
                                       userInfo:nil
                                        repeats:YES];
    self.timer.tolerance = 0.008;
    [[NSRunLoop mainRunLoop] addTimer:self.timer forMode:NSRunLoopCommonModes];
}

- (void)pause {
    if (!self.playing) {
        return;
    }
    self.playing = NO;
    [self.timer invalidate];
    self.timer = nil;
}

- (void)togglePlayback {
    if (self.playing) {
        [self pause];
    } else {
        [self play];
    }
}

- (void)tick:(NSTimer *)timer {
    NSTimeInterval now = CACurrentMediaTime();
    NSTimeInterval delta = now - self.lastTickTime;
    self.lastTickTime = now;
    if (delta < 0 || delta > 0.25) {
        delta = 1.0 / 30.0;
    }
    NSTimeInterval cycle = MAX([self cycleDuration], 0.1);
    _currentTime = fmod(_currentTime + delta, cycle);
    [self refresh];
}

- (void)configurationChanged:(NSNotification *)notification {
    if (notification.object != self.configuration) {
        return;
    }
    NSTimeInterval cycle = MAX([self cycleDuration], 0.1);
    _currentTime = fmod(_currentTime, cycle);
    self.needsLayout = YES;
    [self layoutPanel];
    [self refresh];
}

@end
