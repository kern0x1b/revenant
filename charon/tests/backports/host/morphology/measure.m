// measure.m - what the host's own NSMorphology, NSMorphologyCustomPronoun, NSMorphologyPronoun,
// NSInflectionRule and NSInflectionRuleExplicit answer, measured once and written to expected.txt.
// The 26.2 members come from CharonMorphology26.h, a category on the SDK's own classes, so what is
// measured is the host's class and not a rename of it.
//
//   xcrun clang -fobjc-arc -Wno-deprecated-declarations -Wno-unguarded-availability-new \
//       -I . -o measure measure.m -framework Foundation
//   ./measure > expected.txt
//
// One case per line, tab-separated, in a fixed order so a diff means something. The port is held to
// this file by tests/backports/host/morphology/differential.m.

#import <Foundation/Foundation.h>
#import <dlfcn.h>
#import "CharonMorphology26.h"

static NSArray *Languages(void)
{
    // The languages the release and the host are both likely to answer for, and a few that neither is:
    // a bare language, a language with a region, a language with a script, an empty one, and a made-up one.
    return @[@"en", @"en_US", @"en_GB", @"fr", @"fr_FR", @"de", @"ru", @"ja", @"ar", @"es", @"pt", @"zh", @"it",
             @"nl", @"pl", @"tr", @"ko", @"he", @"th", @"hi", @"und", @"", @"xx_YY", @"klingon", @"123"];
}

static NSString *List(NSArray *values)
{
    return values ? [values componentsJoinedByString:@","] : @"(nil)";
}

static void Emit(NSString *what, id answer)
{
    printf("%s\t%s\n", what.UTF8String, [answer description].UTF8String);
}

