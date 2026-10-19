#import "MPMediaItemStandin.h"
#import <UIKit/UIKit.h>

@implementation MPNowPlayingInfoLanguageOption
@end
@implementation MPChangeRepeatModeCommand
@end
@implementation MPChangeShuffleModeCommand
@end
@implementation MPChangePlaybackPositionCommand
@end

#define CHARON_MEDIAPLAYER_STANDIN 1
#include "MPRemoteCommandCenter71.m"

static int failures = 0;

static void check(const char *what, int held, const char *got) {
    if (held) { printf("  ok   %s: %s\n", what, got); }
    else { printf("  RED  %s: %s\n", what, got); failures++; }
}

static const char *name_of(MPSeekCommandEventType type) {
    switch (type) {
    case MPSeekCommandEventTypeBeginSeeking: return "BeginSeeking";
    case MPSeekCommandEventTypeEndSeeking: return "EndSeeking";
    }
    return "other";
}

int main(void) {
    MPRemoteCommand *sent = [[MPRemoteCommand alloc] init];
    MPSeekCommandEvent *event = [[MPSeekCommandEvent alloc] initWithCommand:sent];
    check("the event is a kind of the base the port carries",
          [event isKindOfClass:[MPRemoteCommandEvent class]],
          [event isKindOfClass:[MPRemoteCommandEvent class]] ? "an MPRemoteCommandEvent" : "not");
    check("the base's command is what the event was built with", event.command == sent,
          event.command == sent ? "the command" : "other");

    event.type = MPSeekCommandEventTypeBeginSeeking;
    check("type reads back BeginSeeking", event.type == MPSeekCommandEventTypeBeginSeeking,
          name_of(event.type));
    event.type = MPSeekCommandEventTypeEndSeeking;
    check("type reads back EndSeeking", event.type == MPSeekCommandEventTypeEndSeeking,
          name_of(event.type));

    check("the enumeration's zero is BeginSeeking", MPSeekCommandEventTypeBeginSeeking == 0,
          MPSeekCommandEventTypeBeginSeeking == 0 ? "0" : "other");
    check("EndSeeking is the next case", MPSeekCommandEventTypeEndSeeking == 1,
          MPSeekCommandEventTypeEndSeeking == 1 ? "1" : "other");

    MPSeekCommandEvent *untouched = [[MPSeekCommandEvent alloc] initWithCommand:sent];
    check("an event nothing set answers the type's zero",
          untouched.type == MPSeekCommandEventTypeBeginSeeking, name_of(untouched.type));
    if (failures) { printf("mpseekcommandevent: %d RED\n", failures); return 1; }
    printf("mpseekcommandevent: OK (0 failures)\n");
    return 0;
}
