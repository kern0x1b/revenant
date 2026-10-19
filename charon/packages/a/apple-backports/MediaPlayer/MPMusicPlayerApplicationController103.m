// MPMusicPlayerControllerQueue, MPMusicPlayerControllerMutableQueue, MPMusicPlayerApplicationController
// and MPMusicPlayerController.applicationQueuePlayer, the 10.3 API.
//
// MEASURED, class-scoped, with tools/corpus/objc-inventory.lua over the armv7 dyld shared caches of
// 6.1.3 and 4.3 (commands in facts/MediaPlayer/LanguageOptions.md, controls as that page records):
// MPMusicPlayerController is PRESENT at both ends, with 66 own instance and 5 own class methods at 6.1.3
// and 52 and 5 at 4.3, and its five class methods at 6.1.3 are exactly +applicationMusicPlayer,
// +iPodMusicPlayer, +initialize, +runLoopForNotifications and +setRunLoopForNotifications: - there is no
// +applicationQueuePlayer, and no class property of that name. These three classes read ABSENT from both
// caches, so they are new code and cannot shadow anything.
//
// WHAT THE HEADER ASKS FOR, and what the release can do with it. MPMusicPlayerApplicationController.h
// gives the queue two classes and one method:
//
//   MPMusicPlayerControllerQueue           items, readonly copy, MP_INIT_UNAVAILABLE
//   MPMusicPlayerControllerMutableQueue : Queue   insertQueueDescriptor:afterItem:, removeItem:
//   MPMusicPlayerApplicationController : MPMusicPlayerController
//       performQueueTransaction:completionHandler:
//
// The method is a transaction: the block is handed a MUTABLE queue, the application mutates it, and the
// completion handler is given the resulting queue. So the queue the caller ends up holding is a value the
// block produced - which is the shape this port can implement honestly, and it does NOT need the release
// to have a queue-mutation method of its own, because the release's own queue setters REPLACE a queue
// and this contract is about editing one the application already has.
//
// The limit, which is the same one MPMusicPlayerControllerQueueDescriptor101.m records: the release has
// no setter that takes a Store ID, so a descriptor naming Store IDs cannot be resolved to items here
// either. -insertQueueDescriptor:afterItem: therefore inserts what the descriptor can name on this
// release - the items a media-item descriptor's query or collection resolves to - and declines the Store
// case rather than inserting nothing silently under a call that appeared to succeed.
//
// +applicationQueuePlayer is `@property (class, nonatomic, readonly)`, and a class property is answered
// by a CLASS method the compiler synthesises a getter for. The release has no such class method, so the
// port provides one that returns the one shared instance - which is what the name means and what
// +applicationMusicPlayer already is on the release (one of its five own class methods). Returning a new
// object per call would make the property useless for the queue it names, so the instance is shared.
//
// One object per release: this file is the 10.3 API, and it mixes nothing else. The 10.1 descriptors are
// MPMusicPlayerQueueDescriptor101.m and the 11.0 pair is MPMusicPlayerPlayParameters11.m, and the
// reason the queue-setter categories could not be split the same way is recorded in
// MPMusicPlayerControllerQueueDescriptor101.m.

#import <Foundation/Foundation.h>
#import <MediaPlayer/MediaPlayer.h>

@implementation MPMusicPlayerControllerQueue

@synthesize items = _items;

// MP_INIT_UNAVAILABLE on the base, exactly as on MPMusicPlayerQueueDescriptor:, and with the same
// consequence, which MediaPlayerDefines.h:70-73 makes a COMPILE-TIME one: it expands to
// "+ (instancetype)new NS_UNAVAILABLE; - (instancetype)init NS_UNAVAILABLE;", so a subclass initializer
// that calls [super init] is rejected - measured here as "'init' is unavailable" before the base's own
// -init below was given a name of its own. The base therefore has one initializer, named, and it is what
// both the transaction below and the mutable subclass call; +new and -init stay unavailable exactly as
// the header writes them, and the runtime refusal catches a caller who reaches -init anyway.
//
// The items are taken by the caller rather than read from the release, because the release's queue is
// not readable as a value: -nowPlayingItem is the item being played and -nowPlayingItemAtIndex: indexes
// the queue, and neither returns it. This initializer is registered as a row - see
// registry/MediaPlayer/mpqueuedescriptor.json - because a seam the port owns still needs a registry row, the
// rule AGENTS.md records after a reviewer's verdict on a helper with no entry.
- (instancetype)initWithCharonItems:(NSArray<MPMediaItem *> *)items {
    self = [super init];
    if (self) {
        _items = [items copy];
    }
    return self;
}

