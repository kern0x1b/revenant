#import <AVFoundation/AVFoundation.h>
#import <CoreVideo/CoreVideo.h>

#pragma clang diagnostic ignored "-Wunguarded-availability-new"
#pragma clang diagnostic ignored "-Wunguarded-availability"
#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

// The iOS 10 API of the release-10 absent rows that no other object carries: -[AVPlayer
// timeControlStatus]. This file first carried -playImmediatelyAtRate: and -initWithOutputSettings: too;
// AVFoundation100.m already defined both (with automaticallyWaitsToMinimizeStalling), so they are that
// object's alone and a second category definition of the same selector is not left beside it. Every
// other row of that release stays absent, and the measurement that closes it is in
// facts/AVFoundation/AVFoundation10.md, which names the commands and their output.
//
// It is a CATEGORY method, so nm -gU over this object defines no API symbol at all and
// tools/release-split.lua checks ZERO symbols here and reports the file clean vacuously - the blind spot
// its own header documents. The class-scoped check for a category is a selector-string walk of the cache
// ladder, which is what first-rung.lua answers, and the selector is 10.0.1 there while 6.1.3's AVPlayer
// does not carry it.

@implementation AVPlayer (CharonAVFoundation10)

// 10.0: the header's own three conditions, read against members the release carries.
//
//   - WaitingToPlayAtSpecifiedRate holds while the player holds no playable item (currentItem reads nil), asked first because the header names it unconditionally.
//   - Paused is entered on a pause, which reaches the player as -setRate: with 0.0, so a zero rate with an item to play is Paused (AVPlayer.h:185).
//   - Playing against WaitingToPlayAtSpecifiedRate turns on once the media data is enough to continue playback, which is what
//     -[AVPlayerItem isPlaybackLikelyToKeepUp] answers (AVPlayerItem.h) - the property is a
//     `(readonly, getter=isPlaybackLikelyToKeepUp)` and the release carries that getter.
//
// The value is right on every read. No KVO notification is sent for it, because there is no state here
// to announce - the release's own -rate, -currentItem and -isPlaybackLikelyToKeepUp carry the changes, and
// a caller that observes this property observes those three instead. That limit is stated in the row's
// effect rather than papered over.
- (AVPlayerTimeControlStatus)timeControlStatus
{
    AVPlayerItem *item = self.currentItem;
    if (item == nil)
        return AVPlayerTimeControlStatusWaitingToPlayAtSpecifiedRate;
    if (self.rate == 0.0f)
        return AVPlayerTimeControlStatusPaused;
    return item.isPlaybackLikelyToKeepUp ? AVPlayerTimeControlStatusPlaying
                                         : AVPlayerTimeControlStatusWaitingToPlayAtSpecifiedRate;
}

@end
