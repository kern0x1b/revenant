// MPNowPlayingInfoCenter.playbackState, the 13.0 member, and nothing else.
//
// MPNowPlayingInfoCenter.h at SDK 26.2 is the whole contract, quoted:
//
//   @property (nonatomic) MPNowPlayingPlaybackState playbackState MP_API(macos(10.12.2), ios(13.0), macCatalyst(13.0));
//
// readwrite. The port implements it as a stored value, because that is what readwrite means and what the
// release does for every other readwrite property on a class it carries: the system writes it, a caller
// reads it back. There is nothing to compute and nothing to fabricate.
//
// MEASURED, read with tools/mach32_methods.py from the armv7 cache of 6.1.3 (MediaPlayer image at
// 0x31fe3000):
//   - MPNowPlayingInfoCenter has 5 own instance methods and 1 own class method. The 5 are
//     _pushNowPlayingInfoAndRetry:, setNowPlayingInfo:, nowPlayingInfo, _init and init; the class method
//     is +defaultCenter. `playbackState` is not among them.
//   - all 41 of the image's categories were read WITH THE CLASS EACH ONE EXTENDS and none extends
//     MPNowPlayingInfoCenter, so nothing here clobbers the release's five and nothing in the release
//     clobbers this one. -aSelectorNoFrameworkHas is absent as the control.
//   - `playbackState` is on ONE line of the release's whole-cache selector list (113981 distinct names), so
//     some other framework's class declares that name and it decides nothing about this one - the trap
//     facts/MediaPlayer/MPMediaItem.md:105 records for albumTrackNumber. The per-class read above decides.
//
// THE VALUE NOTHING SET IS THE ENUM'S OWN NAME FOR IT. MPNowPlayingPlaybackState has no other zero:
// MPNowPlayingInfoCenter.h:44 gives MPNowPlayingPlaybackStateUnknown = 0, then Playing, Paused, Stopped,
// Interrupted. So an unset playbackState answers MPNowPlayingPlaybackStateUnknown, which is exactly what
// "the system does not know the playback state" means and is the honest answer on a release whose
// centre has no way to be told one - 6.1.3's own five methods take a dictionary and never a state.
//
// STORAGE, and why it is an associated object. A category cannot add an ivar, and this is a CATEGORY on a
// class the release owns - the release's MPNowPlayingInfoCenter is the one that carries the five methods
// above and `+defaultCenter`. Redeclaring the class here to add storage would change a class the release
// defines, which is undefined behaviour and not something a port may do. `objc_setAssociatedObject` is
// public API, it is what this tree already uses for the same problem
// (WebKit/WKWebpagePreferences13.m:39-42, SensorKit/SRSensorReader.m:120-135), and it is a real store: the
// value a caller sets is the value that reads back, and it is released with the object.
//
// One object per release, per band()'s own rule: this file holds the 13.0 member. MediaPlayerConstants70.m
// holds the 7.0 keys the same class publishes and MediaPlayerConstants93.m the 9.0 ones, each in its own
// object for the same reason.

#import <Foundation/Foundation.h>
#if defined(CHARON_MEDIAPLAYER_STANDIN)
#import "MPMediaItemStandin.h"
#else
#import <MediaPlayer/MediaPlayer.h>
#endif
#import <objc/runtime.h>

#if defined(CHARON_MEDIAPLAYER_STANDIN)
// The SDK's own declaration is not available to the stand-in build, so the contract is restated for it -
// read from MPNowPlayingInfoCenter.h above, not invented for the check to pass.
typedef NSUInteger MPNowPlayingPlaybackState;
enum { MPNowPlayingPlaybackStateUnknown = 0, MPNowPlayingPlaybackStatePlaying = 1, MPNowPlayingPlaybackStatePaused = 2,
       MPNowPlayingPlaybackStateStopped = 3, MPNowPlayingPlaybackStateInterrupted = 4 };
@interface MPNowPlayingInfoCenter : NSObject
- (void)setNowPlayingInfo:(NSDictionary *)info;
- (NSDictionary *)nowPlayingInfo;
@end
@interface MPNowPlayingInfoCenter (Charon130)
@property (nonatomic) MPNowPlayingPlaybackState playbackState;
@end
#endif

// A distinct address, not a selector name: one static key per stored property, so two properties on two
// classes can never share a slot and no selector this port does not define is registered anywhere. The
// port's own prefix, as WebKit/WKWebpagePreferences13.m:38 does.
static const void *charon_mediaplayer_playback_state_key = &charon_mediaplayer_playback_state_key;

// A CATEGORY on a class the release owns, not an @implementation of it - written as a bare
// `@implementation MPNowPlayingInfoCenter` it would claim the release's five own methods and
// +defaultCenter, and clang would ask for all of them.
@implementation MPNowPlayingInfoCenter (Charon130)

- (MPNowPlayingPlaybackState)playbackState {
    // NSNumber, because the stored value is an enum and an associated object holds a pointer. nil is the
    // enum's own zero, read as the name the SDK gives that zero.
    NSNumber *held = objc_getAssociatedObject(self, charon_mediaplayer_playback_state_key);
    return held ? (MPNowPlayingPlaybackState)[held unsignedIntegerValue] : MPNowPlayingPlaybackStateUnknown;
}

- (void)setPlaybackState:(MPNowPlayingPlaybackState)playbackState {
    objc_setAssociatedObject(self, charon_mediaplayer_playback_state_key,
                             [NSNumber numberWithUnsignedInteger:playbackState],
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end