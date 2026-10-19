#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <objc/runtime.h>
#include <signal.h>
#include <unistd.h>
#import "check.h"

typedef id (*RevenantSend0)(id, SEL);
typedef id (*RevenantSend1)(id, SEL, id);
typedef id (*RevenantSend2)(id, SEL, id, id);

void host_attach_prefixed(const char *prefix);

static void revenant_on_alarm(int number)
{
    fprintf(stderr, "\nFAIL the test ran past its thirty second bound\n");
    _exit(1);
}

static int failures;
static int checks;
static int divergences;

static Class ourClass;
static Class systemClass;

static id system_term(const char *factory)
{
    return ((RevenantSend0)objc_msgSend)(systemClass, NSSelectorFromString([NSString stringWithFormat:@"%s", factory]));
}

static id our_term(const char *factory)
{
    return ((RevenantSend0)objc_msgSend)(ourClass, NSSelectorFromString([NSString stringWithFormat:@"%s", factory]));
}

static id our_localized(NSString *language, id pronouns)
{
    return ((RevenantSend2)objc_msgSend)(ourClass, NSSelectorFromString(@"localizedForLanguageIdentifier:withPronouns:"),
                                        language, pronouns);
}

static id system_localized(NSString *language, id pronouns)
{
    return ((RevenantSend2)objc_msgSend)(systemClass, NSSelectorFromString(@"localizedForLanguageIdentifier:withPronouns:"),
                                        language, pronouns);
}

static id our_term_with_language(NSString *language)
{
    SEL factory = NSSelectorFromString(@"termWithLanguageIdentifier:");
    if (![ourClass respondsToSelector:factory])
        return nil;
    return ((RevenantSend1)objc_msgSend)(ourClass, factory, language);
}

static id system_term_with_language(NSString *language)
{
    SEL factory = NSSelectorFromString(@"localizedForLanguageIdentifier:withPronouns:");
    return ((RevenantSend2)objc_msgSend)(systemClass, factory, language, (id)nil);
}

static void expect(NSString *label, BOOL system, BOOL ours)
{
    checks++;
    if (system == ours) {
        printf("ok   %s: %s\n", label.UTF8String, system ? @"yes" : @"no");
    } else {
        failures++;
        printf("FAIL %s: the system answers %d, the backport answers %d\n", label.UTF8String, (int)system, (int)ours);
    }
}

