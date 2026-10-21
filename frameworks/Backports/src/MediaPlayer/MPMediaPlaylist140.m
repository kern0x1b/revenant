#import <Foundation/Foundation.h>
#if defined(REVENANT_MEDIAPLAYER_STANDIN)
#import "MPMediaItemStandin.h"
#else
#import <MediaPlayer/MediaPlayer.h>
#endif

#if defined(REVENANT_MEDIAPLAYER_STANDIN)
@interface MPMediaPlaylist : NSObject
- (id)valueForProperty:(NSString *)property;
@end
@interface MPMediaPlaylist (Revenant140)
@property (nonatomic, readonly, nullable) NSString *cloudGlobalID;
@end
#endif

extern NSString *const MPMediaPlaylistPropertyCloudGlobalID;

@implementation MPMediaPlaylist (Revenant140)

- (nullable NSString *)cloudGlobalID {
    id value = [self valueForProperty:MPMediaPlaylistPropertyCloudGlobalID];
    return [value isKindOfClass:[NSString class]] ? (NSString *)value : nil;
}

@end
