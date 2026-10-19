#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <stdlib.h>
#import "CharonMenus.h"

@interface NSLayoutManager (CharonNative)
- (NSUInteger)glyphAtIndex:(NSUInteger)index;
- (NSUInteger)glyphAtIndex:(NSUInteger)index isValidIndex:(BOOL *)valid;
- (BOOL)notShownAttributeForGlyphAtIndex:(NSUInteger)index;
- (CGRect *)rectArrayForGlyphRange:(NSRange)glyphRange withinSelectedGlyphRange:(NSRange)selected inTextContainer:(NSTextContainer *)container rectCount:(NSUInteger *)count;
- (void)getGlyphsInRange:(NSRange)range glyphs:(unsigned short *)glyphs characterIndexes:(NSUInteger *)characterIndexes glyphInscriptions:(NSUInteger *)inscriptions elasticBits:(BOOL *)elastic bidiLevels:(unsigned char *)levels;
- (void)textStorage:(NSTextStorage *)storage edited:(NSUInteger)mask range:(NSRange)range changeInLength:(NSInteger)delta invalidatedRange:(NSRange)invalidated;
- (void)insertGlyphs:(const unsigned int *)glyphs length:(NSUInteger)length forStartingGlyphAtIndex:(NSUInteger)glyphIndex characterIndex:(NSUInteger)characterIndex;
@end

static const void *GlyphPropertyOverridesKey = &GlyphPropertyOverridesKey;

typedef CGRect (*UsedRectIMP)(id, SEL, NSTextContainer *);
static UsedRectIMP native_used_rect;

static const void *LayingOutKey = &LayingOutKey;