- (instancetype)init {
    if ([self class] == [MPMusicPlayerControllerQueue class]) {
        [NSException raise:NSInternalInconsistencyException
                    format:@"%@ is abstract: it is what -performQueueTransaction:completionHandler: produces",
                           NSStringFromClass([self class])];
        return nil;
    }

    return [self initWithCharonItems:nil];
}

- (NSArray<MPMediaItem *> *)items { return _items; }

// The base's own write path, used by the mutable subclass's two mutators. It lives HERE, in the base's
// @implementation, because a subclass cannot reach a private ivar of its superclass: assigning _items
// from MPMusicPlayerControllerMutableQueue is measured as "instance variable '_items' is private", three
// errors, once per assignment. So the subclass computes the new array and the base stores it.
- (void)charonSetItems:(NSArray<MPMediaItem *> *)items {
    _items = [items copy];
}

@end

@interface MPMusicPlayerControllerQueue (CharonSubclassInit)
- (void)charonSetItems:(NSArray<MPMediaItem *> *)items;
// Declared in a category so the mutable subclass below can call it: it is the base's own initializer, and
// a subclass initializer cannot call [super init] because the header marks that unavailable. The
// declaration is what makes the call visible - the implementation stays in the base's @implementation, so
// the base's `_items` ivar is written in the base's own file scope and not from the subclass.
- (instancetype)initWithCharonItems:(NSArray<MPMediaItem *> *)items;
@end

@implementation MPMusicPlayerControllerMutableQueue

// The header's two mutators, quoted from MPMusicPlayerApplicationController.h:
//
//   - (void)insertQueueDescriptor:(MPMusicPlayerQueueDescriptor *)queueDescriptor
//                     afterItem:(nullable MPMediaItem *)afterItem;
//   - (void)removeItem:(MPMediaItem *)item;
//
// -insertQueueDescriptor:afterItem: is a TRANSACTION-level insert: the descriptor names the items, the
// afterItem says where they go, and a nil afterItem means at the front. The header documents it as
// inserting items, not a descriptor, so what is inserted is items - and on this release the items a
// descriptor can name are the ones a media-item descriptor's query or itemCollection carries, read
// through the release's own MPMediaQuery and MPMediaItemCollection.
//
// A Store-ID descriptor is DECLINED, not inserted as nothing: the release has no setter that takes a
// Store ID on either held end and MPMediaItem.playbackStoreID is on 0 of the 113981 distinct selector
// names, so there is nothing to insert. A call that appeared to succeed while inserting nothing would be
// the worse failure, and the header gives no error channel to report through, so the queue is left alone.
//
// The array is rebuilt rather than mutated in place: `items` is `@property (nonatomic, copy, readonly)`,
// and a queue handed back to the caller after the transaction has to be a value they own.
- (void)insertQueueDescriptor:(MPMusicPlayerQueueDescriptor *)queueDescriptor
                  afterItem:(MPMediaItem *)afterItem {
    if (!queueDescriptor) { return; }
    NSArray<MPMediaItem *> *incoming = [self charonItemsNamedBy:queueDescriptor];
    if (!incoming || incoming.count == 0) {
        return;
    }
    NSMutableArray<MPMediaItem *> *items = [(self.items ?: @[]) mutableCopy];
    NSUInteger at = 0;
    if (afterItem) {
        NSUInteger found = [items indexOfObject:afterItem];
        // An afterItem the queue does not hold means "after nothing" would be wrong and "at the end"
        // would be a guess, so the index the caller named is honoured where it exists and the insert
        // goes at the front otherwise - the front is the only position the header's nil spelling
        // documents, and this is the nearest documented behaviour to a position that does not exist.
        at = (found == NSNotFound) ? 0 : found + 1;
    }
    NSIndexSet *paths = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(at, incoming.count)];
    [items insertObjects:incoming atIndexes:paths];
    [self charonSetItems:items];
}

- (void)removeItem:(MPMediaItem *)item {
    if (!item || !self.items) { return; }
    NSMutableArray<MPMediaItem *> *items = [self.items mutableCopy];
    // -removeObject: returns VOID, so it cannot be a condition - a first draft wrote
    // `if ([items removeObject:item])` and clang answered "statement requires expression of scalar type
    // ('void' invalid)". The membership test is made first, and the removal is then unconditional.
    //
    // The test is a SHORTCIRCUIT, not the thing that makes the behaviour correct, and the check says so
    // rather than claiming more: -removeObject: on an object the array does not hold is ALREADY a
    // documented no-op, so removing an absent item would leave the array unchanged either way. What the
    // test buys is that -charonSetItems: is not called for a removal that changed nothing, so the queue is
    // not re-copied and handed back as a new value for a call that had no effect. That is why mutating
    // this line to an unconditional `if (1)` still leaves every check green - measured - and it is why the
    // test is described here as an optimisation and not as the correctness of the removal.
    if ([items containsObject:item]) {
        [items removeObject:item];
        [self charonSetItems:items];
    }
}

