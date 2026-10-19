#import <Foundation/Foundation.h>
#if defined(CHARON_MEDIAPLAYER_STANDIN)
#import "MPMediaItemStandin.h"
#else
#import <MediaPlayer/MediaPlayer.h>
#endif

@interface MPMediaItem (Charon103)
@property (nonatomic, readonly) NSString * playbackStoreID;
@property (nonatomic, readonly) BOOL preorder;
@end

extern NSString * const MPMediaItemPropertyPlaybackStoreID;

@implementation MPMediaItem (Charon103)

- (NSString *)playbackStoreID {
    return (NSString *)[self valueForProperty:@"playbackStoreID"];
}

- (BOOL)isPreorder {
    return [[self valueForProperty:@"isPreorder"] boolValue];
}

@end

NSString * const MPMediaItemPropertyPlaybackStoreID = @"playbackStoreID";
