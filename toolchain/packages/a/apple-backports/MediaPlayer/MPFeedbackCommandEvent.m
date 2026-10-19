#import <Foundation/Foundation.h>
#if defined(REVENANT_MEDIAPLAYER_STANDIN)
#import "MPMediaItemStandin.h"
#else
#import <MediaPlayer/MediaPlayer.h>
#endif

#if defined(REVENANT_MEDIAPLAYER_STANDIN)
@interface MPFeedbackCommandEvent : MPRemoteCommandEvent
@property (nonatomic, assign, readwrite, getter = isNegative) BOOL negative;
@end
#else
@interface MPFeedbackCommandEvent ()
@property (nonatomic, assign, readwrite, getter = isNegative) BOOL negative;
@end
#endif

@implementation MPFeedbackCommandEvent
@synthesize negative = _negative;

- (BOOL)isNegative {
    return _negative;
}

@end
