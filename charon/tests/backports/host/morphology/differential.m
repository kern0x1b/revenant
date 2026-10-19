#import <Foundation/Foundation.h>
#import <dlfcn.h>
#import "CharonMorphology26.h"

static int checks, failures;

static void expect(BOOL ok, NSString *what, NSString *detail)
{
    checks++;
    if (ok)
        return;
    failures++;
    printf("FAIL %s: %s\n", what.UTF8String, detail.UTF8String);
}

static NSString *charon_normalised(NSString *text)
{
    if (!text)
        return nil;
    NSMutableString *out = [text mutableCopy];
    [out replaceOccurrencesOfString:@"charonHost" withString:@"" options:0 range:NSMakeRange(0, out.length)];
    static NSRegularExpression *address;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ address = [NSRegularExpression regularExpressionWithPattern:@"0x[0-9a-f]+" options:0 error:NULL]; });
    [address replaceMatchesInString:out options:0 range:NSMakeRange(0, out.length) withTemplate:@"0xX"];
    return out;
}

static NSString *charon_field(NSString *description, NSString *property)
{
    NSRange at = [description rangeOfString:[property stringByAppendingString:@" = "]];
    if (at.location == NSNotFound)
        return nil;
    NSUInteger from = NSMaxRange(at), to = from;
    while (to < description.length && [description characterAtIndex:to] != ',' && [description characterAtIndex:to] != ' ')
        to++;
    return [description substringWithRange:NSMakeRange(from, to - from)];
}

static void expectEqual(NSString *ours, NSString *theirs, NSString *what)
{
    if (ours == theirs || [ours isEqualToString:theirs]) {
        checks++;
        return;
    }
    checks++;
    failures++;
    printf("FAIL %s: ours [%s] host [%s]\n", what.UTF8String, ours.UTF8String ?: "(nil)", theirs.UTF8String ?: "(nil)");
}

static void expectEqualInt(long ours, long theirs, NSString *what)
{
    checks++;
    if (ours == theirs)
        return;
    failures++;
    printf("FAIL %s: ours %ld host %ld\n", what.UTF8String, ours, theirs);
}

static void charon_report_uncaught(NSException *exception)
{
    fprintf(stderr, "\nuncaught %s: %s\n", exception.name.UTF8String, exception.reason.UTF8String);
    for (NSUInteger index = 0; index < exception.callStackSymbols.count; index++)
        fprintf(stderr, "  #%lu %s\n", (unsigned long)index, exception.callStackSymbols[index].UTF8String);
    fflush(stderr);
}

