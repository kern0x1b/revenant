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
@interface MPMediaPlaylist (Charon80)
@property (nonatomic, readonly, nullable) NSArray<MPMediaItem *> *seedItems;
@end
#endif

extern NSString *const MPMediaPlaylistPropertySeedItems;

@implementation MPMediaPlaylist (Charon80)

- (nullable NSArray<MPMediaItem *> *)seedItems {
    id value = [self valueForProperty:MPMediaPlaylistPropertySeedItems];
    if (![value isKindOfClass:[NSArray class]]) {
        return nil;
    }
    for (id element in (NSArray *)value) {
        if (![element isKindOfClass:[MPMediaItem class]]) {
            return nil;
        }
    }
    return (NSArray<MPMediaItem *> *)value;
}

@end
