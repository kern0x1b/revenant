#import <Foundation/Foundation.h>
#import <GameKit/GameKit.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import "check.h"

static void check_named(BOOL passed, NSString *name, NSString *detail)
{
    revenant_check(passed, [name UTF8String], detail);
}

@interface RevenantHostGKLeaderboardSet : NSObject
@property (nonatomic, readonly, copy) NSString *identifier;
@property (nonatomic, readonly, copy) NSString *title;
@property (nonatomic, readonly, copy) NSString *groupIdentifier;
+ (void)loadLeaderboardSetsWithCompletionHandler:(void (^)(NSArray *sets, NSError *error))completionHandler;
- (void)loadLeaderboardsWithCompletionHandler:(void (^)(NSArray *boards, NSError *error))completionHandler;
- (void)loadImageWithCompletionHandler:(void (^)(id image, NSError *error))completionHandler;
@end

@interface RevenantHostGKBasePlayer : NSObject
@property (nonatomic, readonly, copy) NSString *playerID;
@property (nonatomic, readonly, copy) NSString *displayName;
@end

@interface RevenantHostGKCloudPlayer : RevenantHostGKBasePlayer
+ (void)getCurrentSignedInPlayerForContainer:(NSString *)containerID completionHandler:(void (^)(RevenantHostGKCloudPlayer *player, NSError *error))completionHandler;
@end

static void hostSetShapes(void (^report)(NSString *name, NSString *detail))
{
    if (GKErrorDomain != nil) {
        Class domain = object_getClass(GKErrorDomain);
        report(@"the host's error domain", [NSString stringWithFormat:@"the class is %s, read through the runtime and not messaged",
                                               class_getName(domain)]);
    } else {
        report(@"the host's error domain", @"(the host does not carry the symbol: a GK_EXTERN_WEAK address that is NULL here)");
        printf("the host carries no GKErrorDomain, so its error vocabulary is read from the SDK\n");
    }
    report(@"the host's error codes", [NSString stringWithFormat:@"GKErrorUnknown = %ld, GKErrorNotAuthenticated = %ld, GKErrorCommunicationsFailure = %ld",
                                       (long)GKErrorUnknown, (long)GKErrorNotAuthenticated, (long)GKErrorCommunicationsFailure]);
    check_named(GKErrorNotAuthenticated == 6, @"GKErrorNotAuthenticated is 6, which is what the port's cloud player answers",
                [NSString stringWithFormat:@"%ld", (long)GKErrorNotAuthenticated]);
    check_named(GKErrorCommunicationsFailure == 3, @"and GKErrorCommunicationsFailure is 3, which is what the port's set load answers",
                [NSString stringWithFormat:@"%ld", (long)GKErrorCommunicationsFailure]);
    NSArray *classes = @[@"GKBasePlayer", @"GKCloudPlayer", @"GKLeaderboardSet"];
    for (NSString *name in (NSArray<NSString *> *)classes) {
        report([NSString stringWithFormat:@"the host has %@", name], NSClassFromString(name) ? @"yes" : @"no");
    }
}

