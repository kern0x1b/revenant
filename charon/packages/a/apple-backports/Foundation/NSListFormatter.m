#import <Foundation/Foundation.h>

#import "CharonListPatterns.h"

static const CharonListPattern *charon_list_pattern(NSLocale *locale)
{
    NSString *identifier = locale.localeIdentifier;
    NSRange marker = [identifier rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"@."]];
    if (marker.location != NSNotFound)
        identifier = [identifier substringToIndex:marker.location];
    identifier = [identifier stringByReplacingOccurrencesOfString:@"-" withString:@"_"];
    for (;;) {
        NSUInteger low = 0, high = sizeof(charon_list_patterns) / sizeof(charon_list_patterns[0]);
        const char *wanted = identifier.UTF8String;
        while (low < high) {
            NSUInteger middle = (low + high) / 2;
            int order = strcmp(wanted, charon_list_patterns[middle].identifier);
            if (!order)
                return &charon_list_patterns[middle];
            if (order < 0)
                high = middle;
            else
                low = middle + 1;
        }
        NSRange cut = [identifier rangeOfString:@"_" options:NSBackwardsSearch];
        if (cut.location == NSNotFound)
            break;
        identifier = [identifier substringToIndex:cut.location];
    }
    return charon_list_pattern([NSLocale localeWithLocaleIdentifier:@"en_US"]);
}

static BOOL charon_list_is_right_to_left(UTF32Char point)
{
    return (point >= 0x0590 && point <= 0x08FF && !(point >= 0x0660 && point <= 0x0669) && !(point >= 0x06F0 && point <= 0x06F9) && !(point >= 0x0600 && point <= 0x0605) &&
            !(point >= 0x064B && point <= 0x065F) && point != 0x0670 && !(point >= 0x0591 && point <= 0x05BD) && !(point >= 0x05BF && point <= 0x05C7) && !(point >= 0x06D6 && point <= 0x06DC) &&
            !(point >= 0x06DF && point <= 0x06E4) && !(point >= 0x06E7 && point <= 0x06E8) && !(point >= 0x06EA && point <= 0x06ED) && !(point >= 0x0898 && point <= 0x089F) && !(point >= 0x08CA && point <= 0x08FF)) ||
           (point >= 0xFB1D && point <= 0xFDFF) || (point >= 0xFE70 && point <= 0xFEFF) || point == 0x200F || point == 0x061C || (point >= 0x10800 && point < 0x11000) || (point >= 0x1E800 && point < 0x1F000);
}

static BOOL charon_list_is_hebrew(UTF32Char point)
{
    return (point >= 0x0590 && point <= 0x05FF) || (point >= 0xFB1D && point <= 0xFB4F);
}

static BOOL charon_list_is_inherited(UTF32Char point)
{
    return (point >= 0x0300 && point <= 0x036F) || (point >= 0x0483 && point <= 0x0489) || (point >= 0x1AB0 && point <= 0x1AFF) || (point >= 0x1DC0 && point <= 0x1DFF) ||
           (point >= 0x20D0 && point <= 0x20FF) || (point >= 0xFE00 && point <= 0xFE0F) || (point >= 0xFE20 && point <= 0xFE2F);
}

static void charon_list_scan(NSString *text, BOOL *hasLeft, BOOL *hasRight)
{
    static NSCharacterSet *letters, *marks;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        letters = [NSCharacterSet letterCharacterSet];
        marks = [NSCharacterSet nonBaseCharacterSet];
    });
    for (NSUInteger index = 0; index < text.length; index++) {
        unichar first = [text characterAtIndex:index];
        UTF32Char point = first;
        if (first >= 0xD800 && first < 0xDC00 && index + 1 < text.length)
            point = 0x10000 + (((UTF32Char)first - 0xD800) << 10) + ([text characterAtIndex:++index] - 0xDC00);
        BOOL letter = [letters longCharacterIsMember:point] && ![marks longCharacterIsMember:point];
        if (charon_list_is_right_to_left(point) && (letter || point == 0x200F || point == 0x061C))
            *hasRight = YES;
        else if (point == 0x200E || letter)
            *hasLeft = YES;
    }
}

static BOOL charon_list_hebrew_start(NSString *text)
{
    if (!text.length)
        return YES;
    for (NSUInteger index = 0; index < text.length; index++) {
        unichar first = [text characterAtIndex:index];
        UTF32Char point = first;
        if (first >= 0xD800 && first < 0xDC00 && index + 1 < text.length)
            point = 0x10000 + (((UTF32Char)first - 0xD800) << 10) + ([text characterAtIndex:++index] - 0xDC00);
        if (charon_list_is_hebrew(point))
            return YES;
        if (!charon_list_is_inherited(point))
            return NO;
        if (index + 1 >= text.length)
            return YES;
    }
    return NO;
}

static BOOL charon_list_is_thai(unichar point)
{
    return (point >= 0x0E01 && point <= 0x0E3A) || (point >= 0x0E40 && point <= 0x0E5B);
}

static BOOL charon_list_spanish_start(NSString *text)
{
    NSString *lower = text.lowercaseString;
    if ([lower hasPrefix:@"i"])
        return YES;
    return [lower hasPrefix:@"hi"] && ![lower hasPrefix:@"hia"] && ![lower hasPrefix:@"hie"];
}

