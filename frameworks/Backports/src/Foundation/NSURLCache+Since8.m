#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <sqlite3.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

void revenant_cache_remove_since(NSURLCache *cache, NSString *database, NSDate *date);

void revenant_cache_remove_since(NSURLCache *cache, NSString *database, NSDate *date)
{
    sqlite3 *handle = NULL;
    NSMutableArray *keys = [NSMutableArray array];
    if (sqlite3_open_v2(database.fileSystemRepresentation, &handle, SQLITE_OPEN_READONLY, NULL) == SQLITE_OK) {
        sqlite3_busy_timeout(handle, 1000);
        sqlite3_stmt *statement = NULL;
        if (sqlite3_prepare_v2(handle, "SELECT request_key FROM cfurl_cache_response WHERE time_stamp >= datetime(?, 'unixepoch')", -1, &statement, NULL) == SQLITE_OK) {
            sqlite3_bind_double(statement, 1, date.timeIntervalSince1970);
            while (sqlite3_step(statement) == SQLITE_ROW) {
                const unsigned char *key = sqlite3_column_text(statement, 0);
                NSURL *url = key ? [NSURL URLWithString:[NSString stringWithUTF8String:(const char *)key]] : nil;
                if (url)
                    [keys addObject:url];
            }
        }
        sqlite3_finalize(statement);
    }
    sqlite3_close(handle);
    for (NSURL *url in keys)
        [cache removeCachedResponseForRequest:[NSURLRequest requestWithURL:url]];
}

static NSString *revenant_cache_database(NSURLCache *cache)
{
    NSString *caches = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).firstObject;
    SEL selector = NSSelectorFromString(@"_cacheDirectory");
    id directory = [cache respondsToSelector:selector] ? ((id (*)(id, SEL))objc_msgSend)(cache, selector) : nil;
    if ([directory isKindOfClass:[NSURL class]])
        directory = [directory path];
    if (![directory isKindOfClass:[NSString class]] || ![directory length])
        directory = [caches stringByAppendingPathComponent:[[NSBundle mainBundle] bundleIdentifier] ?: [[NSProcessInfo processInfo] processName]];
    else if (![directory isAbsolutePath])
        directory = [caches stringByAppendingPathComponent:directory];
    return [directory stringByAppendingPathComponent:@"Cache.db"];
}

@implementation NSURLCache (RevenantSince8)

- (void)removeCachedResponsesSinceDate:(NSDate *)date
{
    revenant_cache_remove_since(self, revenant_cache_database(self), date);
}

@end
