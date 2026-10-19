#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <objc/runtime.h>
#include <signal.h>
#include <unistd.h>
#import "check.h"

/* NSTermOfAddress against the system's own, in one process.

   The port's class is compiled under a name of its own (uikit2/renames.sh with "*", which renames the
   classes and leaves the selectors), so the two never meet and each answer can be held beside the
   other. The expectations are the ones facts/Foundation/NSTermOfAddress.md states, which are the ones
   the review measured against the host: the three gendered terms are three distinct singletons with
   no language and no pronouns; +currentUser is a singleton equal only to itself; a localized term is
   equal to another with the same language and the same pronouns, different when the language differs,
   and different again when the pronouns are an empty array rather than nil; equal terms hash alike.

   This harness is what the delivery did not have, and the review is right that it is the missing half
   of the evidence: the band had measured the *host only*, which is why -isEqual: and -hash sitting on
   the state class went unnoticed for four commits.

   IT DOES NOT BUILD YET, and the first error is worth the space:

       packages/a/apple-backports/Foundation/CharonTermOfAddress.h:39:1: error: duplicate interface
       definition for class 'NSTermOfAddress'

   The cause is the rename, and it is not obvious. renames.sh rewrites NSTermOfAddress to
   CharonHostNSTermOfAddress *everywhere*, so on the host the umbrella's own declaration and the one in
   CharonTermOfAddress.h both become CharonHostNSTermOfAddress. The header's guard cannot tell the two
   builds apart: __has_include(<Foundation/NSTermOfAddress.h>) is false in the host's build -- the class
   reaches the test through the umbrella, and no such file is reachable by that path -- so the port's
   declaration is compiled where it is not needed. The port's own build is the opposite: 16.4 has the
   class nowhere, and the declaration is the whole reason the file compiles.

   So the guard has to be a test of the *build SDK's* version rather than of a file, something like

       #if defined(__IPHONE_OS_VERSION_MAX_ALLOWED) && __IPHONE_OS_VERSION_MAX_ALLOWED < 170000
       ... the declaration ...
       #else
       #import <Foundation/NSTermOfAddress.h>
       #endif

   and that is one edit plus a run of both builds, which is the next piece of work rather than
   something to guess at here. The expectations below are the ones the review measured and the facts
   file states, so the harness is complete apart from that line. */

/* The one cast the whole file uses. A typedef'd pointer is what clang accepts here: a bare
   ((id (*)(id, SEL))objc_msgSend) in a message argument is where the parse gives up. */
typedef id (*CharonSend0)(id, SEL);
typedef id (*CharonSend1)(id, SEL, id);
typedef id (*CharonSend2)(id, SEL, id, id);

void host_attach_prefixed(const char *prefix);

static void charon_on_alarm(int number)
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
    return ((CharonSend0)objc_msgSend)(systemClass, NSSelectorFromString([NSString stringWithFormat:@"%s", factory]));
}

static id our_term(const char *factory)
{
    return ((CharonSend0)objc_msgSend)(ourClass, NSSelectorFromString([NSString stringWithFormat:@"%s", factory]));
}

static id our_localized(NSString *language, id pronouns)
{
    return ((CharonSend2)objc_msgSend)(ourClass, NSSelectorFromString(@"localizedForLanguageIdentifier:withPronouns:"),
                                        language, pronouns);
}

static id system_localized(NSString *language, id pronouns)
{
    return ((CharonSend2)objc_msgSend)(systemClass, NSSelectorFromString(@"localizedForLanguageIdentifier:withPronouns:"),
                                        language, pronouns);
}

/* The fixture the review asked for: a factory on the port that makes a term with a language and no
   pronouns, so the two comparisons -isEqual: makes that the four singletons cannot reach are
   exercised -- "is this the current user's term" and "is this the same language". Without it the suite
   only ever compared terms that carry no language at all, so both lines of the method were untested. */
static id our_term_with_language(NSString *language)
{
    SEL factory = NSSelectorFromString(@"termWithLanguageIdentifier:");
    if (![ourClass respondsToSelector:factory])
        return nil;
    return ((CharonSend1)objc_msgSend)(ourClass, factory, language);
}

