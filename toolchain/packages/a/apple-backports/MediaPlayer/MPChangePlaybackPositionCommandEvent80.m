#import <Foundation/Foundation.h>
#if defined(CHARON_MEDIAPLAYER_STANDIN)
#import "MPMediaItemStandin.h"
#else
#import <MediaPlayer/MediaPlayer.h>
#endif

#if defined(CHARON_MEDIAPLAYER_STANDIN)
@interface MPChangePlaybackPositionCommandEvent : MPRemoteCommandEvent
@property (nonatomic, assign, readwrite) NSTimeInterval positionTime;
@end
#else
@interface MPChangePlaybackPositionCommandEvent ()
@property (nonatomic, assign, readwrite) NSTimeInterval positionTime;
@end
#endif

@implementation MPChangePlaybackPositionCommandEvent
@synthesize positionTime = _positionTime;

- (NSTimeInterval)positionTime {
    return _positionTime;
}

@end
