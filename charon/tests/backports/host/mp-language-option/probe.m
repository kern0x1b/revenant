// What Apple's own MediaPlayer answers, measured on THIS machine, for the two accessors
// MPNowPlayingInfoLanguageOption90.m answers rather than stores.
//
// Each header line is a paraphrase of MPNowPlayingInfoLanguageOption.h, which documents both as the
// special option standing for the best legible or audible language, chosen from system preferences (:56-63),
// and :57-59 says a languageTag holding the auto language-tag constant is that
// special case - a constant the SDK declares nowhere, so its value cannot be written down from the
// headers. This program asks the question the other way round: build every option the class's own
// designated initialiser can build and print what Apple's class answers, so the port's answer is
// compared with the real one rather than with a reading of the comment.
//
// Three questions, each with its own control:
//
//   1. DOES THE INITIALISER STORE THE TYPE? Without this the rest measures nothing: an initialiser that
//      dropped the type would answer NO on every row and the table would look like a refutation of the
//      type without being one.
//   2. WHICH TAG, IF ANY, ANSWERS YES? Thirteen values, among them the literal constant name the header
//      prints, plus the nil tag :57-58 says disables the option.
//   3. DO THE OTHER THREE ARGUMENTS DECIDE IT? characteristics, displayName and identifier, as nil, as
//      empty and as filled, and the same option installed as a group's default.
//
// The one control is that the class really declares the five-argument initialiser: a framework that did
// not would answer through the inherited -init and every row below would be about nothing. Nothing here
// is CALLED on a library and nothing writes to the user's media library; options are constructed and
// read.
//
//     xcrun clang -fobjc-arc -w -framework Foundation -framework MediaPlayer probe.m -o probe
//     ./probe
//
// What the answer was when this file was written, on this machine: 34 options built, 0 answering YES,
// and the type round-tripping for 0 and 1 - so the discriminator is none of the five arguments the
// initialiser takes. The option the system inserts to mean "choose for me" is not one a caller can build,
// on Apple's class or on the port's.
#import <Foundation/Foundation.h>
#import <MediaPlayer/MediaPlayer.h>
#import <objc/message.h>
#include <stdio.h>

static SEL s_init, s_audible, s_legible, s_tag, s_type, s_ident;

static id make(NSUInteger type, NSString *tag, NSArray *characteristics, NSString *displayName, NSString *identifier)
{
    return ((id (*)(id, SEL, NSUInteger, id, id, id, id))objc_msgSend)([MPNowPlayingInfoLanguageOption alloc],
                                                                        s_init, type, tag,
                                                                        characteristics, displayName, identifier);
}

static BOOL flag(id option, SEL sel)
{
    return (BOOL)((BOOL (*)(id, SEL))objc_msgSend)(option, sel);
}

static NSString *tag(id option)
{
    return ((NSString *(*)(id, SEL))objc_msgSend)(option, s_tag);
}

static NSUInteger type(id option)
{
    return (NSUInteger)((NSUInteger (*)(id, SEL))objc_msgSend)(option, s_type);
}

