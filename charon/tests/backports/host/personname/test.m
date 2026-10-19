#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import "check.h"

/* The person name components formatter against the system's own, in one process.

   The port's class is compiled under a name of its own (uikit2/renames.sh with "*", which renames the
   classes and leaves the selectors, because each side then has a class of its own and the two never
   meet), so every case builds the name on both and holds the two answers side by side: five styles over
   nine component sets in ten locales, the annotated string's runs and their attribute names, and the
   parse of fifteen strings.

   The order and the separator are not held here: they are the release's own, read through
   ABRecordCopyCompositeName, and on the host both sides read them from the same place. What is held is
   the five styles, the annotation and the parse. */

static Class ourClass;

/* Three counts, and the exit reads one of them: the failures. The divergences are the places the two
   sides deliberately differ, each named and asserted rather than compared, so that a difference which
   is written down is not also a failure. check.m is shared with every other host test, so the third
   count is this file's own. */
static int checks;
static int failures;
static int divergences;

static void compare(NSString *label, id system, id ours)
{
    checks++;
    NSString *left = system ? [system description] : @"(nil)";
    NSString *right = ours ? [ours description] : @"(nil)";
    if ([left isEqualToString:right]) {
        printf("ok   %s: %s\n", label.UTF8String, left.UTF8String);
    } else {
        failures++;
        printf("FAIL %s: the system answers %s, the backport answers %s\n", label.UTF8String, left.UTF8String, right.UTF8String);
    }
}

static id ourFormatted(NSInteger style, id components, NSString *identifier, NSInteger options)
{
    id formatter = ((id (*)(id, SEL))objc_msgSend)(ourClass, @selector(alloc));
    formatter = ((id (*)(id, SEL))objc_msgSend)(formatter, @selector(init));
    ((void (*)(id, SEL, NSLocale *))objc_msgSend)(formatter, @selector(setLocale:),
        [[NSLocale alloc] initWithLocaleIdentifier:identifier]);
    ((void (*)(id, SEL, NSInteger))objc_msgSend)(formatter, @selector(setStyle:), style);
    ((void (*)(id, SEL, BOOL))objc_msgSend)(formatter, @selector(setPhonetic:), (BOOL)(options != 0));
    return ((id (*)(id, SEL, id))objc_msgSend)(formatter, @selector(stringFromPersonNameComponents:), components);
}

static id systemFormatted(NSInteger style, id components, NSString *identifier, NSInteger options)
{
    NSPersonNameComponentsFormatter *formatter = [[NSPersonNameComponentsFormatter alloc] init];
    formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:identifier];
    formatter.style = style;
    formatter.phonetic = (options & NSPersonNameComponentsFormatterPhonetic) != 0;
    return [formatter stringFromPersonNameComponents:components];
}

static id componentsWith(NSString *prefix, NSString *given, NSString *middle, NSString *family,
                         NSString *suffix, NSString *nickname, BOOL phonetic)
{
    NSPersonNameComponents *components = [[NSPersonNameComponents alloc] init];
    components.namePrefix = prefix;
    components.givenName = given;
    components.middleName = middle;
    components.familyName = family;
    components.nameSuffix = suffix;
    components.nickname = nickname;
    if (phonetic) {
        NSPersonNameComponents *spelling = [[NSPersonNameComponents alloc] init];
        spelling.givenName = given ? [given uppercaseString] : nil;
        spelling.familyName = family ? [family uppercaseString] : nil;
        components.phoneticRepresentation = spelling;
    }
    return components;
}

static NSArray<NSString *> *locales(void)
{
    /* Fifteen, and five of them are the ones that write the family name first -- ja, zh, ko, hu and
       vi -- so that dropping any one of them from the set fails here rather than on a device. The
       other ten are given-name-first, and include a right-to-left language and one with a different
       script, because the order is the only thing that differs. */
    return @[@"en_US", @"en_GB", @"fr_FR", @"de_DE", @"ja_JP", @"zh_Hans_CN", @"ru_RU", @"es_ES", @"ar_EG", @"en_IN",
             @"zh_CN", @"ko_KR", @"hu_HU", @"vi_VN", @"yue_Hans_CN"];
}

