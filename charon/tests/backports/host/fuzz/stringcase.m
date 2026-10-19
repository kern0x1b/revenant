#import <Foundation/Foundation.h>
#import <objc/message.h>

#import "fuzz.h"

void host_attach_prefixed(const char *prefix);
static uint32_t roll(uint32_t n) { return fuzz_roll(n); }

static NSString *word(void)
{
    NSArray *pieces = @[@"a", @"A", @"e", @"é", @"É", @"ß", @"SS", @"ss", @"İ", @"i", @"I", @"ı", @"Σ", @"σ", @"ς",
                        @"Ａ", @"ａ", @"ﬁ", @"fi", @"Å", @"Å", @"Å", @"и", @"И", @"й", @"й", @" ",
                        @"-", @"1", @"١", @"½", @"あ", @"ア", @"ｱ", @"中", @"\U0001F600", @"́", @"o", @"O", @"ö",
                        @"œ", @"oe", @"ǅ", @"Ǆ", @"ǆ", @"ẞ", @"µ", @"μ"];
    NSMutableString *made = [NSMutableString string];
    uint32_t count = roll(7);
    for (uint32_t i = 0; i < count; i++)
        [made appendString:pieces[roll((uint32_t)pieces.count)]];
    return made;
}

static NSString *shown(id value)
{
    if (!value)
        return @"nil";
    if ([value isKindOfClass:[NSValue class]] && strcmp([value objCType], @encode(NSRange)) == 0)
        return NSStringFromRange([value rangeValue]);
    if ([value isKindOfClass:[NSNumber class]])
        return [value description];
    NSMutableString *made = [NSMutableString string];
    NSString *string = value;
    for (NSUInteger i = 0; i < string.length; i++) {
        unichar c = [string characterAtIndex:i];
        if (c >= 0x20 && c < 0x7f)
            [made appendFormat:@"%C", c];
        else
            [made appendFormat:@"\\u%04x", c];
    }
    return made;
}

static SEL named(NSString *selector, BOOL ours)
{
    return NSSelectorFromString(ours ? [@"charonHost_" stringByAppendingString:selector] : selector);
}


static NSString *one(NSString *subject, NSString *selector, id argument, BOOL ours)
{
    @try {
        SEL chosen = named(selector, ours);
        if ([selector isEqualToString:@"localizedStandardRangeOfString:"])
            return shown([NSValue valueWithRange:((NSRange (*)(id, SEL, id))objc_msgSend)(subject, chosen, argument)]);
        if ([selector hasSuffix:@"ContainsString:"] || [selector isEqualToString:@"containsString:"])
            return ((BOOL (*)(id, SEL, id))objc_msgSend)(subject, chosen, argument) ? @"YES" : @"NO";
        return shown(((id (*)(id, SEL))objc_msgSend)(subject, chosen));
    } @catch (NSException *exception) {
        return [@"raised " stringByAppendingString:exception.name];
    }
}

static NSString *transformed(NSString *subject, NSString *transform, BOOL reverse, BOOL ours)
{
    @try {
        return shown(((id (*)(id, SEL, id, BOOL))objc_msgSend)(subject, named(@"stringByApplyingTransform:reverse:", ours), transform, reverse));
    } @catch (NSException *exception) {
        return [@"raised " stringByAppendingString:exception.name];
    }
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        host_attach_prefixed("");
        int rounds = 20000;
        fuzz_start(argc, argv, &rounds);
        NSArray *transforms = @[NSStringTransformLatinToKatakana, NSStringTransformLatinToHiragana, NSStringTransformLatinToHangul,
                                NSStringTransformLatinToArabic, NSStringTransformLatinToHebrew, NSStringTransformLatinToThai,
                                NSStringTransformLatinToCyrillic, NSStringTransformLatinToGreek, NSStringTransformToLatin,
                                NSStringTransformMandarinToLatin, NSStringTransformHiraganaToKatakana, NSStringTransformFullwidthToHalfwidth,
                                NSStringTransformToXMLHex, NSStringTransformToUnicodeName, NSStringTransformStripCombiningMarks,
                                NSStringTransformStripDiacritics, @"Any-Latin; Latin-ASCII", @"Latin-Greek", @"Upper", @"NFD", @"nonsense", @""];
        for (int round = 0; round < rounds; round++) @autoreleasepool {
            NSString *subject = word(), *search = word();
            for (NSString *selector in @[@"localizedUppercaseString", @"localizedLowercaseString", @"localizedCapitalizedString"])
                fuzz_compare(selector, [NSString stringWithFormat:@"[%@]", shown(subject)], one(subject, selector, nil, NO), one(subject, selector, nil, YES));
            for (NSString *selector in @[@"containsString:", @"localizedCaseInsensitiveContainsString:", @"localizedStandardContainsString:", @"localizedStandardRangeOfString:"])
                fuzz_compare(selector, [NSString stringWithFormat:@"[%@] in [%@]", shown(search), shown(subject)],
                        one(subject, selector, search, NO), one(subject, selector, search, YES));
            NSString *transform = transforms[roll((uint32_t)transforms.count)];
            BOOL reverse = roll(2);
            NSString *system = transformed(subject, transform, reverse, NO), *port = transformed(subject, transform, reverse, YES);
            BOOL twoWays = ![system isEqualToString:port] && [transformed(subject, transform, reverse, NO) isEqualToString:port];
            fuzz_compare(twoWays ? @"stringByApplyingTransform:reverse:.hostAnswersTwoWays" : @"stringByApplyingTransform:reverse:",
                         [NSString stringWithFormat:@"%@ reverse %d [%@]", transform, reverse, shown(subject)], system, port);
        }
        return fuzz_finish();
    }
}
