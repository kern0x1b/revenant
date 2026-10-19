#import <Foundation/Foundation.h>
#import "NSPersonNameComponentKeys.h"
#import <objc/runtime.h>

static char RevenantPersonNameStyleKey;
static char RevenantPersonNamePhoneticKey;

@interface RevenantPersonNameParts : NSObject
@property BOOL familyFirst;
@property NSString *delimiter;
@property NSString *composite;
@end

@implementation RevenantPersonNameParts
@synthesize familyFirst = _familyFirst;
@synthesize delimiter = _delimiter;
@synthesize composite = _composite;
@end

static BOOL revenant_language_is_family_first(NSString *identifier)
{
    static NSSet *familyFirst;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        familyFirst = [NSSet setWithObjects:@"hu", @"ja", @"ko", @"vi", @"yue", @"zh", nil];
    });
    NSString *language = identifier;
    NSRange mark = [language rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"_-.@"]];
    if (mark.location != NSNotFound)
        language = [language substringToIndex:mark.location];
    return [familyFirst containsObject:language];
}

static RevenantPersonNameParts *revenant_parts(NSPersonNameComponents *components, NSString *identifier)
{
    RevenantPersonNameParts *parts = [[RevenantPersonNameParts alloc] init];
    parts.familyFirst = revenant_language_is_family_first(identifier);
    parts.delimiter = @" ";
    NSString *given = components.givenName, *family = components.familyName;
    NSMutableString *composite = [NSMutableString string];
    if (given.length)
        [composite appendString:given];
    if (given.length && family.length)
        [composite appendString:@" "];
    if (family.length)
        [composite appendString:family];
    parts.composite = composite;
    return parts;
}

static NSString *revenant_initial(NSString *text)
{
    if (!text.length)
        return nil;
    return [[text substringToIndex:1] uppercaseString];
}

static NSPersonNameComponents *revenant_reads(NSPersonNameComponents *components, BOOL phonetic)
{
    if (!phonetic)
        return components;
    NSPersonNameComponents *spelling = components.phoneticRepresentation;
    return spelling ?: components;
}

static NSArray *revenant_pieces(NSString *first, NSString *second, NSString *third, NSString *fourth, NSString *fifth)
{
    NSMutableArray *pieces = [NSMutableArray array];
    for (NSString *piece in @[first ?: @"", second ?: @"", third ?: @"", fourth ?: @"", fifth ?: @""])
        if (piece.length)
            [pieces addObject:piece];
    return pieces;
}

static NSString *revenant_join(NSArray<NSString *> *pieces, NSString *delimiter)
{
    NSMutableArray *kept = [NSMutableArray array];
    for (NSString *piece in pieces)
        if (piece.length)
            [kept addObject:piece];
    return [kept componentsJoinedByString:delimiter ?: @" "];
}

@implementation NSPersonNameComponentsFormatter

