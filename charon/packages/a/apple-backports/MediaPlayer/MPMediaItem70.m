// MPMediaItem's 2 7.0 members, the ones this release does not have at all.
//
// Generated from the one list in tests/backports/host/mediaplayeritem/generate.lua, with the facts rows
// and the host check's table, so the three cannot drift. Do not edit by hand: change the list and run the
// generator.
//
// What 6.1.3 has, measured against the 6.1.3 cache: none of these is in any of the image's 236 classes' own
// instance lists nor in any of its 41 categories - not on MPMediaItem (75 own methods), not on MPMediaEntity
// (18), not on MPConcreteMediaItem (29), the private class a real item's receiver is. What the release does
// have is the accessor they are conveniences over: valueForProperty: is an own method of MPMediaEntity. So a
// port-created item answers from its own dictionary, a real item is answered by the release, and a category
// on the public class clobbers nothing because a subclass's own method wins over a category on its public
// ancestor.
//
// Split by introduced release, per band()'s own rule: this file holds the 2 the 26.2 header
// declares MP_API(ios(7.0)).

#import <Foundation/Foundation.h>
#if defined(CHARON_MEDIAPLAYER_STANDIN)
// The host contract check compiles this file with the stand-in in place of the framework, so it measures
// this code and not the Mac's own MediaPlayer.
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
