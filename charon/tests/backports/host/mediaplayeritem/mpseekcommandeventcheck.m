// MPSeekCommandEvent's contract: the class is a kind of the base the port carries, the base's command
// answers what the event was built with, the property reads back what was set for each of the
// enumeration's two cases, and an event nothing set answers the type's zero.
//
// Unlike its two siblings this check includes the port's whole 7.1 object rather than one class's own
// file: MPSeekCommandEvent's @implementation is inside MPRemoteCommandCenter71.m beside the other nine
// classes that arrived in 7.1 and cannot be included on its own. What is measured is still the port's own
// code -- the base's -initWithCommand: and -command and MPSeekCommandEvent's -type are the port's, not
// this file's copy of them -- and not this Mac's MediaPlayer, which has no MPSeekCommandEvent at all.
//
// The mutation's verdict is printed by hand on both sides, because mutate.lua cannot enforce that:
//   xmake l tests/backports/host/mediaplayeritem/mutate.lua MPRemoteCommandCenter71.m \
//       "return _type;" "return 0;" <scratch>
// then compile this file with -I<scratch> in place of the library directory. The two verdicts must differ.
#import "MPMediaItemStandin.h"
#import <UIKit/UIKit.h>

// The stand-in declares the 9.0 event's option type and three of the command classes as interfaces
// only; a class whose symbol is referenced needs a body at link time, which is the same defect
// MPMediaItemStandin.h's own UIImage note records.
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

    // Both cases of the enumeration, so the check cannot pass on one of them.
    event.type = MPSeekCommandEventTypeBeginSeeking;
    check("type reads back BeginSeeking", event.type == MPSeekCommandEventTypeBeginSeeking,
          name_of(event.type));
    event.type = MPSeekCommandEventTypeEndSeeking;
    check("type reads back EndSeeking", event.type == MPSeekCommandEventTypeEndSeeking,
          name_of(event.type));

    // The enumeration's numbering is the header's own, so the zero is a fact about it and not a choice.
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