- (instancetype)init
{
    if ((self = [super init]))
        objc_setAssociatedObject(self, &RevenantPersonNameStyleKey, @(NSPersonNameComponentsFormatterStyleDefault),
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return self;
}

- (NSPersonNameComponentsFormatterStyle)style
{
    NSNumber *stored = objc_getAssociatedObject(self, &RevenantPersonNameStyleKey);
    return (NSPersonNameComponentsFormatterStyle)(stored ? stored.integerValue : NSPersonNameComponentsFormatterStyleDefault);
}

- (void)setStyle:(NSPersonNameComponentsFormatterStyle)style
{
    objc_setAssociatedObject(self, &RevenantPersonNameStyleKey, @(style), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)isPhonetic
{
    return [objc_getAssociatedObject(self, &RevenantPersonNamePhoneticKey) boolValue];
}

- (void)setPhonetic:(BOOL)phonetic
{
    objc_setAssociatedObject(self, &RevenantPersonNamePhoneticKey, @(phonetic), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSString *)revenant_nameLocale
{
    return self.locale.localeIdentifier ?: [NSLocale autoupdatingCurrentLocale].localeIdentifier;
}

- (NSString *)stringFromPersonNameComponents:(NSPersonNameComponents *)components
{
    if (!components)
        [NSException raise:NSInternalInconsistencyException format:@"Invalid parameter not satisfying: components != nil"];
    NSPersonNameComponents *read = revenant_reads(components, self.isPhonetic);
    NSString *given = read.givenName, *family = read.familyName, *middle = read.middleName;
    NSString *prefix = read.namePrefix, *suffix = read.nameSuffix, *nickname = read.nickname;
    switch (self.style) {
        case NSPersonNameComponentsFormatterStyleShort:
            if (nickname.length)
                return nickname;
            if (given.length)
                return given;
            return family ?: @"";
        case NSPersonNameComponentsFormatterStyleAbbreviated: {
            if (self.isPhonetic) {
                NSString *first = @"phoneticRepresentation.givenName";
                NSString *second = @"phoneticRepresentation.familyName";
                if (!given.length) {
                    NSString *swap = first;
                    first = second;
                    second = swap;
                }
                return [revenant_pieces(revenant_initial([read valueForKey:first]),
                                      revenant_initial([read valueForKey:second]), nil, nil, nil)
                        componentsJoinedByString:@""];
            }
            if (!given.length && !family.length)
                return nickname ?: @"";
            RevenantPersonNameParts *parts = revenant_parts(read, [self revenant_nameLocale]);
            return [revenant_pieces(parts.familyFirst ? revenant_initial(family) : revenant_initial(given),
                                  parts.familyFirst ? revenant_initial(given) : revenant_initial(family),
                                  nil, nil, nil) componentsJoinedByString:@""];
        }
        case NSPersonNameComponentsFormatterStyleLong: {
            RevenantPersonNameParts *parts = revenant_parts(read, [self revenant_nameLocale]);
            NSArray *pieces = parts.familyFirst
                ? revenant_pieces(prefix, family, given, middle, suffix)
                : revenant_pieces(prefix, given, middle, family, suffix);
            if (!pieces.count)
                return nickname ?: @"";
            return revenant_join(pieces, parts.delimiter);
        }
        case NSPersonNameComponentsFormatterStyleDefault:
        case NSPersonNameComponentsFormatterStyleMedium:
        default: {
            RevenantPersonNameParts *parts = revenant_parts(read, [self revenant_nameLocale]);
            return revenant_join(parts.familyFirst ? revenant_pieces(family, given, nil, nil, nil)
                                                : revenant_pieces(given, family, nil, nil, nil),
                               parts.delimiter);
        }
    }
}

+ (NSString *)localizedStringFromPersonNameComponents:(NSPersonNameComponents *)components
                                                style:(NSPersonNameComponentsFormatterStyle)style
                                              options:(NSPersonNameComponentsFormatterOptions)options
{
    NSPersonNameComponentsFormatter *formatter = [[NSPersonNameComponentsFormatter alloc] init];
    formatter.style = style;
    formatter.phonetic = (options & NSPersonNameComponentsFormatterPhonetic) != 0;
    return [formatter stringFromPersonNameComponents:components];
}

- (NSAttributedString *)annotatedStringFromPersonNameComponents:(NSPersonNameComponents *)components
{
    NSPersonNameComponents *read = revenant_reads(components, self.isPhonetic);
    self.style = NSPersonNameComponentsFormatterStyleDefault;
    RevenantPersonNameParts *parts = revenant_parts(read, [self revenant_nameLocale]);
    NSArray *order = parts.familyFirst
        ? @[@[read.familyName ?: @"", NSPersonNameComponentFamilyName],
           @[read.givenName ?: @"", NSPersonNameComponentGivenName]]
        : @[@[read.givenName ?: @"", NSPersonNameComponentGivenName],
           @[read.familyName ?: @"", NSPersonNameComponentFamilyName]];
    NSMutableArray *kept = [NSMutableArray array];
    for (NSArray *piece in order)
        if ([piece[0] length])
            [kept addObject:piece];
    if (!kept.count)
        return [[NSAttributedString alloc] initWithString:@""];
    NSMutableAttributedString *out = [[NSMutableAttributedString alloc] init];
    NSUInteger position = 0;
    for (NSUInteger index = 0; index < kept.count; index++) {
        NSArray *piece = kept[index];
        if (index) {
            [out appendAttributedString:[[NSAttributedString alloc] initWithString:parts.delimiter
                                                                        attributes:@{NSPersonNameComponentKey: NSPersonNameComponentDelimiter}]];
            position += parts.delimiter.length;
        }
        NSString *value = piece[0];
        [out appendAttributedString:[[NSAttributedString alloc] initWithString:value
                                                                    attributes:@{NSPersonNameComponentKey: piece[1]}]];
        position += value.length;
    }
    (void)position;
    return out;
}

- (NSPersonNameComponents *)personNameComponentsFromString:(NSString *)string
{
    if (!string)
        return nil;
    NSString *trimmed = [string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!trimmed.length)
        return nil;
    NSPersonNameComponents *components = [[NSPersonNameComponents alloc] init];
    NSArray *words = [trimmed componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSMutableArray *kept = [NSMutableArray array];
    for (NSString *word in words)
        if (word.length)
            [kept addObject:word];
    if (!kept.count)
        return nil;
    NSRange comma = [trimmed rangeOfString:@","];
    if (comma.location != NSNotFound && comma.location + 1 < trimmed.length) {
        NSString *family = [[trimmed substringToIndex:comma.location]
                            stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        NSString *given = [[trimmed substringFromIndex:NSMaxRange(comma)]
                           stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        components.familyName = family.length ? family : nil;
        components.givenName = given.length ? given : nil;
        return (components.familyName.length || components.givenName.length) ? components : nil;
    }
    NSString *first = kept[0], *last = kept[kept.count - 1];
    NSUInteger from = 0, to = kept.count;
    if (kept.count > 1 && [first hasSuffix:@"."]) {
        components.namePrefix = first;
        from = 1;
    }
    if (kept.count - from > 1 && [last hasSuffix:@"."]) {
        components.nameSuffix = last;
        to = kept.count - 1;
    }
    if (from >= to) {
        components.givenName = components.namePrefix ? nil : first;
        components.namePrefix = components.namePrefix ? nil : first;
        return components.givenName.length ? components : nil;
    }
    components.givenName = kept[from];
    if (to - from > 1) {
        NSArray *rest = [kept subarrayWithRange:NSMakeRange(from + 1, to - from - 1)];
        components.familyName = [rest componentsJoinedByString:@" "];
    }
    return components;
}

- (BOOL)getObjectValue:(id *)object forString:(NSString *)string errorDescription:(NSString **)error
{
    NSPersonNameComponents *components = [self personNameComponentsFromString:string];
    if (!components) {
        if (object)
            *object = nil;
        if (error)
            *error = @"Person's name could not be detected";
        return NO;
    }
    if (object)
        *object = components;
    return YES;
}

@end
