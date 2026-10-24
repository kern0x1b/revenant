#import "../Foundation/check.h"
#import "RevenantPhotosImageCache.h"

int main(int argc, char **argv)
{
    revenant_read_arguments(argc, argv);
    RevenantPhotosImageCache *cache = [[RevenantPhotosImageCache alloc] initWithCapacity:100];
    NSObject *old = [[NSObject alloc] init];
    NSObject *recent = [[NSObject alloc] init];
    NSObject *newest = [[NSObject alloc] init];
    [cache setObject:old forKey:@"old" cost:40];
    [cache setObject:recent forKey:@"recent" cost:40];
    [cache objectForKey:@"old"];
    [cache setObject:newest forKey:@"newest" cost:40];
    revenant_check([cache objectForKey:@"old"] == (revenant_negative ? nil : old) && [cache objectForKey:@"recent"] == nil && cache.totalCost == 80,
                   "the cache evicts the least recently used object within its byte bound", @"unexpected eviction or cost");
    [cache removeObjectForKey:@"old"];
    revenant_check(cache.totalCost == 40 && [cache objectForKey:@"newest"] == newest, "removing one key returns its cost", @"cost differs");
    [cache removeAllObjects];
    revenant_check(cache.totalCost == 0 && cache.count == 0, "clearing the cache releases every object", @"cache is not empty");

    NSObject *oversized = [[NSObject alloc] init];
    [cache setObject:oversized forKey:@"oversized" cost:101];
    revenant_check(cache.count == 0 && cache.totalCost == 0, "an object larger than the cache is not kept", @"the cache holds an oversized object");

    NSObject *third = [[NSObject alloc] init];
    NSObject *replacement = [[NSObject alloc] init];
    [cache setObject:old forKey:@"a" cost:30];
    [cache setObject:recent forKey:@"b" cost:30];
    [cache setObject:third forKey:@"c" cost:30];
    [cache setObject:replacement forKey:@"b" cost:50];
    revenant_check(cache.totalCost == 80 && cache.count == 2 && [cache objectForKey:@"a"] == nil && [cache objectForKey:@"b"] == replacement,
                   "replacing a key takes the new cost and evicts from the oldest end", @"replacement accounting differs");
    [cache objectForKey:@"c"];
    NSObject *fourth = [[NSObject alloc] init];
    [cache setObject:fourth forKey:@"d" cost:25];
    revenant_check(cache.totalCost == 55 && [cache objectForKey:@"b"] == nil && [cache objectForKey:@"c"] == third && [cache objectForKey:@"d"] == fourth,
                   "a hit moves the object to the newest end before eviction", @"a hit did not protect the object");
    [cache removeAllObjects];
    return revenant_finish();
}