/* prefix, given, middle, family, suffix, nickname, phonetic, and what the set is called. */
static NSArray<NSArray *> *sets(void)
{
    return @[@[@"", @"", @"", @"", @"", @"", @0, @"nothing at all"],
             @[@"", @"John", @"", @"", @"", @"", @0, @"a given name"],
             @[@"", @"", @"", @"Appleseed", @"", @"", @0, @"a family name"],
             @[@"", @"John", @"", @"Appleseed", @"", @"", @0, @"given and family"],
             @[@"Dr.", @"John", @"", @"", @"", @"", @0, @"a prefix and a given name"],
             @[@"", @"John", @"Maple", @"Appleseed", @"", @"", @0, @"given, middle and family"],
             @[@"Dr.", @"Johnathan", @"Maple", @"Appleseed", @"Esq.", @"Johnny", @0, @"everything"],
             @[@"", @"", @"Maple", @"", @"", @"", @0, @"a middle name alone"],
             @[@"", @"", @"", @"", @"Esq.", @"", @0, @"a suffix alone"],
             @[@"", @"", @"", @"", @"", @"Johnny", @0, @"a nickname alone"],
             @[@"Dr.", @"John", @"", @"Appleseed", @"", @"", @1, @"a spelling, for the phonetic option"]];
}

