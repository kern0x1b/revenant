#import <Foundation/Foundation.h>
#if defined(REVENANT_MEDIAPLAYER_STANDIN)
#import "MPMediaItemStandin.h"
#else
#import <MediaPlayer/MediaPlayer.h>
#endif

@interface MPMediaItem (Revenant92)
@property (nonatomic, readonly) BOOL protectedAsset;
@end

extern NSString * const MPMediaItemPropertyHasProtectedAsset;

@implementation MPMediaItem (Revenant92)

- (BOOL)hasProtectedAsset {
    return [[self valueForProperty:@"hasProtectedAsset"] boolValue];
}

@end

NSString * const MPMediaItemPropertyHasProtectedAsset = @"hasProtectedAsset";
