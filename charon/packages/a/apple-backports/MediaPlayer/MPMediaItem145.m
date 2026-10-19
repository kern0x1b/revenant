#import <Foundation/Foundation.h>
#if defined(CHARON_MEDIAPLAYER_STANDIN)
#import "MPMediaItemStandin.h"
#else
#import <MediaPlayer/MediaPlayer.h>
#endif

@interface MPMediaItem (Charon145)
@end

extern NSString * const MPMediaItemPropertyIsPreorder;

@implementation MPMediaItem (Charon145)

@end

NSString * const MPMediaItemPropertyIsPreorder = @"isPreorder";
