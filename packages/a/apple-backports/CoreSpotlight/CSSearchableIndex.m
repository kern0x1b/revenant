#import <CoreSpotlight/CoreSpotlight.h>
#import <dlfcn.h>
#import <objc/message.h>
#import "CharonSpotlightStore.h"

NSString * const CSIndexErrorDomain = @"CSIndexErrorDomain";

static NSError *CharonIndexErrorBecause(CSIndexErrorCode code, NSString *reason, NSError *cause)
{
    NSMutableDictionary *info = [NSMutableDictionary dictionaryWithObject:reason forKey:NSLocalizedDescriptionKey];
    if (cause)
        info[NSUnderlyingErrorKey] = cause;
    return [NSError errorWithDomain:CSIndexErrorDomain code:code userInfo:info];
}

static NSError *CharonIndexError(CSIndexErrorCode code, NSString *reason)
{
    return CharonIndexErrorBecause(code, reason, nil);
}

// A search bundle - CharonSearchDatastore.m, the principal class of
// org.charon.corespotlight.searchBundle - runs in whatever process hosts system search, not this
// application's own process, so an index only this app's sandbox can read is one no search bundle
// can ever answer a query against. This mirrors org.charon.callkit's own bridge
// (CharonCallScreen.m): a shared, world-readable cache path rather than the sandboxed
// NSApplicationSupportDirectory this store used before a search bundle needed to read it too, kept
// one subdirectory per indexing application so one app's items never collide with another's.
NSString *const CharonSpotlightSharedRoot = CHARON_SPOTLIGHT_SHARED_ROOT;

static NSString *CharonSpotlightStoreDirectory(void)
{
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier] ?: @"space.kern0x1b.corespotlight.default";
    NSString *directory = [CharonSpotlightSharedRoot stringByAppendingPathComponent:bundleID];
    [[NSFileManager defaultManager] createDirectoryAtPath:directory withIntermediateDirectories:YES
                                                attributes:@{NSFilePosixPermissions: @(0777)} error:NULL];
    return directory;
}

static NSString *CharonSpotlightCategory(void)
{
    return [[NSBundle mainBundle] bundleIdentifier] ?: @"space.kern0x1b.corespotlight.default";
}

@interface CharonSpotlightBridge : NSObject
+ (instancetype)sharedBridge;
- (void)registerCategory:(NSString *)category;
- (void)recordsChanged:(NSArray<NSString *> *)identifiers category:(NSString *)category;
@end

@implementation CharonSpotlightBridge
{
    Class _managerClass;
    id _manager;
    NSMutableSet<NSString *> *_registeredCategories;
}

+ (instancetype)sharedBridge
{
    static CharonSpotlightBridge *bridge;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        bridge = [[self alloc] init];
    });
    return bridge;
}

- (instancetype)init
{
    if ((self = [super init])) {
        _registeredCategories = [NSMutableSet set];
        void *handle = dlopen("/System/Library/PrivateFrameworks/Spotlight.framework/Spotlight", RTLD_LAZY);
        if (handle) {
            _managerClass = NSClassFromString(@"SPSpotlightManager");
            SEL shared = sel_registerName("sharedManager");
            if (_managerClass && [_managerClass respondsToSelector:shared])
                _manager = ((id (*)(id, SEL))objc_msgSend)(_managerClass, shared);
        }
    }
    return self;
}

- (void)registerCategory:(NSString *)category
{
    if (!_manager || !category || [_registeredCategories containsObject:category])
        return;
    SEL start = sel_registerName("startRecordUpdatesForApplication:andCategory:");
    @try {
        if ([_manager respondsToSelector:start]) {
            ((id (*)(id, SEL, id, id))objc_msgSend)(_manager, start, self, category);
            [_registeredCategories addObject:category];
        }
    } @catch (NSException *exception) {
        NSLog(@"CSSearchableIndex: SPSpotlightManager refused to start record updates for %@: %@: %@", category, exception.name, exception.reason);
    }
}

