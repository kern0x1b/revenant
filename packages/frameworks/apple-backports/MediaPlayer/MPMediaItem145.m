#import <Foundation/Foundation.h>
#if defined(REVENANT_MEDIAPLAYER_STANDIN)
#import "MPMediaItemStandin.h"
#else
#import <MediaPlayer/MediaPlayer.h>
#endif

@interface MPMediaItem (Revenant145)
@end

extern NSString * const MPMediaItemPropertyIsPreorder;

@implementation MPMediaItem (Revenant145)

@end

NSString * const MPMediaItemPropertyIsPreorder = @"isPreorder";
