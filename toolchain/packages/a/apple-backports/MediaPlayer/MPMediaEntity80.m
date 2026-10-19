#import <Foundation/Foundation.h>
#if defined(CHARON_MEDIAPLAYER_STANDIN)
#import "MPMediaItemStandin.h"
#else
#import <MediaPlayer/MediaPlayer.h>
#endif

#if defined(CHARON_MEDIAPLAYER_STANDIN)
@interface MPMediaEntity : NSObject
- (id)valueForProperty:(NSString *)property;
@end
@interface MPMediaEntity (Charon80)
- (nullable id)objectForKeyedSubscript:(id)key;
@end
#endif

@implementation MPMediaEntity (Charon80)

- (nullable id)objectForKeyedSubscript:(id)key {
    return [self valueForProperty:key];
}

@end
