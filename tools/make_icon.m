// make_icon.m — renders the LED Banner app icon as an .iconset.
//
// The artwork is drawn from scratch with CoreGraphics (no assets, no external
// dependencies): a dark rounded-square panel with a dot-matrix display showing
// "LED" in the app's coral LED color. Glyph shapes come from LEBGlyphFont so the
// icon always matches the renderer.
//
// Usage: make-icon <output.iconset>

#import <Cocoa/Cocoa.h>
#import <ImageIO/ImageIO.h>
#import "LEBGlyphFont.h"

static const CGFloat kCanvasSize = 1024.0;
static const CGFloat kPanelInset = 100.0;
static const CGFloat kPanelRadius = 185.4;
static const CGFloat kScreenInset = 40.0;
static const CGFloat kScreenRadius = 138.0;

static const NSUInteger kGridColumns = 17;
static const NSUInteger kGridRows = 17;
static const NSUInteger kGlyphRows = 7;
static const NSUInteger kWordRow = 5; // first lit row, leaves 5 dim rows above/below
static const CGFloat kDotPitch = 41.5;
static const CGFloat kDotRadius = 13.2;

static void SetFill(CGContextRef ctx, CGFloat r, CGFloat g, CGFloat b, CGFloat a) {
    CGContextSetRGBFillColor(ctx, r, g, b, a);
}

static void SetStroke(CGContextRef ctx, CGFloat r, CGFloat g, CGFloat b, CGFloat a) {
    CGContextSetRGBStrokeColor(ctx, r, g, b, a);
}

static CGGradientRef CreateGradient(const CGFloat *components, const CGFloat *locations, size_t count) {
    CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGGradientRef gradient = CGGradientCreateWithColorComponents(space, components, locations, count);
    CGColorSpaceRelease(space);
    return gradient;
}

static CGPathRef CreateRoundedRect(CGRect rect, CGFloat radius) {
    return CGPathCreateWithRoundedRect(rect, radius, radius, NULL);
}

static void FillRoundedRectVerticalGradient(CGContextRef ctx, CGRect rect,
                                            CGFloat radius, CGGradientRef gradient) {
    CGPathRef path = CreateRoundedRect(rect, radius);
    CGContextSaveGState(ctx);
    CGContextAddPath(ctx, path);
    CGContextClip(ctx);
    CGContextDrawLinearGradient(ctx, gradient,
                                CGPointMake(CGRectGetMidX(rect), CGRectGetMaxY(rect)),
                                CGPointMake(CGRectGetMidX(rect), CGRectGetMinY(rect)), 0);
    CGContextRestoreGState(ctx);
    CGPathRelease(path);
}

// Draws a highlight ring just inside the panel edge. The ring fades from a
// bright top rim to a faint bottom rim, which keeps the icon from looking flat.
static void DrawPanelRim(CGContextRef ctx, CGRect panel, CGFloat radius, CGFloat width) {
    CGPathRef outer = CreateRoundedRect(panel, radius);
    CGRect innerRect = CGRectInset(panel, width, width);
    CGPathRef inner = CreateRoundedRect(innerRect, MAX(radius - width, 1.0));

    CGContextSaveGState(ctx);
    CGContextAddPath(ctx, outer);
    CGContextAddPath(ctx, inner);
    CGContextEOClip(ctx);

    CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGFloat components[] = {
        1.00, 1.00, 1.00, 0.26,
        1.00, 1.00, 1.00, 0.05,
        1.00, 1.00, 1.00, 0.00,
        1.00, 1.00, 1.00, 0.10,
    };
    CGFloat locations[] = { 0.0, 0.42, 0.62, 1.0 };
    CGGradientRef rim = CGGradientCreateWithColorComponents(space, components, locations, 4);
    CGColorSpaceRelease(space);

    CGContextDrawLinearGradient(ctx, rim,
                                CGPointMake(CGRectGetMidX(panel), CGRectGetMaxY(panel)),
                                CGPointMake(CGRectGetMidX(panel), CGRectGetMinY(panel)), 0);
    CGContextRestoreGState(ctx);

    CGGradientRelease(rim);
    CGPathRelease(inner);
    CGPathRelease(outer);
}

