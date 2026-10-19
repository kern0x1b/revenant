#import <Foundation/Foundation.h>
#import <MediaPlayer/MediaPlayer.h>

@implementation MPMusicPlayerControllerQueue

@synthesize items = _items;

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

- (void)charonSetItems:(NSArray<MPMediaItem *> *)items {
    _items = [items copy];
}

@end

@interface MPMusicPlayerControllerQueue (CharonSubclassInit)
- (void)charonSetItems:(NSArray<MPMediaItem *> *)items;
- (instancetype)initWithCharonItems:(NSArray<MPMediaItem *> *)items;
@end

@implementation MPMusicPlayerControllerMutableQueue

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
        at = (found == NSNotFound) ? 0 : found + 1;
    }
    NSIndexSet *paths = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(at, incoming.count)];
    [items insertObjects:incoming atIndexes:paths];
    [self charonSetItems:items];
}

- (void)removeItem:(MPMediaItem *)item {
    if (!item || !self.items) { return; }
    NSMutableArray<MPMediaItem *> *items = [self.items mutableCopy];
    if ([items containsObject:item]) {
        [items removeObject:item];
        [self charonSetItems:items];
    }
}

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
    MPMusicPlayerControllerQueue *_queue;
}

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
        completionHandler(result, nil);
    }
}

@end

@implementation MPMusicPlayerController (CharonApplicationQueuePlayer103)

+ (MPMusicPlayerApplicationController *)applicationQueuePlayer {
    static MPMusicPlayerApplicationController *shared;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        shared = [[MPMusicPlayerApplicationController alloc] init];
    });
    return shared;
}

@end
