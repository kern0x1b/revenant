// MPChangeRepeatModeCommandEvent, the 8.0 command event, and the two properties its header declares.
//
// Carried, and for the same reason as its 9.0 and 7.1 event siblings: measured with
// tools/mach32_methods.py against the 6.1.3 cache, no class whose name holds 'CommandEvent' exists in any
// of its 236 classes and none of its 41 categories, with a nonsense selector absent as the control; and
// every one of the 236 was read and none of them declares -repeatType or -preservesRepeatMode. Those two
// names are not the same question as the class: the release's whole-cache selector list
// (~/.charon/dyld/6.1.3/selectors_armv7.txt, 113981 distinct names) has one line for 'repeatType' and none
// for 'preservesRepeatMode', so 'repeatType' belongs to some other framework's class - the trap
// facts/MediaPlayer/MPMediaItem.md:105 records for albumTrackNumber, where a name in the per-cache list is
// necessary and not sufficient and the per-class read is what decides a member. A class the release does
// not have is new code and cannot shadow anything, so there is nothing native for it to be. `absent` is
// for a member whose answer needs hardware the device lacks, and none of this family needs any.
//
// WHAT IT IS NOT, because the first draft of this file claimed it and was wrong. The port already CARRIES
// the command this event belongs to - MPChangeRepeatModeCommand, introduced 8.0, ios71remotecommand.json -
// and that command's own row already says the honest thing: "a real, stateful object; never messaged by
// this port's own bridge, since no old-style repeat-mode gesture exists". The first draft here said the
// port's bridge builds every command event lazily by class, so carrying the event is what makes the
// command reach a handler. It does not, and no commit in this tree makes it: MPRemoteCommandCenter71.m's
// switch at :250-275 maps exactly TEN UIEventSubtypeRemoteControl* cases to ten commands, and this event
// is not among them.
//
// The measurement that settles it, because "the bridge does not do it" is only half a claim:
//   - APPLE PUBLISHES NO API THAT HANDS A COMMAND AN EVENT, so there is nothing to wire. grep -rn
//     'deliverEvent|sendEvent' over MediaPlayer.framework/Headers reads NO file in SDK 26.2 and no file
//     in 16.4, and MPRemoteCommand's public surface is exactly enabled, addTarget:action:,
//     removeTarget:action:, removeTarget: and addTargetWithHandler:. An application sets a handler; only
//     the system invokes it. "deliverEvent:" is a PRIVATE selector on MPRemoteCommandCenter that no
//     header declares - which is why the 6.1.3 selector universe's 113981 distinct names cannot hold it
//     either, the 236 classes having no MPRemoteCommand to declare it - and why no file under
//     packages/a/apple-backports/ defines it either. The port's equivalent is its own
//     -charon_dispatch: (MPRemoteCommandCenter71.m:133), and that is called from exactly one place.
//     Adding a delivery seam of the port's own would be the port inventing the event source that no iOS
//     provides, which is the failure this port exists to avoid - and it would be a private-API trick
//     where a public mechanism does not exist.
//   - THE LINE THAT PRODUCED THE FALSE CLAIM IS MPRemoteCommandCenter71.m:33: charon_command()
//     "creates them lazily by class regardless of which object file defines them". That sentence is
//     true, and "them" is the COMMAND objects - MPRemoteCommand and its subclasses - which is exactly
//     what charon_command() allocates. Reading it as covering the events is what this file first
//     claimed, and the next reader should not.
//     -charon_dispatch: is called from exactly one place, the switch.
//   - that switch handles ten subtypes: Play, Pause, Stop, TogglePlayPause, NextTrack, PreviousTrack,
//     BeginSeekingForward, EndSeekingForward, BeginSeekingBackward, EndSeekingBackward.
//   - and UIEvent.h in SDK 26.2 AND in 16.4 declares exactly those ten, 100 through 109, with no
//     repeat-mode, shuffle-mode, rating, playback-rate or feedback case at any availability. There is no
//     iOS version whose UIEvent can carry a repeat-mode change, so no code path anywhere can build this
//     event from a UIEvent. A repeat-mode change on this release is a setting in Settings.app and nothing
//     else, and it reaches an application through no API at all.
//
// So this class is CARRIED as what it actually is: a real, addressable MPChangeRepeatModeCommandEvent that
// a caller may construct, set -repeatType and -preservesRepeatMode on, and hand to its own handler. It is
// never messaged by this port's own bridge, for the reason measured above - which is the same honest
// posture MPChangeRepeatModeCommand's own row has carried since it landed, and the same one
// MPChangePlaybackPositionCommandEvent's row words as "the event type MPChangeRepeatModeCommand would
// deliver if this release had a scrubbing gesture to source it from". The corpus filed this row `absent`
// with the reason "the class arrived in iOS 8.0"; the truth is narrower and better: the class is here and
// works, and nothing on this device produces one.
//
// New code over the base MPRemoteCommandCenter71.m already carries. The header lines it implements,
// quoted:
//
//   @property (nonatomic, readonly) MPRepeatType repeatType;
//   @property (nonatomic, readonly) BOOL preservesRepeatMode;
//
// at MP_API(ios(8.0)). Neither carries a getter=, so the property names are the selectors, and the
// registry row is MPChangeRepeatModeCommandEvent.repeatType beside the accessor.
//
// Readwrite in the port where the header has them readonly: an event the port builds has to be able to
// carry the mode it is an event *about*, and a new class shadows nothing.

#import <Foundation/Foundation.h>
#if defined(CHARON_MEDIAPLAYER_STANDIN)
#import "MPMediaItemStandin.h"
#else
#import <MediaPlayer/MediaPlayer.h>
#endif

#if defined(CHARON_MEDIAPLAYER_STANDIN)
@interface MPChangeRepeatModeCommandEvent : MPRemoteCommandEvent
@property (nonatomic, assign, readwrite) MPRepeatType repeatType;
@property (nonatomic, assign, readwrite) BOOL preservesRepeatMode;
@end
#else
// The SDK declares this class with its properties readonly; the port's events have to be built carrying
// theirs, so they are made writable here, in an extension, and not declared a second time.
@interface MPChangeRepeatModeCommandEvent ()
@property (nonatomic, assign, readwrite) MPRepeatType repeatType;
@property (nonatomic, assign, readwrite) BOOL preservesRepeatMode;
@end
#endif

@implementation MPChangeRepeatModeCommandEvent
@synthesize repeatType = _repeatType;
@synthesize preservesRepeatMode = _preservesRepeatMode;

// The header's readonly accessors, written out rather than left to the synthesiser, so what a caller
// reads is the port's own code and a mutation of it is a change of behaviour. NO is what an event that
// set nothing answers, and it is also the declared zero of BOOL. MPRepeatType has no "unknown" case -
// MPRemoteControlTypes.h:17 gives MPRepeatTypeOff, MPRepeatTypeOne, MPRepeatTypeAll - so an event that
// set nothing answers MPRepeatTypeOff, which is what "the user asked for no repeat" means, and a caller
// can tell "nothing was set" from "off was asked for" only by the event it was given.
- (MPRepeatType)repeatType {
    return _repeatType;
}

- (BOOL)preservesRepeatMode {
    return _preservesRepeatMode;
}

@end