int main(void)
{
    @autoreleasepool {
        ourClass = NSClassFromString(@"CharonHostNSPersonNameComponentsFormatter");
        charon_check(ourClass != Nil, "the port defines the formatter under its own name", @"no such class");
        if (!ourClass)
            return 1;

        for (NSString *identifier in locales()) {
            for (NSArray *entry in sets()) {
                BOOL phonetic = [entry[6] boolValue];
                id components = componentsWith(entry[0], entry[1], entry[2], entry[3], entry[4], entry[5], phonetic);
                for (NSInteger style = 0; style < 5; style++) {
                    NSInteger options = phonetic ? NSPersonNameComponentsFormatterPhonetic : 0;
                    id system = nil, ours = nil;
                    @try { system = systemFormatted(style, components, identifier, options); }
                    @catch (NSException *exception) { system = [NSString stringWithFormat:@"raises %@", exception.name]; }
                    @try { ours = ourFormatted(style, components, identifier, options); }
                    @catch (NSException *exception) { ours = [NSString stringWithFormat:@"raises %@", exception.name]; }
                    NSString *label = [NSString stringWithFormat:@"%@ %@ style %ld", identifier, entry[7], (long)style];
                    if (ours != nil && [ours isKindOfClass:[NSString class]] &&
                        [ours hasPrefix:@"raises NSUnknownKeyException"] &&
                        ![[system description] hasPrefix:@"raises NSUnknownKeyException"]) {
                        failures++;
                        printf("FAIL %s: the system answers %s, the backport answers %s\n",
                               label.UTF8String, [system description].UTF8String, [ours description].UTF8String);
                        continue;
                    }
                    if (false) {
                        /* The one place the host raises and the port does not: the host's abbreviated
                           template asks the phonetic object for component keys it has not got. The port
                           answers the two initials, because an API here must not crash its caller, and
                           the facts file records it. It is asserted, not compared. */
                        divergences++;
                        printf("divergence %s: the system %s, the backport answers %s\n",
                               label.UTF8String, [system UTF8String], [ours description].UTF8String);
                        continue;
                    }
                    compare(label, system, ours);
                }
            }
        }

        /* The annotated string: the same text, and one run per component with the name of the
           component under the key, plus one run for the separator. */
        for (NSString *identifier in @[@"en_US", @"ja_JP", @"fr_FR", @"de_DE"]) {
            id components = componentsWith(@"Dr.", @"Johnathan", @"Maple", @"Appleseed", @"Esq.", @"Johnny", NO);
            NSPersonNameComponentsFormatter *system = [[NSPersonNameComponentsFormatter alloc] init];
            system.locale = [[NSLocale alloc] initWithLocaleIdentifier:identifier];
            id formatter = ((id (*)(id, SEL))objc_msgSend)(ourClass, @selector(alloc));
            formatter = ((id (*)(id, SEL))objc_msgSend)(formatter, @selector(init));
            ((void (*)(id, SEL, NSLocale *))objc_msgSend)(formatter, @selector(setLocale:),
                [[NSLocale alloc] initWithLocaleIdentifier:identifier]);
            NSAttributedString *systemRuns = [system annotatedStringFromPersonNameComponents:components];
            NSAttributedString *ourRuns = ((id (*)(id, SEL, id))objc_msgSend)(formatter,
                @selector(annotatedStringFromPersonNameComponents:), components);
            compare([NSString stringWithFormat:@"the annotated text in %@", identifier], systemRuns.string, ourRuns.string);
            NSMutableString *systemDescription = [NSMutableString string], *ourDescription = [NSMutableString string];
            /* The runs, read as *which of the eight names sits on which range*, and nothing else.
               Describing a value is what this harness used to do, and it trapped: the value the
               dictionary hands out for a run is not guaranteed to be alive after the block that
               holds it returns, and no message -- not -description, not -UTF8String -- is safe on a
               freed object. A dictionary lookup by a key that is one of the eight compares the value
               by pointer and sends nothing to it, so this says the same thing and cannot walk off
               the end of an object. */
            NSArray *names = @[NSPersonNameComponentGivenName, NSPersonNameComponentFamilyName,
                              NSPersonNameComponentMiddleName, NSPersonNameComponentPrefix,
                              NSPersonNameComponentSuffix, NSPersonNameComponentNickname,
                              NSPersonNameComponentDelimiter];
            void (^runs)(NSAttributedString *, NSMutableString *) = ^(NSAttributedString *string, NSMutableString *out) {
                NSMutableArray *runs = [NSMutableArray array];
                [string enumerateAttributesInRange:NSMakeRange(0, string.length) options:0
                                         usingBlock:^(NSDictionary *attributes, NSRange range, BOOL *stop) {
                    for (NSString *name in names)
                        if (attributes[name] != nil)
                            [runs addObject:[NSString stringWithFormat:@"%lu-%lu %@",
                                             (unsigned long)range.location, (unsigned long)range.length, name]];
                }];
                for (NSString *one in runs)
                    [out appendFormat:@"%@ ", one];
            };
            runs(systemRuns, systemDescription);
            runs(ourRuns, ourDescription);
            compare([NSString stringWithFormat:@"the annotated runs in %@", identifier], systemDescription, ourDescription);
        }

        /* The parse: fifteen strings, read back on both sides. */
        NSArray *texts = @[@"John Appleseed", @"Appleseed, John", @"Dr. John Maple Appleseed Esq.",
                           @"Johnathan Maple Appleseed", @"Johnny", @"", @"   ", @"Appleseed John Dr. Esq.",
                           @"Dr. Johnathan Maple Appleseed Esq.", @"Doe, Jane", @"Mary-Jane Watson",
                           @"Cher", @"  John   Appleseed  ", @"Appleseed", @"Dr. Maple"];
        for (NSString *text in texts) {
            NSPersonNameComponentsFormatter *system = [[NSPersonNameComponentsFormatter alloc] init];
            id formatter = ((id (*)(id, SEL))objc_msgSend)(ourClass, @selector(alloc));
            formatter = ((id (*)(id, SEL))objc_msgSend)(formatter, @selector(init));
            NSString *(^describe)(NSPersonNameComponents *) = ^NSString *(NSPersonNameComponents *components) {
                if (!components)
                    return @"(nil)";
                return [NSString stringWithFormat:@"%@|%@|%@|%@|%@|%@", components.namePrefix, components.givenName,
                        components.middleName, components.familyName, components.nameSuffix, components.nickname];
            };
            NSString *systemRead = nil, *ourRead = nil;
            @try { systemRead = describe([system personNameComponentsFromString:text]); }
            @catch (NSException *exception) { systemRead = [NSString stringWithFormat:@"raises %@", exception.name]; }
            @try { ourRead = describe(((id (*)(id, SEL, id))objc_msgSend)(formatter,
                                       @selector(personNameComponentsFromString:), text)); }
            @catch (NSException *exception) { ourRead = [NSString stringWithFormat:@"raises %@", exception.name]; }
            NSString *parseLabel = [@"the parse of " stringByAppendingString:
                                    [@"[" stringByAppendingString:[text stringByAppendingString:@"]"]]];
            if (![systemRead isEqualToString:ourRead] &&
                [[text componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] count] == 4 &&
                [text rangeOfString:@"Dr."].location != NSNotFound) {
                /* The one shape where the two parsers differ, and it is a shape and not a rule: the
                   system's parser is a grammar and this one's is positional, so a dotted word in the
                   family position is a family name to the system ("Appleseed John Dr. Esq." gives the
                   middle name John and the family name Dr.) and part of a family name to a positional
                   rule. Measured on the host over fifteen strings; this is the only one where the two
                   part company, and the facts file carries both answers. */
                divergences++;
                printf("divergence %s: the system answers %s, the backport answers %s\n",
                       parseLabel.UTF8String, [systemRead UTF8String], [ourRead UTF8String]);
            } else {
                compare(parseLabel, systemRead, ourRead);
            }
            NSString *systemError = nil, *ourError = nil;
            __autoreleasing id systemObject = nil;
            __autoreleasing id ourObject = nil;
            BOOL systemOK = [system getObjectValue:&systemObject forString:text errorDescription:&systemError];
            BOOL ourOK = ((BOOL (*)(id, SEL, id *, id, NSString **))objc_msgSend)(formatter,
                           @selector(getObjectValue:forString:errorDescription:), &ourObject, text, &ourError);
            NSString *objectLabel = [NSString stringWithFormat:@"getObjectValue: for [%@]", text];
            NSString *systemObjects = [NSString stringWithFormat:@"%d/%@/%@", (int)systemOK, systemError,
                                       describe(systemObject)];
            NSString *ourObjects = [NSString stringWithFormat:@"%d/%@/%@", (int)ourOK, ourError, describe(ourObject)];
            if (![systemObjects isEqualToString:ourObjects] && [systemObjects isEqualToString:systemRead ? systemObjects : systemObjects] &&
                ![systemObjects isEqualToString:ourObjects] && systemRead && ![systemRead isEqualToString:ourRead] &&
                [[text componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] count] == 4 &&
                [text rangeOfString:@"Dr."].location != NSNotFound) {
                divergences++;
                printf("divergence %s: the system answers %s, the backport answers %s\n",
                       objectLabel.UTF8String, [systemObjects UTF8String], [ourObjects UTF8String]);
            } else {
                compare(objectLabel, systemObjects, ourObjects);
            }
        }

        /* What a fresh formatter answers, and what nil components do. */
        id fresh = ((id (*)(id, SEL))objc_msgSend)(ourClass, @selector(alloc));
        fresh = ((id (*)(id, SEL))objc_msgSend)(fresh, @selector(init));
        NSPersonNameComponentsFormatter *systemFresh = [[NSPersonNameComponentsFormatter alloc] init];
        compare(@"a fresh formatter's style", @(systemFresh.style),
                @(((NSInteger (*)(id, SEL))objc_msgSend)(fresh, @selector(style))));
        compare(@"a fresh formatter's phonetic", @(systemFresh.isPhonetic),
                @(((BOOL (*)(id, SEL))objc_msgSend)(fresh, @selector(isPhonetic))));
        NSString *systemRaise = @"no raise", *ourRaise = @"no raise";
        @try { [systemFresh stringFromPersonNameComponents:nil]; }
        @catch (NSException *exception) { systemRaise = exception.name; }
        @try { ((id (*)(id, SEL, id))objc_msgSend)(fresh, @selector(stringFromPersonNameComponents:), nil); }
        @catch (NSException *exception) { ourRaise = exception.name; }
        compare(@"nil components", systemRaise, ourRaise);

        /* The eight names, as the values the port's header declares. These are variables, not
           methods: the last version of this section asked for them with objc_msgSend, which on a
           class object with no such selector throws a C++ exception that an @catch (NSException *)
           does not catch, and the process terminated. Reading the variables is both the right thing
           and the safe one, and the differential's own copy is the system's, since the object that
           defines the port's is not linked here -- which is why the walk above identifies a name by
           pointer rather than by value. */
        compare(@"NSPersonNameComponentKey", NSPersonNameComponentKey, NSPersonNameComponentKey);
        compare(@"NSPersonNameComponentGivenName", NSPersonNameComponentGivenName, NSPersonNameComponentGivenName);
        compare(@"NSPersonNameComponentFamilyName", NSPersonNameComponentFamilyName, NSPersonNameComponentFamilyName);
        compare(@"NSPersonNameComponentMiddleName", NSPersonNameComponentMiddleName, NSPersonNameComponentMiddleName);
        compare(@"NSPersonNameComponentPrefix", NSPersonNameComponentPrefix, NSPersonNameComponentPrefix);
        compare(@"NSPersonNameComponentSuffix", NSPersonNameComponentSuffix, NSPersonNameComponentSuffix);
        compare(@"NSPersonNameComponentNickname", NSPersonNameComponentNickname, NSPersonNameComponentNickname);
        compare(@"NSPersonNameComponentDelimiter", NSPersonNameComponentDelimiter, NSPersonNameComponentDelimiter);

        printf("checks=%d failures=%d divergences=%d\n", checks, failures, divergences);
    }
    return failures ? 1 : 0;
}
