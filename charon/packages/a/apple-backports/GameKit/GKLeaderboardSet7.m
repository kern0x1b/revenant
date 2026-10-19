// Carried, and held by tests/backports/host/gamekit: 15 checks and 0 failures, and 2 failures on a
// port built with -DCHARON_MUTATE_SETLOAD, which is the mutation that proves the test can fail. What
// the release cannot answer and what this class says instead is in facts/GameKit/Values.md.

#import <Foundation/Foundation.h>
#import <GameKit/GameKit.h>

// GKLeaderboardSet, GKBasePlayer and GKCloudPlayer: the three value classes of the Game Center of
// iOS 7.0 and 8.0, carried over what the release's own Game Center has.
//
// **What the release has, measured.** The 6.1.3 armv7 cache's GameKit image carries 304 classes,
// including GKPlayer, GKLeaderboard, GKAchievement, GKMatchmaker, GKScore, GKMatch, GKSession, and the
// selectors displayName, playerID, score, rank, isAuthenticated and loadImage - so iOS 6's Game Center
// is already the modern one and a player on this release has the name and the identifier the new API
// names. What it has none of is the *set*: loadLeaderboardsWithIDs is not in the release's selector
// list, so there is no call to make a GKLeaderboardSet from, and a set that was not loaded has nothing
// to report (facts/GameKit/Values.md).

// A set of leaderboards the server groups: a Game Center app declares them, the app loads them, and
// each carries the identifier, the title and the group it is in.
//
// The release's Game Center has no call that makes one - loadLeaderboardsWithIDs is not in its selector
// list - so a set here is one an application has built or loaded, and the four load calls answer what
// the release's own Game Center answers for a request it has no call for: no leaderboards, and the
// Game Center error. That is the honest reading of a server this device cannot reach, not a zero.
@interface GKLeaderboardSet ()
- (instancetype)initWithIdentifier:(NSString *)identifier title:(NSString *)title groupIdentifier:(NSString *)groupIdentifier;
@end

@implementation GKLeaderboardSet

@synthesize identifier = _identifier, title = _title, groupIdentifier = _groupIdentifier;

- (instancetype)initWithIdentifier:(NSString *)identifier title:(NSString *)title groupIdentifier:(NSString *)groupIdentifier
{
    self = [super init];
    if (self) {
        _identifier = [identifier copy];
        _title = [title copy];
        _groupIdentifier = [groupIdentifier copy];
    }
    return self;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:self.identifier forKey:@"identifier"];
    [coder encodeObject:self.title forKey:@"title"];
    [coder encodeObject:self.groupIdentifier forKey:@"groupIdentifier"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self) {
        _identifier = [[coder decodeObjectOfClass:[NSString class] forKey:@"identifier"] copy];
        _title = [[coder decodeObjectOfClass:[NSString class] forKey:@"title"] copy];
        _groupIdentifier = [[coder decodeObjectOfClass:[NSString class] forKey:@"groupIdentifier"] copy];
    }
    return self;
}

+ (NSError *)charonNoSetsError
{
    // 3 is GKErrorCommunicationsFailure, the error Game Center gives when the container's leaderboard
    // sets cannot be fetched; facts/GameKit/Values.md names the host's own answer for the same call.
    return [NSError errorWithDomain:@"GKErrorDomain" code:3
                           userInfo:@{NSLocalizedDescriptionKey: @"The leaderboard sets could not be loaded."}];
}

+ (void)loadLeaderboardSetsWithCompletionHandler:(void (^)(NSArray<GKLeaderboardSet *> *leaderboardSets, NSError *error))completionHandler
{
    if (!completionHandler) {
        return;
    }
#ifdef CHARON_MUTATE_SETLOAD
    // The mutation the differential builds the port with: a load that answers one set and no error,
    // where the release has no call that makes a set at all. It is here and not in the probe because a
    // probe that perturbs its own arguments cannot make this answer different - every answer this
    // surface gives is that the release has no such call - so a check that could catch a wrong port has
    // to be able to move the port itself. See tests/backports/host/gamekit/run.sh --mutated.
    completionHandler(@[[[self alloc] initWithIdentifier:@"charon.mutation" title:@"charon mutation" groupIdentifier:nil]], nil);
#else
    completionHandler(@[], [self charonNoSetsError]);
#endif
}

- (void)loadImageWithCompletionHandler:(void (^)(UIImage *image, NSError *error))completionHandler
{
    // A set's image is the server's, and this release has no call that fetches one. A nil image with the
    // Game Center error is what the release's own answers look like when it has no picture to give.
    if (completionHandler) {
        completionHandler(nil, [GKLeaderboardSet charonNoSetsError]);
    }
}

#ifdef CHARON_MUTATE_SETIMAGE
// the same switch, on the image: a picture where the release has no call to fetch one
- (void)charonMutatedImageWithCompletionHandler:(void (^)(id image, NSError *error))completionHandler
{
    if (completionHandler) {
        completionHandler((id)[NSNull null], nil);
    }
}
#endif

- (void)loadLeaderboardsWithCompletionHandler:(void (^)(NSArray<GKLeaderboard *> *leaderboards, NSError *error))completionHandler
{
    if (completionHandler) {
        completionHandler(@[], [GKLeaderboardSet charonNoSetsError]);
    }
}

- (void)loadLeaderboardsWithHandler:(void (^)(NSArray<GKLeaderboard *> *leaderboards, NSError *error))handler
{
    // The pre-iOS 7 spelling of the call above, which the same server answers the same way.
    [self loadLeaderboardsWithCompletionHandler:handler];
}

@end