- (void)recordsChanged:(NSArray<NSString *> *)identifiers category:(NSString *)category
{
    if (!_manager || !category)
        return;
    [self registerCategory:category];
    SEL request = sel_registerName("requestRecordUpdatesForApplication:category:andIDs:");
    SEL notify = sel_registerName("notifyIndexer");
    @try {
        if ([_manager respondsToSelector:request])
            ((id (*)(id, SEL, id, id, id))objc_msgSend)(_manager, request, self, category, identifiers ?: @[]);
        if ([_manager respondsToSelector:notify])
            ((id (*)(id, SEL))objc_msgSend)(_manager, notify);
    } @catch (NSException *exception) {
        NSLog(@"CSSearchableIndex: SPSpotlightManager refused the changed records of %@: %@: %@", category, exception.name, exception.reason);
    }
}

- (void)application:(id)application modifiedRecordIDs:(NSArray *)ids forCategory:(NSString *)category
{
}

- (void)appModifiedRecordIDs:(NSArray *)ids forCategory:(NSString *)category
{
}

@end

@interface CharonSpotlightStore : NSObject
@property (nonatomic, copy, readonly) NSString *name;
@property (nonatomic, strong, readonly) NSMutableDictionary<NSString *, NSData *> *entries;
@property (nonatomic, strong) NSData *clientState;
- (instancetype)initWithName:(NSString *)name;
- (NSString *)path;
- (NSError *)apply:(void (^)(void))change;
@end

@implementation CharonSpotlightStore

@synthesize name = _name;
@synthesize entries = _entries;
@synthesize clientState = _clientState;

+ (instancetype)storeNamed:(NSString *)name
{
    static NSMutableDictionary<NSString *, CharonSpotlightStore *> *stores;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        stores = [NSMutableDictionary dictionary];
    });
    @synchronized (stores) {
        CharonSpotlightStore *store = stores[name];
        if (!store) {
            store = [[self alloc] initWithName:name];
            stores[name] = store;
        }
        return store;
    }
}

- (instancetype)initWithName:(NSString *)name
{
    if ((self = [super init])) {
        _name = [name copy];
        NSDictionary *disk = [NSDictionary dictionaryWithContentsOfFile:[self path]];
        _entries = [NSMutableDictionary dictionaryWithDictionary:disk[@"entries"]];
        _clientState = disk[@"clientState"];
    }
    return self;
}

- (NSString *)path
{
    return [CharonSpotlightStoreDirectory() stringByAppendingPathComponent:[self.name stringByAppendingPathExtension:@"plist"]];
}

// Answers nil once the store is on disk, where the search bundle reads it, or the error the caller's
// completion handler receives: an index that could not be written holds nothing a search can find.
// The code is CSIndexErrorCodeIndexUnavailableError, which the SDK's CSSearchableIndex.h documents as
// "The indexer was unavailable": this file store is the port's indexer (facts/CoreSpotlight/
// CoreSpotlight.md, "What differs from the release"). The cause goes under NSUnderlyingErrorKey.
- (NSError *)save
{
    NSString *path = [self path];
    NSString *directory = path.stringByDeletingLastPathComponent;
    NSError *cause = nil;
    if (![[NSFileManager defaultManager] createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:&cause])
        return CharonIndexErrorBecause(CSIndexErrorCodeIndexUnavailableError, [NSString stringWithFormat:@"cannot create %@: %@", directory, cause.localizedDescription], cause);
    NSMutableDictionary *disk = [NSMutableDictionary dictionary];
    disk[@"entries"] = self.entries;
    if (self.clientState)
        disk[@"clientState"] = self.clientState;
    NSData *data = [NSPropertyListSerialization dataWithPropertyList:disk format:NSPropertyListXMLFormat_v1_0 options:0 error:&cause];
    if (!data)
        return CharonIndexErrorBecause(CSIndexErrorCodeIndexUnavailableError, [NSString stringWithFormat:@"cannot serialize the store for %@: %@", path, cause.localizedDescription], cause);
    if (![data writeToFile:path options:NSDataWritingAtomic error:&cause])
        return CharonIndexErrorBecause(CSIndexErrorCodeIndexUnavailableError, [NSString stringWithFormat:@"cannot write %@: %@", path, cause.localizedDescription], cause);
    return nil;
}