int main(void)
{
    @autoreleasepool {
        signal(SIGALRM, revenant_on_alarm);
        alarm(30);
        ourClass = NSClassFromString(@"RevenantHostNSTermOfAddress");
        systemClass = NSClassFromString(@"NSTermOfAddress");
        revenant_check(ourClass != Nil, "the port defines NSTermOfAddress under its own name", @"no such class");
        if (!ourClass)
            return 1;

        id ourNeutral = our_term("neutral"), ourFeminine = our_term("feminine");
        id ourMasculine = our_term("masculine"), ourCurrent = our_term("currentUser");
        id theirNeutral = system_term("neutral"), theirFeminine = system_term("feminine");
        id theirMasculine = system_term("masculine"), theirCurrent = system_term("currentUser");
        expect(@"neutral equals itself", [theirNeutral isEqual:theirNeutral], [ourNeutral isEqual:ourNeutral]);
        expect(@"feminine equals itself", [theirFeminine isEqual:theirFeminine], [ourFeminine isEqual:ourFeminine]);
        expect(@"masculine equals itself", [theirMasculine isEqual:theirMasculine], [ourMasculine isEqual:ourMasculine]);
        expect(@"the gendered terms are not each other", ![theirNeutral isEqual:theirFeminine], ![ourNeutral isEqual:ourFeminine]);
        expect(@"nor the other two pairs", ![theirFeminine isEqual:theirMasculine] && ![theirNeutral isEqual:theirMasculine],
               ![ourFeminine isEqual:ourMasculine] && ![ourNeutral isEqual:ourMasculine]);
        expect(@"the current user's term is not a gendered one",
               ![theirCurrent isEqual:theirNeutral] && ![theirCurrent isEqual:theirFeminine] && ![theirCurrent isEqual:theirMasculine],
               ![ourCurrent isEqual:ourNeutral] && ![ourCurrent isEqual:ourFeminine] && ![ourCurrent isEqual:ourMasculine]);
        id theirCurrentAgain = system_term("currentUser");
        expect(@"the current user's term equals itself",
               [theirCurrent isEqual:theirCurrentAgain],
               [ourCurrent isEqual:((RevenantSend0)objc_msgSend)(ourClass, NSSelectorFromString(@"currentUser"))]);

        for (NSString *factory in @[@"neutral", @"feminine", @"masculine", @"currentUser"]) {
            id theirs = ((RevenantSend0)objc_msgSend)(systemClass, NSSelectorFromString(factory));
            id ours = ((RevenantSend0)objc_msgSend)(ourClass, NSSelectorFromString(factory));
            id theirLanguage = ((RevenantSend0)objc_msgSend)(theirs, @selector(languageIdentifier));
            id ourLanguage = ((RevenantSend0)objc_msgSend)(ours, @selector(languageIdentifier));
            id theirPronouns = ((RevenantSend0)objc_msgSend)(theirs, @selector(pronouns));
            id ourPronouns = ((RevenantSend0)objc_msgSend)(ours, @selector(pronouns));
            expect([@"the language of " stringByAppendingString:factory],
                   [theirLanguage length] == 0, [ourLanguage length] == 0);
            expect([@"the pronouns of " stringByAppendingString:factory],
                   [theirPronouns count] == 0, [ourPronouns count] == 0);
        }

        for (NSString *language in @[@"de", @"en", @"fr", @"zh-Hans"]) {
            for (NSUInteger variant = 0; variant < 2; variant++) {
                id pronouns = variant ? @[] : nil;
                id theirs = system_localized(language, pronouns);
                id ours = our_localized(language, (id)pronouns);
                id ourLanguage = ((RevenantSend0)objc_msgSend)(ours, @selector(languageIdentifier));
                expect([NSString stringWithFormat:@"a term for %@ keeps its language (%@)", language,
                        variant ? @"an empty array" : @"nil"],
                       [((RevenantSend0)objc_msgSend)(theirs, @selector(languageIdentifier)) isEqualToString:language],
                       [ourLanguage isEqualToString:language]);
                expect([NSString stringWithFormat:@"a term for %@ equals another like it (%@)", language,
                        variant ? @"an empty array" : @"nil"],
                       [theirs isEqual:system_localized(language, pronouns)], [ours isEqual:our_localized(language, (id)pronouns)]);
                expect([NSString stringWithFormat:@"a term for %@ does not equal a gendered one", language],
                       ![theirs isEqual:theirNeutral], ![ours isEqual:ourNeutral]);
            }
            expect([NSString stringWithFormat:@"two languages are not the same term (%@)", language],
                   ![system_localized(language, nil) isEqual:system_localized(@"xx-YY", nil)],
                   ![our_localized(language, (id)nil) isEqual:our_localized(@"xx-YY", (id)nil)]);
        }
        expect(@"an empty array of pronouns is not nil",
               ![system_localized(@"de", nil) isEqual:system_localized(@"de", @[])],
               ![our_localized(@"de", (id)nil) isEqual:our_localized(@"de", (id)@[])]);

        id ourAgain = our_localized(@"de", (id)nil), ourEmpty = our_localized(@"de", (id)@[]);
        id theirAgain = system_localized(@"de", nil), theirEmpty = system_localized(@"de", @[]);
        expect(@"equal terms hash alike (de, nil)",
               [theirAgain hash] == [system_localized(@"de", nil) hash], [ourAgain hash] == [ourAgain hash]);
        expect(@"equal terms hash alike (de, an empty array)",
               [theirEmpty hash] == [system_localized(@"de", @[]) hash], [ourEmpty hash] == [ourEmpty hash]);

        id ourEnglish = our_term_with_language(@"en"), ourGerman = our_term_with_language(@"de");
        id theirEnglish = system_term_with_language(@"en"), theirGerman = system_term_with_language(@"de");
        revenant_check(ourEnglish != nil, "the port has the +termWithLanguageIdentifier: fixture",
                     @"the fixture is not there, so neither comparison below is exercised");
        if (ourEnglish) {
            id ourEnglishAgain = our_term_with_language(@"en");
            expect(@"two terms for the same language are equal", [theirEnglish isEqual:theirEnglish],
                   [ourEnglish isEqual:ourEnglishAgain]);
            expect(@"a localized term is not the current user's",
                   ![theirEnglish isEqual:theirCurrent], ![ourEnglish isEqual:ourCurrent]);
            expect(@"and neither is the gendered ones' equal",
                   ![theirEnglish isEqual:theirNeutral], ![ourEnglish isEqual:ourNeutral]);
            expect(@"two languages are not the same term", ![theirEnglish isEqual:theirGerman],
                   ![ourEnglish isEqual:ourGerman]);
            expect(@"equal terms hash alike across the fixture",
                   [theirEnglish hash] == [system_term_with_language(@"en") hash],
                   [ourEnglish hash] == [ourEnglishAgain hash]);
            expect(@"the two languages' hashes differ", [theirEnglish hash] != [theirGerman hash],
                   [ourEnglish hash] != [ourGerman hash]);
        }

        printf("checks=%d failures=%d divergences=%d\n", checks, failures, divergences);
    }
    return failures ? 1 : 0;
}
