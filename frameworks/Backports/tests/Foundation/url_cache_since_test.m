#import "check.h"
#import <sqlite3.h>

void revenant_cache_remove_since(NSURLCache *cache, NSString *database, NSDate *date);

static void revenant_store(NSURLCache *cache, NSString *address)
{
    NSURL *url = [NSURL URLWithString:address];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    NSData *body = [@"body" dataUsingEncoding:NSUTF8StringEncoding];
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:url statusCode:200 HTTPVersion:@"HTTP/1.1" headerFields:@{@"Cache-Control": @"max-age=3600", @"Content-Type": @"text/plain"}];
    [cache storeCachedResponse:[[NSCachedURLResponse alloc] initWithResponse:response data:body userInfo:nil storagePolicy:NSURLCacheStorageAllowed] forRequest:request];
}

static BOOL revenant_has_row(NSString *database, NSString *address)
{
    sqlite3 *handle = NULL;
    BOOL found = NO;
    if (sqlite3_open_v2(database.fileSystemRepresentation, &handle, SQLITE_OPEN_READONLY, NULL) == SQLITE_OK) {
        sqlite3_stmt *statement = NULL;
        if (sqlite3_prepare_v2(handle, "SELECT count(*) FROM cfurl_cache_response WHERE request_key = ?", -1, &statement, NULL) == SQLITE_OK) {
            sqlite3_bind_text(statement, 1, address.UTF8String, -1, SQLITE_TRANSIENT);
            found = sqlite3_step(statement) == SQLITE_ROW && sqlite3_column_int(statement, 0) > 0;
        }
        sqlite3_finalize(statement);
    }
    sqlite3_close(handle);
    return found;
}

static BOOL revenant_row_goes(NSString *database, NSString *address)
{
    for (int attempt = 0; attempt < 50; attempt++) {
        if (!revenant_has_row(database, address))
            return YES;
        usleep(100000);
    }
    return NO;
}

static BOOL revenant_wait_for(NSString *database, int rows)
{
    for (int attempt = 0; attempt < 100; attempt++) {
        sqlite3 *handle = NULL;
        int found = 0;
        if (sqlite3_open_v2(database.fileSystemRepresentation, &handle, SQLITE_OPEN_READONLY, NULL) == SQLITE_OK) {
            sqlite3_stmt *statement = NULL;
            if (sqlite3_prepare_v2(handle, "SELECT count(*) FROM cfurl_cache_response", -1, &statement, NULL) == SQLITE_OK && sqlite3_step(statement) == SQLITE_ROW)
                found = sqlite3_column_int(statement, 0);
            sqlite3_finalize(statement);
        }
        sqlite3_close(handle);
        if (found >= rows)
            return YES;
        usleep(100000);
    }
    return NO;
}

int main(int argc, char **argv)
{
    revenant_read_arguments(argc, argv);
    NSString *folder = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSUUID UUID].UUIDString];
    NSURLCache *cache = [[NSURLCache alloc] initWithMemoryCapacity:512000 diskCapacity:10000000 directoryURL:[NSURL fileURLWithPath:folder isDirectory:YES]];
    NSString *database = [folder stringByAppendingPathComponent:@"Cache.db"];
    revenant_store(cache, @"http://example.com/old");
    revenant_check(revenant_wait_for(database, 1), "the first response reaches the database", @"timeout");
    sleep(2);
    NSDate *cut = [NSDate date];
    sleep(1);
    revenant_store(cache, @"http://example.com/new");
    revenant_check(revenant_wait_for(database, 2), "the second response reaches the database", @"timeout");
    revenant_cache_remove_since(cache, database, revenant_negative ? [cut dateByAddingTimeInterval:-100] : cut);
    revenant_check(revenant_row_goes(database, @"http://example.com/new"), "a response stored after the date goes", @"kept");
    revenant_check(revenant_has_row(database, @"http://example.com/old"), "a response stored before the date stays", @"removed");
    [[NSFileManager defaultManager] removeItemAtPath:folder error:NULL];
    return revenant_finish();
}
