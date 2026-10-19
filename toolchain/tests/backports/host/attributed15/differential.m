#import <Foundation/Foundation.h>
#import <dlfcn.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import "check.h"
#import "ported.h"

void host_attach_prefixed(const char *prefix);

@interface ProbeDelegate : NSObject <NSURLSessionTaskDelegate>
@end
@implementation ProbeDelegate
@end

static NSAttributedString *plain(NSString *text);

static NSString *printed(id value)
{
    if (!value)
        return @"(nil)";
    if ([value isKindOfClass:[NSNumber class]])
        return [value stringValue];
    if ([value isKindOfClass:[NSURL class]])
        return [(NSURL *)value absoluteString];
    if ([value isKindOfClass:[NSString class]])
        return [NSString stringWithFormat:@"\"%@\"", value];
    if ([NSStringFromClass([value class]) hasPrefix:@"NSPresentationIntent"]) {
        NSMutableString *chain = [NSMutableString string];
        id intent = value;
        while (intent && [NSStringFromClass([intent class]) hasPrefix:@"NSPresentationIntent"]) {
            [chain appendFormat:@"%@", [intent valueForKey:@"intentKind"]];
            if ([intent valueForKey:@"identity"])
                [chain appendFormat:@"/%@", [intent valueForKey:@"identity"]];
            if ([[intent valueForKey:@"ordinal"] integerValue])
                [chain appendFormat:@" ord%@", [intent valueForKey:@"ordinal"]];
            if ([intent valueForKey:@"indentationLevel"])
                [chain appendFormat:@" ind%@", [intent valueForKey:@"indentationLevel"]];
            if ([intent valueForKey:@"column"])
                [chain appendFormat:@" col%@", [intent valueForKey:@"column"]];
            if ([intent valueForKey:@"row"])
                [chain appendFormat:@" row%@", [intent valueForKey:@"row"]];
            if ([intent valueForKey:@"columnCount"])
                [chain appendFormat:@" cols%@/%@", [intent valueForKey:@"columnCount"],
                                   [[intent valueForKey:@"columnAlignments"] componentsJoinedByString:@"."]];
            if ([intent valueForKey:@"headerLevel"])
                [chain appendFormat:@" h%@", [intent valueForKey:@"headerLevel"]];
            if ([intent valueForKey:@"languageHint"])
                [chain appendFormat:@" hint\"%@\"", [intent valueForKey:@"languageHint"]];
            intent = [intent valueForKey:@"parentIntent"];
            if (intent)
                [chain appendString:@"<"];
        }
        return chain;
    }
    return [value description];
}

static NSString *const CharonListItemDelimiter = @"NSListItemDelimiter";

static NSString *shape(NSAttributedString *string)
{
    if (!string)
        return @"(nil)";
    NSMutableString *out = [NSMutableString string];
    __block NSUInteger run = 0;
    NSString *text = [string string];
    [string enumerateAttributesInRange:NSMakeRange(0, string.length) options:0
                            usingBlock:^(NSDictionary *attributes, NSRange range, BOOL *stop) {
        [out appendFormat:@"%lu[%lu,%lu)\"%@\"", (unsigned long)run++, (unsigned long)range.location,
                           (unsigned long)range.length, [text substringWithRange:range]];
        for (NSString *key in [[attributes allKeys] sortedArrayUsingSelector:@selector(compare:)]) {
            if ([key isEqualToString:CharonListItemDelimiter])
                continue;
            [out appendFormat:@" %@=%@", key, printed(attributes[key])];
        }
        [out appendString:@"\n"];
    }];
    return out;
}

static NSAttributedString *plain(NSString *text)
{
    return [[NSAttributedString alloc] initWithString:text];
}

static NSMorphology *plainPlural(void)
{
    NSMorphology *morphology = [[NSMorphology alloc] init];
    morphology.number = NSGrammaticalNumberPlural;
    morphology.grammaticalGender = NSGrammaticalGenderMasculine;
    morphology.partOfSpeech = NSGrammaticalPartOfSpeechNoun;
    return morphology;
}

static NSAttributedString *twoTagged(void)
{
    NSMutableAttributedString *string = [[NSMutableAttributedString alloc] initWithString:@"the house and the dog"];
    [string addAttribute:NSLanguageIdentifierAttributeName value:@"en" range:NSMakeRange(0, string.length)];
    [string addAttribute:NSInflectionRuleAttributeName
                   value:[[NSInflectionRuleExplicit alloc] initWithMorphology:plainPlural()]
                   range:NSMakeRange(4, 5)];
    [string addAttribute:NSInflectionRuleAttributeName
                   value:[[NSInflectionRuleExplicit alloc] initWithMorphology:plainPlural()]
                   range:NSMakeRange(18, 3)];
    return string;
}

static NSString *const CharonFormatKey = @"CharonTestFormatAttribute";
static NSString *const CharonArgumentKey = @"CharonTestArgumentAttribute";