// Runs a change and saves it; when the save fails, the entries and the client state go back to what
// they were, so memory never holds what the caller was told was not stored - a later save would write
// it without searchd being told, and -fetchLastClientState would answer it.
// The store's lock: a change and a search's copy of the entries are never interleaved.
- (NSError *)apply:(void (^)(void))change
{
    @synchronized (self) {
        NSMutableDictionary<NSString *, NSData *> *entries = [_entries mutableCopy];
        NSData *clientState = _clientState;
        @try {
            change();
        } @catch (NSException *exception) {
            // An item that cannot be archived raises from inside the change; what it changed so far goes too.
            _entries = entries;
            _clientState = clientState;
            @throw;
        }
        NSError *error = [self save];
        if (error) {
            _entries = entries;
            _clientState = clientState;
        }
        return error;
    }
}

- (void)setItem:(CSSearchableItem *)item
{
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:item];
    if (data)
        self.entries[item.uniqueIdentifier] = data;
}

- (CSSearchableItem *)itemForIdentifier:(NSString *)identifier
{
    NSData *data = self.entries[identifier];
    return data ? [NSKeyedUnarchiver unarchiveObjectWithData:data] : nil;
}

- (void)removeIdentifiers:(NSArray<NSString *> *)identifiers
{
    [self.entries removeObjectsForKeys:identifiers];
}

- (void)removeDomainIdentifiers:(NSArray<NSString *> *)domainIdentifiers
{
    NSMutableArray<NSString *> *doomed = [NSMutableArray array];
    for (NSString *identifier in self.entries) {
        CSSearchableItem *item = [self itemForIdentifier:identifier];
        NSString *domain = item.domainIdentifier;
        if (!domain)
            continue;
        for (NSString *prefix in domainIdentifiers) {
            if ([domain isEqualToString:prefix] || [domain hasPrefix:[prefix stringByAppendingString:@"."]]) {
                [doomed addObject:identifier];
                break;
            }
        }
    }
    [self removeIdentifiers:doomed];
}

- (void)removeAll
{
    [self.entries removeAllObjects];
    self.clientState = nil;
}

@end

NSArray<CSSearchableItem *> *CharonSpotlightDefaultItems(void)
{
    CharonSpotlightStore *store = [CharonSpotlightStore storeNamed:@"__defaultIndex"];
    NSMutableArray<CSSearchableItem *> *items = [NSMutableArray array];
    @synchronized (store) {
        NSArray<NSString *> *identifiers = [store.entries.allKeys sortedArrayUsingSelector:@selector(compare:)];
        for (NSString *identifier in identifiers) {
            CSSearchableItem *item = [store itemForIdentifier:identifier];
            if (item)
                [items addObject:item];
        }
    }
    return items;
}

@interface CSSearchableIndex ()
@property (nonatomic, copy) NSString *charonName;
@property (nonatomic, strong) CharonSpotlightStore *charonStore;
@end

@implementation CSSearchableIndex

@synthesize charonName = _charonName;
@synthesize charonStore = _charonStore;
// Weak, as the header declares it: the index keeps no delegate alive, and a delegate that is freed reads back as nil.
@synthesize indexDelegate = _indexDelegate;

+ (BOOL)isIndexingAvailable
{
    return YES;
}

+ (instancetype)defaultSearchableIndex
{
    static CSSearchableIndex *shared;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        shared = [[CSSearchableIndex alloc] initWithName:@"__defaultIndex"];
    });
    return shared;
}

- (instancetype)initWithName:(NSString *)name
{
    return [self initWithName:name protectionClass:nil];
}

- (instancetype)initWithName:(NSString *)name protectionClass:(NSFileProtectionType)protectionClass
{
    if ((self = [super init])) {
        self.charonName = name;
        self.charonStore = [CharonSpotlightStore storeNamed:name ?: @"__defaultIndex"];
    }
    return self;
}

