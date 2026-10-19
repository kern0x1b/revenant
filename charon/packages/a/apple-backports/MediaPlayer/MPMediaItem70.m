#import <Foundation/Foundation.h>
#if defined(CHARON_MEDIAPLAYER_STANDIN)
#import "MPMediaItemStandin.h"
#else
#import <MediaPlayer/MediaPlayer.h>
#endif

@interface MPMediaItem (Charon70)
@property (nonatomic, readonly) NSUInteger albumTrackNumber;
@property (nonatomic, readonly) NSUInteger discNumber;
@end

extern NSString * const MPMediaItemPropertyIsExplicit;

@implementation MPMediaItem (Charon70)

- (NSUInteger)albumTrackNumber {
    return [[self valueForProperty:@"albumTrackNumber"] unsignedIntegerValue];
}

- (NSUInteger)discNumber {
    return [[self valueForProperty:@"discNumber"] unsignedIntegerValue];
}

@end

NSString * const MPMediaItemPropertyIsExplicit = @"isExplicit";
