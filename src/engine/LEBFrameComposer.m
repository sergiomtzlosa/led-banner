#import "LEBFrameComposer.h"
#import "LEBConfiguration.h"
#import "LEBGlyphFont.h"

#import <math.h>

static void LEBGetSRGBComponents(NSColor *color, CGFloat *r, CGFloat *g, CGFloat *b) {
    NSColor *converted = [color colorUsingColorSpace:[NSColorSpace sRGBColorSpace]];
    if (!converted) {
        converted = [NSColor whiteColor];
    }
    CGFloat ignoredAlpha = 1.0;
    [converted getRed:r green:g blue:b alpha:&ignoredAlpha];
}

static void LEBHSVToRGB(CGFloat h, CGFloat s, CGFloat v,
                        CGFloat *outR, CGFloat *outG, CGFloat *outB) {    h = h - floor(h);
    CGFloat hh = h * 6.0;
    NSInteger sector = (NSInteger)floor(hh);
    CGFloat f = hh - sector;
    CGFloat p = v * (1.0 - s);
    CGFloat q = v * (1.0 - f * s);
    CGFloat t = v * (1.0 - (1.0 - f) * s);

    CGFloat r = 0, g = 0, b = 0;
    switch (sector % 6) {
        case 0: r = v; g = t; b = p; break;
        case 1: r = q; g = v; b = p; break;
        case 2: r = p; g = v; b = t; break;
        case 3: r = p; g = q; b = v; break;
        case 4: r = t; g = p; b = v; break;
        default: r = v; g = p; b = q; break;
    }
    *outR = r; *outG = g; *outB = b;
}

@interface LEBFrameComposer () {
    CGImageRef _backgroundImage;
    NSUInteger _bgRows;
    NSUInteger _bgColumns;
    CGFloat _bgCellSize;
    CGFloat _bgDiameter;
    BOOL _bgSquare;
    CGFloat _bgR, _bgG, _bgB;
    CGFloat _bgLedR, _bgLedG, _bgLedB;
}
@end

@implementation LEBFrameComposer

- (instancetype)initWithConfiguration:(LEBConfiguration *)configuration {
    self = [super init];
    if (self) {
        _configuration = configuration;
    }
    return self;
}

- (void)dealloc {
    if (_backgroundImage) {
        CGImageRelease(_backgroundImage);
    }
}

- (NSTimeInterval)cycleDuration {
    return [self.configuration cycleDuration];
}

- (CGRect)dotRectForRow:(NSUInteger)row
                 column:(NSUInteger)column
                  rows:(NSUInteger)rows
               cellSize:(CGFloat)cell
               diameter:(CGFloat)diameter {
    CGFloat x = column * cell + (cell - diameter) * 0.5;
    CGFloat y = (rows - 1 - row) * cell + (cell - diameter) * 0.5;
    return CGRectMake(x, y, diameter, diameter);
}

- (void)addDotForRow:(NSUInteger)row
              column:(NSUInteger)column
                rows:(NSUInteger)rows
            cellSize:(CGFloat)cell
            diameter:(CGFloat)diameter
                path:(CGMutablePathRef)path
              square:(BOOL)square {
    CGRect rect = [self dotRectForRow:row column:column rows:rows cellSize:cell diameter:diameter];
    if (square) {
        CGPathAddRoundedRect(path, NULL, rect, diameter * 0.14, diameter * 0.14);
    } else {
        CGPathAddEllipseInRect(path, NULL, rect);
    }
}

