// MPSkipIntervalCommandEvent's contract: the class is a kind of the base the port carries, the base's command answers what
// the event was built with, the property reads back what was set, and an event nothing set answers the
// type's zero. The mutation's verdict is printed on both sides, because mutate.lua cannot enforce that.
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

@implementation MPRemoteCommand
@end

// The stand-in declares the 9.0 event's option type, which the 8.0 and 7.1 headers pull in; it is unused
// here and has to exist for the link.
@implementation MPNowPlayingInfoLanguageOption
@end

#define CHARON_MEDIAPLAYER_STANDIN 1
#include "MPSkipIntervalCommandEvent.m"

static int failures = 0;

static void check(const char *what, int held, const char *got) {
    if (held) { printf("  ok   %s: %s\n", what, got); }
    else { printf("  RED  %s: %s\n", what, got); failures++; }
}

int main(void) {
    MPRemoteCommand *sent = [[MPRemoteCommand alloc] init];
    MPSkipIntervalCommandEvent *event = [[MPSkipIntervalCommandEvent alloc] initWithCommand:sent];
    check("the event is a kind of the base the port carries",
          [event isKindOfClass:[MPRemoteCommandEvent class]],
          [event isKindOfClass:[MPRemoteCommandEvent class]] ? "an MPRemoteCommandEvent" : "not");
    check("the base's command is what the event was built with", event.command == sent,
          event.command == sent ? "the command" : "other");
    event.interval = 30;
    check("interval reads back what was set", event.interval == 30,
          event.interval == 30 ? "30" : "other");
    MPSkipIntervalCommandEvent *untouched = [[MPSkipIntervalCommandEvent alloc] initWithCommand:sent];
    check("an event nothing set answers the type's zero", untouched.interval == 0,
          untouched.interval == 0 ? "0" : "other");
    if (failures) { printf("mpskipintervalcommandevent: %d RED\n", failures); return 1; }
    printf("mpskipintervalcommandevent: OK (0 failures)\n");
    return 0;
}
