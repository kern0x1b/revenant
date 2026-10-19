#import <Foundation/Foundation.h>
#import <objc/message.h>
#import "check.h"

static NSString *listing(NSString *path)
{
    NSMutableArray *names = [NSMutableArray array];
    for (NSString *name in [[NSFileManager defaultManager] enumeratorAtPath:path])
        [names addObject:name];
    return [[names sortedArrayUsingSelector:@selector(compare:)] componentsJoinedByString:@","];
}

static NSString *run(BOOL port, NSString *directory)
{
    NSFileManager *manager = [NSFileManager defaultManager];
    [manager removeItemAtPath:directory error:NULL];
    NSURL *URL = [NSURL fileURLWithPath:directory isDirectory:YES];
    NSURLCache *cache = port ? ((id (*)(id, SEL, NSUInteger, NSUInteger, id))objc_msgSend)([NSURLCache alloc], NSSelectorFromString(@"initWithMemoryCapacity:diskCapacity:directoryURL:"), 1 << 20, 10 << 20, URL)
                             : [[NSURLCache alloc] initWithMemoryCapacity:1 << 20 diskCapacity:10 << 20 directoryURL:URL];
    NSMutableString *log = [NSMutableString stringWithFormat:@"mem %lu disk %lu", (unsigned long)cache.memoryCapacity, (unsigned long)cache.diskCapacity];
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:@"http://example.com/a"]];
    NSURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:request.URL statusCode:200 HTTPVersion:@"HTTP/1.1" headerFields:@{@"Cache-Control": @"max-age=100"}];
    NSCachedURLResponse *stored = [[NSCachedURLResponse alloc] initWithResponse:response data:[@"hello" dataUsingEncoding:NSUTF8StringEncoding] userInfo:nil storagePolicy:NSURLCacheStorageAllowed];
    [cache storeCachedResponse:stored forRequest:request];
    [NSThread sleepForTimeInterval:0.6];
    NSString *hosted = [[directory.stringByDeletingLastPathComponent stringByAppendingPathComponent:[[NSProcessInfo processInfo] processName]] stringByAppendingPathComponent:directory.lastPathComponent];
    [log appendFormat:@" | %@ | used %d", [[listing(directory) stringByAppendingString:listing(hosted)] containsString:@"Cache.db"] ? @"Cache.db" : @"nothing", cache.currentDiskUsage > 0];
    NSURLCache *again = port ? ((id (*)(id, SEL, NSUInteger, NSUInteger, id))objc_msgSend)([NSURLCache alloc], NSSelectorFromString(@"initWithMemoryCapacity:diskCapacity:directoryURL:"), 0, 10 << 20, URL)
                             : [[NSURLCache alloc] initWithMemoryCapacity:0 diskCapacity:10 << 20 directoryURL:URL];
    [log appendFormat:@" | again %@", [[NSString alloc] initWithData:[again cachedResponseForRequest:request].data ?: [NSData data] encoding:NSUTF8StringEncoding]];
    [manager removeItemAtPath:directory error:NULL];
    [manager removeItemAtPath:hosted error:NULL];
    return log;
}

int main(void)
{
    @autoreleasepool {
        NSString *directory = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).firstObject stringByAppendingPathComponent:@"f14-cache"];
        NSString *a = run(YES, directory), *b = run(NO, directory);
        CHECK_EQUAL(a, b, "a cache kept in a directory stores there and is read back as the system's is");
        NSURLCache *nothing = ((id (*)(id, SEL, NSUInteger, NSUInteger, id))objc_msgSend)([NSURLCache alloc], NSSelectorFromString(@"initWithMemoryCapacity:diskCapacity:directoryURL:"), 4096, 8192, nil);
        NSURLCache *theirs = [[NSURLCache alloc] initWithMemoryCapacity:4096 diskCapacity:8192 directoryURL:nil];
        CHECK(nothing.memoryCapacity == theirs.memoryCapacity && nothing.diskCapacity == theirs.diskCapacity, "no directory keeps the capacities and the default place");
    }
    printf("checks=%d failures=%d\n", charon_checks, charon_failures);
    return charon_failures;
}
