#import "RevenantPhotosImageCache.h"

@interface RevenantPhotosImageCacheEntry : NSObject

@property (nonatomic, strong) id object;
@property (nonatomic) NSUInteger cost;
@property (nonatomic) uint64_t access;

@end

@implementation RevenantPhotosImageCacheEntry
@synthesize object = _object;
@synthesize cost = _cost;
@synthesize access = _access;
@end

@implementation RevenantPhotosImageCache {
    NSUInteger _capacity;
    NSMutableDictionary *_entries;
    uint64_t _access;
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

- (id)objectForKey:(id<NSCopying>)key
{
    @synchronized (self) {
        RevenantPhotosImageCacheEntry *entry = _entries[key];
        if (!entry)
            return nil;
        entry.access = ++_access;
        return entry.object;
    }
}

- (void)removeObjectForKey:(id<NSCopying>)key
{
    @synchronized (self) {
        RevenantPhotosImageCacheEntry *entry = _entries[key];
        if (!entry)
            return;
        _totalCost -= entry.cost;
        [_entries removeObjectForKey:key];
    }
}

- (void)setObject:(id)object forKey:(id<NSCopying>)key cost:(NSUInteger)cost
{
    @synchronized (self) {
        [self removeObjectForKey:key];
        if (!object || cost == 0 || cost > _capacity)
            return;
        while (_totalCost > _capacity - cost) {
            id oldestKey = nil;
            uint64_t oldestAccess = UINT64_MAX;
            for (id candidate in _entries) {
                RevenantPhotosImageCacheEntry *entry = _entries[candidate];
                if (entry.access < oldestAccess) {
                    oldestAccess = entry.access;
                    oldestKey = candidate;
                }
            }
            if (!oldestKey)
                break;
            [self removeObjectForKey:oldestKey];
        }
        RevenantPhotosImageCacheEntry *entry = [[RevenantPhotosImageCacheEntry alloc] init];
        entry.object = object;
        entry.cost = cost;
        entry.access = ++_access;
        _entries[key] = entry;
        _totalCost += cost;
    }
}

- (void)removeAllObjects
{
    @synchronized (self) {
        [_entries removeAllObjects];
        _totalCost = 0;
    }
}

@end
