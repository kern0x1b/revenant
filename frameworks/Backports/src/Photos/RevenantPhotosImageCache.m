#import "RevenantPhotosImageCache.h"

@interface RevenantPhotosImageCacheEntry : NSObject

@property (nonatomic, strong) id<NSCopying> key;
@property (nonatomic, strong) id object;
@property (nonatomic) NSUInteger cost;
@property (nonatomic, assign) RevenantPhotosImageCacheEntry *newer;
@property (nonatomic, assign) RevenantPhotosImageCacheEntry *older;

@end

@implementation RevenantPhotosImageCacheEntry
@synthesize key = _key;
@synthesize object = _object;
@synthesize cost = _cost;
@synthesize newer = _newer;
@synthesize older = _older;
@end

@implementation RevenantPhotosImageCache {
    NSUInteger _capacity;
    NSMutableDictionary *_entries;
    RevenantPhotosImageCacheEntry *_newest;
    RevenantPhotosImageCacheEntry *_oldest;
    NSUInteger _totalCost;
}
@synthesize capacity = _capacity;

- (instancetype)initWithCapacity:(NSUInteger)capacity
{
    self = [super init];
    if (self) {
        _capacity = capacity;
        _entries = [NSMutableDictionary dictionary];
    }
    return self;
}

- (NSUInteger)totalCost
{
    @synchronized (self) {
        return _totalCost;
    }
}

- (NSUInteger)count
{
    @synchronized (self) {
        return _entries.count;
    }
}

- (void)unlink:(RevenantPhotosImageCacheEntry *)entry
{
    if (entry.newer)
        entry.newer.older = entry.older;
    else
        _newest = entry.older;
    if (entry.older)
        entry.older.newer = entry.newer;
    else
        _oldest = entry.newer;
    entry.newer = nil;
    entry.older = nil;
}

- (void)linkNewest:(RevenantPhotosImageCacheEntry *)entry
{
    entry.older = _newest;
    if (_newest)
        _newest.newer = entry;
    else
        _oldest = entry;
    _newest = entry;
}

- (void)removeEntry:(RevenantPhotosImageCacheEntry *)entry
{
    [self unlink:entry];
    _totalCost -= entry.cost;
    [_entries removeObjectForKey:entry.key];
}

- (id)objectForKey:(id<NSCopying>)key
{
    @synchronized (self) {
        RevenantPhotosImageCacheEntry *entry = _entries[key];
        if (!entry)
            return nil;
        if (entry != _newest) {
            [self unlink:entry];
            [self linkNewest:entry];
        }
        return entry.object;
    }
}

- (void)removeObjectForKey:(id<NSCopying>)key
{
    @synchronized (self) {
        RevenantPhotosImageCacheEntry *entry = _entries[key];
        if (entry)
            [self removeEntry:entry];
    }
}

- (void)setObject:(id)object forKey:(id<NSCopying>)key cost:(NSUInteger)cost
{
    @synchronized (self) {
        RevenantPhotosImageCacheEntry *replaced = _entries[key];
        if (replaced)
            [self removeEntry:replaced];
        if (!object || cost == 0 || cost > _capacity)
            return;
        while (_oldest && _totalCost > _capacity - cost)
            [self removeEntry:_oldest];
        RevenantPhotosImageCacheEntry *entry = [[RevenantPhotosImageCacheEntry alloc] init];
        entry.key = key;
        entry.object = object;
        entry.cost = cost;
        _entries[key] = entry;
        _totalCost += cost;
        [self linkNewest:entry];
    }
}

- (void)removeAllObjects
{
    @synchronized (self) {
        [_entries removeAllObjects];
        _newest = nil;
        _oldest = nil;
        _totalCost = 0;
    }
}

@end
