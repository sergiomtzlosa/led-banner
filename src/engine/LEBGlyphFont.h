#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// A hand-encoded 5×7 bitmap font suitable for LED signage.
/// Lowercase letters are treated as uppercase; unsupported characters render as '?'.
@interface LEBGlyphFont : NSObject

+ (NSUInteger)glyphWidth;
+ (NSUInteger)glyphHeight;
+ (NSUInteger)advance;

/// Fills `rows` with seven 5-bit rows (bit 4 is the leftmost column).
/// A space yields seven zero rows. Returns NO for unknown characters.
+ (BOOL)getRows:(uint8_t *)rows forCharacter:(unichar)character;

@end

NS_ASSUME_NONNULL_END
