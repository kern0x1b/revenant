// AVPlayerItem.nowPlayingInfo, the 16.0 member, and nothing else.
//
// AVPlayerItem+MediaPlayerAdditions.h at SDK 26.2 is the whole contract, quoted:
//
//   @interface AVPlayerItem (MPAdditions)
//   @property (nonatomic, copy, nullable) NSDictionary<NSString *, id> *nowPlayingInfo MP_API(ios(16.0), tvos(16.0));
//   @end
//
// Readwrite, copy, nullable. A MediaPlayer category on an AVFoundation class, which is what the SDK's own
// header is - so this file is a MediaPlayer object and belongs in this directory, and the object name says
// which class it adds to.
//
// AND HOW THE BAND LINKS IT, because a category on a class the band's link does not carry cannot link at
// all: the class reference is a symbol, so with no AVFoundation on the link line ld leaves
// _OBJC_CLASS_$_AVPlayerItem undefined and the 6.1.3 band fails. MediaPlayerBackports therefore names
// AVFoundation among its frameworks (modules/apple/backports.lua), and what that binds is the RELEASE's own
// AVPlayerItem - the one carrying the 237 methods read below - and nothing this port defines. It costs no
// image: this band links -framework MediaPlayer anyway and the release's own libMediaPlayer loads
// AVFoundation itself (otool -L; facts/MediaPlayer/WholeCacheRead.md). A stand-in AVPlayerItem would have
// quieted ld and left a NULL class pointer at run time, which is the state backports.lua's
// check_categories() exists to refuse.
//
// MEASURED, and this row waited two turns for it because it is the one member of the family whose owner
// class does not live in MediaPlayer's image. The per-image read (tools/mach32_methods.py over the MediaPlayer
// image at 0x31fe3000) cannot see AVPlayerItem at all, and the release's whole-cache selector list could not
// decide it either: `nowPlayingInfo` is on ONE of its 113981 distinct names, because some class somewhere
// declares it. The rung that decides a member is the whole cache, and it was run through coordination/heavy.sh
// at a load of 9.08, under the limit of 12:
//
//   CHARON_ROOT=<worktree> xmake l tools/corpus/objc-inventory.lua \
//     ~/.charon/dyld/6.1.3/dyld_shared_cache_armv7 > inventory-6.1.3.tsv
//   12549 lines: 11378 classes and 1171 protocols.
//
// From that read, all with the control that the same reader answers YES to AVPlayerItem's real selectors:
//
//   - AVPlayerItem lives in AVFoundation.framework/AVFoundation and has 237 own instance selectors and 35
//     own class selectors. `status`, `timedMetadata`, `duration` and `MPAVItem` ARE among the 237 - MPAVItem
//     is the MediaPlayer category's own method, which the per-category read already found - and
//     `nowPlayingInfo` and `setNowPlayingInfo:` are NOT. One class, one reader, a YES and a NO.
//   - exactly TWO classes in the whole 6.1.3 cache declare `nowPlayingInfo` in their own instance list:
//     MPNowPlayingInfoCenter (MediaPlayer) and MRMediaRemoteState (PrivateFrameworks/MediaRemote). Neither
//     is AVPlayerItem, and the second is a private framework no application links.
//   - a class no framework has reads absent from the same file, so the reader is not answering YES to
//     everything.
//
// THE ANSWER is Apple's own shape: a dictionary that copies on set and reads back what was set, nil when
// nothing was set - the header's own nullability. There is nothing to compute: on a release where the
// system reads this property it fills it in, and on this one there is no system reader, so the value is
// whatever the caller stored. A nowPlayingInfo that answered a synthesised dictionary from the item's
// timedMetadata would be inventing an answer Apple's own accessor does not produce on this release - the
// 16.0 contract is that the ITEM publishes what its owner set, and the owner is the caller.
//
// STORAGE, and why it is an associated object. This is a CATEGORY on a class AVFoundation owns - the
// release's AVPlayerItem is the one that carries its 237 methods, and a bare `@implementation AVPlayerItem`
// would claim all of them. A category cannot add an ivar, and redeclaring the class to add storage would
// change a class the release defines. `objc_setAssociatedObject` is public API and what this tree already
// does for the same problem (WebKit/WKWebpagePreferences13.m:39-42, SensorKit/SRSensorReader.m:120-135),
// one static address per stored property as WebKit does.
//
// One object per release, per band()'s own rule: this file holds the 16.0 member and no other AVPlayerItem
// member. MediaPlayer/MPAdTimeRange16.m is the other 16.0 object and not this one.

#import <Foundation/Foundation.h>
#if defined(CHARON_MEDIAPLAYER_STANDIN)
#import "MPMediaItemStandin.h"
#else
#import <AVFoundation/AVFoundation.h>
#endif
#import <objc/runtime.h>

#if defined(CHARON_MEDIAPLAYER_STANDIN)
// The SDK's own declaration is not available to the stand-in build, so the contract is restated for it -
// read from AVPlayerItem+MediaPlayerAdditions.h above, not invented for the check to pass.
@interface AVPlayerItem : NSObject
@end
@interface AVPlayerItem (CharonMPAdditions)
@property (nonatomic, copy, nullable) NSDictionary<NSString *, id> *nowPlayingInfo;
@end
#endif

// A distinct address, not a selector name: one static key per stored property, so no selector this port
// does not define is registered anywhere. The port's own prefix, as WebKit/WKWebpagePreferences13.m:38.
static const void *charon_avplayeritem_now_playing_info_key = &charon_avplayeritem_now_playing_info_key;

// A CATEGORY on a class the release owns, not an @implementation of it.
@implementation AVPlayerItem (CharonMPAdditions)

- (nullable NSDictionary<NSString *, id> *)nowPlayingInfo {
    // The stored copy, or nil - the header's own nullability, and what an item nobody has published
    // through answers on every iOS.
    return objc_getAssociatedObject(self, charon_avplayeritem_now_playing_info_key);
}

- (void)setNowPlayingInfo:(nullable NSDictionary<NSString *, id> *)nowPlayingInfo {
    // OBJC_ASSOCIATION_COPY, because the header says `copy`: a caller that mutates the dictionary it passed
    // must not reach through into the item's value, and Apple's own synthesised setter copies for the same
    // reason. nil clears it, which is what the header's nullable setter does too.
    objc_setAssociatedObject(self, charon_avplayeritem_now_playing_info_key, nowPlayingInfo,
                             OBJC_ASSOCIATION_COPY_NONATOMIC);
}

@end