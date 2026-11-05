#include "../revenant_impl.h"
#import "RevenantWebKit.h"

NSString *const BACKPORT_IMPL(WKWebsiteDataTypeCookies) = @"WKWebsiteDataTypeCookies";
NSString *const BACKPORT_IMPL(WKWebsiteDataTypeDiskCache) = @"WKWebsiteDataTypeDiskCache";
NSString *const BACKPORT_IMPL(WKWebsiteDataTypeMemoryCache) = @"WKWebsiteDataTypeMemoryCache";
NSString *const BACKPORT_IMPL(WKWebsiteDataTypeOfflineWebApplicationCache) = @"WKWebsiteDataTypeOfflineWebApplicationCache";
NSString *const BACKPORT_IMPL(WKWebsiteDataTypeLocalStorage) = @"WKWebsiteDataTypeLocalStorage";
NSString *const BACKPORT_IMPL(WKWebsiteDataTypeSessionStorage) = @"WKWebsiteDataTypeSessionStorage";
NSString *const BACKPORT_IMPL(WKWebsiteDataTypeWebSQLDatabases) = @"WKWebsiteDataTypeWebSQLDatabases";
NSString *const BACKPORT_IMPL(WKWebsiteDataTypeIndexedDBDatabases) = @"WKWebsiteDataTypeIndexedDBDatabases";
NSString *const BACKPORT_IMPL(WKWebsiteDataTypeFetchCache) = @"WKWebsiteDataTypeFetchCache";
NSString *const BACKPORT_IMPL(WKWebsiteDataTypeServiceWorkerRegistrations) = @"WKWebsiteDataTypeServiceWorkerRegistrations";

@implementation WKWebsiteDataStore {
    BOOL _persistent;
}

+ (WKWebsiteDataStore *)defaultDataStore
{
    static WKWebsiteDataStore *store;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        store = [self alloc];
        store->_persistent = YES;
    });
    return store;
}

+ (WKWebsiteDataStore *)nonPersistentDataStore
{
    WKWebsiteDataStore *store = [self alloc];
    store->_persistent = NO;
    return store;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    return [WKWebsiteDataStore defaultDataStore];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
}

- (BOOL)isPersistent
{
    return _persistent;
}

+ (NSSet<NSString *> *)allWebsiteDataTypes
{
    return [NSSet setWithObjects:BACKPORT_IMPL(WKWebsiteDataTypeCookies), BACKPORT_IMPL(WKWebsiteDataTypeDiskCache), BACKPORT_IMPL(WKWebsiteDataTypeMemoryCache), BACKPORT_IMPL(WKWebsiteDataTypeOfflineWebApplicationCache),
            BACKPORT_IMPL(WKWebsiteDataTypeLocalStorage), BACKPORT_IMPL(WKWebsiteDataTypeSessionStorage), BACKPORT_IMPL(WKWebsiteDataTypeWebSQLDatabases), BACKPORT_IMPL(WKWebsiteDataTypeIndexedDBDatabases), nil];
}

- (void)fetchDataRecordsOfTypes:(NSSet<NSString *> *)dataTypes completionHandler:(void (^)(NSArray<WKWebsiteDataRecord *> *))completionHandler
{
    dispatch_async(dispatch_get_main_queue(), ^{
        completionHandler(@[]);
    });
}

- (void)removeDataOfTypes:(NSSet<NSString *> *)dataTypes forDataRecords:(NSArray<WKWebsiteDataRecord *> *)dataRecords completionHandler:(void (^)(void))completionHandler
{
    dispatch_async(dispatch_get_main_queue(), ^{
        completionHandler();
    });
}

- (void)removeDataOfTypes:(NSSet<NSString *> *)dataTypes modifiedSince:(NSDate *)date completionHandler:(void (^)(void))completionHandler
{
    if ([dataTypes containsObject:BACKPORT_IMPL(WKWebsiteDataTypeCookies)]) {
        NSHTTPCookieStorage *storage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
        for (NSHTTPCookie *cookie in [storage.cookies copy])
            [storage deleteCookie:cookie];
    }
    if ([dataTypes containsObject:BACKPORT_IMPL(WKWebsiteDataTypeDiskCache)] || [dataTypes containsObject:BACKPORT_IMPL(WKWebsiteDataTypeMemoryCache)])
        [[NSURLCache sharedURLCache] removeCachedResponsesSinceDate:date];
    dispatch_async(dispatch_get_main_queue(), ^{
        completionHandler();
    });
}

@end