static void DrawScreen(CGContextRef ctx, CGRect screen) {
    CGPathRef path = CreateRoundedRect(screen, kScreenRadius);

    // Cut line between bezel and screen.
    CGContextSaveGState(ctx);
    CGContextAddPath(ctx, path);
    SetStroke(ctx, 0.0, 0.0, 0.0, 0.85);
    CGContextSetLineWidth(ctx, 6.0);
    CGContextStrokePath(ctx);
    CGContextRestoreGState(ctx);

    // Screen glass: near-black with a faint cool tint at the top.
    CGContextSaveGState(ctx);
    CGContextAddPath(ctx, path);
    CGContextClip(ctx);
    CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGFloat components[] = {
        0.045, 0.046, 0.055, 1.0,
        0.012, 0.012, 0.016, 1.0,
    };
    CGFloat locations[] = { 0.0, 1.0 };
    CGGradientRef glass = CGGradientCreateWithColorComponents(space, components, locations, 2);
    CGColorSpaceRelease(space);
    CGContextDrawLinearGradient(ctx, glass,
                                CGPointMake(CGRectGetMidX(screen), CGRectGetMaxY(screen)),
                                CGPointMake(CGRectGetMidX(screen), CGRectGetMinY(screen)), 0);
    CGGradientRelease(glass);
    CGContextRestoreGState(ctx);

    // Hairline screen bezel.
    CGContextSaveGState(ctx);
    CGContextAddPath(ctx, path);
    SetStroke(ctx, 1.0, 1.0, 1.0, 0.085);
    CGContextSetLineWidth(ctx, 2.0);
    CGContextStrokePath(ctx);
    CGContextRestoreGState(ctx);

    // Inset shadow at the top of the screen.
    CGContextSaveGState(ctx);
    CGContextAddPath(ctx, path);
    CGContextClip(ctx);
    CGRect top = CGRectMake(CGRectGetMinX(screen), CGRectGetMaxY(screen) - 26.0,
                            CGRectGetWidth(screen), 26.0);
    CGFloat shadeComponents[] = { 0.0, 0.0, 0.0, 0.55, 0.0, 0.0, 0.0, 0.0 };
    CGFloat shadeLocations[] = { 0.0, 1.0 };
    CGGradientRef shade = CreateGradient(shadeComponents, shadeLocations, 2);
    CGContextDrawLinearGradient(ctx, shade,
                                CGPointMake(CGRectGetMidX(top), CGRectGetMaxY(top)),
                                CGPointMake(CGRectGetMidX(top), CGRectGetMinY(top)), 0);
    CGGradientRelease(shade);
    CGContextRestoreGState(ctx);

    CGPathRelease(path);
}

// Gives the dot matrix a warm ambient bloom behind the lit glyphs.
static void DrawAmbientGlow(CGContextRef ctx, CGRect screen) {
    CGPathRef path = CreateRoundedRect(screen, kScreenRadius);
    CGContextSaveGState(ctx);
    CGContextAddPath(ctx, path);
    CGContextClip(ctx);
    CGContextTranslateCTM(ctx, CGRectGetMidX(screen), CGRectGetMidY(screen) + 18.0);
    CGContextScaleCTM(ctx, 1.35, 0.80);

    CGFloat components[] = {
        0.95, 0.22, 0.10, 0.16,
        0.85, 0.14, 0.05, 0.05,
        0.70, 0.08, 0.02, 0.00,
    };
    CGFloat locations[] = { 0.0, 0.55, 1.0 };
    CGGradientRef glow = CreateGradient(components, locations, 3);
    CGContextSetBlendMode(ctx, kCGBlendModePlusLighter);
    CGContextDrawRadialGradient(ctx, glow, CGPointZero, 0.0, CGPointZero, 330.0, 0);
    CGContextSetBlendMode(ctx, kCGBlendModeNormal);
    CGGradientRelease(glow);
    CGContextRestoreGState(ctx);
    CGPathRelease(path);
}