int main(int argc, char **argv)
{
    setvbuf(stdout, NULL, _IONBF, 0);
    @autoreleasepool {
        // A fresh object's eight settings and the two answers that are not storage.
        NSMorphology *fresh = [[NSMorphology alloc] init];
        Emit(@"fresh.gender", @(fresh.grammaticalGender));
        Emit(@"fresh.partOfSpeech", @(fresh.partOfSpeech));
        Emit(@"fresh.number", @(fresh.number));
        Emit(@"fresh.case", @(fresh.grammaticalCase));
        Emit(@"fresh.determination", @(fresh.determination));
        Emit(@"fresh.person", @(fresh.grammaticalPerson));
        Emit(@"fresh.pronounType", @(fresh.pronounType));
        Emit(@"fresh.definiteness", @(fresh.definiteness));
        Emit(@"fresh.unspecified", @(fresh.unspecified));
        Emit(@"userMorphology.unspecified", @([NSMorphology userMorphology].unspecified));
        Emit(@"userMorphology.gender", @([NSMorphology userMorphology].grammaticalGender));

        // Each setting written, and what -isUnspecified then says.
        for (NSInteger value = 0; value <= 3; value++) {
            NSMorphology *m = [[NSMorphology alloc] init];
            m.grammaticalGender = (NSGrammaticalGender)value;
            m.partOfSpeech = (NSGrammaticalPartOfSpeech)value;
            m.number = (NSGrammaticalNumber)value;
            m.grammaticalCase = (NSGrammaticalCase)value;
            m.determination = (NSGrammaticalDetermination)value;
            m.grammaticalPerson = (NSGrammaticalPerson)value;
            m.pronounType = (NSGrammaticalPronounType)value;
            m.definiteness = (NSGrammaticalDefiniteness)value;
            printf("set%ld\t%ld\t%ld\t%ld\t%ld\t%ld\t%ld\t%ld\t%ld\t%d\n", (long)value, (long)m.grammaticalGender,
                   (long)m.partOfSpeech, (long)m.number, (long)m.grammaticalCase, (long)m.determination,
                   (long)m.grammaticalPerson, (long)m.pronounType, (long)m.definiteness, (int)m.unspecified);
        }
        // A value outside each enumeration: read back as written, or refused.
        for (NSInteger value = 40; value <= 43; value++) {
            NSMorphology *m = [[NSMorphology alloc] init];
            m.grammaticalGender = (NSGrammaticalGender)value;
            m.partOfSpeech = (NSGrammaticalPartOfSpeech)value;
            m.number = (NSGrammaticalNumber)value;
            m.grammaticalCase = (NSGrammaticalCase)value;
            m.determination = (NSGrammaticalDetermination)value;
            m.grammaticalPerson = (NSGrammaticalPerson)value;
            m.pronounType = (NSGrammaticalPronounType)value;
            m.definiteness = (NSGrammaticalDefiniteness)value;
            printf("set%ld\t%ld\t%ld\t%ld\t%ld\t%ld\t%ld\t%ld\t%ld\t%d\n", (long)value, (long)m.grammaticalGender,
                   (long)m.partOfSpeech, (long)m.number, (long)m.grammaticalCase, (long)m.determination,
                   (long)m.grammaticalPerson, (long)m.pronounType, (long)m.definiteness, (int)m.unspecified);
        }
        // Which of the eight settings -isUnspecified reads, one at a time: the three the SDK declares
        // at 15.0 and the five at 17.0 do not have the same standing (7777ac79's finding).
        {
            const char *names[] = {"grammaticalGender", "partOfSpeech", "number", "grammaticalCase", "determination",
                                   "grammaticalPerson", "pronounType", "definiteness", NULL};
            for (int index = 0; names[index]; index++) {
                for (NSInteger value = 0; value <= 2; value++) {
                    NSMorphology *m = [[NSMorphology alloc] init];
                    [m setValue:@(value) forKey:[NSString stringWithUTF8String:names[index]]];
                    printf("only%s%ld\t%d\n", names[index], (long)value, (int)m.unspecified);
                }
            }
        }
        // The description's own field order, and a value outside each enumeration.
        {
            NSMorphology *m = [[NSMorphology alloc] init];
            m.grammaticalGender = 1;
            m.number = 2;
            m.partOfSpeech = 9;
            m.grammaticalCase = 3;
            m.definiteness = 2;
            m.determination = 1;
            m.grammaticalPerson = 2;
            m.pronounType = 1;
            printf("description.ordered\t%s\n", [m.description UTF8String]);
            NSMorphology *out = [[NSMorphology alloc] init];
            out.grammaticalGender = -2;
            out.number = -2;
            out.partOfSpeech = -2;
            out.grammaticalCase = 40;
            out.definiteness = -1;
            out.determination = 9;
            out.grammaticalPerson = -1;
            out.pronounType = 9;
            printf("description.outOfRange\t%s\n", [out.description UTF8String]);
        }

        // Which number makes it not unspecified, and which make it specified.
        for (NSInteger value = 0; value <= 3; value++) {
            NSMorphology *m = [[NSMorphology alloc] init];
            m.number = (NSGrammaticalNumber)value;
            printf("number%ld.unspecified\t%d\n", (long)value, (int)m.unspecified);
        }
        for (NSInteger value = 0; value <= 3; value++) {
            NSMorphology *m = [[NSMorphology alloc] init];
            m.grammaticalGender = (NSGrammaticalGender)value;
            m.partOfSpeech = (NSGrammaticalPartOfSpeech)value;
            m.grammaticalCase = (NSGrammaticalCase)value;
            m.determination = (NSGrammaticalDetermination)value;
            m.grammaticalPerson = (NSGrammaticalPerson)value;
            m.pronounType = (NSGrammaticalPronounType)value;
            m.definiteness = (NSGrammaticalDefiniteness)value;
            printf("only%ld.unspecified\t%d\n", (long)value, (int)m.unspecified);
        }

        // The per-language custom pronoun support, over the set above.
        for (NSString *language in Languages()) {
            printf("supported.%s\t%d\n", language.UTF8String, (int)[NSMorphologyCustomPronoun isSupportedForLanguage:language]);
            NSString *required = List([NSMorphologyCustomPronoun requiredKeysForLanguage:language]);
            printf("required.%s\t%s\n", language.UTF8String, required.UTF8String);
        }

        // Setting a custom pronoun: the full one, an empty one, nil, and one with only the required keys.
        NSMorphologyCustomPronoun *full = [[NSMorphologyCustomPronoun alloc] init];
        full.subjectForm = @"she";
        full.objectForm = @"her";
        full.possessiveForm = @"hers";
        full.possessiveAdjectiveForm = @"her";
        full.reflexiveForm = @"herself";
        NSMorphologyCustomPronoun *subjectOnly = [[NSMorphologyCustomPronoun alloc] init];
        subjectOnly.subjectForm = @"sie";
        for (NSString *language in @[@"en", @"fr", @"de", @"xx_YY", @"klingon", @"", @"123"]) {
            NSMorphology *m = [[NSMorphology alloc] init];
            NSError *error = nil;
            BOOL ok = [m setCustomPronoun:full forLanguage:language error:&error];
            printf("setFull.%s\t%d\t%s\t%ld\t%s\t%s\n", language.UTF8String, (int)ok,
                   error.domain.UTF8String ?: "(none)", error ? (long)error.code : 0,
                   error.localizedDescription.UTF8String ?: "(none)",
                   [m customPronounForLanguage:language].subjectForm.UTF8String ?: "(nil)");
        }
        for (NSString *language in @[@"en", @"fr", @"xx_YY"]) {
            NSMorphology *m = [[NSMorphology alloc] init];
            NSError *error = nil;
            BOOL ok = [m setCustomPronoun:subjectOnly forLanguage:language error:&error];
            printf("setSubjectOnly.%s\t%d\t%s\t%ld\t%s\n", language.UTF8String, (int)ok, error.domain.UTF8String ?: "(none)",
                   error ? (long)error.code : 0, error.localizedDescription.UTF8String ?: "(none)");
            NSError *emptyError = nil;
            BOOL emptyOK = [m setCustomPronoun:[[NSMorphologyCustomPronoun alloc] init] forLanguage:language
                                                  error:&emptyError];
            printf("setEmpty.%s\t%d\t%s\t%ld\t%s\n", language.UTF8String, (int)emptyOK, emptyError.domain.UTF8String ?: "(none)",
                   emptyError ? (long)emptyError.code : 0, emptyError.localizedDescription.UTF8String ?: "(none)");
            NSError *nilError = nil;
            BOOL nilOK = [m setCustomPronoun:nil forLanguage:language error:&nilError];
            printf("setNil.%s\t%d\t%s\t%ld\t%s\n", language.UTF8String, (int)nilOK, nilError.domain.UTF8String ?: "(none)",
                   nilError ? (long)nilError.code : 0, nilError.localizedDescription.UTF8String ?: "(none)");
        }
        // Reading a language that was never set, and one that was.
        {
            NSMorphology *m = [[NSMorphology alloc] init];
            printf("readback.unset\t%s\n", [m customPronounForLanguage:@"en"] ? "an object" : "(nil)");
            [m setCustomPronoun:full forLanguage:@"en" error:NULL];
            printf("readback.en\t%s\n", [m customPronounForLanguage:@"en"].subjectForm.UTF8String ?: "(nil)");
            printf("readback.fr\t%s\n", [m customPronounForLanguage:@"fr"] ? "an object" : "(nil)");
        }

        // The five forms, each written and read back, and the two in the middle defaulted.
        {
            NSMorphologyCustomPronoun *p = [[NSMorphologyCustomPronoun alloc] init];
            printf("forms.empty\t%s\t%s\t%s\t%s\t%s\n", p.subjectForm.UTF8String ?: "(nil)",
                   p.objectForm.UTF8String ?: "(nil)", p.possessiveForm.UTF8String ?: "(nil)",
                   p.possessiveAdjectiveForm.UTF8String ?: "(nil)", p.reflexiveForm.UTF8String ?: "(nil)");
            p.objectForm = @"o";
            p.possessiveForm = @"p";
            p.possessiveAdjectiveForm = @"pa";
            p.reflexiveForm = @"r";
            printf("forms.four\t%s\t%s\t%s\t%s\t%s\n", p.subjectForm.UTF8String ?: "(nil)", p.objectForm.UTF8String,
                   p.possessiveForm.UTF8String, p.possessiveAdjectiveForm.UTF8String, p.reflexiveForm.UTF8String);
        }

        // A pronoun, and what the two unavailable initialisers do.
        {
            NSMorphologyPronoun *p = [[NSMorphologyPronoun alloc] initWithPronoun:@"she"
                                                                              morphology:[[NSMorphology alloc] init]
                                                                  dependentMorphology:nil];
            printf("pronoun\t%s\t%s\t%s\n", p.pronoun.UTF8String, p.morphology ? "an object" : "(nil)",
                   p.dependentMorphology ? "an object" : "(nil)");
        }

        // The inflection rules, over the same languages.
        for (NSString *language in Languages())
            printf("canInflect.%s\t%d\n", language.UTF8String, (int)[NSInflectionRule canInflectLanguage:language]);
        @try {
            printf("automaticRule\t%s\n", [[NSInflectionRule automaticRule] description].UTF8String);
        } @catch (NSException *exception) {
            printf("automaticRule\traises %s: %s\n", exception.name.UTF8String, exception.reason.UTF8String);
        }
        printf("canInflectPreferredLocalization\t%d\n", (int)[NSInflectionRule canInflectPreferredLocalization]);
        {
            NSMorphology *m = [[NSMorphology alloc] init];
            m.number = NSGrammaticalNumberPlural;
            NSInflectionRuleExplicit *rule = [[NSInflectionRuleExplicit alloc] initWithMorphology:m];
            printf("explicit\t%s\t%d\n", [rule.morphology number] == NSGrammaticalNumberPlural ? "plural" : "other",
                   (int)[rule.morphology isEqual:m]);
            @try {
                NSInflectionRuleExplicit *copied = [rule copy];
                printf("explicit.copy\t%s\n", copied.morphology.number == NSGrammaticalNumberPlural ? @"plural" : @"other");
            } @catch (NSException *exception) {
                printf("explicit.copy\traises %s: %s\n", exception.name.UTF8String, exception.reason.UTF8String);
            }
        }

        // The archives, so the keys are the host's.
        {
            NSMutableData *data = [NSMutableData data];
            NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:data];
            [archiver encodeObject:[[NSMorphology alloc] init] forKey:NSKeyedArchiveRootObjectKey];
            [archiver finishEncoding];
            printf("archive.morphology\t%lu\n", (unsigned long)data.length);
            NSKeyedUnarchiver *un = [[NSKeyedUnarchiver alloc] initForReadingWithData:data];
            NSMorphology *back = [un decodeObjectForKey:NSKeyedArchiveRootObjectKey];
            printf("archive.read\t%d\t%d\t%d\t%d\n", (int)back.grammaticalGender, (int)back.partOfSpeech,
                   (int)back.number, (int)back.unspecified);
            NSMutableData *pd = [NSMutableData data];
            NSKeyedArchiver *pa = [[NSKeyedArchiver alloc] initForWritingWithMutableData:pd];
            [pa encodeObject:[[NSMorphologyCustomPronoun alloc] init] forKey:NSKeyedArchiveRootObjectKey];
            [pa finishEncoding];
            printf("archive.pronoun\t%lu\n", (unsigned long)pd.length);
            NSMutableData *rd = [NSMutableData data];
            NSKeyedArchiver *ra = [[NSKeyedArchiver alloc] initForWritingWithMutableData:rd];
            [ra encodeObject:[[NSMorphologyPronoun alloc] initWithPronoun:@"she" morphology:[[NSMorphology alloc] init]
                                                           dependentMorphology:nil]
                      forKey:NSKeyedArchiveRootObjectKey];
            [ra finishEncoding];
            printf("archive.pronounObject\t%lu\n", (unsigned long)rd.length);
            NSMutableData *ed = [NSMutableData data];
            NSKeyedArchiver *ea = [[NSKeyedArchiver alloc] initForWritingWithMutableData:ed];
            [ea encodeObject:[[NSInflectionRuleExplicit alloc] initWithMorphology:[[NSMorphology alloc] init]]
                      forKey:NSKeyedArchiveRootObjectKey];
            [ea finishEncoding];
            printf("archive.rule\t%lu\n", (unsigned long)ed.length);
        }

        // The seven attribute-name constants, read out of the host's own image: each is a
        // FOUNDATION_EXPORT NSAttributedStringKey in the 26.2 SDK's NSAttributedString.h, so the symbol
        // holds an NSString * and the pointer is read, not the bytes at it.
        // Every enumeration name, one case per value from NotSet to the last and the value one past it,
        // which is the parenthesised form. A -description that printed a bare number, or a table with a
        // single wrong entry, answered 344/0 before these were here; these are the cases that hold the
        // eight tables to the host's own names.
        {
            static const struct { const char *property; NSInteger count; } sets[] = {
                {"grammaticalGender:grammaticalGender", 4}, {"partOfSpeech:partOfSpeech", 12},
                {"number:number", 7}, {"grammaticalCase:case", 16},
                {"determination:determination", 3}, {"grammaticalPerson:grammaticalPerson", 4},
                {"definiteness:definiteness", 3}, {"pronounType:pronounType", 4},
            };
            for (unsigned set = 0; set < sizeof(sets) / sizeof(*sets); set++) {
                NSArray *pair = [[NSString stringWithUTF8String:sets[set].property] componentsSeparatedByString:@":"];
                NSString *property = pair[0], *field = pair.count > 1 ? pair[1] : pair[0];
                for (NSInteger value = 0; value <= sets[set].count; value++) {
                    NSMorphology *m = [[NSMorphology alloc] init];
                    [m setValue:@(value) forKey:property];
                    NSString *text = [m description];
                    NSRange at = [text rangeOfString:[field stringByAppendingString:@" = "]];
                    NSUInteger from = at.location == NSNotFound ? 0 : NSMaxRange(at), to = from;
                    while (to < text.length && [text characterAtIndex:to] != ',' && [text characterAtIndex:to] != ' ')
                        to++;
                    printf("every.enumeration.name.%s%ld\t%s\n", property.UTF8String, (long)value,
                           to > from ? [text substringWithRange:NSMakeRange(from, to - from)].UTF8String : "(absent)");
                }
            }
        }

        static const char *constantNames[] = {"NSMorphologyAttributeName", "NSInflectionRuleAttributeName",
                                              "NSInflectionAlternativeAttributeName", "NSInflectionConceptsKey",
                                              "NSInflectionAgreementConceptAttributeName",
                                              "NSInflectionAgreementArgumentAttributeName",
                                              "NSInflectionReferentConceptAttributeName", NULL};
        for (int index = 0; constantNames[index]; index++) {
            const char *name = constantNames[index];
            void *symbol = dlsym(RTLD_DEFAULT, name);
            id value = symbol ? *(__unsafe_unretained id *)symbol : nil;
            printf("constant.%s\t%s\n", name, [value UTF8String] ?: "(null)");
        }

        // The class names, so a rename is caught.
        printf("attributeName\t%s\n", NSMorphologyAttributeName.UTF8String);
        const char *classNames[] = {"NSMorphology", "NSMorphologyCustomPronoun", "NSMorphologyPronoun",
                                   "NSInflectionRule", "NSInflectionRuleExplicit", NULL};
        for (int i = 0; classNames[i]; i++) {
            Class cls = NSClassFromString([NSString stringWithUTF8String:classNames[i]]);
            printf("class.%s\t%d\n", classNames[i], (int)(cls != Nil));
        }
    }
    return 0;
}
