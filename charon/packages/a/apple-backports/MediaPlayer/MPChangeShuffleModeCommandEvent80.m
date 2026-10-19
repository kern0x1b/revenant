// MPChangeShuffleModeCommandEvent, the 8.0 command event, and the two properties its header declares.
//
// Carried, and for the same reason as its repeat-mode sibling beside it: measured with
// tools/mach32_methods.py against the 6.1.3 cache, no class whose name holds 'CommandEvent' exists in any
// of its 236 classes and none of its 41 categories, with a nonsense selector absent as the control; and
// every one of the 236 was read and none of them declares -shuffleType or -preservesShuffleMode. The two
// are not the same question as the class: the release's whole-cache selector list
// (~.charon/dyld/6.1.3/selectors_armv7.txt, 113981 distinct names) has one line for 'shuffleType' and
// none for 'preservesShuffleMode', so 'shuffleType' belongs to some other framework's class - the trap
// facts/MediaPlayer/MPMediaItem.md:105 records for albumTrackNumber, where a name in the per-cache list is
// necessary and not sufficient and the per-class read is what decides a member. A class the release does
// not have is new code and cannot shadow anything, so there is nothing native for it to be.
//
// WHAT IT IS NOT, and it is the same thing its repeat-mode neighbour beside it gets wrong if you let it,
// so it is said here too rather than left to be copied. The port already CARRIES the command this event
// belongs to - MPChangeShuffleModeCommand, introduced 8.0, ios71remotecommand.json - and that command's own
// row already says "a real, stateful object; never messaged by this port's own bridge, since no old-style
// shuffle-mode gesture exists". Nothing in this tree makes it otherwise:
//   - APPLE PUBLISHES NO API THAT HANDS A COMMAND AN EVENT, so there is nothing to wire: grep -rn
//     'deliverEvent|sendEvent' over MediaPlayer.framework/Headers reads no file in 26.2 and no file in
//     16.4, and MPRemoteCommand's public surface is exactly enabled, addTarget:action:,
//     removeTarget:action:, removeTarget: and addTargetWithHandler:. "deliverEvent:" is a PRIVATE
//     selector on MPRemoteCommandCenter that no header declares, so the 6.1.3 universe's 113981 names
//     cannot hold it either - the 236 classes have no MPRemoteCommand - and no file under
//     packages/a/apple-backports/ defines it. The line that produced the false claim in the first
//     draft of this file is MPRemoteCommandCenter71.m:33, whose "creates them lazily by class" is about
//     the COMMAND objects charon_command() allocates, not about the events.
//   - the port's own -charon_dispatch: (MPRemoteCommandCenter71.m:133) is called from exactly one place,
//     the subtype switch at :250-275, and that switch maps ten cases and this is not one of them.
//   - UIEvent.h in SDK 26.2 AND 16.4 declares exactly those ten subtypes, 100 through 109, with no
//     shuffle-mode case at any availability. No UIEvent on any iOS can carry a shuffle-mode change.
//
// So this class is CARRIED as a real, addressable MPChangeShuffleModeCommandEvent a caller may construct,
// set -shuffleType and -preservesShuffleMode on, and hand to its own handler; and it is never messaged by
// this port's own bridge, because there is no gesture to message it from. The corpus filed this row
// `absent` with the reason "the class arrived in iOS 8.0"; the truth is narrower: the class is here and
// works, and nothing on this device produces one.
//
// One object per release, per band()'s own rule: this file holds the 8.0 shuffle event and not the 8.0
// repeat one, which is its own file.
//
// New code over the base MPRemoteCommandCenter71.m already carries. The header lines it implements,
// quoted:
//
//   @property (nonatomic, readonly) MPShuffleType shuffleType;
//   @property (nonatomic, readonly) BOOL preservesShuffleMode;
//
// at MP_API(ios(8.0)). Neither carries a getter=, so the property names are the selectors.
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
@interface MPChangeShuffleModeCommandEvent : MPRemoteCommandEvent
@property (nonatomic, assign, readwrite) MPShuffleType shuffleType;
@property (nonatomic, assign, readwrite) BOOL preservesShuffleMode;
@end
#else
// The SDK declares this class with its properties readonly; the port's events have to be built carrying
// theirs, so they are made writable here, in an extension, and not declared a second time.
@interface MPChangeShuffleModeCommandEvent ()
@property (nonatomic, assign, readwrite) MPShuffleType shuffleType;
@property (nonatomic, assign, readwrite) BOOL preservesShuffleMode;
@end
#endif

@implementation MPChangeShuffleModeCommandEvent
@synthesize shuffleType = _shuffleType;
@synthesize preservesShuffleMode = _preservesShuffleMode;

// The header's readonly accessors, written out rather than left to the synthesiser. NO is what an event
// that set nothing answers, and it is also the declared zero of BOOL. MPShuffleType has no "unknown"
// case either - MPRemoteControlTypes.h:11 gives MPShuffleTypeOff, MPShuffleTypeItems,
// MPShuffleTypeCollections - so an event that set nothing answers MPShuffleTypeOff.
- (MPShuffleType)shuffleType {
    return _shuffleType;
}

- (BOOL)preservesShuffleMode {
    return _preservesShuffleMode;
}

@end