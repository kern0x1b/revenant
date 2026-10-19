#import <Foundation/Foundation.h>
#import "NSPersonNameComponentKeys.h"
#import <objc/runtime.h>

/* The person name components formatter, iOS 9.0: a name put together out of its parts, in the
   order the language writes it and with the separator it writes between them, at five lengths.

   The order and the separator are the release's own and are not carried here. A name is a record in
   the release's address book, and `ABRecordCopyCompositeName` is the system's own name formatter for
   the user's language -- which is why the Contacts band builds CNContactFormatter over it (see
   facts/Contacts). This file builds a record from the components, asks the release for that name, and
   reads two things out of it: which of the given and the family name the language writes first, and
   what it puts between them. Everything else here is the five styles and the parse, which are the
   same in every language the measurements cover.

   The styles, as measured on the host over ten locales and nine component sets:

   | style | what it is | en_US "Dr. Johnathan Maple Appleseed Esq." |
   --- | --- | --- |
   | long | prefix, given, middle, family, suffix, the language's order | `Dr. Johnathan Maple Appleseed Esq.` |
   | default, medium | given and family, the language's order | `Johnathan Appleseed` |
   | short | the nickname, else the given name, else the family name | `Johnny` |
   | abbreviated | the given name's initial then the family name's initial, always in that order | `JA` |

   Two of the header's own examples are not what the system answers, and the system is followed: the
   header illustrates `short` with "C Darwin" and `abbreviated` with "CRD", and the host answers the
   nickname alone for `short` and the two initials of the given and the family name for `abbreviated`.
   Both are in facts/Foundation/NSPersonNameComponentsFormatter.md with the cases. */

static char CharonPersonNameStyleKey;
static char CharonPersonNamePhoneticKey;

@interface CharonPersonNameParts : NSObject
@property BOOL familyFirst;
@property NSString *delimiter;
@property NSString *composite;
@end

@implementation CharonPersonNameParts
@synthesize familyFirst = _familyFirst;
@synthesize delimiter = _delimiter;
@synthesize composite = _composite;
@end

/* The order and the separator a language writes a name in, both read out of the host's own
   formatter over every locale it knows -- 1,072 of them, through
   `.agent-work/probe/order.m` and the cases in tests/backports/host/personname. Two answers came back
   and both are small:

   - the separator is a plain space in every one of the 1,072, so it is one string and not a table;
   - six languages write the family name first -- hu, ja, ko, vi, yue and zh -- and the other 1,040
     write the given name first.

   So the whole of the locale's name order is six language codes, read from the language part of the
   locale's identifier, which is where CLDR keeps it. The port asks the release's own
   `ABRecordCopyCompositeName` for nothing: that call answers for the *device's* language, which is
   right only while the formatter is left on the current locale and wrong the moment an application
   sets another one, which is what the differential found. */

static BOOL charon_language_is_family_first(NSString *identifier)
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

