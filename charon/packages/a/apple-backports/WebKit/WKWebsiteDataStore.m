#import "CharonWebKit.h"

NSString *const WKWebsiteDataTypeCookies = @"WKWebsiteDataTypeCookies";
NSString *const WKWebsiteDataTypeDiskCache = @"WKWebsiteDataTypeDiskCache";
NSString *const WKWebsiteDataTypeMemoryCache = @"WKWebsiteDataTypeMemoryCache";
NSString *const WKWebsiteDataTypeOfflineWebApplicationCache = @"WKWebsiteDataTypeOfflineWebApplicationCache";
NSString *const WKWebsiteDataTypeLocalStorage = @"WKWebsiteDataTypeLocalStorage";
NSString *const WKWebsiteDataTypeSessionStorage = @"WKWebsiteDataTypeSessionStorage";
NSString *const WKWebsiteDataTypeWebSQLDatabases = @"WKWebsiteDataTypeWebSQLDatabases";
NSString *const WKWebsiteDataTypeIndexedDBDatabases = @"WKWebsiteDataTypeIndexedDBDatabases";

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
    return [NSSet setWithObjects:WKWebsiteDataTypeCookies, WKWebsiteDataTypeDiskCache, WKWebsiteDataTypeMemoryCache, WKWebsiteDataTypeOfflineWebApplicationCache,
            WKWebsiteDataTypeLocalStorage, WKWebsiteDataTypeSessionStorage, WKWebsiteDataTypeWebSQLDatabases, WKWebsiteDataTypeIndexedDBDatabases, nil];
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
    if ([dataTypes containsObject:WKWebsiteDataTypeCookies]) {
        NSHTTPCookieStorage *storage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
        for (NSHTTPCookie *cookie in [storage.cookies copy])
            [storage deleteCookie:cookie];
    }
    if ([dataTypes containsObject:WKWebsiteDataTypeDiskCache] || [dataTypes containsObject:WKWebsiteDataTypeMemoryCache])
        [[NSURLCache sharedURLCache] removeCachedResponsesSinceDate:date];
    dispatch_async(dispatch_get_main_queue(), ^{
        completionHandler();
    });
}

@end