static void DrawOffDot(CGContextRef ctx, CGPoint center, CGGradientRef gradient) {
    CGContextSaveGState(ctx);
    CGContextAddEllipseInRect(ctx, CGRectMake(center.x - kDotRadius, center.y - kDotRadius,
                                              kDotRadius * 2.0, kDotRadius * 2.0));
    CGContextClip(ctx);
    CGContextDrawRadialGradient(ctx, gradient,
                                CGPointMake(center.x, center.y + kDotRadius * 0.30), 0.0,
                                center, kDotRadius, 0);
    CGContextRestoreGState(ctx);
}

static void DrawLitDot(CGContextRef ctx, CGPoint center,
                       CGGradientRef glow, CGGradientRef core) {
    // Bloom.
    CGContextSaveGState(ctx);
    CGContextSetBlendMode(ctx, kCGBlendModePlusLighter);
    CGContextDrawRadialGradient(ctx, glow, center, 0.0, center, kDotRadius * 3.2, 0);
    CGContextRestoreGState(ctx);

    // The LED itself, with an offset hotspot for a rounded, glassy look.
    CGContextSaveGState(ctx);
    CGContextAddEllipseInRect(ctx, CGRectMake(center.x - kDotRadius, center.y - kDotRadius,
                                              kDotRadius * 2.0, kDotRadius * 2.0));
    CGContextClip(ctx);
    CGPoint hotspot = CGPointMake(center.x - kDotRadius * 0.28,
                                  center.y + kDotRadius * 0.30);
    CGContextDrawRadialGradient(ctx, core, hotspot, 0.0, hotspot, kDotRadius * 1.7, 0);
    CGContextRestoreGState(ctx);

    // Specular pin.
    SetFill(ctx, 1.0, 0.88, 0.80, 0.38);
    CGRect spec = CGRectMake(center.x - kDotRadius * 0.55, center.y + kDotRadius * 0.38,
                             kDotRadius * 0.42, kDotRadius * 0.42);
    CGContextFillEllipseInRect(ctx, spec);
}

static BOOL WordIsLit(NSUInteger column, NSUInteger row) {
    if (row < kWordRow || row >= kWordRow + kGlyphRows) {
        return NO;
    }
    NSUInteger glyph = column / 6;
    NSUInteger glyphColumn = column % 6;
    if (glyph > 2 || glyphColumn >= 5) {
        return NO; // inter-character gap (or a trailing column)
    }

    unichar characters[] = { 'L', 'E', 'D' };
    uint8_t bits[7] = { 0 };
    if (![LEBGlyphFont getRows:bits forCharacter:characters[glyph]]) {
        return NO;
    }

    NSUInteger line = row - kWordRow;
    // Glyph rows are stored top-down, bit 4 is the leftmost pixel.
    return (bits[line] & (1u << (4 - glyphColumn))) != 0;
}

