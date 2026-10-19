#import "CharonMenus.h"
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static const void *HyphenationKey = &HyphenationKey;

@implementation NSLayoutManager (CharonText13)

- (BOOL)usesDefaultHyphenation
{
    return [objc_getAssociatedObject(self, HyphenationKey) boolValue];
}

- (void)setUsesDefaultHyphenation:(BOOL)usesDefaultHyphenation
{
    if (usesDefaultHyphenation)
        charon_menus_say_once(@"default-hyphenation", @"NSLayoutManager.usesDefaultHyphenation: the text system of iOS 6 hyphenates nothing by default, so the flag is kept and read back and lines break as before");
    objc_setAssociatedObject(self, HyphenationKey, @(usesDefaultHyphenation), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)showCGGlyphs:(const CGGlyph *)glyphs positions:(const CGPoint *)positions count:(NSUInteger)glyphCount font:(UIFont *)font textMatrix:(CGAffineTransform)textMatrix
          attributes:(NSDictionary<NSAttributedStringKey, id> *)attributes inContext:(CGContextRef)graphicsContext
{
    if (!glyphCount || !graphicsContext)
        return;
    UIColor *color = attributes[NSForegroundColorAttributeName];
    CGFontRef face = CGFontCreateWithFontName((__bridge CFStringRef)font.fontName);
    if (!face)
        return;
    CGContextSaveGState(graphicsContext);
    CGContextSetFillColorWithColor(graphicsContext, (color ? color : [UIColor blackColor]).CGColor);
    CGContextSetTextMatrix(graphicsContext, textMatrix);
    CGContextSetFont(graphicsContext, face);
    CGContextSetFontSize(graphicsContext, font.pointSize);
    CGContextShowGlyphsAtPositions(graphicsContext, glyphs, positions, glyphCount);
    CGContextRestoreGState(graphicsContext);
    CFRelease(face);
}

@end
