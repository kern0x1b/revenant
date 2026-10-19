#import <Foundation/Foundation.h>
#if defined(CHARON_MEDIAPLAYER_STANDIN)
#import "MPMediaItemStandin.h"
#else
#import <MediaPlayer/MediaPlayer.h>
#endif

#if defined(CHARON_MEDIAPLAYER_STANDIN)
@interface MPRatingCommandEvent : MPRemoteCommandEvent
@property (nonatomic, assign, readwrite) float rating;
@end
#else
@interface MPRatingCommandEvent ()
@property (nonatomic, assign, readwrite) float rating;
@end
#endif

@implementation MPRatingCommandEvent
@synthesize rating = _rating;

- (float)rating {
    return _rating;
}

@end
