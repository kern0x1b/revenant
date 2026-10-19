// The queue-descriptor family: 10.1's three classes, 10.3's three, 11.0's two, and the setters that
// consume a descriptor (facts/MediaPlayer/QueueDescriptors.md).
//
// Compiled against a stand-in whose MPMusicPlayerController RECORDS which release setter it was asked to
// call. That is what makes the central claim checkable at all: without it, "the bridge called the
// release's own method" and "the bridge built a queue of its own" look identical to a caller, and the
// second is the failure this family exists to avoid. The check therefore asserts the release setter's NAME
// for the two descriptors that have one, and asserts that NO setter is called for the ones that do not.
//
// Two of the mutants tried against this file do not turn it RED, and both are recorded in the facts page
// with the reason: -removeItem:'s membership test is a shortcut rather than the correctness of the removal
// (-removeObject: is already a no-op for an absent object), and the double-handler mutation was written
// against this file's own main rather than the port's call site. Neither is left as a claim the check
// cannot support.
#import <Foundation/Foundation.h>

// uint64_t, as BOTH SDKs spell it (MPMediaEntity.h:15 in 16.4 and in 26.2). A first draft of this stand-in
// used the NSNumber * spelling from MPMediaItemStandin.h's comment, which is wrong about the framework,
// and the port's key arithmetic then failed against this build while passing the framework one.
typedef uint64_t MPMediaEntityPersistentID;

@class MPMusicPlayerApplicationController;
@interface MPMediaItem : NSObject
- (MPMediaEntityPersistentID)persistentID;
@end
@interface MPMediaItemCollection : NSObject
- (NSArray<MPMediaItem *> *)items;
@end
@interface MPMediaQuery : NSObject
- (NSArray<MPMediaItem *> *)items;
@end

@interface MPMusicPlayerQueueDescriptor : NSObject
@end
@interface MPMusicPlayerMediaItemQueueDescriptor : MPMusicPlayerQueueDescriptor
- (instancetype)initWithQuery:(MPMediaQuery *)query;
- (instancetype)initWithItemCollection:(MPMediaItemCollection *)itemCollection;
@property (nonatomic, readonly, copy) MPMediaQuery *query;
@property (nonatomic, readonly, strong) MPMediaItemCollection *itemCollection;
@property (nonatomic, nullable, strong) MPMediaItem *startItem;
- (void)setStartTime:(NSTimeInterval)startTime forItem:(MPMediaItem *)mediaItem;
- (void)setEndTime:(NSTimeInterval)endTime forItem:(MPMediaItem *)mediaItem;
@end
@interface MPMusicPlayerStoreQueueDescriptor : MPMusicPlayerQueueDescriptor
- (instancetype)initWithStoreIDs:(NSArray<NSString *> *)storeIDs;
@property (nonatomic, nullable, copy) NSArray<NSString *> *storeIDs;
@property (nonatomic, nullable, copy) NSString *startItemID;
- (void)setStartTime:(NSTimeInterval)startTime forItemWithStoreID:(NSString *)storeID;
- (void)setEndTime:(NSTimeInterval)endTime forItemWithStoreID:(NSString *)storeID;
@end
@interface MPMusicPlayerPlayParameters : NSObject
- (nullable instancetype)initWithDictionary:(NSDictionary<NSString *, id> *)dictionary;
@property (nonatomic, readonly, copy) NSDictionary<NSString *, id> *dictionary;
@end
@interface MPMusicPlayerPlayParametersQueueDescriptor : MPMusicPlayerQueueDescriptor
- (instancetype)initWithPlayParametersQueue:(NSArray<MPMusicPlayerPlayParameters *> *)playParametersQueue;
@property (nonatomic, copy) NSArray<MPMusicPlayerPlayParameters *> *playParametersQueue;
@property (nonatomic, nullable, strong) MPMusicPlayerPlayParameters *startItemPlayParameters;
- (void)setStartTime:(NSTimeInterval)startTime forItemWithPlayParameters:(MPMusicPlayerPlayParameters *)playParameters;
@end