static CGRect used_rect_for_container(NSLayoutManager *self, SEL selector, NSTextContainer *container)
{
    if (!objc_getAssociatedObject(self, LayingOutKey)) {
        objc_setAssociatedObject(self, LayingOutKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [self glyphRangeForTextContainer:container];
        objc_setAssociatedObject(self, LayingOutKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return native_used_rect(self, selector, container);
}

@interface CharonLayoutManager7 : NSObject
@end

@implementation CharonLayoutManager7

+ (void)load
{
    if ([NSLayoutManager instancesRespondToSelector:@selector(enumerateLineFragmentsForGlyphRange:usingBlock:)])
        return;
    Method method = class_getInstanceMethod([NSLayoutManager class], @selector(usedRectForTextContainer:));
    if (method) {
        native_used_rect = (UsedRectIMP)method_getImplementation(method);
        method_setImplementation(method, (IMP)used_rect_for_container);
    }
}

@end

@implementation NSLayoutManager (CharonText7)

- (CGGlyph)CGGlyphAtIndex:(NSUInteger)index
{
    return (CGGlyph)[self glyphAtIndex:index];
}

- (CGGlyph)CGGlyphAtIndex:(NSUInteger)index isValidIndex:(BOOL *)valid
{
    return (CGGlyph)[self glyphAtIndex:index isValidIndex:valid];
}

- (void)enumerateLineFragmentsForGlyphRange:(NSRange)glyphRange usingBlock:(void (^)(CGRect, CGRect, NSTextContainer *, NSRange, BOOL *))block
{
    NSUInteger index = glyphRange.location, end = NSMaxRange(glyphRange);
    BOOL stop = NO;
    while (index < end && !stop) {
        NSRange fragment;
        CGRect rect = [self lineFragmentRectForGlyphAtIndex:index effectiveRange:&fragment];
        CGRect used = [self lineFragmentUsedRectForGlyphAtIndex:index effectiveRange:NULL];
        NSTextContainer *container = [self textContainerForGlyphAtIndex:index effectiveRange:NULL];
        block(rect, used, container, fragment, &stop);
        if (!fragment.length)
            break;
        index = NSMaxRange(fragment);
    }
}

- (void)enumerateEnclosingRectsForGlyphRange:(NSRange)glyphRange withinSelectedGlyphRange:(NSRange)selectedRange inTextContainer:(NSTextContainer *)container usingBlock:(void (^)(CGRect, BOOL *))block
{
    NSUInteger count = 0;
    CGRect *rects = [self rectArrayForGlyphRange:glyphRange withinSelectedGlyphRange:selectedRange inTextContainer:container rectCount:&count];
    BOOL stop = NO;
    for (NSUInteger index = 0; index < count && !stop; index++)
        block(rects[index], &stop);
}

- (void)setGlyphs:(const CGGlyph *)glyphs properties:(const NSGlyphProperty *)props characterIndexes:(const NSUInteger *)characterIndexes font:(UIFont *)aFont forGlyphRange:(NSRange)glyphRange
{
    NSUInteger count = glyphRange.length;
    if (count) {
        for (NSUInteger offset = 0; offset < count; offset++) {
            unsigned int nativeGlyph = (unsigned int)glyphs[offset];
            NSUInteger characterIndex = characterIndexes ? characterIndexes[offset] : [self characterIndexForGlyphAtIndex:glyphRange.location + offset];
            [self insertGlyphs:&nativeGlyph length:1 forStartingGlyphAtIndex:glyphRange.location + offset characterIndex:characterIndex];
        }
    }
    if (aFont && characterIndexes && count) {
        NSDictionary *attributes = [self.textStorage attributesAtIndex:characterIndexes[0] effectiveRange:NULL];
        UIFont *attributeFont = attributes[NSFontAttributeName];
        if (attributeFont && (![attributeFont.fontName isEqualToString:aFont.fontName] || attributeFont.pointSize != aFont.pointSize))
            charon_menus_say_once(@"glyph-font-substitution", @"-[NSLayoutManager setGlyphs:properties:characterIndexes:font:forGlyphRange:] "
                @"was given a font that differs from the character's own font attribute (a substitution, e.g. font fallback); "
                @"the glyphs are stored, but nothing in this port measures or draws glyphs against a per-glyph substituted font yet, "
                @"so metrics and drawing use the character's own attribute, not the font this call named");
    }
    if (props) {
        NSMutableDictionary *overrides = objc_getAssociatedObject(self, GlyphPropertyOverridesKey);
        if (!overrides) {
            overrides = [NSMutableDictionary dictionary];
            objc_setAssociatedObject(self, GlyphPropertyOverridesKey, overrides, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        for (NSUInteger offset = 0; offset < count; offset++)
            overrides[@(glyphRange.location + offset)] = @(props[offset]);
    }
}

- (NSGlyphProperty)propertyForGlyphAtIndex:(NSUInteger)index
{
    NSNumber *overridden = objc_getAssociatedObject(self, GlyphPropertyOverridesKey)[@(index)];
    if (overridden)
        return (NSGlyphProperty)overridden.unsignedIntegerValue;
    NSGlyphProperty property = 0;
    BOOL elastic = NO;
    unsigned short glyph;
    [self getGlyphsInRange:NSMakeRange(index, 1) glyphs:&glyph characterIndexes:NULL glyphInscriptions:NULL elasticBits:&elastic bidiLevels:NULL];
    unichar character = [self.textStorage.string characterAtIndex:[self characterIndexForGlyphAtIndex:index]];
    if ([[NSCharacterSet controlCharacterSet] characterIsMember:character])
        property |= NSGlyphPropertyControlCharacter;
    else if (elastic)
        property |= NSGlyphPropertyElastic;
    else if ([self notShownAttributeForGlyphAtIndex:index])
        property |= NSGlyphPropertyNull;
    if ([[NSCharacterSet nonBaseCharacterSet] characterIsMember:character])
        property |= NSGlyphPropertyNonBaseCharacter;
    return property;
}

- (void)getGlyphsInRange:(NSRange)range glyphs:(CGGlyph *)glyphs properties:(NSGlyphProperty *)properties characterIndexes:(NSUInteger *)characterIndexes bidiLevels:(unsigned char *)bidiLevels
{
    [self getGlyphsInRange:range glyphs:glyphs characterIndexes:characterIndexes glyphInscriptions:NULL elasticBits:NULL bidiLevels:bidiLevels];
    if (properties)
        for (NSUInteger offset = 0; offset < range.length; offset++)
            properties[offset] = [self propertyForGlyphAtIndex:range.location + offset];
}

- (NSRange)truncatedGlyphRangeInLineFragmentForGlyphAtIndex:(NSUInteger)glyphIndex
{
    return NSMakeRange(NSNotFound, 0);
}

- (void)processEditingForTextStorage:(NSTextStorage *)textStorage edited:(NSTextStorageEditActions)editMask range:(NSRange)newCharRange changeInLength:(NSInteger)delta invalidatedRange:(NSRange)invalidatedCharRange
{
    [self textStorage:textStorage edited:editMask range:newCharRange changeInLength:delta invalidatedRange:invalidatedCharRange];
}

@end
