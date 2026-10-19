// MPPlayableContentManager (7.1), MPContentItem (7.1) and MPPlayableContentManagerContext (8.4): the
// playable-content family, none of which any held release carries
// (facts/MediaPlayer/PlayableContent.md).
//
// Compiled against a stand-in, not this Mac's own MediaPlayer, and that is not a formality: this Mac HAS
// MPContentItem, and a first draft of this file let <MediaPlayer/MediaPlayer.h> resolve to the host's,
// so the port's source compiled against Apple's classes and clang reported a dozen "duplicate interface
// definition for class 'MPContentItem'" errors. The stand-in directory in the include path holds an empty
// MediaPlayer/MediaPlayer.h, which is the whole mechanism - the same reason MPMediaItemStandin.h exists.
//
// Every assertion has been shown to fail on a mutation of the object it covers; the table of mutants and
// their verdicts is in the facts page. Two of them are load-bearing in a way that is easy to get wrong
// and is written into the checks themselves: playbackProgress must default to the header's -1.0 rather
// than a zero-initialised 0.0, and the update depth must clamp at zero so an unpaired -endUpdates cannot
// make a later balanced pair look balanced.
#import <Foundation/Foundation.h>

// MPPlayableContentManager is named by the delegate protocol below before it is declared, so it is
// forward-declared with the rest. (A first draft omitted it and clang read the name as a type and
// failed with "expected a type" on the protocol's method.)
@class MPContentItem, MPPlayableContentManager, MPPlayableContentManagerContext;
@protocol MPPlayableContentDataSource <NSObject>
@required
- (NSInteger)numberOfChildItemsAtIndexPath:(NSIndexPath *)indexPath;
- (MPContentItem *)contentItemAtIndexPath:(NSIndexPath *)indexPath;
@end
@protocol MPPlayableContentDelegate <NSObject>
@optional
- (void)playableContentManager:(MPPlayableContentManager *)contentManager
  initiatePlaybackOfContentItemAtIndexPath:(NSIndexPath *)indexPath
                        completionHandler:(void (^)(NSError *))completionHandler;
@end

@interface MPContentItem : NSObject
- (instancetype)initWithIdentifier:(NSString *)identifier;
@property (nonatomic, copy, readonly) NSString *identifier;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *subtitle;
@property (nonatomic, strong) id artwork;
@property (nonatomic, assign) float playbackProgress;
@property (nonatomic, assign, getter=isStreamingContent) BOOL streamingContent;
@property (nonatomic, assign, getter=isExplicitContent) BOOL explicitContent;
@property (nonatomic, assign, getter=isContainer) BOOL container;
@property (nonatomic, assign, getter=isPlayable) BOOL playable;
@end

@interface MPPlayableContentManager : NSObject
@property (nonatomic, weak) id<MPPlayableContentDataSource> dataSource;
@property (nonatomic, weak) id<MPPlayableContentDelegate> delegate;
@property (nonatomic, readonly) MPPlayableContentManagerContext *context;
@property (nonatomic, copy) NSArray<NSString *> *nowPlayingIdentifiers;
+ (instancetype)sharedContentManager;
- (NSUInteger)charonUpdateDepth;
- (NSUInteger)charonReloadCount;
- (void)reloadData;
- (void)beginUpdates;
- (void)endUpdates;
@end

@interface MPPlayableContentManagerContext : NSObject
@property (nonatomic, readonly) NSInteger enforcedContentItemsCount;
@property (nonatomic, readonly) NSInteger enforcedContentTreeDepth;
@property (nonatomic, readonly) BOOL contentLimitsEnforced;
@property (nonatomic, readonly) BOOL endpointAvailable;
- (BOOL)contentLimitsEnabled;
@end

#include "MPPlayableContentManager71.m"
#include "MPPlayableContentManagerContext84.m"

// A data source that answers the two REQUIRED members, and the delegate's one optional callback. If the
// port's objects could not hold and reach an app's own implementations of these protocols, nothing below
// would have a subject.
@interface Source : NSObject <MPPlayableContentDataSource> @end
@implementation Source
// NSIndexPath is the parameter type the data source protocol declares, and on this host it is a UIKit
// type, so the check declares the one class method the protocol's contract needs rather than linking
// UIKit - the port's own object never constructs an index path, it only hands the data source's answers
// back to the caller, and that is what the checks below exercise.
+ (NSIndexPath *)charonTestIndexPath { static NSIndexPath *p; if (!p) { p = [[NSIndexPath alloc] init]; } return p; }
- (NSInteger)numberOfChildItemsAtIndexPath:(NSIndexPath *)indexPath { return 3; }
- (MPContentItem *)contentItemAtIndexPath:(NSIndexPath *)indexPath {
    return [[MPContentItem alloc] initWithIdentifier:@"song-1"];
}
@end

