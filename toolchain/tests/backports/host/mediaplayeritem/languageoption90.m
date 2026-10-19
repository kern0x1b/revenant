#import <Foundation/Foundation.h>
#import "MPMediaItemStandin.h"

#define REVENANT_MEDIAPLAYER_STANDIN 1
#include "MPNowPlayingInfoLanguageOption90.m"

static int failures = 0;
static void check(const char *what, int held, const char *got) {
    if (held) { printf("  ok   %s: %s\n", what, got); }
    else { printf("  RED  %s: %s\n", what, got); failures++; }
}

int main(void) {
    NSMutableArray *chars = [@[ @"public.audio", @"public.subtitles" ] mutableCopy];
    MPNowPlayingInfoLanguageOption *legible =
        [[MPNowPlayingInfoLanguageOption alloc] initWithType:MPNowPlayingInfoLanguageOptionTypeLegible
                                                 languageTag:@"en"
                                             characteristics:chars
                                                 displayName:@"English"
                                                  identifier:@"opt-en"];
    check("the designated initializer's type reads back",
          legible.languageOptionType == MPNowPlayingInfoLanguageOptionTypeLegible, "Legible");
    check("characteristics read back", [legible.languageOptionCharacteristics isEqualToArray:chars], "2");
    check("displayName reads back", [legible.displayName isEqualToString:@"English"], "English");
    check("identifier reads back", [legible.identifier isEqualToString:@"opt-en"], "opt-en");

    MPNowPlayingInfoLanguageOption *audible =
        [[MPNowPlayingInfoLanguageOption alloc] initWithType:MPNowPlayingInfoLanguageOptionTypeAudible
                                                 languageTag:@"en"
                                             characteristics:nil
                                                 displayName:@"English"
                                                  identifier:@"aud-en"];
    check("neither 'automatic' accessor fires on an ordinary option",
          ![legible isAutomaticLegibleLanguageOption] && ![legible isAutomaticAudibleLanguageOption] &&
          ![audible isAutomaticAudibleLanguageOption] && ![audible isAutomaticLegibleLanguageOption],
          "NO for both types");
    check("the type reads back for an Audible option, so the accessor is not reading it",
          audible.languageOptionType == MPNowPlayingInfoLanguageOptionTypeAudible, "Audible");

    [chars addObject:@"public.music"];
    check("characteristics were copied, not retained",
          legible.languageOptionCharacteristics.count == 2, "2");

    MPNowPlayingInfoLanguageOptionGroup *group =
        [[MPNowPlayingInfoLanguageOptionGroup alloc] initWithLanguageOptions:@[ legible, audible ]
                                                      defaultLanguageOption:legible
                                                        allowEmptySelection:YES];
    check("languageOptions reads back", group.languageOptions.count == 2, "2");
    check("defaultLanguageOption reads back", group.defaultLanguageOption == legible, "the legible one");
    check("allowEmptySelection reads back", group.allowEmptySelection, "YES");
    check("the group keeps every option it was given rather than enforcing exclusivity",
          [group.languageOptions containsObject:audible], "both kept");

    if (failures) { printf("langcheck: %d RED\n", failures); return 1; }
    printf("langcheck: OK (0 failures)\n");
    return 0;
}
