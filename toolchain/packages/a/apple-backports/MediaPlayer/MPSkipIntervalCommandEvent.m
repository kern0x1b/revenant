#import <Foundation/Foundation.h>
#if defined(CHARON_MEDIAPLAYER_STANDIN)
#import "MPMediaItemStandin.h"
#else
#import <MediaPlayer/MediaPlayer.h>
#endif

#if defined(CHARON_MEDIAPLAYER_STANDIN)
@interface MPSkipIntervalCommandEvent : MPRemoteCommandEvent
@property (nonatomic, assign, readwrite) NSTimeInterval interval;
@end
#else
@interface MPSkipIntervalCommandEvent ()
@property (nonatomic, assign, readwrite) NSTimeInterval interval;
@end
#endif

@implementation MPSkipIntervalCommandEvent
@synthesize interval = _interval;

- (NSTimeInterval)interval {
    return _interval;
}

@end
