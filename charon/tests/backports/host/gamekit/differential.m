#import <Foundation/Foundation.h>
#import <GameKit/GameKit.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import "check.h"

// The port's three Game Center value classes against the host's own GameKit, which has all three.
//
// The questions are the ones whose answer is a shape rather than a value: a leaderboard set that was
// never loaded has no title, no identifier and no group on the host, and a load call answers an error
// rather than a value. The port's answers must have the same shapes, because a caller that gets a title
// for a set nobody loaded is a caller showing a name of nothing.

static void check_named(BOOL passed, NSString *name, NSString *detail)
{
    charon_check(passed, [name UTF8String], detail);
}

@interface CharonHostGKLeaderboardSet : NSObject
@property (nonatomic, readonly, copy) NSString *identifier;
@property (nonatomic, readonly, copy) NSString *title;
@property (nonatomic, readonly, copy) NSString *groupIdentifier;
+ (void)loadLeaderboardSetsWithCompletionHandler:(void (^)(NSArray *sets, NSError *error))completionHandler;
- (void)loadLeaderboardsWithCompletionHandler:(void (^)(NSArray *boards, NSError *error))completionHandler;
- (void)loadImageWithCompletionHandler:(void (^)(id image, NSError *error))completionHandler;
@end

@interface CharonHostGKBasePlayer : NSObject
@property (nonatomic, readonly, copy) NSString *playerID;
@property (nonatomic, readonly, copy) NSString *displayName;
@end

@interface CharonHostGKCloudPlayer : CharonHostGKBasePlayer
+ (void)getCurrentSignedInPlayerForContainer:(NSString *)containerID completionHandler:(void (^)(CharonHostGKCloudPlayer *player, NSError *error))completionHandler;
@end

// The host's own answers, where they are safe to ask. A *load* is not: it reaches Game Center's
// servers, and the host's own GKLeaderboardSet load crashed this probe outright, which is the same
// lesson seckeycurve taught - a host call that touches a service is not an oracle. What is safe is a
// value read: a set that was never loaded has no title, no identifier and no group, on the host too.
static void hostSetShapes(void (^report)(NSString *name, NSString *detail))
{
    // A set cannot be made here to read its properties: Apple's own -[GKLeaderboardSet init] is not
    // available to an application and raises when called, which this probe measured. What the host can
    // answer without an instance is the vocabulary the port must use: the error domain, the two error
    // codes, and that the three classes and the properties the port carries are the ones it declares.
    // GKErrorDomain is GK_EXTERN_WEAK. Its *address* is the only thing this probe may touch: in a
    // binary that links the port's objects nothing holds a strong reference, the weak address is NULL at
    // load, and a message to nil is the optimiser's objc_opt_respondsToSelector trap rather than a
    // no-op - which is what this probe kept stopping on, three times and in three ways. So the address
    // is read, the symbol is never messaged, and what comes back is recorded whether it is the string
    // or the absence of one.
    if (GKErrorDomain != nil) {
        // The guard is not the point: the symbol is not nil here and the *message* is what traps,
        // because a weak global is a load the optimiser cannot prove strong. So the object is not
        // messaged at all - its class is read through the runtime, which is a C function.
        Class domain = object_getClass(GKErrorDomain);
        report(@"the host's error domain", [NSString stringWithFormat:@"the class is %s, read through the runtime and not messaged",
                                               class_getName(domain)]);
    } else {
        // A fact, not a failure: the host does not carry the symbol, so its GameKit has no error domain to
        // answer with, and the port's own answers are held to the SDK's declarations below.
        report(@"the host's error domain", @"(the host does not carry the symbol: a GK_EXTERN_WEAK address that is NULL here)");
        printf("the host carries no GKErrorDomain, so its error vocabulary is read from the SDK\n");
    }
    report(@"the host's error codes", [NSString stringWithFormat:@"GKErrorUnknown = %ld, GKErrorNotAuthenticated = %ld, GKErrorCommunicationsFailure = %ld",
                                       (long)GKErrorUnknown, (long)GKErrorNotAuthenticated, (long)GKErrorCommunicationsFailure]);
    // the codes are enum constants, not weak symbols: the host answers them either way, and the port's
    // answers are held to the same two numbers
    check_named(GKErrorNotAuthenticated == 6, @"GKErrorNotAuthenticated is 6, which is what the port's cloud player answers",
                [NSString stringWithFormat:@"%ld", (long)GKErrorNotAuthenticated]);
    check_named(GKErrorCommunicationsFailure == 3, @"and GKErrorCommunicationsFailure is 3, which is what the port's set load answers",
                [NSString stringWithFormat:@"%ld", (long)GKErrorCommunicationsFailure]);
    // the host's own classes, by their own names: this half of the probe is about what Apple's
    // What the host is asked here is only what it answers without an instance and without a network:
    // the error vocabulary the port's answers are built from, and whether the three classes are there
    // at all. The *shape* question - whether a set nobody loaded has a title - needs a host instance,
    // and Apple's own -[GKLeaderboardSet init] is not available to an application and raised when the
    // probe called it, so that is held to the SDK's own declarations and not to a value the host will
    // not make.
    NSArray *classes = @[@"GKBasePlayer", @"GKCloudPlayer", @"GKLeaderboardSet"];
    for (NSString *name in (NSArray<NSString *> *)classes) {
        report([NSString stringWithFormat:@"the host has %@", name], NSClassFromString(name) ? @"yes" : @"no");
    }
}

