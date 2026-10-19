// MPFeedbackCommandEvent, the 7.1 command event, and the one property its header declares.
//
// Carried, and for the same reason as its siblings: measured with tools/mach32_methods.py against the
// 6.1.3 cache, no class whose name holds 'CommandEvent' exists in any of its 236 classes and none of its
// 41 categories, with a nonsense selector absent as the control. A class the release does not have is new
// code and cannot shadow anything, so there is nothing native for it to be. `absent` is for a member
// whose answer needs hardware the device lacks, and none of this family needs any.
//
// WHY THIS CLASS IS CARRIED, stated at its real size.
//
// The first draft of this file justified it by a gap in the port's own event hierarchy: "the port already
// carries four public events whose public ancestor chain names this class, so [event
// isKindOfClass:[MPFeedbackCommandEvent class]] answered NO for every event it builds". That was false,
// and the header says so. MPRemoteCommandEvent.h at SDK 26.2 declares MPRatingCommandEvent,
// MPSkipIntervalCommandEvent, MPChangePlaybackRateCommandEvent and MPChangeLanguageOptionCommandEvent
// all as `: MPRemoteCommandEvent` - flat, not `: MPFeedbackCommandEvent` - and grep for
// "@interface.*: MPFeedbackCommandEvent" over MediaPlayer.framework/Headers finds NOTHING in 26.2 and
// nothing in 16.4. No class Apple publishes derives from it. The port followed 26.2 for its siblings and
// so should not claim a chain the SDK does not have.
//
// What is true, and is the whole justification: this is a PUBLIC class the SDK declares at
// MP_API(ios(7.1)) with one member, and 6.1.3 carries neither it nor its selector. Measured with
// tools/mach32_methods.py from the armv7 cache of 6.1.3 (MediaPlayer image at 0x31fe3000): no class
// whose name holds 'CommandEvent' is among the 236 classes and none of the 41 categories adds one, and
// all 236 were read and none declares isNegative; in the release's whole-cache selector list
// (selectors_armv7.txt, 113981 distinct names) -isNegative is on one line, because some other framework's
// class declares that name, which is the trap facts/MediaPlayer/MPMediaItem.md:105 records for
// albumTrackNumber - so the per-class read above is what decides it. -aSelectorNoFrameworkHas is absent
// as the control.
//
// So before this, NSClassFromString(@"MPFeedbackCommandEvent") answered nil and `[MPFeedbackCommandEvent
// new]` was a call on nil. After it, the class exists, a caller may construct one, set -isNegative and
// read it back, and ask isKindOfClass: of it. That is what carried means here: a real, addressable
// object, not a wire-up. Like every other event class this port carries, it is never messaged by the
// port's own bridge - and that is not an omission on this side either: APPLE PUBLISHES NO API THAT HANDS A
// COMMAND AN EVENT. grep -rn 'deliverEvent|sendEvent' over MediaPlayer.framework/Headers reads no file in
// SDK 26.2 and no file in 16.4, MPRemoteCommand's public surface is exactly enabled, addTarget:action:,
// removeTarget:action:, removeTarget: and addTargetWithHandler:, and "deliverEvent:" is a PRIVATE selector on
// MPRemoteCommandCenter that no header declares - so it is on no line of the 6.1.3 universe either, the 236
// classes having no MPRemoteCommand, and no file under packages/a/apple-backports/ defines it. The
// port's own -charon_dispatch: (MPRemoteCommandCenter71.m:133) is reached only from the subtype switch at
// :250-275, which handles the ten UIEventSubtypeRemoteControl* cases UIEvent.h declares in 26.2 and 16.4
// (100 through 109) and which has no feedback case at any availability. MPFeedbackCommand's own row in
// ios71remotecommand.json has said "never messaged by this port's own bridge, since no old-style
// feedback gesture exists" since it landed; this event's row now says the same about itself.
//
// New code over the base MPRemoteCommandCenter71.m already carries. The header line it implements:
//
//   @property (nonatomic, readonly, getter = isNegative) BOOL negative;
//
// at MP_API(ios(7.1)). The getter= attribute means the SELECTOR is -isNegative and the property name is
// not a selector on any platform, so the port declares -isNegative and nothing named negative; the
// registry row is MPFeedbackCommandEvent.isNegative for the same reason MPMediaItem.isCompilation is
// (facts/MediaPlayer/MPMediaItem.md:61) - a property whose header writes a getter= is registered under
// the getter.
//
// Readwrite in the port where the header has it readonly, like every other event the port carries: an
// event a caller builds has to be able to carry the feedback it is an event *about*, and a new class
// shadows nothing.

#import <Foundation/Foundation.h>
#if defined(CHARON_MEDIAPLAYER_STANDIN)
#import "MPMediaItemStandin.h"
#else
#import <MediaPlayer/MediaPlayer.h>
#endif

#if defined(CHARON_MEDIAPLAYER_STANDIN)
@interface MPFeedbackCommandEvent : MPRemoteCommandEvent
@property (nonatomic, assign, readwrite, getter = isNegative) BOOL negative;
@end
#else
// The SDK declares this class with its property readonly; the port's events have to be built carrying
// theirs, so it is made writable here, in an extension, and not declared a second time.
@interface MPFeedbackCommandEvent ()
@property (nonatomic, assign, readwrite, getter = isNegative) BOOL negative;
@end
#endif

@implementation MPFeedbackCommandEvent
@synthesize negative = _negative;

// The header's readonly accessor, written out rather than left to the synthesiser, so what a caller
// reads is the port's own code: removing the @synthesize is not a change of behaviour, because ARC then
// synthesises exactly the same accessor. NO is what an event that set nothing answers, and it is the
// value of BOOL's zero.
- (BOOL)isNegative {
    return _negative;
}

@end