static NSString *charon_list_apply(NSString *pattern, NSString *first, NSString *second)
{
    NSRange one = [pattern rangeOfString:@"{0}"], two = [pattern rangeOfString:@"{1}"];
    if (one.location == NSNotFound || two.location == NSNotFound)
        return pattern;
    if (one.location < two.location)
        return [NSString stringWithFormat:@"%@%@%@%@%@", [pattern substringToIndex:one.location], first, [pattern substringWithRange:NSMakeRange(NSMaxRange(one), two.location - NSMaxRange(one))], second, [pattern substringFromIndex:NSMaxRange(two)]];
    return [NSString stringWithFormat:@"%@%@%@%@%@", [pattern substringToIndex:two.location], second, [pattern substringWithRange:NSMakeRange(NSMaxRange(two), one.location - NSMaxRange(two))], first, [pattern substringFromIndex:NSMaxRange(one)]];
}

@implementation NSListFormatter {
    NSLocale *_locale;
    NSFormatter *_itemFormatter;
}

+ (NSString *)localizedStringByJoiningStrings:(NSArray<NSString *> *)strings
{
    return [[[NSListFormatter alloc] init] stringFromItems:strings];
}

- (NSLocale *)locale
{
    return _locale ?: [NSLocale autoupdatingCurrentLocale];
}

- (void)setLocale:(NSLocale *)locale
{
    _locale = [locale copy];
}

- (NSFormatter *)itemFormatter
{
    return _itemFormatter;
}

- (void)setItemFormatter:(NSFormatter *)itemFormatter
{
    _itemFormatter = [itemFormatter copy];
}

- (id)copyWithZone:(NSZone *)zone
{
    NSListFormatter *copy = [[[self class] allocWithZone:zone] init];
    copy->_locale = [_locale copy];
    copy->_itemFormatter = [_itemFormatter copy];
    return copy;
}

- (NSString *)charon_text:(id)item locale:(NSLocale *)locale
{
    NSString *text = _itemFormatter ? [_itemFormatter stringForObjectValue:item] : nil;
    if (text)
        return text;
    if ([item isKindOfClass:[NSString class]])
        return item;
    if ([item respondsToSelector:@selector(descriptionWithLocale:)])
        return [item descriptionWithLocale:locale];
    if ([item respondsToSelector:@selector(localizedDescription)])
        return [item localizedDescription];
    return [item description];
}

- (NSString *)stringFromItems:(NSArray *)items
{
    if (![items isKindOfClass:[NSArray class]])
        return nil;
    NSLocale *locale = self.locale;
    NSMutableArray *texts = [NSMutableArray arrayWithCapacity:items.count];
    for (id item in items) {
        NSString *text = [self charon_text:item locale:locale];
        if (!text)
            return nil;
        [texts addObject:text];
    }
    const CharonListPattern *pattern = charon_list_pattern(locale);
    NSString *identifier = [[locale.localeIdentifier componentsSeparatedByString:@"@"].firstObject stringByReplacingOccurrencesOfString:@"." withString:@""];
    BOOL rightToLeft = [NSLocale characterDirectionForLanguage:identifier] == NSLocaleLanguageDirectionRightToLeft;
    NSString *language = [locale objectForKey:NSLocaleLanguageCode];
    NSString *last = texts.lastObject;
    NSArray *raw = [texts copy];
    for (NSUInteger index = 0; index < texts.count; index++) {
        BOOL hasLeft = NO, hasRight = NO;
        charon_list_scan(texts[index], &hasLeft, &hasRight);
        if (rightToLeft ? hasLeft : hasRight)
            texts[index] = [NSString stringWithFormat:@"\u2068%@\u2069", texts[index]];
    }
    NSString *two = pattern->two, *end = pattern->end;
    if ([language isEqualToString:@"es"] && charon_list_spanish_start(last)) {
        two = [two stringByReplacingOccurrencesOfString:@" y " withString:@" e "];
        end = [end stringByReplacingOccurrencesOfString:@" y " withString:@" e "];
    } else if ([language isEqualToString:@"th"]) {
        NSString *before = texts.count > 1 ? raw[raw.count - 2] : @"";
        BOOL trimBefore = !before.length || charon_list_is_thai([before characterAtIndex:before.length - 1]);
        BOOL trimAfter = !last.length || charon_list_is_thai([last characterAtIndex:0]);
        for (NSString *name in @[@"two", @"end"]) {
            NSString *pattern = [name isEqualToString:@"two"] ? two : end;
            if (trimBefore && [name isEqualToString:@"two"])
                pattern = [pattern stringByReplacingOccurrencesOfString:@" \u0E41\u0E25\u0E30" withString:@"\u0E41\u0E25\u0E30"];
            if (trimAfter)
                pattern = [pattern stringByReplacingOccurrencesOfString:@"\u0E41\u0E25\u0E30 " withString:@"\u0E41\u0E25\u0E30"];
            if ([name isEqualToString:@"two"])
                two = pattern;
            else
                end = pattern;
        }
    } else if ([language isEqualToString:@"he"] && charon_list_hebrew_start(last)) {
        two = [two stringByReplacingOccurrencesOfString:@"\u05D5-" withString:@"\u05D5"];
        end = [end stringByReplacingOccurrencesOfString:@"\u05D5-" withString:@"\u05D5"];
    }
    NSUInteger count = texts.count;
    if (count == 0)
        return @"";
    if (count == 1)
        return texts[0];
    if (count == 2)
        return charon_list_apply(two, texts[0], texts[1]);
    NSString *joined = charon_list_apply(end, texts[count - 2], texts[count - 1]);
    for (NSInteger index = (NSInteger)count - 3; index >= 1; index--)
        joined = charon_list_apply(pattern->middle, texts[index], joined);
    return charon_list_apply(pattern->start, texts[0], joined);
}

- (NSString *)stringForObjectValue:(id)obj
{
    return [self stringFromItems:obj];
}

@end
