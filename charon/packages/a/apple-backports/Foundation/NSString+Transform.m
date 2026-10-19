#import <Foundation/Foundation.h>

NSString * const NSStringTransformLatinToKatakana = @")kCFStringTransformLatinKatakana";
NSString * const NSStringTransformLatinToHiragana = @")kCFStringTransformLatinHiragana";
NSString * const NSStringTransformLatinToHangul = @")kCFStringTransformLatinHangul";
NSString * const NSStringTransformLatinToArabic = @")kCFStringTransformLatinArabic";
NSString * const NSStringTransformLatinToHebrew = @")kCFStringTransformLatinHebrew";
NSString * const NSStringTransformLatinToThai = @")kCFStringTransformLatinThai";
NSString * const NSStringTransformLatinToCyrillic = @")kCFStringTransformLatinCyrillic";
NSString * const NSStringTransformLatinToGreek = @")kCFStringTransformLatinGreek";
NSString * const NSStringTransformToLatin = @")kCFStringTransformToLatin";
NSString * const NSStringTransformMandarinToLatin = @")kCFStringTransformMandarinLatin";
NSString * const NSStringTransformHiraganaToKatakana = @")kCFStringTransformHiraganaKatakana";
NSString * const NSStringTransformFullwidthToHalfwidth = @")kCFStringTransformFullwidthHalfwidth";
NSString * const NSStringTransformToXMLHex = @")kCFStringTransformToXMLHex";
NSString * const NSStringTransformToUnicodeName = @")kCFStringTransformToUnicodeName";
NSString * const NSStringTransformStripCombiningMarks = @")kCFStringTransformStripCombiningMarks";
NSString * const NSStringTransformStripDiacritics = @")kCFStringTransformStripDiacritics";

static const struct {
    const CFStringRef *identifier;
    __unsafe_unretained NSString *inverse;
} charon_transforms[] = {
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

static NSString *charon_transform_swapped(NSString *step)
{
    NSRange separator = [step rangeOfString:@"-"];
    if (separator.location == NSNotFound)
        return nil;
    return [NSString stringWithFormat:@"%@-%@", [step substringFromIndex:NSMaxRange(separator)], [step substringToIndex:separator.location]];
}

static NSString *charon_transform_inverse(NSString *transform)
{
    for (size_t index = 0; index < sizeof charon_transforms / sizeof *charon_transforms; index++) {
        if ([transform isEqualToString:(__bridge NSString *)*charon_transforms[index].identifier])
            return charon_transforms[index].inverse;
    }
    NSArray *steps = [transform componentsSeparatedByString:@";"];
    NSMutableArray *inverted = [NSMutableArray arrayWithCapacity:steps.count];
    for (NSString *step in steps) {
        NSString *swapped = charon_transform_swapped([step stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]);
        if (!swapped)
            return nil;
        [inverted insertObject:swapped atIndex:0];
    }
    return [inverted componentsJoinedByString:@"; "];
}

static BOOL charon_transform_reverses(void)
{
    static BOOL honoured;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSMutableString *probe = [@"\u30ab" mutableCopy];
        honoured = CFStringTransform((__bridge CFMutableStringRef)probe, NULL, kCFStringTransformLatinKatakana, true) && ![probe isEqualToString:@"\u30ab"];
    });
    return honoured;
}

static CFStringRef charon_transform_identifier(NSString *transform, BOOL *reverse)
{
    if (*reverse && !charon_transform_reverses()) {
        *reverse = NO;
        return (__bridge CFStringRef)charon_transform_inverse(transform);
    }
    for (size_t index = 0; index < sizeof charon_transforms / sizeof *charon_transforms; index++) {
        if ([transform isEqualToString:(__bridge NSString *)*charon_transforms[index].identifier])
            return *charon_transforms[index].identifier;
    }
    return (__bridge CFStringRef)transform;
}

@implementation NSString (CharonTransform)

- (NSString *)stringByApplyingTransform:(NSString *)transform reverse:(BOOL)reverse
{
    BOOL reversed = reverse;
    CFStringRef identifier = charon_transform_identifier(transform, &reversed);
    if (!identifier)
        return nil;
    NSMutableString *transformed = [self mutableCopy];
    if (!CFStringTransform((__bridge CFMutableStringRef)transformed, NULL, identifier, reversed))
        return nil;
    return [transformed copy];
}

@end

@implementation NSMutableString (CharonTransform)

- (BOOL)applyTransform:(NSString *)transform reverse:(BOOL)reverse range:(NSRange)range updatedRange:(NSRangePointer)resultingRange
{
    BOOL reversed = reverse;
    CFStringRef identifier = charon_transform_identifier(transform, &reversed);
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