- (CGImageRef)copyBackgroundImageForColumns:(NSUInteger)columns
                                       rows:(NSUInteger)rows
                                   cellSize:(CGFloat)cell
                                   diameter:(CGFloat)diameter
                                     square:(BOOL)square
                                        bgR:(CGFloat)bgR bgG:(CGFloat)bgG bgB:(CGFloat)bgB
                                      ledR:(CGFloat)ledR ledG:(CGFloat)ledG ledB:(CGFloat)ledB {
    size_t width = (size_t)llround((CGFloat)columns * cell);
    size_t height = (size_t)llround((CGFloat)rows * cell);
    if (width == 0 || height == 0) {
        return NULL;
    }
    CGColorSpaceRef colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGContextRef context = CGBitmapContextCreate(NULL, width, height, 8, width * 4, colorSpace,
                                                 kCGBitmapByteOrder32Little |
                                                 kCGImageAlphaPremultipliedFirst);
    CGColorSpaceRelease(colorSpace);
    if (!context) {
        return NULL;
    }

    CGContextSetRGBFillColor(context, bgR, bgG, bgB, 1.0);
    CGContextFillRect(context, CGRectMake(0, 0, columns * cell, rows * cell));

    if (rows * columns <= 20000) {
        CGMutablePathRef dim = CGPathCreateMutable();
        for (NSUInteger r = 0; r < rows; r++) {
            for (NSUInteger c = 0; c < columns; c++) {
                [self addDotForRow:r column:c rows:rows cellSize:cell
                          diameter:diameter * 0.92 path:dim square:square];
            }
        }
        CGContextSetRGBFillColor(context, ledR, ledG, ledB, 0.075);
        CGContextAddPath(context, dim);
        CGContextFillPath(context);
        CGPathRelease(dim);
    }

    CGImageRef image = CGBitmapContextCreateImage(context);
    CGContextRelease(context);
    return image;
}