int main(int argc, char **argv)
{
    setvbuf(stdout, NULL, _IOLBF, 0);
    BOOL mutated = argc > 1 && strcmp(argv[1], "--mutated") == 0;

    hostSetShapes(^(NSString *name, NSString *detail) { printf("%-40s %s\n", [name UTF8String], [detail UTF8String]); });

    __block NSUInteger sets = 99;
    __block NSError *setsError = nil;
    [RevenantHostGKLeaderboardSet loadLeaderboardSetsWithCompletionHandler:^(NSArray *loaded, NSError *error) {
        sets = loaded.count;
        setsError = error;
    }];
    if (mutated) {
        printf("probe: the port is built with REVENANT_MUTATE_SETLOAD, and the checks that say it answers "
               "no sets with GKErrorCommunicationsFailure are the ones that have to fail\n");
    }
    check_named(sets == 0,
                @"the port's set load answers no sets", [NSString stringWithFormat:@"%lu", (unsigned long)sets]);
    check_named(setsError != nil,
                @"and an error rather than a value", @"no error at all");
    if (setsError) {
        check_named([setsError.domain isEqualToString:@"GKErrorDomain"], @"in Game Center's own domain",
                    setsError.domain);
        check_named(setsError.code == 3, @"with GKErrorCommunicationsFailure, the SDK's own constant 3",
                    [NSString stringWithFormat:@"%ld", (long)setsError.code]);
    }

    RevenantHostGKLeaderboardSet *portSet = [[RevenantHostGKLeaderboardSet alloc] init];

    check_named(portSet.title == nil && portSet.identifier == nil && portSet.groupIdentifier == nil,
                @"a set nobody loaded has no title, no identifier and no group", portSet.title);
    check_named(portSet.title == nil, @"a set nobody loaded has no title", portSet.title);

    __block NSUInteger boards = 99;
    [portSet loadLeaderboardsWithCompletionHandler:^(NSArray *loaded, NSError *error) { boards = loaded.count; }];
    check_named(boards == 0, @"and resolving a set to its leaderboards answers none", [NSString stringWithFormat:@"%lu", (unsigned long)boards]);
    __block id image = @"unset";
    [portSet loadImageWithCompletionHandler:^(id loaded, NSError *error) { image = loaded; }];
    check_named(image == nil, @"and its image is nil, the server's", image);
    [RevenantHostGKLeaderboardSet loadLeaderboardSetsWithCompletionHandler:nil];
    [portSet loadImageWithCompletionHandler:nil];
    check_named(YES, @"a nil handler is allowed by every call", @"raised");

    RevenantHostGKBasePlayer *base = [[RevenantHostGKBasePlayer alloc] init];
    check_named(base.playerID == nil && base.displayName == nil, @"a base player nobody built has no identifier and no name",
                base.displayName);
    printf("probe: before the cloud player's call\n"); fflush(stdout);
    __block void *cloud = NULL;
    __block void *cloudError = NULL;
    [RevenantHostGKCloudPlayer getCurrentSignedInPlayerForContainer:@"i.com.revenant.probe" completionHandler:^(RevenantHostGKCloudPlayer *player, NSError *error) {
        cloud = (__bridge_retained void *)player;
        cloudError = (__bridge_retained void *)error;
    }];
    printf("probe: the call returned, cloud %p\n", cloud); fflush(stdout);
    id player = (__bridge_transfer id)cloud; cloud = NULL;
    id failure = (__bridge_transfer id)cloudError; cloudError = NULL;
    if (player) {
        check_named(failure == nil, @"and a player comes with no error",
                    failure ? (NSString *)[failure localizedDescription] : @"");
        for (NSString *property in (NSArray<NSString *> *)@[@"playerID", @"displayName"]) {
            SEL getter = NSSelectorFromString(property);
            if (player && [player respondsToSelector:getter]) {
                id value = ((id (*)(id, SEL))objc_msgSend)(player, getter);
                check_named(value == nil, [NSString stringWithFormat:@"and the player's %@ is nil when the release has no container record", property],
                            value ? [value description] : @"");
            }
        }
    } else {
        check_named(failure != nil, @"and an error rather than no answer", @"neither a player nor an error");
        if (failure) {
            NSError *error = (NSError *)failure;
            check_named([error.domain isEqualToString:@"GKErrorDomain"], @"in Game Center's own domain", error.domain);
            check_named(error.code == GKErrorNotAuthenticated, @"with GKErrorNotAuthenticated, the SDK's own constant",
                        [NSString stringWithFormat:@"%ld", (long)error.code]);
        }
    }

    printf("checks=%d failures=%d\n", revenant_checks, revenant_failures);
    return revenant_failures == 0 ? 0 : 1;
}