static NSAttributedString *coloured(NSString *text, NSRange range)
{
    NSMutableAttributedString *string = [plain(text) mutableCopy];
    [string addAttribute:CharonFormatKey value:@"format" range:range];
    return string;
}

static NSAttributedString *marked(NSString *text)
{
    NSMutableAttributedString *string = [plain(text) mutableCopy];
    [string addAttribute:CharonArgumentKey value:@"argument" range:NSMakeRange(0, text.length)];
    return string;
}

static void note_delimiters(NSString *name, NSAttributedString *string)
{
    NSMutableArray *found = [NSMutableArray array];
    [string enumerateAttribute:CharonListItemDelimiter
                       inRange:NSMakeRange(0, string.length)
                       options:0
                    usingBlock:^(id value, NSRange range, BOOL *stop) {
        if (value)
            [found addObject:[NSString stringWithFormat:@"%@ at %lu", printed(value), (unsigned long)range.location]];
    }];
    printf("note %s: the system carries %s on %lu run(s) - %s - and the port's SDK does not declare "
           "the name, so the comparison leaves it out\n",
           name.UTF8String, CharonListItemDelimiter.UTF8String, (unsigned long)found.count,
           found.count ? [found componentsJoinedByString:@", "].UTF8String : "none");
}

static NSAttributedString *inflected(NSString *text, NSRange range, id rule, NSString *language)
{
    NSMutableAttributedString *string = [[NSMutableAttributedString alloc] initWithString:text];
    if (rule)
        [string addAttribute:NSInflectionRuleAttributeName value:rule range:range];
    if (language)
        [string addAttribute:NSLanguageIdentifierAttributeName value:language range:NSMakeRange(0, string.length)];
    return string;
}

static NSAttributedString *inflectedWithAlternative(NSString *text, NSString *alternative)
{
    NSMutableAttributedString *string = [[NSMutableAttributedString alloc] initWithString:text];
    [string addAttribute:NSInflectionRuleAttributeName
                   value:[[NSInflectionRuleExplicit alloc] initWithMorphology:plainPlural()]
                   range:NSMakeRange(4, text.length - 4)];
    [string addAttribute:NSInflectionAlternativeAttributeName
                   value:[[NSAttributedString alloc] initWithString:alternative]
                   range:NSMakeRange(4, text.length - 4)];
    return string;
}

static void compare(NSString *name, NSString *system, NSString *port)
{
    charon_check([system isEqualToString:port], name.UTF8String,
                 [NSString stringWithFormat:@"system %@\n           port   %@", system, port]);
}

static NSAttributedString *systemVaList(NSAttributedString *format, NSLocale *locale, ...)
{
    va_list arguments;
    va_start(arguments, locale);
    NSAttributedString *answer = [[NSAttributedString alloc] initWithFormat:format options:0 locale:locale arguments:arguments];
    va_end(arguments);
    return answer;
}

static NSAttributedString *portVaList(NSAttributedString *format, NSLocale *locale, ...)
{
    va_list arguments;
    va_start(arguments, locale);
    NSAttributedString *answer = [plain(@"x") initCharonHostWithFormat:format options:0 locale:locale arguments:arguments];
    va_end(arguments);
    return answer;
}