int main(void)
{
    @autoreleasepool {
        s_init = NSSelectorFromString(@"initWithType:languageTag:characteristics:displayName:identifier:");
        s_audible = NSSelectorFromString(@"isAutomaticAudibleLanguageOption");
        s_legible = NSSelectorFromString(@"isAutomaticLegibleLanguageOption");
        s_tag = NSSelectorFromString(@"languageTag");
        s_type = NSSelectorFromString(@"languageOptionType");
        s_ident = NSSelectorFromString(@"identifier");

        if (![MPNowPlayingInfoLanguageOption instancesRespondToSelector:s_init]) {
            printf("CONTROL-FAILED\tinitWithType:languageTag:characteristics:displayName:identifier:\n");
            return 1;
        }
        printf("CONTROL\tMPNowPlayingInfoLanguageOption declares the five-argument initialiser\n");

        printf("== 1. THE ROUND TRIP: is the type stored? ==\n");
        int round_trip_ok = 0;
        for (NSUInteger given = 0; given < 2; given++) {
            id option = make(given, @"en", @[], @"English", @"1");
            NSUInteger read_back = type(option);
            printf("given=%lu read-back=%lu tag=%s\n", (unsigned long)given, (unsigned long)read_back,
                   [tag(option) UTF8String] ?: "(nil)");
            if (read_back == given)
                round_trip_ok++;
        }
        if (round_trip_ok != 2) {
            printf("CONTROL-FAILED\tthe type does not round-trip, so the grid below would measure nothing\n");
            return 1;
        }
        printf("CONTROL\tboth types round-trip, so a NO below is an answer and not a dropped argument\n");

        printf("== 2. THE TAG: which value, if any, answers YES? ==\n");
        const char *tags[] = {"en", "", "auto", "und", "mul", "zxx", "-auto-", "x-auto", "*",
                              "MPLangaugeOptionAutoLangaugeTag", "auto-langauge", "system", NULL};
        int built = 0, yes = 0;
        for (int i = 0; tags[i]; i++) {
            NSString *value = [NSString stringWithUTF8String:tags[i]];
            for (NSUInteger t = 0; t < 2; t++) {
                id option = make(t, value, @[], @"English", @"1");
                BOOL audible = flag(option, s_audible), legible = flag(option, s_legible);
                printf("type=%lu tag=%-34s audible=%d legible=%d\n", (unsigned long)t, tags[i], audible, legible);
                built++;
                if (audible || legible)
                    yes++;
            }
        }
        for (NSUInteger t = 0; t < 2; t++) {   // the nil tag :57-58 says disables the option
            id option = make(t, nil, @[], @"English", @"1");
            BOOL audible = flag(option, s_audible), legible = flag(option, s_legible);
            printf("type=%lu tag=(nil)                  audible=%d legible=%d\n", (unsigned long)t, audible, legible);
            built++;
            if (audible || legible)
                yes++;
        }

        printf("== 3. THE OTHER THREE ARGUMENTS ==\n");
        for (NSUInteger t = 0; t < 2; t++) {
            id bare = make(t, @"en", nil, nil, nil);
            printf("type=%lu all-nil-except-tag        audible=%d legible=%d\n", (unsigned long)t,
                   flag(bare, s_audible), flag(bare, s_legible));
            built++;
            if (flag(bare, s_audible) || flag(bare, s_legible))
                yes++;
            id empty = make(t, @"en", @[], @"", @"");
            printf("type=%lu empty-strings            audible=%d legible=%d\n", (unsigned long)t,
                   flag(empty, s_audible), flag(empty, s_legible));
            built++;
            if (flag(empty, s_audible) || flag(empty, s_legible))
                yes++;
            id marked = make(t, @"en", @[@"public.audio", @"public.describes-video"], @"English", @"1");
            printf("type=%lu characteristics          audible=%d legible=%d\n", (unsigned long)t,
                   flag(marked, s_audible), flag(marked, s_legible));
            built++;
            if (flag(marked, s_audible) || flag(marked, s_legible))
                yes++;
        }

        printf("== 4. THE GROUP: does being the group's default make an option automatic? ==\n");
        id first = make(0, @"en", @[], @"English", @"1");
        id second = make(1, @"fr", @[], @"French", @"2");
        MPNowPlayingInfoLanguageOptionGroup *group =
            [[MPNowPlayingInfoLanguageOptionGroup alloc] initWithLanguageOptions:@[first, second]
                                                          defaultLanguageOption:second
                                                            allowEmptySelection:YES];
        for (NSUInteger i = 0; i < group.languageOptions.count; i++) {
            id option = group.languageOptions[i];
            printf("group option %lu type=%lu is-default=%d audible=%d legible=%d identifier=%s\n",
                   (unsigned long)i, (unsigned long)type(option), option == group.defaultLanguageOption,
                   flag(option, s_audible), flag(option, s_legible),
                   [((NSString *(*)(id, SEL))objc_msgSend)(option, s_ident) UTF8String] ?: "(nil)");
            built++;
            if (flag(option, s_audible) || flag(option, s_legible))
                yes++;
        }

        printf("== SUMMARY\toptions built=%d\tautomatic=%d ==\n", built, yes);
    }
    return 0;
}
