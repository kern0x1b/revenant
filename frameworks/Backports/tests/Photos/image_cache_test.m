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
    return revenant_finish();
}
