#import <Foundation/Foundation.h>
#if defined(REVENANT_MEDIAPLAYER_STANDIN)
#import "MPMediaItemStandin.h"
#else
#import <MediaPlayer/MediaPlayer.h>
#endif

@interface MPMediaItem (Revenant70)
@property (nonatomic, readonly) NSUInteger albumTrackNumber;
@property (nonatomic, readonly) NSUInteger discNumber;
@end

extern NSString * const MPMediaItemPropertyIsExplicit;

@implementation MPMediaItem (Revenant70)

- (NSUInteger)albumTrackNumber {
    return [[self valueForProperty:@"albumTrackNumber"] unsignedIntegerValue];
}

- (NSUInteger)discNumber {
    return [[self valueForProperty:@"discNumber"] unsignedIntegerValue];
}

@end

NSString * const MPMediaItemPropertyIsExplicit = @"isExplicit";
