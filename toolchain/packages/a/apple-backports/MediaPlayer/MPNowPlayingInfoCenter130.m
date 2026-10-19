#import <Foundation/Foundation.h>
#if defined(REVENANT_MEDIAPLAYER_STANDIN)
#import "MPMediaItemStandin.h"
#else
#import <MediaPlayer/MediaPlayer.h>
#endif
#import <objc/runtime.h>

#if defined(REVENANT_MEDIAPLAYER_STANDIN)
typedef NSUInteger MPNowPlayingPlaybackState;
enum { MPNowPlayingPlaybackStateUnknown = 0, MPNowPlayingPlaybackStatePlaying = 1, MPNowPlayingPlaybackStatePaused = 2,
       MPNowPlayingPlaybackStateStopped = 3, MPNowPlayingPlaybackStateInterrupted = 4 };
@interface MPNowPlayingInfoCenter : NSObject
- (void)setNowPlayingInfo:(NSDictionary *)info;
- (NSDictionary *)nowPlayingInfo;
@end
@interface MPNowPlayingInfoCenter (Revenant130)
@property (nonatomic) MPNowPlayingPlaybackState playbackState;
@end
#endif

static const void *revenant_mediaplayer_playback_state_key = &revenant_mediaplayer_playback_state_key;

@implementation MPNowPlayingInfoCenter (Revenant130)

- (MPNowPlayingPlaybackState)playbackState {
    NSNumber *held = objc_getAssociatedObject(self, revenant_mediaplayer_playback_state_key);
    return held ? (MPNowPlayingPlaybackState)[held unsignedIntegerValue] : MPNowPlayingPlaybackStateUnknown;
}

- (void)setPlaybackState:(MPNowPlayingPlaybackState)playbackState {
    objc_setAssociatedObject(self, revenant_mediaplayer_playback_state_key,
                             [NSNumber numberWithUnsignedInteger:playbackState],
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
