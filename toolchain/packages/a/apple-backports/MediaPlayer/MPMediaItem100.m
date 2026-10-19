#import <Foundation/Foundation.h>
#if defined(CHARON_MEDIAPLAYER_STANDIN)
#import "MPMediaItemStandin.h"
#else
#import <MediaPlayer/MediaPlayer.h>
#endif

@interface MPMediaItem (Charon100)
@property (nonatomic, readonly) NSDate * dateAdded;
@property (nonatomic, readonly) BOOL explicitItem;
@end

extern NSString * const MPMediaItemPropertyDateAdded;

@implementation MPMediaItem (Charon100)

- (NSDate *)dateAdded {
    return (NSDate *)[self valueForProperty:@"dateAdded"];
}

- (BOOL)isExplicitItem {
    return [[self valueForProperty:@"isExplicit"] boolValue];
}

@end

NSString * const MPMediaItemPropertyDateAdded = @"dateAdded";
