#import <Foundation/Foundation.h>
#if defined(CHARON_MEDIAPLAYER_STANDIN)
#import "MPMediaItemStandin.h"
#else
#import <MediaPlayer/MediaPlayer.h>
#endif
#import <objc/runtime.h>

#if defined(CHARON_MEDIAPLAYER_STANDIN)
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

static const void *charon_mediaplayer_playback_state_key = &charon_mediaplayer_playback_state_key;

@implementation MPNowPlayingInfoCenter (Charon130)

- (MPNowPlayingPlaybackState)playbackState {
    NSNumber *held = objc_getAssociatedObject(self, charon_mediaplayer_playback_state_key);
    return held ? (MPNowPlayingPlaybackState)[held unsignedIntegerValue] : MPNowPlayingPlaybackStateUnknown;
}

- (void)setPlaybackState:(MPNowPlayingPlaybackState)playbackState {
    objc_setAssociatedObject(self, charon_mediaplayer_playback_state_key,
                             [NSNumber numberWithUnsignedInteger:playbackState],
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