- (void)charonNotifyChangedIdentifiers:(NSArray<NSString *> *)identifiers
{
    NSString *category = CharonSpotlightCategory();
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [[CharonSpotlightBridge sharedBridge] recordsChanged:identifiers category:category];
    });
}

- (void)indexSearchableItems:(NSArray<CSSearchableItem *> *)items completionHandler:(void (^)(NSError *))completionHandler
{
    CharonSpotlightStore *store = self.charonStore;
    NSError *error = nil;
    NSMutableArray<NSString *> *identifiers = [NSMutableArray array];
    @synchronized (store) {
        error = [store apply:^{
            for (CSSearchableItem *item in items) {
                [store setItem:item];
                [identifiers addObject:item.uniqueIdentifier];
            }
        }];
    }
    if (!error)
        [self charonNotifyChangedIdentifiers:identifiers];
    if (completionHandler)
        completionHandler(error);
}

- (void)deleteSearchableItemsWithIdentifiers:(NSArray<NSString *> *)identifiers completionHandler:(void (^)(NSError *))completionHandler
{
    CharonSpotlightStore *store = self.charonStore;
    NSError *error = nil;
    @synchronized (store) {
        error = [store apply:^{
            [store removeIdentifiers:identifiers];
        }];
    }
    if (!error)
        [self charonNotifyChangedIdentifiers:identifiers];
    if (completionHandler)
        completionHandler(error);
}

- (void)deleteSearchableItemsWithDomainIdentifiers:(NSArray<NSString *> *)domainIdentifiers completionHandler:(void (^)(NSError *))completionHandler
{
    CharonSpotlightStore *store = self.charonStore;
    NSError *error = nil;
    @synchronized (store) {
        error = [store apply:^{
            [store removeDomainIdentifiers:domainIdentifiers];
        }];
    }
    if (!error)
        [self charonNotifyChangedIdentifiers:nil];
    if (completionHandler)
        completionHandler(error);
}

- (void)deleteAllSearchableItemsWithCompletionHandler:(void (^)(NSError *))completionHandler
{
    CharonSpotlightStore *store = self.charonStore;
    NSError *error = nil;
    @synchronized (store) {
        error = [store apply:^{
            [store removeAll];
        }];
    }
    if (!error)
        [self charonNotifyChangedIdentifiers:nil];
    if (completionHandler)
        completionHandler(error);
}

- (void)beginIndexBatch
{
}

- (void)endIndexBatchWithClientState:(NSData *)clientState completionHandler:(void (^)(NSError *))completionHandler
{
    if ([self.charonName isEqualToString:@"__defaultIndex"]) {
        if (completionHandler)
            completionHandler(CharonIndexError(CSIndexErrorCodeInvalidClientStateError, @"batching is unsupported for the default searchable index"));
        return;
    }
    CharonSpotlightStore *store = self.charonStore;
    NSError *error = nil;
    @synchronized (store) {
        error = [store apply:^{
            store.clientState = clientState;
        }];
    }
    if (completionHandler)
        completionHandler(error);
}

- (void)fetchLastClientStateWithCompletionHandler:(void (^)(NSData *, NSError *))completionHandler
{
    CharonSpotlightStore *store = self.charonStore;
    NSData *state;
    @synchronized (store) {
        state = store.clientState;
    }
    if (completionHandler)
        completionHandler(state, nil);
}

// The release answers this on a background queue, never before it returns. It answers -1003 for a bundle the index holds
// nothing for, with or without an index delegate (measured: the delegate's data callback is not asked). This port has no
// external provider to ask, so every request gets that answer: CSIndexErrorCodeRemoteConnectionError with no user info,
// as the release gives it.
- (void)fetchDataForBundleIdentifier:(NSString *)bundleIdentifier
                      itemIdentifier:(NSString *)itemIdentifier
                         contentType:(UTType *)contentType
                   completionHandler:(void (^)(NSData *, NSError *))completionHandler
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        if (completionHandler)
            completionHandler(nil, [NSError errorWithDomain:CSIndexErrorDomain code:CSIndexErrorCodeRemoteConnectionError userInfo:nil]);
    });
}

@end
