#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString * const LEBConfigurationDidChangeNotification;

typedef NS_ENUM(NSInteger, LEBPalette) {
    LEBPaletteSolid = 0,
    LEBPalettePlasma,
    LEBPaletteRainbow
};

typedef NS_ENUM(NSInteger, LEBLedShape) {
    LEBLedShapeCircle = 0,
    LEBLedShapeSquare
};

typedef NS_ENUM(NSInteger, LEBScrollDirection) {
    LEBScrollDirectionRightToLeft = 0,
    LEBScrollDirectionLeftToRight
};

@interface LEBConfiguration : NSObject <NSCopying>

@property (nonatomic, copy) NSString *message;
@property (nonatomic) NSUInteger rows;
@property (nonatomic) NSUInteger columns;
/// Integer scale of the 5×7 glyphs (1–4). Each font pixel becomes fontScale × fontScale LEDs.
@property (nonatomic) NSUInteger fontScale;
@property (nonatomic, copy) NSColor *ledColor;
@property (nonatomic, copy) NSColor *backgroundColor;
@property (nonatomic) LEBPalette palette;
@property (nonatomic) LEBLedShape ledShape;
/// Diameter of a lit dot as a fraction of its cell (0.2 – 1.0).
@property (nonatomic) CGFloat dotRatio;
/// Scroll speed in LED columns per second.
@property (nonatomic) CGFloat scrollSpeed;
@property (nonatomic) BOOL glow;
@property (nonatomic) LEBScrollDirection direction;
@property (nonatomic) NSUInteger exportFPS;
/// Explicit export duration in seconds. 0 means one automatic scroll cycle.
@property (nonatomic) CGFloat exportDuration;

- (void)notifyChanged;

/// Width of the message in LED columns (6 columns per character).
- (NSUInteger)messageColumns;
/// Seconds for one complete scroll cycle (enter, cross, exit, gap).
- (NSTimeInterval)cycleDuration;

@end

NS_ASSUME_NONNULL_END