static void DrawDotMatrix(CGContextRef ctx, CGRect screen) {
    CGFloat pitch = kDotPitch;
    CGPoint origin = CGPointMake(CGRectGetMidX(screen) - pitch * (kGridColumns - 1) / 2.0,
                                 CGRectGetMidY(screen) - pitch * (kGridRows - 1) / 2.0);

    CGFloat offComponents[] = {
        0.72, 0.13, 0.08, 0.34,
        0.48, 0.07, 0.04, 0.16,
        0.28, 0.03, 0.01, 0.05,
    };
    CGFloat offLocations[] = { 0.0, 0.65, 1.0 };
    CGGradientRef off = CreateGradient(offComponents, offLocations, 3);

    CGFloat glowComponents[] = {
        1.00, 0.30, 0.14, 0.42,
        1.00, 0.22, 0.08, 0.16,
        1.00, 0.12, 0.03, 0.00,
    };
    CGFloat glowLocations[] = { 0.0, 0.36, 1.0 };
    CGGradientRef glow = CreateGradient(glowComponents, glowLocations, 3);

    CGFloat coreComponents[] = {
        1.00, 0.86, 0.72, 1.0,
        1.00, 0.53, 0.34, 1.0,
        1.00, 0.24, 0.09, 1.0,
        0.82, 0.06, 0.02, 1.0,
    };
    CGFloat coreLocations[] = { 0.0, 0.30, 0.66, 1.0 };
    CGGradientRef core = CreateGradient(coreComponents, coreLocations, 4);

    // Unlit pixels first, so the bloom of the lit pixels spills over them.
    for (NSUInteger row = 0; row < kGridRows; row++) {
        for (NSUInteger column = 0; column < kGridColumns; column++) {
            if (WordIsLit(column, row)) {
                continue;
            }
            CGPoint center = CGPointMake(origin.x + column * pitch, origin.y + row * pitch);
            DrawOffDot(ctx, center, off);
        }
    }

    for (NSUInteger row = 0; row < kGridRows; row++) {
        for (NSUInteger column = 0; column < kGridColumns; column++) {
            if (!WordIsLit(column, row)) {
                continue;
            }
            CGPoint center = CGPointMake(origin.x + column * pitch, origin.y + row * pitch);
            DrawLitDot(ctx, center, glow, core);
        }
    }

    CGGradientRelease(core);
    CGGradientRelease(glow);
    CGGradientRelease(off);
}

// A little light escapes the display and warms the surrounding bezel.
static void DrawScreenSpill(CGContextRef ctx, CGRect panel, CGRect screen) {
    CGPathRef panelPath = CreateRoundedRect(panel, kPanelRadius);
    CGContextSaveGState(ctx);
    CGContextAddPath(ctx, panelPath);
    CGContextClip(ctx);
    CGContextTranslateCTM(ctx, CGRectGetMidX(screen), CGRectGetMidY(screen));
    CGContextScaleCTM(ctx, 1.18, 1.00);

    CGFloat components[] = {
        0.90, 0.20, 0.07, 0.10,
        0.80, 0.12, 0.03, 0.035,
        0.70, 0.06, 0.01, 0.00,
    };
    CGFloat locations[] = { 0.0, 0.62, 1.0 };
    CGGradientRef glow = CreateGradient(components, locations, 3);
    CGContextSetBlendMode(ctx, kCGBlendModePlusLighter);
    CGContextDrawRadialGradient(ctx, glow, CGPointZero, 0.0, CGPointZero, 455.0, 0);
    CGContextSetBlendMode(ctx, kCGBlendModeNormal);
    CGGradientRelease(glow);
    CGContextRestoreGState(ctx);
    CGPathRelease(panelPath);
}

static void DrawIcon(CGContextRef ctx) {
    CGRect panel = CGRectMake(kPanelInset, kPanelInset,
                              kCanvasSize - kPanelInset * 2.0,
                              kCanvasSize - kPanelInset * 2.0);

    // Dark graphite bezel.
    CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGFloat bezelComponents[] = {
        0.195, 0.198, 0.225, 1.0,
        0.072, 0.073, 0.086, 1.0,
        0.034, 0.034, 0.043, 1.0,
    };
    CGFloat bezelLocations[] = { 0.0, 0.55, 1.0 };
    CGGradientRef bezel = CGGradientCreateWithColorComponents(space, bezelComponents,
                                                             bezelLocations, 3);
    CGColorSpaceRelease(space);
    FillRoundedRectVerticalGradient(ctx, panel, kPanelRadius, bezel);
    CGGradientRelease(bezel);

    DrawPanelRim(ctx, panel, kPanelRadius, 3.0);

    CGRect screen = CGRectInset(panel, kScreenInset, kScreenInset);
    DrawScreen(ctx, screen);
    DrawScreenSpill(ctx, panel, screen);
    DrawAmbientGlow(ctx, screen);
    DrawDotMatrix(ctx, screen);
}