@interface MPMusicPlayerController : NSObject
@property (class, nonatomic, readonly) MPMusicPlayerApplicationController *applicationQueuePlayer;
- (void)setQueueWithQuery:(MPMediaQuery *)query;
- (void)setQueueWithItemCollection:(MPMediaItemCollection *)itemCollection;
- (void)setQueueWithDescriptor:(MPMusicPlayerQueueDescriptor *)descriptor;
- (void)appendQueueDescriptor:(MPMusicPlayerQueueDescriptor *)descriptor;
- (void)prependQueueDescriptor:(MPMusicPlayerQueueDescriptor *)descriptor;
@end
@interface MPMusicPlayerControllerQueue : NSObject
@property (nonatomic, copy, readonly) NSArray<MPMediaItem *> *items;
@end
@interface MPMusicPlayerControllerMutableQueue : MPMusicPlayerControllerQueue
- (void)insertQueueDescriptor:(MPMusicPlayerQueueDescriptor *)queueDescriptor afterItem:(MPMediaItem *)afterItem;
- (void)removeItem:(MPMediaItem *)item;
@end
@interface MPMusicPlayerApplicationController : MPMusicPlayerController
- (void)performQueueTransaction:(void (^)(MPMusicPlayerControllerMutableQueue *))t
             completionHandler:(void (^)(MPMusicPlayerControllerQueue *, NSError *))h;
@end
// MPSystemMusicPlayerController is NOT declared here: the port's own object declares it, because no SDK
// header does (measured: no @interface for it in 16.4 or in 26.2). A first draft of this check declared it
// and clang rejected the pair with "duplicate interface definition for class
// 'MPSystemMusicPlayerController'", which is the check measuring itself.

extern NSString *const MPErrorDomain;
// MPErrorUnknown is Apple's own enum case, MPError.h:17, spelled here as the header spells it.
enum { MPErrorUnknown = 0 };

#include "MPMusicPlayerQueueDescriptor101.m"
#include "MPMusicPlayerControllerQueueDescriptor101.m"
#include "MPMusicPlayerApplicationController103.m"
#include "MPMusicPlayerPlayParameters11.m"

// The stand-in MPMediaItem, with the persistent ID the descriptor keys its windows by.
@implementation MPMediaItem
{ MPMediaEntityPersistentID _pid; }
- (instancetype)initWithCharonID:(MPMediaEntityPersistentID)pid { self = [super init]; if (self) { _pid = pid; } return self; }
- (MPMediaEntityPersistentID)persistentID { return _pid; }
@end
@implementation MPMediaItemCollection
{ NSArray *_items; }
- (instancetype)initWithCharonItems:(NSArray *)items { self = [super init]; if (self) { _items = items; } return self; }
- (NSArray<MPMediaItem *> *)items { return _items; }
@end
@implementation MPMediaQuery
{ NSArray *_items; }
- (instancetype)initWithCharonItems:(NSArray *)items { self = [super init]; if (self) { _items = items; } return self; }
- (NSArray<MPMediaItem *> *)items { return _items; }
// Needed because the header declares `query` @property(copy), so -initWithQuery: copies. A stand-in
// without this throws NSInvalidArgumentException from inside Foundation and the run aborts before any
// check prints, which is a check that measures nothing.
- (id)copyWithZone:(NSZone *)zone { return self; }
@end

// The stand-in controller records which RELEASE setter it was asked to call, so the checks can assert
// the bridge used the release's own method rather than fabricating a queue.
@implementation MPMusicPlayerController
{ NSString *_charonLastReleaseCall; MPMediaQuery *_charonSetQuery; MPMediaItemCollection *_charonSetCollection; }
+ (NSString *)charonLastReleaseCall { static NSString *v; return v; }
+ (void)charonSetLastReleaseCall:(NSString *)v { }
- (NSString *)charonTakeLastReleaseCall { NSString *v = _charonLastReleaseCall; _charonLastReleaseCall = nil; return v; }
- (void)charonRecord:(NSString *)what { _charonLastReleaseCall = what; }
- (void)setQueueWithQuery:(MPMediaQuery *)query { [self charonRecord:@"setQueueWithQuery:"]; _charonSetQuery = query; }
- (void)setQueueWithItemCollection:(MPMediaItemCollection *)c { [self charonRecord:@"setQueueWithItemCollection:"]; _charonSetCollection = c; }
@end
NSString *const MPErrorDomain = @"MPErrorDomain";