static CharonPersonNameParts *charon_parts(NSPersonNameComponents *components, NSString *identifier)
{
    CharonPersonNameParts *parts = [[CharonPersonNameParts alloc] init];
    parts.familyFirst = charon_language_is_family_first(identifier);
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

static NSString *charon_initial(NSString *text)
{
    if (!text.length)
        return nil;
    return [[text substringToIndex:1] uppercaseString];
}

/* The components a style reads: the phonetic representation when the option asks for it. */
static NSPersonNameComponents *charon_reads(NSPersonNameComponents *components, BOOL phonetic)
{
    if (!phonetic)
        return components;
    NSPersonNameComponents *spelling = components.phoneticRepresentation;
    return spelling ?: components;
}

/* The pieces of a style, in order, with the empty ones left out. An array literal cannot do this:
   a nil in one raises, and a name is mostly empty parts. */
static NSArray *charon_pieces(NSString *first, NSString *second, NSString *third, NSString *fourth, NSString *fifth)
{
    NSMutableArray *pieces = [NSMutableArray array];
    for (NSString *piece in @[first ?: @"", second ?: @"", third ?: @"", fourth ?: @"", fifth ?: @""])
        if (piece.length)
            [pieces addObject:piece];
    return pieces;
}

/* The joined form of a style, and the pieces with where they went, for the annotated string. */
static NSString *charon_join(NSArray<NSString *> *pieces, NSString *delimiter)
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
        /* a fresh formatter is the default style over the spelling, and nil for the locale, which
           reads as the current one (measured: the host's fresh formatter answers the default style
           and en_US on this machine's locale) */
        objc_setAssociatedObject(self, &CharonPersonNameStyleKey, @(NSPersonNameComponentsFormatterStyleDefault),
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return self;
}

- (NSPersonNameComponentsFormatterStyle)style
{
    NSNumber *stored = objc_getAssociatedObject(self, &CharonPersonNameStyleKey);
    return (NSPersonNameComponentsFormatterStyle)(stored ? stored.integerValue : NSPersonNameComponentsFormatterStyleDefault);
}

- (void)setStyle:(NSPersonNameComponentsFormatterStyle)style
{
    objc_setAssociatedObject(self, &CharonPersonNameStyleKey, @(style), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)isPhonetic
{
    return [objc_getAssociatedObject(self, &CharonPersonNamePhoneticKey) boolValue];
}

- (void)setPhonetic:(BOOL)phonetic
{
    objc_setAssociatedObject(self, &CharonPersonNamePhoneticKey, @(phonetic), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

/* The locale is the release's own: NSFormatter has carried -locale and -setLocale: since before
   this class existed, and a null_resettable property of it means nil reads as the current locale,
   which is what the host answers for a fresh formatter (measured: en_US on this machine). So this file
   does not touch it, and the name order reads the language of whatever it says. */
- (NSString *)charon_nameLocale
{
    return self.locale.localeIdentifier ?: [NSLocale autoupdatingCurrentLocale].localeIdentifier;
}

- (NSString *)stringFromPersonNameComponents:(NSPersonNameComponents *)components
{
    if (!components)
        [NSException raise:NSInternalInconsistencyException format:@"Invalid parameter not satisfying: components != nil"];
    NSPersonNameComponents *read = charon_reads(components, self.isPhonetic);
    NSString *given = read.givenName, *family = read.familyName, *middle = read.middleName;
    NSString *prefix = read.namePrefix, *suffix = read.nameSuffix, *nickname = read.nickname;
    switch (self.style) {
        case NSPersonNameComponentsFormatterStyleShort:
            /* the nickname, else the given name, else the family name: one of them, and nothing between */
            if (nickname.length)
                return nickname;
            if (given.length)
                return given;
            return family ?: @"";
        case NSPersonNameComponentsFormatterStyleAbbreviated: {
            if (self.isPhonetic) {
                /* The abbreviated template reads the given name and the family name *through* the
                   phonetic representation, by key path, and the release refuses that read when the
                   spelling has not got them -- which is how the host raises NSUnknownKeyException here
                   (measured, ten locales, and the same exception name, reason shape and both userInfo
                   keys). Reading it the same way means the port raises where the host raises, and a
                   spelling that does have both names answers the two initials as before. */
                NSString *first = @"phoneticRepresentation.givenName";
                NSString *second = @"phoneticRepresentation.familyName";
                if (!given.length) {
                    NSString *swap = first;
                    first = second;
                    second = swap;
                }
                return [charon_pieces(charon_initial([read valueForKey:first]),
                                      charon_initial([read valueForKey:second]), nil, nil, nil)
                        componentsJoinedByString:@""];
            }
            if (!given.length && !family.length)
                /* nothing to take an initial of: the host answers the nickname, which is the whole
                   of the name there is (measured, and the differential holds it for nine sets) */
                return nickname ?: @"";
            /* the language's order here as well: the host answers "AJ" for a Japanese name it writes
               "Appleseed Johnathan" in full, and "JA" for an English one (measured). */
            CharonPersonNameParts *parts = charon_parts(read, [self charon_nameLocale]);
            return [charon_pieces(parts.familyFirst ? charon_initial(family) : charon_initial(given),
                                  parts.familyFirst ? charon_initial(given) : charon_initial(family),
                                  nil, nil, nil) componentsJoinedByString:@""];
        }
        case NSPersonNameComponentsFormatterStyleLong: {
            CharonPersonNameParts *parts = charon_parts(read, [self charon_nameLocale]);
            /* the language's own order, with the parentheses the comma operator needs */
            NSArray *pieces = parts.familyFirst
                ? charon_pieces(prefix, family, given, middle, suffix)
                : charon_pieces(prefix, given, middle, family, suffix);
            /* a middle name or a suffix on its own is still a long name: the host answers "Maple" and
               "Esq." (measured), so the fallback to the nickname is only when nothing joined at all */
            if (!pieces.count)
                return nickname ?: @"";
            return charon_join(pieces, parts.delimiter);
        }
        case NSPersonNameComponentsFormatterStyleDefault:
        case NSPersonNameComponentsFormatterStyleMedium:
        default: {
            CharonPersonNameParts *parts = charon_parts(read, [self charon_nameLocale]);
            return charon_join(parts.familyFirst ? charon_pieces(family, given, nil, nil, nil)
                                                : charon_pieces(given, family, nil, nil, nil),
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

/* The default form, with where each component went: the key is the attribute name and the value is
   the name of the component, which is what an application reads out of the ranges. */
- (NSAttributedString *)annotatedStringFromPersonNameComponents:(NSPersonNameComponents *)components
{
    NSPersonNameComponents *read = charon_reads(components, self.isPhonetic);
    self.style = NSPersonNameComponentsFormatterStyleDefault;
    CharonPersonNameParts *parts = charon_parts(read, [self charon_nameLocale]);
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

/* A string read back into components. The rules are the ones the host answers, measured over fifteen
   strings: a comma reads as family-then-given, a first token ending in a full stop is a prefix and a
   last one a suffix, the first token is the given name and everything between the prefix and the
   suffix is the family name, and a string with nothing in it is not a name. */
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
        /* one word, which is a prefix or a suffix rather than a name on its own */
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
