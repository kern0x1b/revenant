#import <Foundation/Foundation.h>
#if defined(REVENANT_MEDIAPLAYER_STANDIN)
#import "MPMediaItemStandin.h"
#else
#import <MediaPlayer/MediaPlayer.h>
#endif

#if defined(REVENANT_MEDIAPLAYER_STANDIN)
@interface MPMediaEntity : NSObject
- (id)valueForProperty:(NSString *)property;
@end
@interface MPMediaEntity (Revenant80)
- (nullable id)objectForKeyedSubscript:(id)key;
@end
#endif

@implementation MPMediaEntity (Revenant80)

- (nullable id)objectForKeyedSubscript:(id)key {
    return [self valueForProperty:key];
}

@end