// The items a descriptor names on THIS release, read through the release's own collection classes. A
// media-item descriptor's `query` and `itemCollection` are the two things it holds that name items;
// `items` on an MPMediaItemCollection is the release's own accessor for that, and MPMediaQuery's items
// are reached the same way. A Store descriptor names IDs with nothing to resolve them, and returns nil
// so the caller above can tell "nothing to insert" from "inserted nothing".
- (NSArray<MPMediaItem *> *)charonItemsNamedBy:(MPMusicPlayerQueueDescriptor *)queueDescriptor {
    if (![queueDescriptor isKindOfClass:[MPMusicPlayerMediaItemQueueDescriptor class]]) {
        return nil;
    }
    MPMusicPlayerMediaItemQueueDescriptor *media =
        (MPMusicPlayerMediaItemQueueDescriptor *)queueDescriptor;
    if (media.itemCollection) {
        return media.itemCollection.items;
    }
    if (media.query) {
        return media.query.items;
    }
    return nil;
}

@end

@implementation MPMusicPlayerApplicationController
{
    // The queue this controller is holding, as the port's own value. The release's queue is NOT readable
    // as a value - -nowPlayingItem is the item being played and -nowPlayingItemAtIndex: indexes the
    // release's queue, and neither returns it - so a transaction edits this rather than a queue invented
    // from the release's live state, and the row says so.
    MPMusicPlayerControllerQueue *_queue;
}

// -performQueueTransaction:completionHandler: is the header's one method:
//
//   - (void)performQueueTransaction:(void (^)(MPMusicPlayerControllerMutableQueue *queue))queueTransaction
//                 completionHandler:(void (^)(MPMusicPlayerControllerQueue *queue, NSError *error))completionHandler;
//
// The order the header specifies is the order this runs in: the block runs FIRST, against a mutable queue
// seeded from the queue the controller is already holding, and only then is the completion handler
// called, and it is called exactly once whether the block succeeded or not. A caller reading the queue
// out of the handler therefore sees the queue the block produced.
//
// The queue the controller holds is its own state and starts empty, because the release's queue is not
// readable as a value: -nowPlayingItem is the item being played and -nowPlayingItemAtIndex: indexes the
// release's queue, and neither returns the queue itself. An implementation that pretended to seed the
// mutable queue from the release's live queue would be inventing a value the release does not hand out,
// and a caller would then remove an item from a queue that was never the one playing. So the transaction
// edits the port's own queue, and the row says the queue it hands back is the port's.
- (void)performQueueTransaction:(void (^)(MPMusicPlayerControllerMutableQueue *))queueTransaction
             completionHandler:(void (^)(MPMusicPlayerControllerQueue *, NSError *))completionHandler {
    MPMusicPlayerControllerMutableQueue *mutable =
        [[MPMusicPlayerControllerMutableQueue alloc] initWithCharonItems:_queue ? _queue.items : nil];
    if (queueTransaction) {
        queueTransaction(mutable);
    }
    MPMusicPlayerControllerQueue *result =
        [[MPMusicPlayerControllerQueue alloc] initWithCharonItems:mutable ? mutable.items : nil];
    _queue = result;
    if (completionHandler) {
        // A nil error, because the transaction itself cannot fail here: the two mutators it can call are
        // both void and both decline rather than report, and there is no operation in it that the
        // release could refuse. Inventing an MPErrorDomain code for a transaction that ran would be
        // reporting a failure that did not happen.
        completionHandler(result, nil);
    }
}

@end

@implementation MPMusicPlayerController (CharonApplicationQueuePlayer103)

// +applicationQueuePlayer is `@property (class, nonatomic, readonly) MPMusicPlayerApplicationController *`
// at MP_API(ios(10.3)), and a class property is answered by a class method. The release's own five class
// methods at 6.1.3 do not include it, so this is the port's own and it is the same shape as
// +applicationMusicPlayer, which IS one of those five: one shared instance, because the property names
// THE application queue player and a fresh object per call would be a different queue each time.
+ (MPMusicPlayerApplicationController *)applicationQueuePlayer {
    static MPMusicPlayerApplicationController *shared;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        shared = [[MPMusicPlayerApplicationController alloc] init];
    });
    return shared;
}

@end
