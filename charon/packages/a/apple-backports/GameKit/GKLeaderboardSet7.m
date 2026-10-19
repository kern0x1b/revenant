#import <Foundation/Foundation.h>
#import <GameKit/GameKit.h>

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
    return [NSError errorWithDomain:@"GKErrorDomain" code:3
                           userInfo:@{NSLocalizedDescriptionKey: @"The leaderboard sets could not be loaded."}];
}

+ (void)loadLeaderboardSetsWithCompletionHandler:(void (^)(NSArray<GKLeaderboardSet *> *leaderboardSets, NSError *error))completionHandler
{
    if (!completionHandler) {
        return;
    }
#ifdef CHARON_MUTATE_SETLOAD
    completionHandler(@[[[self alloc] initWithIdentifier:@"charon.mutation" title:@"charon mutation" groupIdentifier:nil]], nil);
#else
    completionHandler(@[], [self charonNoSetsError]);
#endif
}

- (void)loadImageWithCompletionHandler:(void (^)(UIImage *image, NSError *error))completionHandler
{
    if (completionHandler) {
        completionHandler(nil, [GKLeaderboardSet charonNoSetsError]);
    }
}

#ifdef CHARON_MUTATE_SETIMAGE
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
    [self loadLeaderboardsWithCompletionHandler:handler];
}

@end
