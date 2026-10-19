#import <Foundation/Foundation.h>
#if defined(CHARON_MEDIAPLAYER_STANDIN)
#import "MPMediaItemStandin.h"
#else
#import <MediaPlayer/MediaPlayer.h>
#endif

#if defined(CHARON_MEDIAPLAYER_STANDIN)
@interface MPChangePlaybackRateCommandEvent : MPRemoteCommandEvent
@property (nonatomic, assign, readwrite) float playbackRate;
@end
#else
@interface MPChangePlaybackRateCommandEvent ()
@property (nonatomic, assign, readwrite) float playbackRate;
@end
#endif

@implementation MPChangePlaybackRateCommandEvent
@synthesize playbackRate = _playbackRate;

- (float)playbackRate {
    return _playbackRate;
}

@end
