#import <Foundation/Foundation.h>

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

extern NSString *const MPErrorDomain;
enum { MPErrorUnknown = 0 };

#include "MPMusicPlayerQueueDescriptor101.m"
#include "MPMusicPlayerControllerQueueDescriptor101.m"
#include "MPMusicPlayerApplicationController103.m"
#include "MPMusicPlayerPlayParameters11.m"

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
- (id)copyWithZone:(NSZone *)zone { return self; }
@end

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

    @try { [[MPMusicPlayerQueueDescriptor alloc] init]; check("the abstract base refuses -init", 0, "no raise"); }
    @catch (NSException *e) { check("the abstract base refuses -init", 1, "raised"); }
    MPMusicPlayerMediaItemQueueDescriptor *mq = [[MPMusicPlayerMediaItemQueueDescriptor alloc] initWithQuery:query];
    check("a media-item descriptor builds through the named base initializer", mq != nil, "built");
    MPMusicPlayerMediaItemQueueDescriptor *mc =
        [[MPMusicPlayerMediaItemQueueDescriptor alloc] initWithItemCollection:coll];
    check("and the collection spelling builds too", mc.itemCollection == coll, "the collection");

    MPMusicPlayerController *player = [[MPMusicPlayerController alloc] init];
    [player setQueueWithDescriptor:mq];
    check("a query descriptor calls the RELEASE's -setQueueWithQuery:",
          [[player charonTakeLastReleaseCall] isEqualToString:@"setQueueWithQuery:"], "setQueueWithQuery:");
    [player setQueueWithDescriptor:mc];
    check("a collection descriptor calls the RELEASE's -setQueueWithItemCollection:",
          [[player charonTakeLastReleaseCall] isEqualToString:@"setQueueWithItemCollection:"], "setQueueWithItemCollection:");
    MPMusicPlayerStoreQueueDescriptor *store =
        [[MPMusicPlayerStoreQueueDescriptor alloc] initWithStoreIDs:@[ @"1", @"2" ]];
    [player setQueueWithDescriptor:store];
    check("a Store descriptor calls NOTHING: the release has no setter taking a Store ID",
          [player charonTakeLastReleaseCall] == nil, "no call");
    [player appendQueueDescriptor:mq]; [player prependQueueDescriptor:mq];
    check("append/prepend call nothing: every release setter REPLACES a queue",
          [player charonTakeLastReleaseCall] == nil, "no call");

    MPSystemMusicPlayerController *sys = [[MPSystemMusicPlayerController alloc] init];
    __block int calls = 0; __block NSError *seen = nil;
    [sys openToPlayQueueDescriptor:mq completionHandler:^(NSError *e) { calls++; seen = e; }];
    check("-openToPlayQueueDescriptor: calls its handler exactly once", calls == 1, "1");
    __block int second = 0;
    [sys openToPlayQueueDescriptor:store completionHandler:^(NSError *e) { second++; }];
    check("and a second call answers its own handler once, not zero and not twice", second == 1, "1");
    check("and the error is in Apple's own MPErrorDomain, not a spelled string",
          [seen.domain isEqualToString:MPErrorDomain], "MPErrorDomain");
    [sys openToPlayQueueDescriptor:mq completionHandler:nil];
    check("a nil handler is survived rather than crashed on", 1, "returned");

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
    [app performQueueTransaction:^(MPMusicPlayerControllerMutableQueue *q) { [q insertQueueDescriptor:store afterItem:nil]; }
               completionHandler:^(MPMusicPlayerControllerQueue *q, NSError *e) { gotItems = q.items; }];
    check("a Store descriptor inserts nothing, and the queue is unchanged", gotItems.count == 2, "still 2");
    [app performQueueTransaction:^(MPMusicPlayerControllerMutableQueue *q) { [q removeItem:a]; }
               completionHandler:^(MPMusicPlayerControllerQueue *q, NSError *e) { gotItems = q.items; }];
    check("-removeItem: removes exactly the item it names", gotItems.count == 1, "1");
    MPMediaItem *stranger = [[MPMediaItem alloc] initWithCharonID:999];
    [app performQueueTransaction:^(MPMusicPlayerControllerMutableQueue *q) { [q removeItem:stranger]; }
               completionHandler:^(MPMusicPlayerControllerQueue *q, NSError *e) { gotItems = q.items; }];
    check("-removeItem: of an item the queue does not hold leaves it unchanged",
          gotItems.count == 1 && gotItems[0] == b, "still the one item it had");

    MPMusicPlayerPlayParameters *pp = [[MPMusicPlayerPlayParameters alloc] initWithDictionary:@{@"rate": @1.0}];
    check("a play-parameters object holds the dictionary it was built from", pp.dictionary[@"rate"] != nil, "rate");
    check("the header types the initializer nullable and nil is honoured",
          [[MPMusicPlayerPlayParameters alloc] initWithDictionary:nil] == nil, "nil for nil");
    MPMusicPlayerPlayParametersQueueDescriptor *pq =
        [[MPMusicPlayerPlayParametersQueueDescriptor alloc] initWithPlayParametersQueue:@[pp]];
    [pq setStartTime:12.0 forItemWithPlayParameters:pp];
    MPMusicPlayerPlayParameters *other = [[MPMusicPlayerPlayParameters alloc] initWithDictionary:@{@"rate": @2.0}];
    [pq setEndTime:99.0 forItemWithPlayParameters:other];
    check("a queue descriptor holds the play parameters it was built with", pq.playParametersQueue.count == 1, "1");

    if (failures) { printf("queuedescriptor: %d RED\n", failures); return 1; }
    printf("queuedescriptor: OK (0 failures)\n");
    return 0;
}
