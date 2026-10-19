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
@interface MPMediaPlaylist (Revenant93)
@property (nonatomic, readonly, nullable) NSString *authorDisplayName;
@property (nonatomic, readonly, nullable) NSString *descriptionText;
@end
#endif

extern NSString *const MPMediaPlaylistPropertyAuthorDisplayName;
extern NSString *const MPMediaPlaylistPropertyDescriptionText;

@implementation MPMediaPlaylist (Revenant93)

- (nullable NSString *)authorDisplayName {
    id value = [self valueForProperty:MPMediaPlaylistPropertyAuthorDisplayName];
    return [value isKindOfClass:[NSString class]] ? (NSString *)value : nil;
}

- (nullable NSString *)descriptionText {
    id value = [self valueForProperty:MPMediaPlaylistPropertyDescriptionText];
    return [value isKindOfClass:[NSString class]] ? (NSString *)value : nil;
}

@end