int main(int argc, char **argv)
{
    setvbuf(stdout, NULL, _IOLBF, 0);
    BOOL mutated = argc > 1 && strcmp(argv[1], "--mutated") == 0;

    // 1. The host, for the shapes the port must match.
    hostSetShapes(^(NSString *name, NSString *detail) { printf("%-40s %s\n", [name UTF8String], [detail UTF8String]); });

    // 2. The port's own answers, the same questions.
    __block NSUInteger sets = 99;
    __block NSError *setsError = nil;
    [CharonHostGKLeaderboardSet loadLeaderboardSetsWithCompletionHandler:^(NSArray *loaded, NSError *error) {
        sets = loaded.count;
        setsError = error;
    }];
    if (mutated) {
        printf("probe: the port is built with CHARON_MUTATE_SETLOAD, and the checks that say it answers "
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

    CharonHostGKLeaderboardSet *portSet = [[CharonHostGKLeaderboardSet alloc] init];

    check_named(portSet.title == nil && portSet.identifier == nil && portSet.groupIdentifier == nil,
                @"a set nobody loaded has no title, no identifier and no group", portSet.title);
    check_named(portSet.title == nil, @"a set nobody loaded has no title", portSet.title);

    __block NSUInteger boards = 99;
    [portSet loadLeaderboardsWithCompletionHandler:^(NSArray *loaded, NSError *error) { boards = loaded.count; }];
    check_named(boards == 0, @"and resolving a set to its leaderboards answers none", [NSString stringWithFormat:@"%lu", (unsigned long)boards]);
    __block id image = @"unset";
    [portSet loadImageWithCompletionHandler:^(id loaded, NSError *error) { image = loaded; }];
    check_named(image == nil, @"and its image is nil, the server's", image);
    [CharonHostGKLeaderboardSet loadLeaderboardSetsWithCompletionHandler:nil];
    [portSet loadImageWithCompletionHandler:nil];
    check_named(YES, @"a nil handler is allowed by every call", @"raised");

    // 3. The player classes: the port's base player holds what it is given, and the cloud player's one
    //    call answers the release's own signed-in local player or the authentication error.
    CharonHostGKBasePlayer *base = [[CharonHostGKBasePlayer alloc] init];
    check_named(base.playerID == nil && base.displayName == nil, @"a base player nobody built has no identifier and no name",
                base.displayName);
    // The cloud player's one call. Its handler's arguments come back as void* through a block, and the
    // optimiser turns a message to either of them into objc_opt_respondsToSelector - a trap, not a
    // no-op - which is where this probe stopped last. So both are read as pointers and asked about
    // through the runtime's class_getName, and every question about them is guarded by that.
    printf("probe: before the cloud player's call\n"); fflush(stdout);
    __block void *cloud = NULL;
    __block void *cloudError = NULL;
    [CharonHostGKCloudPlayer getCurrentSignedInPlayerForContainer:@"i.com.charon.probe" completionHandler:^(CharonHostGKCloudPlayer *player, NSError *error) {
        cloud = (__bridge_retained void *)player;
        cloudError = (__bridge_retained void *)error;
    }];
    printf("probe: the call returned, cloud %p\n", cloud); fflush(stdout);
    id player = (__bridge_transfer id)cloud; cloud = NULL;
    id failure = (__bridge_transfer id)cloudError; cloudError = NULL;
    if (player) {
        check_named(failure == nil, @"and a player comes with no error",
                    failure ? (NSString *)[failure localizedDescription] : @"");
        // the two properties a base player carries, read as selectors on a guarded object
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

    printf("checks=%d failures=%d\n", charon_checks, charon_failures);
    return charon_failures == 0 ? 0 : 1;
}
