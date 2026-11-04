#include "../revenant_impl.h"
#import <Foundation/Foundation.h>

NSString * const BACKPORT_IMPL(NSStringTransformLatinToKatakana) = @")kCFStringTransformLatinKatakana";
NSString * const BACKPORT_IMPL(NSStringTransformLatinToHiragana) = @")kCFStringTransformLatinHiragana";
NSString * const BACKPORT_IMPL(NSStringTransformLatinToHangul) = @")kCFStringTransformLatinHangul";
NSString * const BACKPORT_IMPL(NSStringTransformLatinToArabic) = @")kCFStringTransformLatinArabic";
NSString * const BACKPORT_IMPL(NSStringTransformLatinToHebrew) = @")kCFStringTransformLatinHebrew";
NSString * const BACKPORT_IMPL(NSStringTransformLatinToThai) = @")kCFStringTransformLatinThai";
NSString * const BACKPORT_IMPL(NSStringTransformLatinToCyrillic) = @")kCFStringTransformLatinCyrillic";
NSString * const BACKPORT_IMPL(NSStringTransformLatinToGreek) = @")kCFStringTransformLatinGreek";
NSString * const BACKPORT_IMPL(NSStringTransformToLatin) = @")kCFStringTransformToLatin";
NSString * const BACKPORT_IMPL(NSStringTransformMandarinToLatin) = @")kCFStringTransformMandarinLatin";
NSString * const BACKPORT_IMPL(NSStringTransformHiraganaToKatakana) = @")kCFStringTransformHiraganaKatakana";
NSString * const BACKPORT_IMPL(NSStringTransformFullwidthToHalfwidth) = @")kCFStringTransformFullwidthHalfwidth";
NSString * const BACKPORT_IMPL(NSStringTransformToXMLHex) = @")kCFStringTransformToXMLHex";
NSString * const BACKPORT_IMPL(NSStringTransformToUnicodeName) = @")kCFStringTransformToUnicodeName";
NSString * const BACKPORT_IMPL(NSStringTransformStripCombiningMarks) = @")kCFStringTransformStripCombiningMarks";
NSString * const BACKPORT_IMPL(NSStringTransformStripDiacritics) = @")kCFStringTransformStripDiacritics";

static const struct {
    const CFStringRef *identifier;
    __unsafe_unretained NSString *inverse;
} revenant_transforms[] = {
    {&kCFStringTransformLatinKatakana, @"Katakana-Latin"},
    {&kCFStringTransformLatinHiragana, @"Hiragana-Latin"},
    {&kCFStringTransformLatinHangul, @"Hangul-Latin"},
    {&kCFStringTransformLatinArabic, @"Arabic-Latin"},
    {&kCFStringTransformLatinHebrew, @"Hebrew-Latin"},
    {&kCFStringTransformLatinThai, @"Thai-Latin"},
    {&kCFStringTransformLatinCyrillic, @"Cyrillic-Latin"},
    {&kCFStringTransformLatinGreek, @"Greek-Latin"},
    {&kCFStringTransformToLatin, @"Latin-Any"},
    {&kCFStringTransformMandarinLatin, @"Latin-Han"},
    {&kCFStringTransformHiraganaKatakana, @"Katakana-Hiragana"},
    {&kCFStringTransformFullwidthHalfwidth, @"Halfwidth-Fullwidth"},
    {&kCFStringTransformToXMLHex, @"Hex/XML-Any"},
    {&kCFStringTransformToUnicodeName, @"Name-Any"},
    {&kCFStringTransformStripCombiningMarks, nil},
    {&kCFStringTransformStripDiacritics, nil}
};

static NSString *revenant_transform_swapped(NSString *step)
{
    NSRange separator = [step rangeOfString:@"-"];
    if (separator.location == NSNotFound)
        return nil;
    return [NSString stringWithFormat:@"%@-%@", [step substringFromIndex:NSMaxRange(separator)], [step substringToIndex:separator.location]];
}

static NSString *revenant_transform_inverse(NSString *transform)
{
    for (size_t index = 0; index < sizeof revenant_transforms / sizeof *revenant_transforms; index++) {
        if ([transform isEqualToString:(__bridge NSString *)*revenant_transforms[index].identifier])
            return revenant_transforms[index].inverse;
    }
    NSArray *steps = [transform componentsSeparatedByString:@";"];
    NSMutableArray *inverted = [NSMutableArray arrayWithCapacity:steps.count];
    for (NSString *step in steps) {
        NSString *swapped = revenant_transform_swapped([step stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]);
        if (!swapped)
            return nil;
        [inverted insertObject:swapped atIndex:0];
    }
    return [inverted componentsJoinedByString:@"; "];
}

static BOOL revenant_transform_reverses(void)
{
    static BOOL honoured;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSMutableString *probe = [@"\u30ab" mutableCopy];
        honoured = CFStringTransform((__bridge CFMutableStringRef)probe, NULL, kCFStringTransformLatinKatakana, true) && ![probe isEqualToString:@"\u30ab"];
    });
    return honoured;
}

static CFStringRef revenant_transform_identifier(NSString *transform, BOOL *reverse)
{
    if (*reverse && !revenant_transform_reverses()) {
        *reverse = NO;
        return (__bridge CFStringRef)revenant_transform_inverse(transform);
    }
    for (size_t index = 0; index < sizeof revenant_transforms / sizeof *revenant_transforms; index++) {
        if ([transform isEqualToString:(__bridge NSString *)*revenant_transforms[index].identifier])
            return *revenant_transforms[index].identifier;
    }
    return (__bridge CFStringRef)transform;
}

@implementation NSString (RevenantTransform)

- (NSString *)stringByApplyingTransform:(NSString *)transform reverse:(BOOL)reverse
{
    BOOL reversed = reverse;
    CFStringRef identifier = revenant_transform_identifier(transform, &reversed);
    if (!identifier)
        return nil;
    NSMutableString *transformed = [self mutableCopy];
    if (!CFStringTransform((__bridge CFMutableStringRef)transformed, NULL, identifier, reversed))
        return nil;
    return [transformed copy];
}

@end

@implementation NSMutableString (RevenantTransform)

- (BOOL)applyTransform:(NSString *)transform reverse:(BOOL)reverse range:(NSRange)range updatedRange:(NSRangePointer)resultingRange
{
    BOOL reversed = reverse;
    CFStringRef identifier = revenant_transform_identifier(transform, &reversed);
    if (!identifier)
        return NO;
    CFRange updated = CFRangeMake((CFIndex)range.location, (CFIndex)range.length);
    if (!CFStringTransform((__bridge CFMutableStringRef)self, &updated, identifier, reversed))
        return NO;
    if (resultingRange)
        *resultingRange = NSMakeRange((NSUInteger)updated.location, (NSUInteger)updated.length);
    return YES;
}

@end
