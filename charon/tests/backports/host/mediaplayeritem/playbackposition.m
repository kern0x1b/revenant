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

@implementation MPRemoteCommand
@end

// The 9.0 event's option type is declared by the stand-in because the 8.0 event's own
// header pulls MediaPlayer in; it is not used here.
@implementation MPNowPlayingInfoLanguageOption
@end

#define CHARON_MEDIAPLAYER_STANDIN 1
#include "MPChangePlaybackPositionCommandEvent80.m"

static int failures = 0;

static void check(const char *what, int held, const char *got) {
    if (held) { printf("  ok   %s: %s\n", what, got); }
    else { printf("  RED  %s: %s\n", what, got); failures++; }
}

int main(void) {
    MPRemoteCommand *sent = [[MPRemoteCommand alloc] init];
    MPChangePlaybackPositionCommandEvent *event =
        [[MPChangePlaybackPositionCommandEvent alloc] initWithCommand:sent];
    check("the event is a kind of the base the port carries",
          [event isKindOfClass:[MPRemoteCommandEvent class]],
          [event isKindOfClass:[MPRemoteCommandEvent class]] ? "an MPRemoteCommandEvent" : "not");
    check("the base's command is what the event was built with", event.command == sent,
          event.command == sent ? "the command" : "other");
    MPNowPlayingInfoLanguageOption *option = [[MPNowPlayingInfoLanguageOption alloc] init];

    event.positionTime = 42.5;
    check("positionTime reads back what was set", event.positionTime == 42.5,
          event.positionTime == 42.5 ? "42.5" : "other");
    MPChangePlaybackPositionCommandEvent *untouched = [[MPChangePlaybackPositionCommandEvent alloc] initWithCommand:sent];
    check("an event nothing set answers the type's zero", untouched.positionTime == 0,
          untouched.positionTime == 0 ? "0" : "other");
    if (failures) { printf("playbackposition: %d RED\n", failures); return 1; }
    printf("playbackposition: OK (0 failures)\n");
    return 0;
}
