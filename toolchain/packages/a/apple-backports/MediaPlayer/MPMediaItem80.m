#import <Foundation/Foundation.h>
#if defined(CHARON_MEDIAPLAYER_STANDIN)
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
