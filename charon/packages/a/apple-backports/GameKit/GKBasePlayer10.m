#import <Foundation/Foundation.h>
#import <GameKit/GameKit.h>

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

@implementation GKCloudPlayer

+ (void)getCurrentSignedInPlayerForContainer:(NSString *)containerID completionHandler:(void (^)(GKCloudPlayer *player, NSError *error))completionHandler
{
    if (!completionHandler) {
        return;
    }
    GKLocalPlayer *local = [GKLocalPlayer localPlayer];
    if (local && local.isAuthenticated) {
        completionHandler([[GKCloudPlayer alloc] initWithPlayerID:local.playerID displayName:local.displayName], nil);
        return;
    }
    completionHandler(nil, [NSError errorWithDomain:@"GKErrorDomain" code:6
                                        userInfo:@{NSLocalizedDescriptionKey: @"The player is not authenticated."}]);
}

@end
