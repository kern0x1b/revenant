#import <Foundation/Foundation.h>
#if defined(CHARON_MEDIAPLAYER_STANDIN)
#import "MPMediaItemStandin.h"
#else
#import <MediaPlayer/MediaPlayer.h>
#endif

@interface MPMediaItem (Charon92)
@property (nonatomic, readonly) BOOL protectedAsset;
@end

extern NSString * const MPMediaItemPropertyHasProtectedAsset;

@implementation MPMediaItem (Charon92)

- (BOOL)hasProtectedAsset {
    return [[self valueForProperty:@"hasProtectedAsset"] boolValue];
}

@end

NSString * const MPMediaItemPropertyHasProtectedAsset = @"hasProtectedAsset";