static BOOL WritePNG(CGContextRef ctx, NSUInteger pixels, NSURL *url) {
    // Draw on a transparent canvas, scaled from the 1024-point design space.
    CGFloat scale = (CGFloat)pixels / kCanvasSize;
    CGContextSaveGState(ctx);
    CGContextScaleCTM(ctx, scale, scale);
    DrawIcon(ctx);
    CGContextRestoreGState(ctx);

    CGImageRef image = CGBitmapContextCreateImage(ctx);
    if (!image) {
        return NO;
    }

    CGImageDestinationRef destination =
        CGImageDestinationCreateWithURL((__bridge CFURLRef)url, CFSTR("public.png"), 1, NULL);
    if (!destination) {
        CGImageRelease(image);
        return NO;
    }

    NSDictionary *properties = @{
        (__bridge NSString *)kCGImagePropertyPNGDictionary: @{
            (__bridge NSString *)kCGImagePropertyPNGInterlaceType: @1,
        },
    };
    CGImageDestinationAddImage(destination, image, (__bridge CFDictionaryRef)properties);
    BOOL ok = CGImageDestinationFinalize(destination);
    CFRelease(destination);
    CGImageRelease(image);
    return ok;
}

static BOOL RenderPNG(NSUInteger pixels, NSURL *url) {
    CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGContextRef ctx = CGBitmapContextCreate(NULL, pixels, pixels, 8, 0, space,
                                             kCGImageAlphaPremultipliedLast |
                                             kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(space);
    if (!ctx) {
        return NO;
    }

    CGContextSetAllowsAntialiasing(ctx, true);
    CGContextSetShouldAntialias(ctx, true);
    CGContextSetInterpolationQuality(ctx, kCGInterpolationHigh);
    CGContextSetMiterLimit(ctx, 10.0);

    BOOL ok = WritePNG(ctx, pixels, url);
    CGContextRelease(ctx);
    return ok;
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc != 2) {
            fprintf(stderr, "usage: %s <output.iconset>\n", argv[0]);
            return 2;
        }

        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSString *outputPath = [NSString stringWithUTF8String:argv[1]];
        NSError *error = nil;
        if (![fileManager createDirectoryAtPath:outputPath
                    withIntermediateDirectories:YES
                                     attributes:nil
                                          error:&error]) {
            fprintf(stderr, "cannot create %s: %s\n", outputPath.UTF8String,
                    error.localizedDescription.UTF8String);
            return 1;
        }

        // name (without @2x) -> (points, pixels)
        NSArray *variants = @[
            @[ @"icon_16x16.png", @16, @16 ],
            @[ @"icon_16x16@2x.png", @16, @32 ],
            @[ @"icon_32x32.png", @32, @32 ],
            @[ @"icon_32x32@2x.png", @32, @64 ],
            @[ @"icon_128x128.png", @128, @128 ],
            @[ @"icon_128x128@2x.png", @128, @256 ],
            @[ @"icon_256x256.png", @256, @256 ],
            @[ @"icon_256x256@2x.png", @256, @512 ],
            @[ @"icon_512x512.png", @512, @512 ],
            @[ @"icon_512x512@2x.png", @512, @1024 ],
        ];

        for (NSArray *variant in variants) {
            NSString *name = variant[0];
            NSUInteger pixels = [variant[2] unsignedIntegerValue];
            NSURL *url = [NSURL fileURLWithPath:[outputPath stringByAppendingPathComponent:name]];
            if (!RenderPNG(pixels, url)) {
                fprintf(stderr, "failed to write %s\n", url.path.UTF8String);
                return 1;
            }
        }

        printf("Rendered %s\n", outputPath.UTF8String);
    }
    return 0;
}
