// MPMediaItem's 15 8.0 members, the ones this release does not have at all.
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
// Split by introduced release, per band()'s own rule: this file holds the 15 the 26.2 header
// declares MP_API(ios(8.0)).

#import <Foundation/Foundation.h>
#if defined(CHARON_MEDIAPLAYER_STANDIN)
// The host contract check compiles this file with the stand-in in place of the framework, so it measures
// this code and not the Mac's own MediaPlayer.
#import "MPMediaItemStandin.h"
#else
#import <MediaPlayer/MediaPlayer.h>
#endif

@interface MPMediaItem (Charon80)
@property (nonatomic, readonly) MPMediaEntityPersistentID albumPersistentID;
@property (nonatomic, readonly) MPMediaEntityPersistentID artistPersistentID;
@property (nonatomic, readonly) MPMediaEntityPersistentID albumArtistPersistentID;
@property (nonatomic, readonly) MPMediaEntityPersistentID genrePersistentID;
@property (nonatomic, readonly) MPMediaEntityPersistentID composerPersistentID;
@property (nonatomic, readonly) MPMediaEntityPersistentID podcastPersistentID;
@property (nonatomic, readonly) NSUInteger albumTrackCount;
@property (nonatomic, readonly) NSUInteger discCount;
@property (nonatomic, readonly) NSUInteger beatsPerMinute;
@property (nonatomic, readonly) BOOL compilation;
@property (nonatomic, readonly) BOOL cloudItem;
@property (nonatomic, readonly) NSString * lyrics;
@property (nonatomic, readonly) NSString * comments;
@property (nonatomic, readonly) NSString * userGrouping;
@property (nonatomic, readonly) NSURL * assetURL;
@end


@implementation MPMediaItem (Charon80)

- (MPMediaEntityPersistentID)albumPersistentID {
    return (MPMediaEntityPersistentID)[self valueForProperty:@"albumPersistentID"];
}

- (MPMediaEntityPersistentID)artistPersistentID {
    return (MPMediaEntityPersistentID)[self valueForProperty:@"artistPersistentID"];
}

- (MPMediaEntityPersistentID)albumArtistPersistentID {
    return (MPMediaEntityPersistentID)[self valueForProperty:@"albumArtistPersistentID"];
}

- (MPMediaEntityPersistentID)genrePersistentID {
    return (MPMediaEntityPersistentID)[self valueForProperty:@"genrePersistentID"];
}

- (MPMediaEntityPersistentID)composerPersistentID {
    return (MPMediaEntityPersistentID)[self valueForProperty:@"composerPersistentID"];
}

- (MPMediaEntityPersistentID)podcastPersistentID {
    return (MPMediaEntityPersistentID)[self valueForProperty:@"podcastPersistentID"];
}

- (NSUInteger)albumTrackCount {
    return [[self valueForProperty:@"albumTrackCount"] unsignedIntegerValue];
}

- (NSUInteger)discCount {
    return [[self valueForProperty:@"discCount"] unsignedIntegerValue];
}

- (NSUInteger)beatsPerMinute {
    return [[self valueForProperty:@"beatsPerMinute"] unsignedIntegerValue];
}

- (BOOL)isCompilation {
    return [[self valueForProperty:@"isCompilation"] boolValue];
}

- (BOOL)isCloudItem {
    return [[self valueForProperty:@"isCloudItem"] boolValue];
}

- (NSString *)lyrics {
    return (NSString *)[self valueForProperty:@"lyrics"];
}

- (NSString *)comments {
    return (NSString *)[self valueForProperty:@"comments"];
}

- (NSString *)userGrouping {
    return (NSString *)[self valueForProperty:@"userGrouping"];
}

- (NSURL *)assetURL {
    return (NSURL *)[self valueForProperty:@"assetURL"];
}

@end