@interface Delegate : NSObject <MPPlayableContentDelegate> @end
@implementation Delegate
- (void)playableContentManager:(MPPlayableContentManager *)m
  initiatePlaybackOfContentItemAtIndexPath:(NSIndexPath *)indexPath
                        completionHandler:(void (^)(NSError *))completionHandler {
    completionHandler(nil);
}
@end

static int failures = 0;
static void check(const char *what, int held, const char *got) {
    if (held) { printf("  ok   %s: %s\n", what, got); }
    else { printf("  RED  %s: %s\n", what, got); failures++; }
}

int main(void) {
    MPContentItem *item = [[MPContentItem alloc] initWithIdentifier:@"song-1"];
    check("the designated initializer's identifier reads back",
          [item.identifier isEqualToString:@"song-1"], "song-1");
    // The header's documented default is -1.0 ("no progress indicator shown"), NOT the 0.0 a
    // zero-initialised ivar would give, which means "not watched/listened/viewed".
    check("playbackProgress defaults to the header's -1.0, not a zero-initialised 0.0",
          item.playbackProgress == -1.0f, "-1.0");
    item.title = @"Title"; item.subtitle = @"Artist";
    item.streamingContent = YES; item.explicitContent = YES; item.container = YES; item.playable = YES;
    check("title reads back", [item.title isEqualToString:@"Title"], "Title");
    check("the getter= spellings are the selectors, as the header declares them",
          item.isStreamingContent && item.isExplicitContent && item.isContainer && item.isPlayable,
          "all four YES");

    MPPlayableContentManager *shared = [MPPlayableContentManager sharedContentManager];
    check("+sharedContentManager is one instance, as the header's 'the application's instance' says",
          shared == [MPPlayableContentManager sharedContentManager], "same object");

    Source *source = [[Source alloc] init];
    Delegate *delegate = [[Delegate alloc] init];
    shared.dataSource = source; shared.delegate = delegate;
    check("the manager holds the data source it was given", shared.dataSource == source, "the source");
    check("the manager holds the delegate it was given", shared.delegate == delegate, "the delegate");
    check("the required data source members are reachable through the port's object",
          [shared.dataSource numberOfChildItemsAtIndexPath:[Source charonTestIndexPath]] == 3,
          "3");
    MPContentItem *reached = [shared.dataSource contentItemAtIndexPath:[Source charonTestIndexPath]];
    check("the required contentItemAtIndexPath: is reachable and answers an MPContentItem",
          [reached isKindOfClass:[MPContentItem class]] && [reached.identifier isEqualToString:@"song-1"],
          "song-1");
    __block int asked = 0;
    [shared.delegate playableContentManager:shared
          initiatePlaybackOfContentItemAtIndexPath:[Source charonTestIndexPath]
                                completionHandler:^(NSError *e) { asked++; }];
    check("the delegate's optional playback callback is reachable and its handler runs", asked == 1, "1");

    NSMutableArray *ids = [@[ @"a", @"b" ] mutableCopy];
    shared.nowPlayingIdentifiers = ids;
    [ids addObject:@"c"];
    check("nowPlayingIdentifiers is @property(copy), so the caller's later mutation cannot change it",
          shared.nowPlayingIdentifiers.count == 2, "2");
    // The update depth is read through the seam below rather than by a guess about balance: a check
    // that only called a balanced sequence passed on a mutant that let the depth go negative, so the
    // depth is exposed and compared. That is what makes the clamp observable.
    shared.reloadData;
    [shared beginUpdates]; [shared beginUpdates];
    check("two -beginUpdates put the depth at 2", [shared charonUpdateDepth] == 2, "2");
    [shared endUpdates];
    check("one -endUpdates brings it back to 1", [shared charonUpdateDepth] == 1, "1");
    [shared endUpdates]; [shared endUpdates];  // the second is UNPAIRED
    check("an unpaired -endUpdates is clamped at 0, not driven negative",
          [shared charonUpdateDepth] == 0, "0");
    [shared beginUpdates];
    check("so a later balanced pair still reads 1, which a negative depth would have broken",
          [shared charonUpdateDepth] == 1, "1");
    [shared endUpdates];
    check("and the reload count is visible rather than the call being a silent nothing",
          [shared charonReloadCount] == 1, "1");

    MPPlayableContentManagerContext *context = [[MPPlayableContentManagerContext alloc] init];
    check("endpointAvailable is NO: there is no external media player on this release",
          !context.endpointAvailable, "NO");
    check("enforcedContentItemsCount is the header's own 'never limit' value, not 0",
          context.enforcedContentItemsCount == NSIntegerMax, "NSIntegerMax");
    check("enforcedContentTreeDepth is 0: no endpoint, no tree, and the header says exceeding it crashes",
          context.enforcedContentTreeDepth == 0, "0");
    check("the deprecated contentLimitsEnabled agrees with the property that replaced it",
          context.contentLimitsEnabled == context.contentLimitsEnforced, "both NO");

    if (failures) { printf("playablecontent: %d RED\n", failures); return 1; }
    printf("playablecontent: OK (0 failures)\n");
    return 0;
}