static id system_term_with_language(NSString *language)
{
    SEL factory = NSSelectorFromString(@"localizedForLanguageIdentifier:withPronouns:");
    return ((CharonSend2)objc_msgSend)(systemClass, factory, language, (id)nil);
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
        signal(SIGALRM, charon_on_alarm);
        alarm(30);
        ourClass = NSClassFromString(@"CharonHostNSTermOfAddress");
        systemClass = NSClassFromString(@"NSTermOfAddress");
        charon_check(ourClass != Nil, "the port defines NSTermOfAddress under its own name", @"no such class");
        if (!ourClass)
            return 1;

        /* The four singletons, and that they are four and not one. */
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
               [ourCurrent isEqual:((CharonSend0)objc_msgSend)(ourClass, NSSelectorFromString(@"currentUser"))]);

        /* No language and no pronouns on the gendered ones, which is what the host answers. */
        for (NSString *factory in @[@"neutral", @"feminine", @"masculine", @"currentUser"]) {
            id theirs = ((CharonSend0)objc_msgSend)(systemClass, NSSelectorFromString(factory));
            id ours = ((CharonSend0)objc_msgSend)(ourClass, NSSelectorFromString(factory));
            id theirLanguage = ((CharonSend0)objc_msgSend)(theirs, @selector(languageIdentifier));
            id ourLanguage = ((CharonSend0)objc_msgSend)(ours, @selector(languageIdentifier));
            id theirPronouns = ((CharonSend0)objc_msgSend)(theirs, @selector(pronouns));
            id ourPronouns = ((CharonSend0)objc_msgSend)(ours, @selector(pronouns));
            expect([@"the language of " stringByAppendingString:factory],
                   [theirLanguage length] == 0, [ourLanguage length] == 0);
            expect([@"the pronouns of " stringByAppendingString:factory],
                   [theirPronouns count] == 0, [ourPronouns count] == 0);
        }

        /* A localized term, and the equality rules the header and the facts file both state. */
        for (NSString *language in @[@"de", @"en", @"fr", @"zh-Hans"]) {
            for (NSUInteger variant = 0; variant < 2; variant++) {
                id pronouns = variant ? @[] : nil;
                id theirs = system_localized(language, pronouns);
                id ours = our_localized(language, (id)pronouns);
                id ourLanguage = ((CharonSend0)objc_msgSend)(ours, @selector(languageIdentifier));
                expect([NSString stringWithFormat:@"a term for %@ keeps its language (%@)", language,
                        variant ? @"an empty array" : @"nil"],
                       [((CharonSend0)objc_msgSend)(theirs, @selector(languageIdentifier)) isEqualToString:language],
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

        /* The hash, which is the other half of F4: equal terms hash alike, and that is the whole
           contract. */
        id ourAgain = our_localized(@"de", (id)nil), ourEmpty = our_localized(@"de", (id)@[]);
        id theirAgain = system_localized(@"de", nil), theirEmpty = system_localized(@"de", @[]);
        expect(@"equal terms hash alike (de, nil)",
               [theirAgain hash] == [system_localized(@"de", nil) hash], [ourAgain hash] == [ourAgain hash]);
        expect(@"equal terms hash alike (de, an empty array)",
               [theirEmpty hash] == [system_localized(@"de", @[]) hash], [ourEmpty hash] == [ourEmpty hash]);

        /* The fixture, and the two comparisons it exists to reach. */
        id ourEnglish = our_term_with_language(@"en"), ourGerman = our_term_with_language(@"de");
        id theirEnglish = system_term_with_language(@"en"), theirGerman = system_term_with_language(@"de");
        charon_check(ourEnglish != nil, "the port has the +termWithLanguageIdentifier: fixture",
                     @"the fixture is not there, so neither comparison below is exercised");
        if (ourEnglish) {
            /* currentUser: a localized term is never the current user's term, whatever else matches. */
            id ourEnglishAgain = our_term_with_language(@"en");
            expect(@"two terms for the same language are equal", [theirEnglish isEqual:theirEnglish],
                   [ourEnglish isEqual:ourEnglishAgain]);
            expect(@"a localized term is not the current user's",
                   ![theirEnglish isEqual:theirCurrent], ![ourEnglish isEqual:ourCurrent]);
            expect(@"and neither is the gendered ones' equal",
                   ![theirEnglish isEqual:theirNeutral], ![ourEnglish isEqual:ourNeutral]);
            /* languageIdentifier: the language is part of the comparison, and part of the hash. */
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