static int failures = 0;
static void check(const char *what, int held, const char *got) {
    if (held) { printf("  ok   %s: %s\n", what, got); }
    else { printf("  RED  %s: %s\n", what, got); failures++; }
}

int main(void) {
    MPMediaItem *a = [[MPMediaItem alloc] initWithCharonID:11];
    MPMediaItem *b = [[MPMediaItem alloc] initWithCharonID:22];
    MPMediaItemCollection *coll = [[MPMediaItemCollection alloc] initWithCharonItems:@[a, b]];
    MPMediaQuery *query = [[MPMediaQuery alloc] initWithCharonItems:@[a]];

    // The abstract base refuses, by class, and both concrete subclasses still build.
    @try { [[MPMusicPlayerQueueDescriptor alloc] init]; check("the abstract base refuses -init", 0, "no raise"); }
    @catch (NSException *e) { check("the abstract base refuses -init", 1, "raised"); }
    MPMusicPlayerMediaItemQueueDescriptor *mq = [[MPMusicPlayerMediaItemQueueDescriptor alloc] initWithQuery:query];
    check("a media-item descriptor builds through the named base initializer", mq != nil, "built");
    MPMusicPlayerMediaItemQueueDescriptor *mc =
        [[MPMusicPlayerMediaItemQueueDescriptor alloc] initWithItemCollection:coll];
    check("and the collection spelling builds too", mc.itemCollection == coll, "the collection");

    // THE central claim: the descriptor resolves onto a setter the release owns.
    MPMusicPlayerController *player = [[MPMusicPlayerController alloc] init];
    [player setQueueWithDescriptor:mq];
    check("a query descriptor calls the RELEASE's -setQueueWithQuery:",
          [[player charonTakeLastReleaseCall] isEqualToString:@"setQueueWithQuery:"], "setQueueWithQuery:");
    [player setQueueWithDescriptor:mc];
    check("a collection descriptor calls the RELEASE's -setQueueWithItemCollection:",
          [[player charonTakeLastReleaseCall] isEqualToString:@"setQueueWithItemCollection:"], "setQueueWithItemCollection:");
    // The Store descriptor has no setter on either held end, so nothing is called and nothing is faked.
    MPMusicPlayerStoreQueueDescriptor *store =
        [[MPMusicPlayerStoreQueueDescriptor alloc] initWithStoreIDs:@[ @"1", @"2" ]];
    [player setQueueWithDescriptor:store];
    check("a Store descriptor calls NOTHING: the release has no setter taking a Store ID",
          [player charonTakeLastReleaseCall] == nil, "no call");
    [player appendQueueDescriptor:mq]; [player prependQueueDescriptor:mq];
    check("append/prepend call nothing: every release setter REPLACES a queue",
          [player charonTakeLastReleaseCall] == nil, "no call");

    // MPSystemMusicPlayerController answers its 11.0 callback exactly once, with the truth.
    MPSystemMusicPlayerController *sys = [[MPSystemMusicPlayerController alloc] init];
    __block int calls = 0; __block NSError *seen = nil;
    [sys openToPlayQueueDescriptor:mq completionHandler:^(NSError *e) { calls++; seen = e; }];
    check("-openToPlayQueueDescriptor: calls its handler exactly once", calls == 1, "1");
    // And a second descriptor does not accumulate: one call in, one call out.
    __block int second = 0;
    [sys openToPlayQueueDescriptor:store completionHandler:^(NSError *e) { second++; }];
    check("and a second call answers its own handler once, not zero and not twice", second == 1, "1");
    check("and the error is in Apple's own MPErrorDomain, not a spelled string",
          [seen.domain isEqualToString:MPErrorDomain], "MPErrorDomain");
    [sys openToPlayQueueDescriptor:mq completionHandler:nil];
    check("a nil handler is survived rather than crashed on", 1, "returned");

    // The 10.3 transaction: the block runs FIRST, the handler is given what the block produced.
    MPMusicPlayerApplicationController *app = [MPMusicPlayerController applicationQueuePlayer];
    check("+applicationQueuePlayer is one shared instance, like +applicationMusicPlayer",
          app == [MPMusicPlayerController applicationQueuePlayer], "same object");
    __block int blockRanBeforeHandler = 0; __block NSArray *gotItems = nil;
    [app performQueueTransaction:^(MPMusicPlayerControllerMutableQueue *q) {
        [q insertQueueDescriptor:mc afterItem:nil];
        blockRanBeforeHandler = 1;
    } completionHandler:^(MPMusicPlayerControllerQueue *q, NSError *e) {
        blockRanBeforeHandler = (blockRanBeforeHandler == 1) ? 2 : 0;
        gotItems = q.items;
    }];
    check("the block ran before the handler, in the order the header specifies", blockRanBeforeHandler == 2, "block then handler");
    check("the handler is given the queue the block produced", gotItems.count == 2, "2 items");
    // A Store descriptor inserts nothing rather than appearing to succeed.
    [app performQueueTransaction:^(MPMusicPlayerControllerMutableQueue *q) { [q insertQueueDescriptor:store afterItem:nil]; }
               completionHandler:^(MPMusicPlayerControllerQueue *q, NSError *e) { gotItems = q.items; }];
    check("a Store descriptor inserts nothing, and the queue is unchanged", gotItems.count == 2, "still 2");
    [app performQueueTransaction:^(MPMusicPlayerControllerMutableQueue *q) { [q removeItem:a]; }
               completionHandler:^(MPMusicPlayerControllerQueue *q, NSError *e) { gotItems = q.items; }];
    check("-removeItem: removes exactly the item it names", gotItems.count == 1, "1");
    // An item the queue does NOT hold. This is the case that exercises the membership test: a first draft
    // of this check only ever removed an item that WAS present, and a mutant that removed unconditionally
    // then passed - measured, 0 RED. Removing a stranger must leave the queue exactly as it was.
    MPMediaItem *stranger = [[MPMediaItem alloc] initWithCharonID:999];
    [app performQueueTransaction:^(MPMusicPlayerControllerMutableQueue *q) { [q removeItem:stranger]; }
               completionHandler:^(MPMusicPlayerControllerQueue *q, NSError *e) { gotItems = q.items; }];
    check("-removeItem: of an item the queue does not hold leaves it unchanged",
          gotItems.count == 1 && gotItems[0] == b, "still the one item it had");

    // The 11.0 play parameters: a nullable initializer, and a window keyed by the entry's index.
    MPMusicPlayerPlayParameters *pp = [[MPMusicPlayerPlayParameters alloc] initWithDictionary:@{@"rate": @1.0}];
    check("a play-parameters object holds the dictionary it was built from", pp.dictionary[@"rate"] != nil, "rate");
    check("the header types the initializer nullable and nil is honoured",
          [[MPMusicPlayerPlayParameters alloc] initWithDictionary:nil] == nil, "nil for nil");
    MPMusicPlayerPlayParametersQueueDescriptor *pq =
        [[MPMusicPlayerPlayParametersQueueDescriptor alloc] initWithPlayParametersQueue:@[pp]];
    [pq setStartTime:12.0 forItemWithPlayParameters:pp];
    MPMusicPlayerPlayParameters *other = [[MPMusicPlayerPlayParameters alloc] initWithDictionary:@{@"rate": @2.0}];
    [pq setEndTime:99.0 forItemWithPlayParameters:other];   // not in the queue: declined
    check("a queue descriptor holds the play parameters it was built with", pq.playParametersQueue.count == 1, "1");

    if (failures) { printf("queuedescriptor: %d RED\n", failures); return 1; }
    printf("queuedescriptor: OK (0 failures)\n");
    return 0;
}