int main(int argc, char **argv)
{
    setvbuf(stdout, NULL, _IONBF, 0);
    NSSetUncaughtExceptionHandler(&charon_report_uncaught);
    @autoreleasepool {
        NSString *path = argc > 1 ? [NSString stringWithUTF8String:argv[1]] : @"expected.txt";
        NSString *table = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:NULL];
        if (!table) {
            printf("differential: no golden file at %s\n", path.UTF8String);
            return 1;
        }
        NSMutableDictionary<NSString *, NSString *> *expected = [NSMutableDictionary dictionary];
        for (NSString *line in [table componentsSeparatedByString:@"\n"]) {
            if (!line.length)
                continue;
            NSArray *fields = [line componentsSeparatedByString:@"\t"];
            NSArray *rest = [fields subarrayWithRange:NSMakeRange(1, fields.count - 1)];
            expected[fields[0]] = [rest componentsJoinedByString:@"\t"];
        }

        static const char *settingNames[] = {"grammaticalGender", "partOfSpeech", "number", "grammaticalCase",
                                             "determination", "grammaticalPerson", "pronounType", "definiteness", NULL};
        for (int s = 0; settingNames[s]; s++) {
            const char *name = settingNames[s];
            for (NSInteger value = 0; value <= 3; value++) {
                charonHostNSMorphology *ours = [[charonHostNSMorphology alloc] init];
                NSMorphology *theirs = [[NSMorphology alloc] init];
                [ours setValue:@(value) forKey:[NSString stringWithUTF8String:name]];
                [theirs setValue:@(value) forKey:[NSString stringWithUTF8String:name]];
                NSString *key = [NSString stringWithFormat:@"fresh.%@%ld", [NSString stringWithUTF8String:name], (long)value];
                expect([[ours valueForKey:[NSString stringWithUTF8String:name]] integerValue]
                           == [[theirs valueForKey:[NSString stringWithUTF8String:name]] integerValue],
                       key, @"the setting is stored as written");
                expect(ours.isUnspecified == theirs.isUnspecified,
                       [key stringByAppendingString:@".unspecified"],
                       [NSString stringWithFormat:@"ours %d host %d", (int)ours.isUnspecified, (int)theirs.isUnspecified]);
            }
        }
        {
            charonHostNSMorphology *ours = [[charonHostNSMorphology alloc] init];
            NSMorphology *theirs = [[NSMorphology alloc] init];
            expect(ours.isUnspecified == theirs.isUnspecified, @"fresh.unspecified", @"a fresh one is unspecified");
            expect([[charonHostNSMorphology class] userMorphology].isUnspecified
                       == [NSMorphology userMorphology].isUnspecified,
                   @"userMorphology.unspecified", @"+userMorphology");
        }
        for (int s = 0; settingNames[s]; s++) {
            const char *name = settingNames[s];
            for (NSInteger value = 0; value <= 2; value++) {
                charonHostNSMorphology *ours = [[charonHostNSMorphology alloc] init];
                NSMorphology *theirs = [[NSMorphology alloc] init];
                NSString *key = [NSString stringWithFormat:[NSString stringWithUTF8String:name]];
                [ours setValue:@(value) forKey:key];
                [theirs setValue:@(value) forKey:key];
                NSString *label = [NSString stringWithFormat:@"only%@%ld", key, (long)value];
                expect(ours.isUnspecified == theirs.isUnspecified, label,
                       [NSString stringWithFormat:@"ours %d host %d", (int)ours.isUnspecified, (int)theirs.isUnspecified]);
                expectEqualInt((long)ours.isUnspecified,
                               (long)[expected[label] integerValue], [label stringByAppendingString:@".golden"]);
            }
        }
        {
            const char *names[] = {"grammaticalGender", "number", "partOfSpeech", "grammaticalCase", "definiteness",
                                   "determination", "grammaticalPerson", "pronounType", NULL};
            charonHostNSMorphology *ours = [[charonHostNSMorphology alloc] init];
            NSMorphology *theirs = [[NSMorphology alloc] init];
            const long inRange[] = {1, 2, 9, 3, 2, 1, 2, 1};
            for (int i = 0; names[i]; i++) {
                NSString *key = [NSString stringWithUTF8String:names[i]];
                [ours setValue:@(inRange[i]) forKey:key];
                [theirs setValue:@(inRange[i]) forKey:key];
            }
            expectEqual((charon_normalised([ours description])),
                        (charon_normalised([theirs description])), @"description.ordered");
            expectEqual((charon_normalised([ours description])),
                        (charon_normalised(expected[@"description.ordered"])), @"description.ordered.golden");

            charonHostNSMorphology *odd = [[charonHostNSMorphology alloc] init];
            NSMorphology *theirsOdd = [[NSMorphology alloc] init];
            const long outOfRange[] = {-2, -2, -2, 40, -1, 9, -1, 9};
            for (int i = 0; names[i]; i++) {
                NSString *key = [NSString stringWithUTF8String:names[i]];
                [odd setValue:@(outOfRange[i]) forKey:key];
                [theirsOdd setValue:@(outOfRange[i]) forKey:key];
            }
            expectEqual((charon_normalised([odd description])),
                        (charon_normalised([theirsOdd description])), @"description.outOfRange");
            expectEqual((charon_normalised([odd description])),
                        (charon_normalised(expected[@"description.outOfRange"])), @"description.outOfRange.golden");
        }
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
                    charonHostNSMorphology *ours = [[charonHostNSMorphology alloc] init];
                    NSMorphology *theirs = [[NSMorphology alloc] init];
                    [ours setValue:@(value) forKey:property];
                    [theirs setValue:@(value) forKey:property];
                    NSString *label = [NSString stringWithFormat:@"every.enumeration.name.%@%ld", property, (long)value];
                    NSString *mine = charon_field([ours description], field);
                    NSString *theirs_ = charon_field([theirs description], field);
                    expectEqual(mine, theirs_, label);
                    expectEqual(mine, expected[label], [label stringByAppendingString:@".golden"]);
                }
            }
        }

        {
            NSArray *languages = @[@"en", @"en_US", @"en_GB", @"fr", @"fr_FR", @"de", @"ru", @"ja", @"ar", @"es", @"pt",
                                   @"zh", @"it", @"nl", @"pl", @"tr", @"ko", @"he", @"th", @"hi", @"und", @"", @"xx_YY",
                                   @"klingon", @"123"];
            for (NSString *language in languages) {
                BOOL ours = [charonHostNSMorphologyCustomPronoun isSupportedForLanguage:language];
                BOOL theirs = [NSMorphologyCustomPronoun isSupportedForLanguage:language];
                expect(ours == theirs, [NSString stringWithFormat:@"supported.%@", language],
                       [NSString stringWithFormat:@"ours %d host %d", (int)ours, (int)theirs]);
                expectEqual(ours ? @"1" : @"0", expected[[NSString stringWithFormat:@"supported.%@", language]],
                            [NSString stringWithFormat:@"supported.%@.golden", language]);
                NSArray *oursKeys = [charonHostNSMorphologyCustomPronoun requiredKeysForLanguage:language];
                NSArray *theirKeys = [NSMorphologyCustomPronoun requiredKeysForLanguage:language];
                expectEqual([oursKeys componentsJoinedByString:@","], [theirKeys componentsJoinedByString:@","],
                            [NSString stringWithFormat:@"required.%@", language]);
                expectEqual([oursKeys componentsJoinedByString:@","],
                            expected[[NSString stringWithFormat:@"required.%@", language]],
                            [NSString stringWithFormat:@"required.%@.golden", language]);
            }
            charonHostNSMorphologyCustomPronoun *full = [[charonHostNSMorphologyCustomPronoun alloc] init];
            full.subjectForm = @"she"; full.objectForm = @"her"; full.possessiveForm = @"hers";
            full.possessiveAdjectiveForm = @"her"; full.reflexiveForm = @"herself";
            for (NSString *language in @[@"en", @"fr", @"xx_YY", @"klingon", @"", @"123"]) {
                charonHostNSMorphology *ours = [[charonHostNSMorphology alloc] init];
                NSMorphology *theirs = [[NSMorphology alloc] init];
                NSError *ourError = nil, *theirError = nil;
                BOOL oursOK = [ours setCustomPronoun:full forLanguage:language error:&ourError];
                BOOL theirOK = [theirs setCustomPronoun:full forLanguage:language error:&theirError];
                NSString *label = [NSString stringWithFormat:@"setFull.%@", language];
                expect(oursOK == theirOK, label, [NSString stringWithFormat:@"ours %d host %d", (int)oursOK, (int)theirOK]);
                expectEqual(ourError.domain, theirError.domain, [label stringByAppendingString:@".domain"]);
                expectEqualInt((long)ourError.code, (long)theirError.code, [label stringByAppendingString:@".code"]);
                expectEqual(ourError.localizedDescription, theirError.localizedDescription, [label stringByAppendingString:@".wording"]);
                expectEqual([ours customPronounForLanguage:language].subjectForm,
                            [theirs customPronounForLanguage:language].subjectForm, [label stringByAppendingString:@".readBack"]);
            }
            for (NSString *language in @[@"en", @"fr", @"xx_YY"]) {
                charonHostNSMorphologyCustomPronoun *subjectOnly = [[charonHostNSMorphologyCustomPronoun alloc] init];
                subjectOnly.subjectForm = @"sie";
                charonHostNSMorphology *ours = [[charonHostNSMorphology alloc] init];
                NSMorphology *theirs = [[NSMorphology alloc] init];
                NSError *ourError = nil, *theirError = nil;
                BOOL oursOK = [ours setCustomPronoun:subjectOnly forLanguage:language error:&ourError];
                BOOL theirOK = [theirs setCustomPronoun:subjectOnly forLanguage:language error:&theirError];
                NSString *label = [NSString stringWithFormat:@"setSubjectOnly.%@", language];
                expect(oursOK == theirOK, label, @"the same verdict");
                expectEqual(ourError.localizedDescription, theirError.localizedDescription, [label stringByAppendingString:@".wording"]);

                charonHostNSMorphology *oursEmpty = [[charonHostNSMorphology alloc] init];
                NSMorphology *theirsEmpty = [[NSMorphology alloc] init];
                NSError *ourEmpty = nil, *theirEmpty = nil;
                BOOL oursEmptyOK = [oursEmpty setCustomPronoun:[[charonHostNSMorphologyCustomPronoun alloc] init]
                                              forLanguage:language error:&ourEmpty];
                BOOL theirsEmptyOK = [theirsEmpty setCustomPronoun:[[NSMorphologyCustomPronoun alloc] init]
                                                  forLanguage:language error:&theirEmpty];
                expect(oursEmptyOK == theirsEmptyOK, [NSString stringWithFormat:@"setEmpty.%@", language], @"the same verdict");
                expectEqual(ourEmpty.localizedDescription, theirEmpty.localizedDescription,
                            [NSString stringWithFormat:@"setEmpty.%@.wording", language]);

                charonHostNSMorphology *oursNil = [[charonHostNSMorphology alloc] init];
                NSMorphology *theirsNil = [[NSMorphology alloc] init];
                NSError *ourNil = nil, *theirNil = nil;
                BOOL oursNilOK = [oursNil setCustomPronoun:nil forLanguage:language error:&ourNil];
                BOOL theirsNilOK = [theirsNil setCustomPronoun:nil forLanguage:language error:&theirNil];
                expect(oursNilOK == theirsNilOK, [NSString stringWithFormat:@"setNil.%@", language], @"the same verdict");
            }
            charonHostNSMorphologyCustomPronoun *oursForms = [[charonHostNSMorphologyCustomPronoun alloc] init];
            NSMorphologyCustomPronoun *theirForms = [[NSMorphologyCustomPronoun alloc] init];
            expectEqual((charon_normalised([oursForms description])),
                        (charon_normalised([theirForms description])), @"forms.empty");
            oursForms.objectForm = @"o"; oursForms.possessiveForm = @"p";
            oursForms.possessiveAdjectiveForm = @"pa"; oursForms.reflexiveForm = @"r";
            theirForms.objectForm = @"o"; theirForms.possessiveForm = @"p";
            theirForms.possessiveAdjectiveForm = @"pa"; theirForms.reflexiveForm = @"r";
            expectEqual((charon_normalised([oursForms description])),
                        (charon_normalised([theirForms description])), @"forms.four");
        }
        {
            charonHostNSMorphologyPronoun *ours = [[charonHostNSMorphologyPronoun alloc] initWithPronoun:@"she"
                                                                                             morphology:[[charonHostNSMorphology alloc] init]
                                                                                     dependentMorphology:nil];
            NSMorphologyPronoun *theirs = [[NSMorphologyPronoun alloc] initWithPronoun:@"she"
                                                                            morphology:[[NSMorphology alloc] init]
                                                                    dependentMorphology:nil];
            expectEqual(ours.pronoun, theirs.pronoun, @"pronoun.itself");
            expect(ours.morphology != nil && theirs.morphology != nil, @"pronoun.morphology", @"both have one");
            expect((ours.dependentMorphology == nil) == (theirs.dependentMorphology == nil), @"pronoun.dependent",
                   @"both nil");
        }
        {
            NSArray *languages = @[@"en", @"en_US", @"en_GB", @"fr", @"fr_FR", @"de", @"ru", @"ja", @"ar", @"es", @"pt",
                                   @"zh", @"it", @"nl", @"pl", @"tr", @"ko", @"he", @"th", @"hi", @"und", @"", @"xx_YY",
                                   @"klingon", @"123"];
            for (NSString *language in languages) {
                BOOL ours = [charonHostNSInflectionRule canInflectLanguage:language];
                BOOL theirs = [NSInflectionRule canInflectLanguage:language];
                NSString *label = [NSString stringWithFormat:@"canInflect.%@", language];
                expect(ours == theirs, label, [NSString stringWithFormat:@"ours %d host %d", (int)ours, (int)theirs]);
                expectEqual(ours ? @"1" : @"0", expected[label], [label stringByAppendingString:@".golden"]);
            }
            expectEqual([[charonHostNSInflectionRule automaticRule] description],
                        [[NSInflectionRule automaticRule] description], @"automaticRule");
            expectEqualInt((long)[charonHostNSInflectionRule canInflectPreferredLocalization],
                           (long)[NSInflectionRule canInflectPreferredLocalization], @"canInflectPreferredLocalization");
        }
        {
            charonHostNSMorphology *morphology = [[charonHostNSMorphology alloc] init];
            morphology.number = 2;
            charonHostNSInflectionRuleExplicit *ours = [[charonHostNSInflectionRuleExplicit alloc] initWithMorphology:morphology];
            NSMorphology *theirMorphology = [[NSMorphology alloc] init];
            theirMorphology.number = 2;
            NSInflectionRuleExplicit *theirs = [[NSInflectionRuleExplicit alloc] initWithMorphology:theirMorphology];
            expectEqualInt((long)ours.morphology.number, (long)theirs.morphology.number, @"explicit.morphology");
            expect([ours.morphology isEqual:morphology] == [theirs.morphology isEqual:theirMorphology], @"explicit.isEqual",
                   @"the same verdict");
            NSString *oursCopy = nil, *theirCopy = nil;
            @try { oursCopy = [ours copy] ? @"a copy" : @"(nil)"; }
            @catch (NSException *e) { oursCopy = [NSString stringWithFormat:@"raises %@: %@", e.name, e.reason]; }
            @try { theirCopy = [theirs copy] ? @"a copy" : @"(nil)"; }
            @catch (NSException *e) { theirCopy = [NSString stringWithFormat:@"raises %@: %@", e.name, e.reason]; }
            expectEqual(charon_normalised(oursCopy), charon_normalised(theirCopy), @"explicit.copy");
            expectEqual(charon_normalised(oursCopy), expected[@"explicit.copy"], @"explicit.copy.golden");
        }
        {
            charonHostNSMorphology *ours = [[charonHostNSMorphology alloc] init];
            ours.number = 2;
            NSMutableData *ourData = [NSMutableData data];
            NSKeyedArchiver *ourArchiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:ourData];
            [ourArchiver encodeObject:ours forKey:NSKeyedArchiveRootObjectKey];
            [ourArchiver finishEncoding];
            NSKeyedUnarchiver *ourUnarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:ourData];
            charonHostNSMorphology *ourBack = [ourUnarchiver decodeObjectForKey:NSKeyedArchiveRootObjectKey];
            expectEqualInt((long)ourBack.number, 2, @"archive.morphology.number");
            expectEqualInt((long)ourBack.isUnspecified, 0, @"archive.morphology.unspecified");

            charonHostNSMorphologyCustomPronoun *ourPronoun = [[charonHostNSMorphologyCustomPronoun alloc] init];
            ourPronoun.subjectForm = @"she";
            NSMutableData *ourPronounData = [NSMutableData data];
            NSKeyedArchiver *ourPronounArchiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:ourPronounData];
            [ourPronounArchiver encodeObject:ourPronoun forKey:NSKeyedArchiveRootObjectKey];
            [ourPronounArchiver finishEncoding];
            NSKeyedUnarchiver *ourPronounUnarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:ourPronounData];
            charonHostNSMorphologyCustomPronoun *ourPronounBack =
                [ourPronounUnarchiver decodeObjectForKey:NSKeyedArchiveRootObjectKey];
            expectEqual(ourPronounBack.subjectForm, @"she", @"archive.pronoun.subjectForm");
        }
        {
            extern NSAttributedStringKey const NSMorphologyAttributeName;
            extern NSAttributedStringKey const NSInflectionRuleAttributeName;
            extern NSAttributedStringKey const NSInflectionAlternativeAttributeName;
            extern NSAttributedStringKey const NSInflectionAgreementConceptAttributeName;
            extern NSAttributedStringKey const NSInflectionAgreementArgumentAttributeName;
            extern NSAttributedStringKey const NSInflectionReferentConceptAttributeName;
            extern NSString *const NSInflectionConceptsKey;
            struct { NSString *key; NSString *ours; } pairs[] = {
                { @"constant.NSMorphologyAttributeName", NSMorphologyAttributeName },
                { @"constant.NSInflectionRuleAttributeName", NSInflectionRuleAttributeName },
                { @"constant.NSInflectionAlternativeAttributeName", NSInflectionAlternativeAttributeName },
                { @"constant.NSInflectionAgreementConceptAttributeName", NSInflectionAgreementConceptAttributeName },
                { @"constant.NSInflectionAgreementArgumentAttributeName", NSInflectionAgreementArgumentAttributeName },
                { @"constant.NSInflectionReferentConceptAttributeName", NSInflectionReferentConceptAttributeName },
                { @"constant.NSInflectionConceptsKey", NSInflectionConceptsKey },
            };
            for (unsigned i = 0; i < sizeof pairs / sizeof *pairs; i++) {
                expectEqual(pairs[i].ours, expected[pairs[i].key], pairs[i].key);
                Dl_info where;
                memset(&where, 0, sizeof where);
                const char *image = dladdr((__bridge const void *)pairs[i].ours, &where) && where.dli_fname
                                    ? strrchr(where.dli_fname, '/') + 1 : "(unresolved)";
                printf("%s.image\t%s\n", pairs[i].key.UTF8String, image);
            }
        }
        for (NSString *key in @[@"class.NSMorphology", @"class.NSMorphologyCustomPronoun", @"class.NSMorphologyPronoun",
                                @"class.NSInflectionRule", @"class.NSInflectionRuleExplicit"]) {
            NSString *name = [key substringFromIndex:@"class.".length];
            expect(NSClassFromString(name) != Nil, key, @"the class is there");
            expectEqual(expected[key], @"1", [key stringByAppendingString:@".golden"]);
        }
        {
            NSMorphology *ours = [[charonHostNSMorphology class] userMorphology];
            NSMorphology *theirs = [NSMorphology userMorphology];
            expect((ours == nil) == (theirs == nil), @"class.userMorphology",
                   [NSString stringWithFormat:@"ours %@ host %@", ours, theirs]);
            expectEqual(expected[@"class.userMorphology.value"], ours ? @"an object" : @"(nil)",
                        @"class.userMorphology.value");
            expect(ours == nil || ours.isUnspecified == theirs.isUnspecified,
                   @"class.userMorphology.unspecified", @"the two read the same setting");
        }
        {
            charonHostNSMorphology *morphology = [[charonHostNSMorphology alloc] init];
            [morphology setValue:@(2) forKey:@"grammaticalCase"];
            NSMorphology *hostMorphology = [[NSMorphology alloc] init];
            [hostMorphology setValue:@(2) forKey:@"grammaticalCase"];

            charonHostNSMorphologyPronoun *ours = [[charonHostNSMorphologyPronoun alloc]
                    initWithPronoun:@"they" morphology:morphology dependentMorphology:nil];
            NSMorphologyPronoun *theirs = [[NSMorphologyPronoun alloc]
                    initWithPronoun:@"they" morphology:hostMorphology dependentMorphology:nil];
            expect([[ours pronoun] isEqual:[theirs pronoun]], @"constructed.pronoun",
                   [NSString stringWithFormat:@"ours %@ host %@", [ours pronoun], [theirs pronoun]]);
            expectEqual(expected[@"constructed.pronoun.value"], [ours pronoun] ?: @"(nil)",
                        @"constructed.pronoun.value");
            expect([ours morphology].grammaticalCase == [theirs morphology].grammaticalCase,
                   @"constructed.morphology", @"the two keep the morphology they were given");
            expect([ours dependentMorphology] == nil && [theirs dependentMorphology] == nil,
                   @"constructed.dependentMorphology", @"neither keeps a dependent one");
            expect([ours copy] != nil, @"constructed.pronoun.copy", @"-copy answers an object");

            charonHostNSInflectionRuleExplicit *rule = [[charonHostNSInflectionRuleExplicit alloc]
                    initWithMorphology:morphology];
            NSInflectionRuleExplicit *hostRule = [[NSInflectionRuleExplicit alloc]
                    initWithMorphology:hostMorphology];
            expect(rule.morphology.grammaticalCase == hostRule.morphology.grammaticalCase,
                   @"constructed.explicitRule.morphology",
                   [NSString stringWithFormat:@"ours %ld host %ld", (long)rule.morphology.grammaticalCase,
                    (long)hostRule.morphology.grammaticalCase]);
        }
        printf("checks=%d failures=%d\n", checks, failures);
    }
    return failures == 0 ? 0 : 1;
}