- (void)drawFrameAtTime:(NSTimeInterval)time
              inContext:(CGContextRef)context
               cellSize:(CGFloat)cellSize {
    LEBConfiguration *config = self.configuration;
    NSUInteger columns = MAX(config.columns, (NSUInteger)8);
    NSUInteger rows = MAX(config.rows, (NSUInteger)1);
    if (!context || cellSize <= 0) {
        return;
    }

    CGFloat cell = cellSize;
    CGFloat diameter = cell * MAX(MIN(config.dotRatio, 1.0), 0.2);
    BOOL square = (config.ledShape == LEBLedShapeSquare);

    CGFloat bgR = 0, bgG = 0, bgB = 0;
    LEBGetSRGBComponents(config.backgroundColor, &bgR, &bgG, &bgB);

    CGFloat baseR = 0, baseG = 0, baseB = 0;
    LEBGetSRGBComponents(config.ledColor, &baseR, &baseG, &baseB);

    CGContextSaveGState(context);
    CGContextSetShouldAntialias(context, YES);
    CGContextSetAllowsAntialiasing(context, YES);

    BOOL cacheValid = _backgroundImage != NULL &&
        _bgRows == rows && _bgColumns == columns &&
        fabs(_bgCellSize - cell) < 0.0001 &&
        fabs(_bgDiameter - diameter) < 0.0001 &&
        _bgSquare == square &&
        fabs(_bgR - bgR) < 0.0001 && fabs(_bgG - bgG) < 0.0001 && fabs(_bgB - bgB) < 0.0001 &&
        fabs(_bgLedR - baseR) < 0.0001 && fabs(_bgLedG - baseG) < 0.0001 &&
        fabs(_bgLedB - baseB) < 0.0001;

    if (!cacheValid) {
        if (_backgroundImage) {
            CGImageRelease(_backgroundImage);
            _backgroundImage = NULL;
        }
        _backgroundImage = [self copyBackgroundImageForColumns:columns rows:rows
                                                     cellSize:cell diameter:diameter square:square
                                                          bgR:bgR bgG:bgG bgB:bgB
                                                         ledR:baseR ledG:baseG ledB:baseB];
        _bgRows = rows;
        _bgColumns = columns;
        _bgCellSize = cell;
        _bgDiameter = diameter;
        _bgSquare = square;
        _bgR = bgR; _bgG = bgG; _bgB = bgB;
        _bgLedR = baseR; _bgLedG = baseG; _bgLedB = baseB;
    }

    if (_backgroundImage) {
        CGContextDrawImage(context,
                           CGRectMake(0, 0, columns * cell, rows * cell),
                           _backgroundImage);
    }

    NSString *message = config.message ?: @"";
    NSUInteger messageLength = message.length;
    NSUInteger fontScale = MAX(config.fontScale, (NSUInteger)1);
    NSInteger advance = (NSInteger)[LEBGlyphFont advance] * (NSInteger)fontScale;
    NSInteger messageColumns = (NSInteger)messageLength * advance;
    if (messageLength == 0 || messageColumns <= 0) {
        CGContextRestoreGState(context);
        return;
    }

    // Pre-decode the message into glyph rows once per frame.
    uint8_t *glyphs = calloc(messageLength * 7, sizeof(uint8_t));
    if (!glyphs) {
        CGContextRestoreGState(context);
        return;
    }
    for (NSUInteger i = 0; i < messageLength; i++) {
        uint8_t decoded[7] = {0};
        [LEBGlyphFont getRows:decoded forCharacter:[message characterAtIndex:i]];
        memcpy(glyphs + i * 7, decoded, 7);
    }

    // Scroll geometry: one cycle = enter + cross + exit + gap.
    CGFloat gap = MAX((CGFloat)columns * 0.5, 8.0);
    CGFloat travel = (CGFloat)columns + (CGFloat)messageColumns + gap;
    CGFloat speed = MAX(config.scrollSpeed, 1.0);
    CGFloat offset = fmod(time * speed + messageColumns, travel);
    if (offset < 0) {
        offset += travel;
    }

    CGFloat textStartX = (config.direction == LEBScrollDirectionRightToLeft)
        ? (CGFloat)columns - offset
        : offset - (CGFloat)messageColumns;

    NSInteger glyphHeight = (NSInteger)[LEBGlyphFont glyphHeight] * (NSInteger)fontScale;
    NSInteger rowOffset = (NSInteger)floor(((CGFloat)rows - (CGFloat)glyphHeight) * 0.5);
    CGFloat sampleOffsets[2] = {0.25, 0.75};

    // With a solid palette every dot has the same color, so batch all columns into
    // three paths (glow, full coverage, partial coverage) instead of drawing per column.
    BOOL solidPalette = (config.palette == LEBPaletteSolid);
    CGMutablePathRef sharedFull = solidPalette ? CGPathCreateMutable() : NULL;
    CGMutablePathRef sharedPartial = solidPalette ? CGPathCreateMutable() : NULL;
    CGMutablePathRef sharedGlow = (solidPalette && config.glow) ? CGPathCreateMutable() : NULL;

    for (NSUInteger c = 0; c < columns; c++) {
        // Columns completely outside the text can be skipped entirely.
        if ((CGFloat)c + 1.0 <= textStartX ||
            (CGFloat)c >= textStartX + (CGFloat)messageColumns) {
            continue;
        }

        CGFloat colR = baseR, colG = baseG, colB = baseB;
        if (config.palette == LEBPaletteRainbow) {
            CGFloat hue = (CGFloat)c / (CGFloat)columns * 0.92;
            LEBHSVToRGB(hue, 0.82, 1.0, &colR, &colG, &colB);
        } else if (config.palette == LEBPalettePlasma) {
            CGFloat hue = (CGFloat)c * 0.011 + (CGFloat)time * 0.09;
            LEBHSVToRGB(hue, 0.80, 1.0, &colR, &colG, &colB);
        }

        CGMutablePathRef fullPath = solidPalette ? sharedFull : CGPathCreateMutable();
        CGMutablePathRef partialPath = solidPalette ? sharedPartial : CGPathCreateMutable();
        CGMutablePathRef glowPath = NULL;
        if (config.glow) {
            glowPath = solidPalette ? sharedGlow : CGPathCreateMutable();
        }
        BOOL anyFull = NO, anyPartial = NO, anyLit = NO;

        for (NSUInteger r = 0; r < rows; r++) {
            NSInteger relativeRow = (NSInteger)r - rowOffset;
            if (relativeRow < 0) {
                continue;
            }
            NSInteger glyphRow = relativeRow / (NSInteger)fontScale;
            if (glyphRow >= (NSInteger)[LEBGlyphFont glyphHeight]) {
                continue;
            }
            NSInteger hits = 0;
            for (NSInteger s = 0; s < 2; s++) {
                CGFloat sampleX = (CGFloat)c + sampleOffsets[s];
                CGFloat localX = sampleX - textStartX;
                if (localX < 0 || localX >= (CGFloat)messageColumns) {
                    continue;
                }
                NSInteger index = (NSInteger)floor(localX);
                NSInteger charIndex = index / advance;
                NSInteger withinGlyph = index % advance;
                NSInteger columnInGlyph = withinGlyph / (NSInteger)fontScale;
                if (charIndex < 0 || charIndex >= (NSInteger)messageLength ||
                    columnInGlyph >= (NSInteger)[LEBGlyphFont glyphWidth]) {
                    continue;
                }
                uint8_t bits = glyphs[charIndex * 7 + glyphRow];
                if ((bits >> (4 - columnInGlyph)) & 0x01) {
                    hits++;
                }
            }

            if (hits == 0) {
                continue;
            }

            anyLit = YES;
            if (hits == 2) {
                [self addDotForRow:r column:c rows:rows cellSize:cell
                          diameter:diameter path:fullPath square:square];
                if (glowPath) {
                    [self addDotForRow:r column:c rows:rows cellSize:cell
                              diameter:diameter * 1.85 path:glowPath square:NO];
                }
                anyFull = YES;
            } else {
                [self addDotForRow:r column:c rows:rows cellSize:cell
                          diameter:diameter path:partialPath square:square];
                if (glowPath) {
                    [self addDotForRow:r column:c rows:rows cellSize:cell
                              diameter:diameter * 1.85 path:glowPath square:NO];
                }
                anyPartial = YES;
            }
        }

        if (!solidPalette) {
            if (anyLit) {
                if (glowPath) {
                    CGContextSetBlendMode(context, kCGBlendModePlusLighter);
                    CGContextSetRGBFillColor(context, colR, colG, colB, 0.20);
                    CGContextAddPath(context, glowPath);
                    CGContextFillPath(context);
                    CGContextSetBlendMode(context, kCGBlendModeNormal);
                }

                if (anyFull) {
                    CGContextSetRGBFillColor(context, colR, colG, colB, 1.0);
                    CGContextAddPath(context, fullPath);
                    CGContextFillPath(context);
                }
                if (anyPartial) {
                    CGContextSetRGBFillColor(context, colR, colG, colB, 0.55);
                    CGContextAddPath(context, partialPath);
                    CGContextFillPath(context);
                }
            }

            CGPathRelease(fullPath);
            CGPathRelease(partialPath);
            if (glowPath) {
                CGPathRelease(glowPath);
            }
        }
    }

    if (solidPalette) {
        if (sharedGlow) {
            CGContextSetBlendMode(context, kCGBlendModePlusLighter);
            CGContextSetRGBFillColor(context, baseR, baseG, baseB, 0.20);
            CGContextAddPath(context, sharedGlow);
            CGContextFillPath(context);
            CGContextSetBlendMode(context, kCGBlendModeNormal);
        }
        CGContextSetRGBFillColor(context, baseR, baseG, baseB, 1.0);
        CGContextAddPath(context, sharedFull);
        CGContextFillPath(context);
        CGContextSetRGBFillColor(context, baseR, baseG, baseB, 0.55);
        CGContextAddPath(context, sharedPartial);
        CGContextFillPath(context);

        CGPathRelease(sharedFull);
        CGPathRelease(sharedPartial);
        if (sharedGlow) {
            CGPathRelease(sharedGlow);
        }
    }

    free(glyphs);
    CGContextRestoreGState(context);
}

- (CGImageRef)copyFrameAtTime:(NSTimeInterval)time
                     cellSize:(CGFloat)cellSize CF_RETURNS_RETAINED {
    LEBConfiguration *config = self.configuration;
    NSUInteger columns = MAX(config.columns, (NSUInteger)8);
    NSUInteger rows = MAX(config.rows, (NSUInteger)1);
    size_t width = (size_t)llround((CGFloat)columns * cellSize);
    size_t height = (size_t)llround((CGFloat)rows * cellSize);
    if (width == 0 || height == 0) {
        return NULL;
    }

    CGColorSpaceRef colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGContextRef context = CGBitmapContextCreate(NULL, width, height, 8, width * 4,
                                                 colorSpace,
                                                 kCGBitmapByteOrder32Little |
                                                 kCGImageAlphaPremultipliedFirst);
    CGColorSpaceRelease(colorSpace);
    if (!context) {
        return NULL;
    }

    [self drawFrameAtTime:time inContext:context cellSize:cellSize];
    CGImageRef image = CGBitmapContextCreateImage(context);
    CGContextRelease(context);
    return image;
}

@end
