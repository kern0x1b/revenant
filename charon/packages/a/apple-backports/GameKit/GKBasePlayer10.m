// Carried, and held by tests/backports/host/gamekit: 15 checks and 0 failures, and 2 failures on a
// port built with -DCHARON_MUTATE_SETLOAD.

#import <Foundation/Foundation.h>
#import <GameKit/GameKit.h>

// GKBasePlayer and GKCloudPlayer, iOS 10.0.1: the two player classes of the Game Center, carried over
// the release's own GKLocalPlayer. They are a file of their own because an object carries the API of
// one release, and the leaderboard set beside them is iOS 7.0 (facts/GameKit/Values.md).

@interface GKBasePlayer ()
- (instancetype)initWithPlayerID:(NSString *)playerID displayName:(NSString *)displayName;
@end

@implementation GKBasePlayer

@synthesize playerID = _playerID, displayName = _displayName;

- (instancetype)initWithPlayerID:(NSString *)playerID displayName:(NSString *)displayName
{
    self = [super init];
    if (self) {
        _playerID = [playerID copy];
        _displayName = [displayName copy];
    }
    return self;
}

- (instancetype)init
{
    return [self initWithPlayerID:nil displayName:nil];
}

- (BOOL)isEqual:(id)other
{
    if (self == other) {
        return YES;
    }
    if (![other isKindOfClass:[GKBasePlayer class]]) {
        return NO;
    }
    GKBasePlayer *player = other;
    return ((self.playerID == nil && player.playerID == nil) || [self.playerID isEqualToString:player.playerID])
        && ((self.displayName == nil && player.displayName == nil) || [self.displayName isEqualToString:player.displayName]);
}

- (NSUInteger)hash
{
    return self.playerID.hash ^ self.displayName.hash;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p, player %@, name %@>", NSStringFromClass([self class]), (void *)self,
                                      self.playerID, self.displayName];
}

@end

// A signed-in player in a Game Center *container*: the server's record of who is signed in, which is
// what GKLocalPlayer is to the old API. The release's GKLocalPlayer is the local player; the container
// record is a server's, and the release's Game Center has no call that returns it, so the call answers
// with the error Game Center itself gives when it cannot authenticate - which the facts name, and which
// the host's own GameKit is the measure of.
@implementation GKCloudPlayer

+ (void)getCurrentSignedInPlayerForContainer:(NSString *)containerID completionHandler:(void (^)(GKCloudPlayer *player, NSError *error))completionHandler
{
    if (!completionHandler) {
        return;
    }
    GKLocalPlayer *local = [GKLocalPlayer localPlayer];
    if (local && local.isAuthenticated) {
        // A signed-in local player is the closest thing this release has to a container's record: its
        // own identifier and name, which is the pair GKBasePlayer carries.
        completionHandler([[GKCloudPlayer alloc] initWithPlayerID:local.playerID displayName:local.displayName], nil);
        return;
    }
    // 6 is GKErrorNotAuthenticated in the SDK's own GKError.h; there is no GKErrorAuthenticationFailed,
    // and GKErrorUnknown is 1, which says nothing about why.
    completionHandler(nil, [NSError errorWithDomain:@"GKErrorDomain" code:6
                                        userInfo:@{NSLocalizedDescriptionKey: @"The player is not authenticated."}]);
}

@end