int main(void)
{
    @autoreleasepool {
        host_attach_prefixed("");

        printf("== 1. the four attribute names: the port's own value beside the system's own\n");
        {
            struct { const char *name; id ours; } pairs[] = {
                { "NSAlternateDescriptionAttributeName", NSAlternateDescriptionAttributeName },
                { "NSImageURLAttributeName", NSImageURLAttributeName },
                { "NSInlinePresentationIntentAttributeName", NSInlinePresentationIntentAttributeName },
                { "NSLanguageIdentifierAttributeName", NSLanguageIdentifierAttributeName },
            };
            void *handles[2] = {
                dlopen("/System/Library/Frameworks/AppKit.framework/AppKit", RTLD_LAZY | RTLD_LOCAL),
                dlopen("/System/Library/Frameworks/Foundation.framework/Foundation", RTLD_LAZY | RTLD_LOCAL),
            };
            for (unsigned i = 0; i < sizeof pairs / sizeof *pairs; i++) {
                char symbol[128];
                id theirs = nil;
                snprintf(symbol, sizeof symbol, "_%s", pairs[i].name);
                for (unsigned image = 0; image < 2 && !theirs; image++) {
                    void *address = handles[image] ? dlsym(handles[image], symbol) : NULL;
                    if (address)
                        theirs = *(__unsafe_unretained id *)address;
                }
                Dl_info where;
                memset(&where, 0, sizeof where);
                const char *image = dladdr((__bridge const void *)pairs[i].ours, &where) && where.dli_fname
                                        ? strrchr(where.dli_fname, '/') + 1 : "(unresolved)";
                printf("   %-38s the port's value comes from %s\n", pairs[i].name, image);
                if (theirs)
                    compare([NSString stringWithFormat:@"constant.%s", pairs[i].name], printed(theirs), printed(pairs[i].ours));
                else
                    printf("   %-38s no symbol on either host image: its value is measured by "
                           "bundle.missingKey, which prints the attribute name the system itself used\n", pairs[i].name);
            }
        }

        printf("== 2. the format: five members, the system's answer beside the port's\n");
        {
            compare(@"format.classMethod",
                    shape([NSAttributedString localizedAttributedStringWithFormat:plain(@"%@ has %d apples"), @"Ann", 3]),
                    shape([NSAttributedString charonHost_localizedAttributedStringWithFormat:plain(@"%@ has %d apples"), @"Ann", 3]));
            compare(@"format.classMethod.options1",
                    shape([NSAttributedString localizedAttributedStringWithFormat:plain(@"%@ has %d apples") options:1, @"Ann", 3]),
                    shape([NSAttributedString charonHost_localizedAttributedStringWithFormat:plain(@"%@ has %d apples") options:1, @"Ann", 3]));
            compare(@"format.classMethod.options2",
                    shape([NSAttributedString localizedAttributedStringWithFormat:plain(@"%@=%d") options:2, @"x", 7]),
                    shape([NSAttributedString charonHost_localizedAttributedStringWithFormat:plain(@"%@=%d") options:2, @"x", 7]));
            NSAttributedString *two = coloured(@"pre %@ mid %@ post", NSMakeRange(4, 3));
            for (NSUInteger options = 0; options < 4; options++) {
                NSString *name = [NSString stringWithFormat:@"format.options%lu", (unsigned long)options];
                compare(name,
                        shape([[NSAttributedString alloc] initWithFormat:two options:options locale:nil, marked(@"ARG"), @"plain"]),
                        shape([plain(@"x") initCharonHostWithFormat:two options:options locale:nil, marked(@"ARG"), @"plain"]));
            }
            NSAttributedString *numbers = plain(@"%d and %.2f");
            for (NSString *identifier in @[ @"de_DE", @"fr_FR" ]) {
                NSLocale *locale = [NSLocale localeWithLocaleIdentifier:identifier];
                compare([NSString stringWithFormat:@"format.canonical.%@", identifier],
                        shape([[NSAttributedString alloc] initWithFormat:numbers options:0 locale:locale, 1234, 1234.5]),
                        shape([plain(@"x") initCharonHostWithFormat:numbers options:0 locale:locale, 1234, 1234.5]));
            }
            compare(@"format.canonical.nilLocale",
                    shape([[NSAttributedString alloc] initWithFormat:numbers options:0 locale:nil, 1234, 1234.5]),
                    shape([plain(@"x") initCharonHostWithFormat:numbers options:0 locale:nil, 1234, 1234.5]));
            compare(@"format.currentLocale",
                    shape([NSAttributedString localizedAttributedStringWithFormat:numbers, 1234, 1234.5]),
                    shape([NSAttributedString charonHost_localizedAttributedStringWithFormat:numbers, 1234, 1234.5]));
            for (NSString *identifier in @[ @"de_DE", @"fr_FR" ]) {
                NSLocale *locale = [NSLocale localeWithLocaleIdentifier:identifier];
                compare([NSString stringWithFormat:@"format.argumentList.%@", identifier],
                        shape(systemVaList(numbers, locale, 1234, 1234.5)),
                        shape(portVaList(numbers, locale, 1234, 1234.5)));
            }
            compare(@"format.argumentList.nilLocale",
                    shape(systemVaList(numbers, nil, 1234, 1234.5)),
                    shape(portVaList(numbers, nil, 1234, 1234.5)));
            compare(@"format.argumentList.currentLocale",
                    shape(systemVaList(numbers, [NSLocale currentLocale], 1234, 1234.5)),
                    shape(portVaList(numbers, [NSLocale currentLocale], 1234, 1234.5)));
            compare(@"format.positional.0",
                    shape([NSAttributedString localizedAttributedStringWithFormat:plain(@"%1$@ and %1$@ and %2$@"), @"one", @"two"]),
                    shape([NSAttributedString charonHost_localizedAttributedStringWithFormat:plain(@"%1$@ and %1$@ and %2$@"), @"one", @"two"]));
            compare(@"format.positional.1",
                    shape([NSAttributedString localizedAttributedStringWithFormat:plain(@"%2$@ then %1$@"), @"one", @"two"]),
                    shape([NSAttributedString charonHost_localizedAttributedStringWithFormat:plain(@"%2$@ then %1$@"), @"one", @"two"]));
            compare(@"format.positional.2",
                    shape([NSAttributedString localizedAttributedStringWithFormat:plain(@"%1$d apples and %1$d oranges"), 3]),
                    shape([NSAttributedString charonHost_localizedAttributedStringWithFormat:plain(@"%1$d apples and %1$d oranges"), 3]));
            compare(@"format.positional.3",
                    shape([NSAttributedString localizedAttributedStringWithFormat:plain(@"%@ %2$@"), @"one", @"two"]),
                    shape([NSAttributedString charonHost_localizedAttributedStringWithFormat:plain(@"%@ %2$@"), @"one", @"two"]));
            compare(@"format.positional.4",
                    shape([NSAttributedString localizedAttributedStringWithFormat:plain(@"%3$@ %1$@ %2$@"), @"one", @"two", @"three"]),
                    shape([NSAttributedString charonHost_localizedAttributedStringWithFormat:plain(@"%3$@ %1$@ %2$@"), @"one", @"two", @"three"]));
            compare(@"format.positional.5",
                    shape([NSAttributedString localizedAttributedStringWithFormat:plain(@"%1$ld"), 7L]),
                    shape([NSAttributedString charonHost_localizedAttributedStringWithFormat:plain(@"%1$ld"), 7L]));
            compare(@"format.positional.6",
                    shape([NSAttributedString localizedAttributedStringWithFormat:plain(@"%1$10d"), 3]),
                    shape([NSAttributedString charonHost_localizedAttributedStringWithFormat:plain(@"%1$10d"), 3]));
            compare(@"format.positional.7",
                    shape([NSAttributedString localizedAttributedStringWithFormat:plain(@"%1$@ and %@"), @"one", @"two"]),
                    shape([NSAttributedString charonHost_localizedAttributedStringWithFormat:plain(@"%1$@ and %@"), @"one", @"two"]));
            compare(@"format.positional.indexOption",
                    shape([NSAttributedString localizedAttributedStringWithFormat:plain(@"%1$@ and %1$@ and %2$@") options:2, @"one", @"two"]),
                    shape([NSAttributedString charonHost_localizedAttributedStringWithFormat:plain(@"%1$@ and %1$@ and %2$@") options:2, @"one", @"two"]));
            compare(@"format.positional.outOfOrder.indexOption",
                    shape([NSAttributedString localizedAttributedStringWithFormat:plain(@"%3$@ %1$@ %2$@") options:2, @"one", @"two", @"three"]),
                    shape([NSAttributedString charonHost_localizedAttributedStringWithFormat:plain(@"%3$@ %1$@ %2$@") options:2, @"one", @"two", @"three"]));
            compare(@"format.star.width",
                    shape([NSAttributedString localizedAttributedStringWithFormat:plain(@"[%*d]"), 6, 42]),
                    shape([NSAttributedString charonHost_localizedAttributedStringWithFormat:plain(@"[%*d]"), 6, 42]));
            compare(@"format.star.left",
                    shape([NSAttributedString localizedAttributedStringWithFormat:plain(@"[%-*d]"), 6, 42]),
                    shape([NSAttributedString charonHost_localizedAttributedStringWithFormat:plain(@"[%-*d]"), 6, 42]));
            compare(@"format.star.negative",
                    shape([NSAttributedString localizedAttributedStringWithFormat:plain(@"[%*d]"), -6, 42]),
                    shape([NSAttributedString charonHost_localizedAttributedStringWithFormat:plain(@"[%*d]"), -6, 42]));
            compare(@"format.star.zero",
                    shape([NSAttributedString localizedAttributedStringWithFormat:plain(@"[%*d]"), 0, 42]),
                    shape([NSAttributedString charonHost_localizedAttributedStringWithFormat:plain(@"[%*d]"), 0, 42]));
            compare(@"format.star.precision",
                    shape([NSAttributedString localizedAttributedStringWithFormat:plain(@"[%.*f]"), 2, 3.14159]),
                    shape([NSAttributedString charonHost_localizedAttributedStringWithFormat:plain(@"[%.*f]"), 2, 3.14159]));
            compare(@"format.star.both",
                    shape([NSAttributedString localizedAttributedStringWithFormat:plain(@"[%*.*f]"), 8, 2, 3.14159]),
                    shape([NSAttributedString charonHost_localizedAttributedStringWithFormat:plain(@"[%*.*f]"), 8, 2, 3.14159]));
            compare(@"format.star.bothNegative",
                    shape([NSAttributedString localizedAttributedStringWithFormat:plain(@"[%*.*f]"), -8, 2, 3.14159]),
                    shape([NSAttributedString charonHost_localizedAttributedStringWithFormat:plain(@"[%*.*f]"), -8, 2, 3.14159]));
            NSAttributedString *systemShortest = [NSAttributedString localizedAttributedStringWithFormat:plain(@"[%.*f]"), -2, 3.14159];
            NSAttributedString *portShortest = [NSAttributedString charonHost_localizedAttributedStringWithFormat:plain(@"[%.*f]"), -2, 3.14159];
            printf("note format.star.negativePrecision: the system answers <%s> and the port <%s> - a negative\n"
                   "           precision on a localized value is the value's own digits, which is not carried; the\n"
                   "           canonical family answers the default six, which is the case beside it\n",
                   systemShortest.string.UTF8String, portShortest.string.UTF8String);
            compare(@"format.star.negativePrecision.canonical",
                    shape(systemVaList(plain(@"[%.*f]"), nil, -2, 3.14159)),
                    shape(portVaList(plain(@"[%.*f]"), nil, -2, 3.14159)));
            compare(@"format.star.indexOption",
                    shape([NSAttributedString localizedAttributedStringWithFormat:plain(@"[%*.*f]") options:2, 8, 2, 3.14159]),
                    shape([NSAttributedString charonHost_localizedAttributedStringWithFormat:plain(@"[%*.*f]") options:2, 8, 2, 3.14159]));
            compare(@"format.star.localizedWidth",
                    shape([NSAttributedString localizedAttributedStringWithFormat:plain(@"[%*.*f]"), 8, 2, 1234.5]),
                    shape([NSAttributedString charonHost_localizedAttributedStringWithFormat:plain(@"[%*.*f]"), 8, 2, 1234.5]));
            const char *literals[] = { "100%% %@ %q", "a % b", "trailing %", "%", "%%" };
            for (unsigned i = 0; i < sizeof literals / sizeof *literals; i++) {
                NSAttributedString *caseFormat = plain(@(literals[i]));
                compare([NSString stringWithFormat:@"format.literal.%u", i],
                        shape([NSAttributedString localizedAttributedStringWithFormat:caseFormat]),
                        shape([NSAttributedString charonHost_localizedAttributedStringWithFormat:caseFormat, (id)nil]));
            }
            compare(@"format.argument.nil",
                    shape([NSAttributedString localizedAttributedStringWithFormat:plain(@"x%@y"), nil]),
                    shape([NSAttributedString charonHost_localizedAttributedStringWithFormat:plain(@"x%@y"), (id)nil]));
            compare(@"format.argument.number",
                    shape([NSAttributedString localizedAttributedStringWithFormat:plain(@"x%@y"), @42]),
                    shape([NSAttributedString charonHost_localizedAttributedStringWithFormat:plain(@"x%@y"), @42]));
            compare(@"format.argument.array",
                    shape([NSAttributedString localizedAttributedStringWithFormat:plain(@"x%@y"), @[ @"a", @"b" ]]),
                    shape([NSAttributedString charonHost_localizedAttributedStringWithFormat:plain(@"x%@y"), @[ @"a", @"b" ]]));
            compare(@"format.widths",
                    shape([NSAttributedString localizedAttributedStringWithFormat:plain(@"[%6.2f] %ld %c"), 3.14159, 42L, (int)65]),
                    shape([NSAttributedString charonHost_localizedAttributedStringWithFormat:plain(@"[%6.2f] %ld %c"), 3.14159, 42L, (int)65]));
            NSMutableAttributedString *systemAppend = [plain(@"Start: ") mutableCopy];
            [systemAppend appendLocalizedFormat:plain(@"%@/%d"), @"Ann", 3];
            NSMutableAttributedString *portAppend = [plain(@"Start: ") mutableCopy];
            [portAppend charonHost_appendLocalizedFormat:plain(@"%@/%d"), @"Ann", 3];
            compare(@"format.append", shape(systemAppend), shape(portAppend));
        }

        printf("== 3. the bundle lookup\n");
        {
            NSString *key = @"NOSUCHKEY-ATTRIBUTED15";
            NSAttributedString *system = [[NSBundle mainBundle] localizedAttributedStringForKey:key value:@"fallback" table:nil];
            NSAttributedString *port = [[NSBundle mainBundle] charonHost_localizedAttributedStringForKey:key
                                                                                                  value:@"fallback"
                                                                                                  table:nil];
            compare(@"bundle.missingKey", shape(system), shape(port));
        }

        printf("== 4. the inflection pass, with a run that carries a rule\n");
        {
            NSMorphology *(^morphology)(NSInteger, NSInteger) = ^NSMorphology *(NSInteger number, NSInteger partOfSpeech) {
                NSMorphology *m = [[NSMorphology alloc] init];
                m.number = number;
                m.grammaticalGender = NSGrammaticalGenderMasculine;
                m.partOfSpeech = partOfSpeech;
                return m;
            };
            NSInflectionRuleExplicit *(^explicit)(NSInteger, NSInteger) = ^NSInflectionRuleExplicit *(NSInteger number, NSInteger partOfSpeech) {
                return [[NSInflectionRuleExplicit alloc] initWithMorphology:morphology(number, partOfSpeech)];
            };
            id plural = explicit(NSGrammaticalNumberPlural, NSGrammaticalPartOfSpeechNoun);
            id singular = explicit(NSGrammaticalNumberSingular, NSGrammaticalPartOfSpeechNoun);

            static const char *words[] = {
                "dog", "key", "day", "guy", "boy", "toy", "piano", "photo", "zero", "pizza", "shoe",
                "canoe", "house", "sieve", "test", "attorney",
                "box", "church", "dish", "bus", "quiz", "index", "matrix", "vertex", "axis", "crisis",
                "analysis", "address", "class", "wish", "status", "alias", "virus", "cactus", "focus",
                "fungus", "nucleus", "octopus", "echo", "veto", "torpedo", "volcano", "mosquito",
                "embargo", "tornado", "hero", "potato", "tomato",
                "city", "baby", "grocery",
                "knife", "leaf", "life", "wife", "half", "loaf", "self", "thief", "wolf", "shelf",
                "calf", "elf", "scarf",
                "mouse", "foot", "tooth", "goose", "ox", "person", "child", "man", "woman", "datum",
                "criterion", "phenomenon", "hypothesis", "thesis", "sheep", "deer", "fish", "moose",
                "buffalo",
                "KNIFE", "Knife", "Wolf", "Person", "CHURCH", "Church",
                "x", "e", "I", "s", "house3", "house-s", "house's", "child's",
            };
            for (unsigned i = 0; i < sizeof words / sizeof *words; i++) {
                NSString *word = [@"the " stringByAppendingString:@(words[i])];
                NSRange range = NSMakeRange(4, word.length - 4);
                compare([NSString stringWithFormat:@"inflect.plural.%u", i],
                        shape([inflected(word, range, plural, nil) attributedStringByInflectingString]),
                        shape([inflected(word, range, plural, nil) charonHost_attributedStringByInflectingString]));
                compare([NSString stringWithFormat:@"inflect.singular.%u", i],
                        shape([inflected(word, range, singular, nil) attributedStringByInflectingString]),
                        shape([inflected(word, range, singular, nil) charonHost_attributedStringByInflectingString]));
            }
            static const char *plurals[] = {
                "houses", "dogs", "keys", "days", "boxes", "churches", "dishes", "buses", "quizzes",
                "indexes", "matrixes", "axes", "crises", "analyses", "hypotheses", "theses",
                "addresses", "classes", "wishes", "statuses", "aliases", "viruses", "cactuses",
                "focuses", "nucleuses", "octopuses", "echoes", "vetoes", "potatoes", "shoes", "canoes",
                "cities", "babies", "groceries", "knives", "leaves", "lives", "wives", "halves",
                "loaves", "selves", "thieves", "wolves", "shelves", "calves", "elves", "scarves",
                "mice", "feet", "teeth", "geese", "oxen", "people", "children", "men", "women",
                "data", "criteria", "phenomena", "cacti", "foci", "nuclei", "photos", "roofs",
                "safes", "chiefs", "beliefs", "pianos", "zeros", "sieves", "tests", "attorneys",
                "KNIVES", "Knives", "Wolves",
            };
            for (unsigned i = 0; i < sizeof plurals / sizeof *plurals; i++) {
                NSString *word = [@"the " stringByAppendingString:@(plurals[i])];
                compare([NSString stringWithFormat:@"inflect.singularOfPlural.%u", i],
                        shape([inflected(word, NSMakeRange(4, word.length - 4), singular, nil) attributedStringByInflectingString]),
                        shape([inflected(word, NSMakeRange(4, word.length - 4), singular, nil) charonHost_attributedStringByInflectingString]));
            }
            const char *numbers[] = { "notSet", "singular", "zero", "plural", "pluralTwo", "pluralFew", "pluralMany" };
            for (NSInteger n = 0; n < 7; n++) {
                NSString *name = [NSString stringWithFormat:@"inflect.number.%@", @(numbers[n])];
                compare(name,
                        shape([inflected(@"the house", NSMakeRange(4, 5), explicit(n, NSGrammaticalPartOfSpeechNoun), nil) attributedStringByInflectingString]),
                        shape([inflected(@"the house", NSMakeRange(4, 5), explicit(n, NSGrammaticalPartOfSpeechNoun), nil) charonHost_attributedStringByInflectingString]));
            }
            for (NSInteger p = 0; p < 15; p++) {
                compare([NSString stringWithFormat:@"inflect.partOfSpeech.%ld", (long)p],
                        shape([inflected(@"the house", NSMakeRange(4, 5), explicit(NSGrammaticalNumberPlural, p), nil) attributedStringByInflectingString]),
                        shape([inflected(@"the house", NSMakeRange(4, 5), explicit(NSGrammaticalNumberPlural, p), nil) charonHost_attributedStringByInflectingString]));
            }
            const char *languages[] = { "en", "en-GB", "en-US", "EN", "de", "fr", "ru", "ar", "ja", "und" };
            for (unsigned i = 0; i < sizeof languages / sizeof *languages; i++)
                compare([NSString stringWithFormat:@"inflect.language.%s", languages[i]],
                        shape([inflected(@"the house", NSMakeRange(4, 5), plural, @(languages[i])) attributedStringByInflectingString]),
                        shape([inflected(@"the house", NSMakeRange(4, 5), plural, @(languages[i])) charonHost_attributedStringByInflectingString]));
            struct { const char *name; const char *text; NSRange range; const char *language; } partial[] = {
                { "inflect.partial.noLanguage", "the house and the dog", { 4, 4 }, NULL },
                { "inflect.partial.language", "the house and the dog", { 4, 3 }, "en" },
                { "inflect.partial.midWord", "1 house", { 4, 3 }, "en" },
                { "inflect.partial.wholeWord", "the house", { 4, 5 }, NULL },
            };
            for (unsigned i = 0; i < sizeof partial / sizeof *partial; i++)
                compare(@(partial[i].name),
                        shape([inflected(@(partial[i].text), partial[i].range, plural, partial[i].language ? @(partial[i].language) : nil) attributedStringByInflectingString]),
                        shape([inflected(@(partial[i].text), partial[i].range, plural, partial[i].language ? @(partial[i].language) : nil) charonHost_attributedStringByInflectingString]));
            compare(@"inflect.alternative",
                    shape([inflectedWithAlternative(@"the mouse", @"mice") attributedStringByInflectingString]),
                    shape([inflectedWithAlternative(@"the mouse", @"mice") charonHost_attributedStringByInflectingString]));
            compare(@"inflect.specifier",
                    shape([inflected(@"%d house", NSMakeRange(0, 8), plural, @"en") attributedStringByInflectingString]),
                    shape([inflected(@"%d house", NSMakeRange(0, 8), plural, @"en") charonHost_attributedStringByInflectingString]));
            compare(@"inflect.twoRuns",
                    shape([twoTagged() attributedStringByInflectingString]),
                    shape([twoTagged() charonHost_attributedStringByInflectingString]));
            NSMutableAttributedString *untagged = [coloured(@"the house", NSMakeRange(4, 5)) mutableCopy];
            compare(@"inflect.untagged",
                    shape([untagged attributedStringByInflectingString]),
                    shape([untagged charonHost_attributedStringByInflectingString]));
        }

        printf("== 5. the Markdown parser\n");
        {
            NSArray *documents = @[
                @"# Title\n\nSome *emph* and **strong** and `code` and a [link](https://example.com).\n\n- one\n- two\n",
                @"> quote\n\n```\ncode\n```\n\npara with [rel](sub/page.html) and ![img](a.png) and ~~del~~\n\n| a | b |\n| - | - |\n| 1 | 2 |\n\n---\n",
                @"one\ntwo\n\n1. first\n2. second\n\nend\n",
            ];
            Class portOptions = NSClassFromString(@"CharonHostNSAttributedStringMarkdownParsingOptions");
            charon_check(portOptions != Nil, "markdown.optionsClass",
                         @"the port's class is in the process, under a name of its own");
            NSAttributedStringMarkdownParsingOptions *systemOptions = [[NSAttributedStringMarkdownParsingOptions alloc] init];
            id portOptionsObject = [[portOptions alloc] init];
            compare(@"markdown.options.defaults",
                    [NSString stringWithFormat:@"extended=%d syntax=%ld policy=%ld language=%@ sourcepos=%d",
                                     (int)systemOptions.allowsExtendedAttributes, (long)systemOptions.interpretedSyntax,
                                     (long)systemOptions.failurePolicy, systemOptions.languageCode ?: @"(nil)",
                                     (int)systemOptions.appliesSourcePositionAttributes],
                    [NSString stringWithFormat:@"extended=%d syntax=%ld policy=%ld language=%@ sourcepos=%d",
                                     (int)[portOptionsObject allowsExtendedAttributes],
                                     (long)[portOptionsObject interpretedSyntax], (long)[portOptionsObject failurePolicy],
                                     [portOptionsObject languageCode] ?: @"(nil)",
                                     (int)[portOptionsObject appliesSourcePositionAttributes]]);
            charon_check([[portOptionsObject copy] class] == portOptions,
                         "markdown.options.copy", @"the port's -copy answers one of the port's own class");
            NSURL *base = [NSURL URLWithString:@"https://base.example/dir/"];
            for (unsigned i = 0; i < documents.count; i++) {
                NSString *markdown = documents[i];
                NSError *systemError = nil, *portError = nil;
                note_delimiters([NSString stringWithFormat:@"markdown.document.%u", i],
                                [[NSAttributedString alloc] initWithMarkdownString:markdown options:nil
                                                                            baseURL:base error:NULL]);
                compare([NSString stringWithFormat:@"markdown.document.%u", i],
                        shape([[NSAttributedString alloc] initWithMarkdownString:markdown options:nil baseURL:base error:&systemError]),
                        shape([plain(@"x") initCharonHostWithMarkdownString:markdown options:nil baseURL:base error:&portError]));
            }
            NSData *bytes = [documents[0] dataUsingEncoding:NSUTF8StringEncoding];
            NSError *systemDataError = nil, *portDataError = nil;
            note_delimiters(@"markdown.data", [[NSAttributedString alloc] initWithMarkdown:bytes options:nil baseURL:nil error:NULL]);
            compare(@"markdown.data",
                    shape([[NSAttributedString alloc] initWithMarkdown:bytes options:nil baseURL:nil error:&systemDataError]),
                    shape([plain(@"x") initCharonHostWithMarkdown:bytes options:nil baseURL:nil error:&portDataError]));
            NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"attributed15.md"];
            [documents[1] writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:NULL];
            NSError *systemFileError = nil, *portFileError = nil;
            compare(@"markdown.file",
                    shape([[NSAttributedString alloc] initWithContentsOfMarkdownFileAtURL:[NSURL fileURLWithPath:path]
                                                                                   options:nil baseURL:nil error:&systemFileError]),
                    shape([plain(@"x") initCharonHostWithContentsOfMarkdownFileAtURL:[NSURL fileURLWithPath:path]
                                                                             options:nil baseURL:nil error:&portFileError]));
            uint8_t rubbish[] = { 0xff, 0xfe, 0xfd };
            NSData *notText = [NSData dataWithBytes:rubbish length:sizeof rubbish];
            NSError *systemBad = nil, *portBad = nil;
            compare(@"markdown.notText",
                    shape([[NSAttributedString alloc] initWithMarkdown:notText options:nil baseURL:nil error:&systemBad]),
                    shape([plain(@"x") initCharonHostWithMarkdown:notText options:nil baseURL:nil error:&portBad]));
            NSAttributedStringMarkdownParsingOptions *french = [[NSAttributedStringMarkdownParsingOptions alloc] init];
            french.languageCode = @"fr";
            id portFrench = [[portOptions alloc] init];
            [portFrench setValue:@"fr" forKey:@"languageCode"];
            compare(@"markdown.languageCode",
                    shape([[NSAttributedString alloc] initWithMarkdownString:@"bonjour *ici*" options:french baseURL:nil error:NULL]),
                    shape([plain(@"x") initCharonHostWithMarkdownString:@"bonjour *ici*" options:portFrench baseURL:nil error:NULL]));
        }

        printf("== 6. the per-task delegate's accessors\n");
        {
            NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration ephemeralSessionConfiguration];
            NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration];
            NSURLSessionTask *task = [session dataTaskWithURL:[NSURL URLWithString:@"https://example.com/"]];
            charon_check(task.delegate == nil, "task.freshDelegate", @"a fresh task has no delegate of its own");
            ProbeDelegate *set = [[ProbeDelegate alloc] init];
            id portRead = [task charonHost_delegate];
            charon_check(portRead == nil, "task.freshDelegate.port", @"and the port's answers nil beside it");
            [task charonHost_setDelegate:set];
            id oursRead = [task charonHost_delegate];
            charon_check(oursRead == set, "task.setAndReadBack", @"the port reads back the object it was given");
            task.delegate = set;
            charon_check(task.delegate == set, "task.systemReadBack", @"and the system's own does the same");
        }

        printf("== 7. what the RELEASE answers for the members of an abstract class\n");
        {
            Class intent = NSClassFromString(@"NSPresentationIntent");
            charon_check(intent != Nil && [intent respondsToSelector:@selector(new)],
                         "release.presentationIntent.new",
                         @"the class is there and +new is one of its selectors");
            id fresh = ((id (*)(id, SEL))objc_msgSend)(intent, @selector(new));
            printf("   +new answers %s, an instance of %s, intentKind %s, identity %s\n",
                   [[fresh description] UTF8String], class_getName([fresh class]),
                   [[fresh valueForKey:@"intentKind"] stringValue].UTF8String,
                   [[fresh valueForKey:@"identity"] stringValue].UTF8String);
            charon_check([fresh isKindOfClass:intent] && [[fresh valueForKey:@"intentKind"] integerValue] == 0,
                         "release.presentationIntent.new.answer",
                         @"it answers an instance of the class whose kind is the enumeration's zero");
            id started = ((id (*)(id, SEL))objc_msgSend)([intent alloc], @selector(init));
            printf("   -init answers an instance of %s, intentKind %s, identity %s\n",
                   class_getName([started class]), [[started valueForKey:@"intentKind"] stringValue].UTF8String,
                   [[started valueForKey:@"identity"] stringValue].UTF8String);
            charon_check([started isKindOfClass:intent] && [[started valueForKey:@"intentKind"] integerValue] == 0,
                         "release.presentationIntent.init.answer",
                         @"-init answers the same shape, and neither initialiser is refused at run time");
            printf("note  the identity is not initialised: it reads 0 on this run and a pointer-shaped "
                   "number -6510171893482810916 - on another, both measured, which is what a row of an "
                   "abstract class's NS_UNAVAILABLE initialiser is: the release answers, and nothing can be "
                   "held to the answer\n");
            Class rule = NSClassFromString(@"NSInflectionRule");
            id answered = ((id (*)(id, SEL))objc_msgSend)((id)rule, @selector(alloc));
            answered = ((id (*)(id, SEL))objc_msgSend)(answered, @selector(init));
            printf("   -[NSInflectionRule init] answers an instance of %s\n", class_getName([answered class]));
            charon_check(answered != nil && [answered isKindOfClass:rule],
                         "release.inflectionRule.init",
                         @"the release answers it with an instance of the abstract class and not a refusal");
        }

        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
    }
    return charon_failures == 0 ? 0 : 1;
}
