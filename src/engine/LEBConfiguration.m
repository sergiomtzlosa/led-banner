#import "LEBConfiguration.h"

NSString * const LEBConfigurationDidChangeNotification = @"LEBConfigurationDidChangeNotification";

@implementation LEBConfiguration

- (instancetype)init {
    self = [super init];
    if (self) {
        _message = [@"HELLO LED" copy];
        _rows = 16;
        _columns = 64;
        _fontScale = 1;
        _ledColor = [NSColor colorWithSRGBRed:0.98 green:0.20 blue:0.12 alpha:1.0];
        _backgroundColor = [NSColor colorWithSRGBRed:0.015 green:0.015 blue:0.02 alpha:1.0];
        _palette = LEBPaletteSolid;
        _ledShape = LEBLedShapeCircle;
        _dotRatio = 0.75;
        _scrollSpeed = 20.0;
        _glow = YES;
        _direction = LEBScrollDirectionRightToLeft;
        _exportFPS = 30;
        _exportDuration = 0.0;
    }
    return self;
}

- (void)setFontScale:(NSUInteger)fontScale {
    _fontScale = MIN(MAX(fontScale, (NSUInteger)1), (NSUInteger)4);
}

- (void)setLedColor:(NSColor *)ledColor {
    NSColor *converted = [ledColor colorUsingColorSpace:[NSColorSpace sRGBColorSpace]];
    _ledColor = [converted copy] ?: [NSColor redColor];
}

- (void)setBackgroundColor:(NSColor *)backgroundColor {
    NSColor *converted = [backgroundColor colorUsingColorSpace:[NSColorSpace sRGBColorSpace]];
    _backgroundColor = [converted copy] ?: [NSColor blackColor];
}

- (NSUInteger)messageColumns {
    return self.message.length * 6 * self.fontScale;
}

- (NSTimeInterval)cycleDuration {
    CGFloat speed = MAX(self.scrollSpeed, 1.0);
    CGFloat gap = MAX(self.columns * 0.5, 8.0);
    CGFloat distance = self.columns + (CGFloat)[self messageColumns] + gap;
    return MAX(distance / speed, 0.1);
}

- (void)notifyChanged {
    [[NSNotificationCenter defaultCenter] postNotificationName:LEBConfigurationDidChangeNotification
                                                        object:self];
}

- (id)copyWithZone:(NSZone *)zone {
    LEBConfiguration *copy = [[LEBConfiguration allocWithZone:zone] init];
    copy.message = self.message;
    copy.rows = self.rows;
    copy.columns = self.columns;
    copy.fontScale = self.fontScale;
    copy.ledColor = self.ledColor;
    copy.backgroundColor = self.backgroundColor;
    copy.palette = self.palette;
    copy.ledShape = self.ledShape;
    copy.dotRatio = self.dotRatio;
    copy.scrollSpeed = self.scrollSpeed;
    copy.glow = self.glow;
    copy.direction = self.direction;
    copy.exportFPS = self.exportFPS;
    copy.exportDuration = self.exportDuration;
    return copy;
}

@end
