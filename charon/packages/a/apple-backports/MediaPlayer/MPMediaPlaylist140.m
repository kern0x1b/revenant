#import <Foundation/Foundation.h>
#if defined(CHARON_MEDIAPLAYER_STANDIN)
#import "MPMediaItemStandin.h"
#else
#import <MediaPlayer/MediaPlayer.h>
#endif

#if defined(CHARON_MEDIAPLAYER_STANDIN)
@interface MPMediaPlaylist : NSObject
- (id)valueForProperty:(NSString *)property;
@end
@interface MPMediaPlaylist (Charon140)
@property (nonatomic, readonly, nullable) NSString *cloudGlobalID;
@end
#endif

extern NSString *const MPMediaPlaylistPropertyCloudGlobalID;

@implementation MPMediaPlaylist (Charon140)

- (nullable NSString *)cloudGlobalID {
    id value = [self valueForProperty:MPMediaPlaylistPropertyCloudGlobalID];
    return [value isKindOfClass:[NSString class]] ? (NSString *)value : nil;
}

@end
