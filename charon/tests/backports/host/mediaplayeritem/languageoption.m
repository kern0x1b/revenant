// The 9.0 command event's contract: the class is a kind of the base the port carries, both properties
// read back what was set, and the base's own command answers what it was built with.
#import "MPMediaItemStandin.h"

@implementation MPRemoteCommandEvent
{
    MPRemoteCommand *_command;
}
- (instancetype)initWithCommand:(MPRemoteCommand *)command {
    self = [super init];
    if (self) { _command = command; }
    return self;
}
- (MPRemoteCommand *)command { return _command; }
- (NSTimeInterval)timestamp { return 0; }
@end

@implementation MPNowPlayingInfoLanguageOption
- (BOOL)isAutomaticLegibleLanguageOption { return NO; }
@end

@implementation MPRemoteCommand
@end

#define CHARON_MEDIAPLAYER_STANDIN 1
#include "MPChangeLanguageOptionCommandEvent90.m"

static int failures = 0;

static void check(const char *what, int held, const char *got) {
    if (held) { printf("  ok   %s: %s\n", what, got); }
    else { printf("  RED  %s: %s\n", what, got); failures++; }
}

int main(void) {
    MPRemoteCommand *sent = [[MPRemoteCommand alloc] init];
    MPChangeLanguageOptionCommandEvent *event =
        [[MPChangeLanguageOptionCommandEvent alloc] initWithCommand:sent];
    check("the event is a kind of the base the port carries",
          [event isKindOfClass:[MPRemoteCommandEvent class]],
          [event isKindOfClass:[MPRemoteCommandEvent class]] ? "an MPRemoteCommandEvent" : "not");
    check("the base's command is what the event was built with", event.command == sent,
          event.command == sent ? "the command" : "other");
    MPNowPlayingInfoLanguageOption *option = [[MPNowPlayingInfoLanguageOption alloc] init];
    event.languageOption = option;
    event.setting = 3;
    check("languageOption reads back what was set", event.languageOption == option,
          event.languageOption == option ? "the option" : "other");
    check("setting reads back what was set", event.setting == 3, "3");
    if (failures) { printf("languageoption: %d RED\n", failures); return 1; }
    printf("languageoption: OK (0 failures)\n");
    return 0;
}
