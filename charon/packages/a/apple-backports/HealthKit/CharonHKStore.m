// The store: one SQLite database of the health data the process saves, its authorization, its
// characteristics, the order of its sources, the background-delivery registrations and the anchors
// of its running queries.
//
// The release runs no healthd and ships no health database, so there is no service to ask and no
// store of Apple's to read. This is that store: SQLite, through the device's own
// /usr/lib/libsqlite3.dylib. Measured, the armv7 shared cache of iOS 4.3 and the one of iOS 6.1.3
// both export all twenty-six of sqlite3_open, sqlite3_open_v2, sqlite3_close, sqlite3_exec,
// sqlite3_prepare_v2, sqlite3_step, sqlite3_finalize, sqlite3_reset, sqlite3_bind_text,
// sqlite3_bind_double, sqlite3_bind_int64, sqlite3_bind_blob, sqlite3_bind_null, sqlite3_column_text,
// sqlite3_column_double, sqlite3_column_int64, sqlite3_column_blob, sqlite3_column_type,
// sqlite3_column_bytes, sqlite3_column_count, sqlite3_errmsg, sqlite3_last_insert_rowid,
// sqlite3_changes, sqlite3_busy_timeout and sqlite3_extended_result_codes
// (~/.charon/dyld/4.3/dyld_shared_cache_armv7, ~/.charon/dyld/6.1.3/dyld_shared_cache_armv7).
//
// A row holds the object itself, archived by its own NSSecureCoding, beside the few facts SQLite has
// to narrow by: the type, the dates, the source and a sequence number that is the store's own
// clock. Nothing an application writes reaches SQLite as SQL: every statement here is one fixed
// string with positional bindings, and the search arguments of a query are handed to the release's
// own NSPredicate, which decides them over the objects read back.

#import <sqlite3.h>

#import "CharonHKStore.h"
#import "../CharonSayOnce.h"

#pragma mark - Errors

NSError *CharonHKError(NSInteger code, NSString *description, NSString *debug)
{
    NSMutableDictionary *info = [NSMutableDictionary dictionaryWithObject:description forKey:NSLocalizedDescriptionKey];
    if (debug)
        info[NSDebugDescriptionErrorKey] = debug;
    return [NSError errorWithDomain:HKErrorDomain code:code userInfo:info];
}

void charon_hk_say_once(NSString *key, NSString *text)
{
    charon_say_once_for(key, text);
}

#pragma mark - Where the database is

NSString *CharonHKStorePath(void)
{
    static NSString *path;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSArray *folders = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
        NSString *root = folders.count ? [folders objectAtIndex:0] : NSTemporaryDirectory();
        NSString *folder = [root stringByAppendingPathComponent:@"CharonHealthKit"];
        NSFileManager *files = [NSFileManager defaultManager];
        if (![files fileExistsAtPath:folder])
            [files createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:NULL];
        path = [folder stringByAppendingPathComponent:@"healthkit.sqlite3"];
    });
    return path;
}

#pragma mark - The row

@interface CharonHKRow ()
@property (readwrite, copy) NSUUID *uuid;
@property (readwrite, copy) NSString *type;
@property (readwrite) NSInteger kind;
@property (readwrite) NSTimeInterval start;
@property (readwrite) NSTimeInterval end;
@property (readwrite) NSTimeInterval created;
@property (readwrite) NSInteger sequence;
@property (readwrite, copy) NSString *sourceBundle;
@property (readwrite, copy) NSString *sourceName;
@property (readwrite, copy, nullable) NSString *sourceVersion;
@property (readwrite, copy) NSData *archive;
@end

@implementation CharonHKRow
@synthesize uuid = _uuid;
@synthesize type = _type;
@synthesize kind = _kind;
@synthesize start = _start;
@synthesize end = _end;
@synthesize created = _created;
@synthesize sequence = _sequence;
@synthesize sourceBundle = _sourceBundle;
@synthesize sourceName = _sourceName;
@synthesize sourceVersion = _sourceVersion;
@synthesize archive = _archive;

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@ %@ of %@ from %@ at %f>", NSStringFromClass(self.class), _uuid, _type,
                                      _sourceName, _start];
}
@end

#pragma mark - The store

// The bits of the authorization a type is recorded with, as the store's own column holds them.
typedef NS_ENUM(NSUInteger, CharonHKAuthorizationBits) {
    CharonHKAuthorizationShare = 1u << 0,
    CharonHKAuthorizationRead = 1u << 1,
};

@implementation CharonHKStore {
    sqlite3 *_database;
    NSRecursiveLock *_lock;
    NSMutableDictionary<NSString *, NSNumber *> *_authorization;
    NSMutableArray *_observers;
    NSInteger _sequence;
    BOOL _opened;
}

@synthesize path = _path;
@synthesize open = _open;

+ (CharonHKStore *)sharedStore
{
    static CharonHKStore *store;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        store = [[CharonHKStore alloc] init];
    });
    return store;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _path = [CharonHKStorePath() copy];
        _lock = [[NSRecursiveLock alloc] init];
        _lock.name = @"org.charon.healthkit.store";
        _authorization = [[NSMutableDictionary alloc] init];
        _observers = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)dealloc
{
    if (_database)
        sqlite3_close(_database);
}

#pragma mark The connection

- (BOOL)charon_openLocked:(NSError **)error
{
    if (_opened)
        return YES;
    NSFileManager *files = [NSFileManager defaultManager];
    NSString *folder = [_path stringByDeletingLastPathComponent];
    if (![files fileExistsAtPath:folder])
        [files createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:NULL];
    int opened = sqlite3_open_v2([_path UTF8String], &_database,
                                 SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX, NULL);
    if (opened != SQLITE_OK) {
        if (error)
            *error = CharonHKError(HKErrorHealthDataUnavailable,
                                   [NSString stringWithFormat:@"The health database at %@ could not be opened: %s.", _path,
                                                              _database ? sqlite3_errmsg(_database) : "no database"], nil);
        if (_database) {
            sqlite3_close(_database);
            _database = NULL;
        }
        return NO;
    }
    sqlite3_busy_timeout(_database, 5000);
    if (![self charon_schemaLocked:error]) {
        sqlite3_close(_database);
        _database = NULL;
        return NO;
    }
    [self charon_loadLocked];
    _open = YES;
    _opened = YES;
    return YES;
}

- (BOOL)openWithError:(NSError **)error
{
    __block BOOL ok = NO;
    __block NSError *failure = nil;
    [_lock lock];
    @try {
        ok = [self charon_openLocked:&failure];
    } @finally {
        [_lock unlock];
    }
    if (!ok && error)
        *error = failure;
    return ok;
}

- (void)close
{
    [_lock lock];
    @try {
        if (self->_database) {
            sqlite3_close(self->_database);
            self->_database = NULL;
        }
        self->_open = NO;
        self->_opened = NO;
    } @finally {
        [_lock unlock];
    }
}

- (void)charon_loadLocked
{
    for (NSDictionary *row in [self charon_rowsLocked:@"SELECT type, share, read FROM authorization" bindings:@[]])
        _authorization[[row objectForKey:@"type"]] = @([[row objectForKey:@"share"] integerValue] * CharonHKAuthorizationShare
                                                       | [[row objectForKey:@"read"] integerValue] * CharonHKAuthorizationRead);
    NSArray *rows = [self charon_rowsLocked:@"SELECT value FROM meta WHERE key = 'sequence'" bindings:@[]];
    _sequence = [[rows.firstObject objectForKey:@"value"] integerValue];
}

#pragma mark SQL

// One statement, positional bindings, no interpolation of anything an application wrote.
- (BOOL)charon_runLocked:(NSString *)sql bindings:(NSArray *)bindings error:(NSError **)error
{
    sqlite3_stmt *statement = NULL;
    if (!_database) {
        if (error)
            *error = CharonHKError(HKErrorHealthDataUnavailable, @"The health database is not open.", nil);
        return NO;
    }
    if (sqlite3_prepare_v2(_database, [sql UTF8String], -1, &statement, NULL) != SQLITE_OK) {
        if (error)
            *error = CharonHKError(HKErrorHealthDataUnavailable,
                                   [NSString stringWithFormat:@"The health database refused a statement: %s.",
                                                              sqlite3_errmsg(_database)], sql);
        return NO;
    }
    [self charon_bindLocked:statement bindings:bindings];
    int stepped = sqlite3_step(statement);
    sqlite3_finalize(statement);
    if (stepped != SQLITE_DONE) {
        if (error)
            *error = CharonHKError(HKErrorHealthDataUnavailable,
                                   [NSString stringWithFormat:@"The health database refused a write: %s.",
                                                              sqlite3_errmsg(_database)], nil);
        return NO;
    }
    return YES;
}

- (void)charon_bindLocked:(sqlite3_stmt *)statement bindings:(NSArray *)bindings
{
    for (NSUInteger index = 0; index < bindings.count; index++) {
        id value = [bindings objectAtIndex:index];
        int at = (int)index + 1;
        if (!value || value == [NSNull null])
            sqlite3_bind_null(statement, at);
        else if ([value isKindOfClass:[NSString class]])
            sqlite3_bind_text(statement, at, [value UTF8String], -1, SQLITE_TRANSIENT);
        else if ([value isKindOfClass:[NSData class]])
            sqlite3_bind_blob(statement, at, [value bytes], (int)[value length], SQLITE_TRANSIENT);
        else if ([value isKindOfClass:[NSNumber class]])
            sqlite3_bind_int64(statement, at, [value longLongValue]);
        else
            sqlite3_bind_text(statement, at, [[value description] UTF8String], -1, SQLITE_TRANSIENT);
    }
}

- (NSArray *)charon_rowsLocked:(NSString *)sql bindings:(NSArray *)bindings
{
    if (!_database)
        return @[];
    sqlite3_stmt *statement = NULL;
    if (sqlite3_prepare_v2(_database, [sql UTF8String], -1, &statement, NULL) != SQLITE_OK)
        return @[];
    [self charon_bindLocked:statement bindings:bindings];
    NSMutableArray *rows = [NSMutableArray array];
    int columns = sqlite3_column_count(statement);
    while (sqlite3_step(statement) == SQLITE_ROW) {
        NSMutableDictionary *row = [NSMutableDictionary dictionaryWithCapacity:(NSUInteger)columns];
        for (int index = 0; index < columns; index++) {
            NSString *name = [NSString stringWithUTF8String:sqlite3_column_name(statement, index)];
            switch (sqlite3_column_type(statement, index)) {
            case SQLITE_INTEGER:
                row[name] = @(sqlite3_column_int64(statement, index));
                break;
            case SQLITE_FLOAT:
                row[name] = @(sqlite3_column_double(statement, index));
                break;
            case SQLITE_BLOB: {
                const void *bytes = sqlite3_column_blob(statement, index);
                int length = sqlite3_column_bytes(statement, index);
                row[name] = bytes ? [NSData dataWithBytes:bytes length:(NSUInteger)length] : [NSData data];
                break;
            }
            case SQLITE_NULL:
                row[name] = [NSNull null];
                break;
            default: {
                const unsigned char *text = sqlite3_column_text(statement, index);
                row[name] = text ? [NSString stringWithUTF8String:(const char *)text] : @"";
                break;
            }
            }
        }
        [rows addObject:row];
    }
    sqlite3_finalize(statement);
    return rows;
}

- (BOOL)charon_schemaLocked:(NSError **)error
{
    NSArray *statements = @[
        @"CREATE TABLE IF NOT EXISTS meta (key TEXT PRIMARY KEY NOT NULL, value TEXT)",
        @"CREATE TABLE IF NOT EXISTS type (identifier TEXT PRIMARY KEY NOT NULL, kind INTEGER NOT NULL, unit TEXT, aggregation INTEGER NOT NULL DEFAULT 0)",
        @"CREATE TABLE IF NOT EXISTS object (uuid TEXT PRIMARY KEY NOT NULL, type TEXT NOT NULL, kind INTEGER NOT NULL, start REAL NOT NULL, end REAL NOT NULL, source_bundle TEXT NOT NULL DEFAULT '', source_name TEXT NOT NULL DEFAULT '', source_version TEXT, sequence INTEGER NOT NULL, created REAL NOT NULL, archive BLOB NOT NULL)",
        @"CREATE INDEX IF NOT EXISTS object_by_type ON object (type, start, end)",
        @"CREATE INDEX IF NOT EXISTS object_by_sequence ON object (sequence)",
        @"CREATE TABLE IF NOT EXISTS correlated (correlation TEXT NOT NULL, member TEXT NOT NULL, position INTEGER NOT NULL, PRIMARY KEY (correlation, member))",
        @"CREATE INDEX IF NOT EXISTS correlated_by_member ON correlated (member)",
        @"CREATE TABLE IF NOT EXISTS authorization (type TEXT PRIMARY KEY NOT NULL, share INTEGER NOT NULL, read INTEGER NOT NULL)",
        @"CREATE TABLE IF NOT EXISTS characteristic (identifier TEXT PRIMARY KEY NOT NULL, value BLOB)",
        @"CREATE TABLE IF NOT EXISTS source_order (type TEXT NOT NULL, bundle TEXT NOT NULL, position INTEGER NOT NULL, PRIMARY KEY (type, bundle))",
        @"CREATE TABLE IF NOT EXISTS background_delivery (type TEXT NOT NULL, frequency INTEGER NOT NULL, PRIMARY KEY (type, frequency))",
        @"CREATE TABLE IF NOT EXISTS activity_summary (start REAL PRIMARY KEY NOT NULL, archive BLOB NOT NULL)",
        @"CREATE TABLE IF NOT EXISTS anchor (uuid TEXT PRIMARY KEY NOT NULL, data BLOB NOT NULL)",
        @"CREATE TABLE IF NOT EXISTS deleted (uuid TEXT PRIMARY KEY NOT NULL, sequence INTEGER NOT NULL)",
    ];
    for (NSString *sql in statements)
        if (![self charon_runLocked:sql bindings:@[] error:error])
            return NO;
    return [self charon_runLocked:@"INSERT OR IGNORE INTO meta (key, value) VALUES ('sequence', '0')" bindings:@[] error:error];
}

- (BOOL)charon_transactionLocked:(BOOL (^)(NSError **))body error:(NSError **)error
{
    if (![self charon_openLocked:error])
        return NO;
    if (![self charon_runLocked:@"BEGIN IMMEDIATE" bindings:@[] error:error])
        return NO;
    NSError *failure = nil;
    if (!body(&failure)) {
        [self charon_runLocked:@"ROLLBACK" bindings:@[] error:NULL];
        if (error)
            *error = failure;
        return NO;
    }
    return [self charon_runLocked:@"COMMIT" bindings:@[] error:error];
}

- (NSInteger)charon_nextSequenceLocked
{
    return ++_sequence;
}

#pragma mark Types

- (BOOL)declareType:(HKObjectType *)type error:(NSError **)error
{
    if (![type conformsToProtocol:@protocol(CharonHKTyped)]) {
        if (error)
            *error = CharonHKError(HKErrorInvalidArgument,
                                   [NSString stringWithFormat:@"A %@ is not a type this database can keep.",
                                                              NSStringFromClass([type class])], nil);
        return NO;
    }
    id<CharonHKTyped> typed = (id<CharonHKTyped>)type;
    __block BOOL ok = NO;
    __block NSError *failure = nil;
    [_lock lock];
    @try {
        ok = [self charon_transactionLocked:^BOOL(NSError **inner) {
            return [self charon_runLocked:@"INSERT OR REPLACE INTO type (identifier, kind, unit, aggregation) VALUES (?, ?, ?, ?)"
                                 bindings:@[type.identifier, @([typed charon_storeKind]),
                                            [typed charon_canonicalUnitString] ?: [NSNull null],
                                            @([typed charon_aggregationStyleValue])]
                                    error:inner];
        } error:&failure];
    } @finally {
        [_lock unlock];
    }
    if (!ok && error)
        *error = failure;
    return ok;
}

- (nullable HKObjectType *)typeWithIdentifier:(NSString *)identifier
{
    if (!identifier.length)
        return nil;
    __block HKObjectType *found = nil;
    [_lock lock];
    @try {
        if (![self charon_openLocked:NULL])
            return nil;
        NSDictionary *row = [self charon_rowsLocked:@"SELECT kind, unit, aggregation FROM type WHERE identifier = ?"
                                         bindings:@[identifier]].firstObject;
        if (!row)
            return nil;
        NSInteger kind = [[row objectForKey:@"kind"] integerValue];
        Class cls = CharonHKClassForTypeKind(kind);
        if (!cls)
            return nil;
        HKObjectType *type = [cls charon_typeWithIdentifier:identifier];
        id unit = [row objectForKey:@"unit"];
        if ([unit isKindOfClass:[NSString class]])
            [(id<CharonHKTyped>)type charon_setCanonicalUnitString:unit aggregationStyle:[[row objectForKey:@"aggregation"] integerValue]];
        found = type;
    } @finally {
        [_lock unlock];
    }
    return found;
}

#pragma mark Authorization

- (BOOL)recordAuthorizationToShare:(nullable NSSet *)typesToShare read:(nullable NSSet *)typesToRead error:(NSError **)error
{
    NSMutableDictionary<NSString *, NSNumber *> *asked = [NSMutableDictionary dictionary];
    for (HKObjectType *type in typesToShare)
        asked[type.identifier] = @(CharonHKAuthorizationShare);
    for (HKObjectType *type in typesToRead)
        asked[type.identifier] = @([asked[type.identifier] unsignedIntegerValue] | CharonHKAuthorizationRead);
    __block BOOL ok = NO;
    __block NSError *failure = nil;
    [_lock lock];
    @try {
        ok = [self charon_transactionLocked:^BOOL(NSError **inner) {
            for (NSString *identifier in asked) {
                NSUInteger bits = [asked[identifier] unsignedIntegerValue];
                if (![self charon_runLocked:@"INSERT OR REPLACE INTO authorization (type, share, read) VALUES (?, ?, ?)"
                                  bindings:@[identifier, @((bits & CharonHKAuthorizationShare) ? 1 : 0),
                                             @((bits & CharonHKAuthorizationRead) ? 1 : 0)]
                                     error:inner])
                    return NO;
            }
            return YES;
        } error:&failure];
    } @finally {
        [_lock unlock];
    }
    if (ok) {
        @synchronized(_authorization) {
            [_authorization addEntriesFromDictionary:asked];
        }
    } else if (error) {
        *error = failure;
    }
    return ok;
}

- (NSUInteger)charon_bitsForType:(HKObjectType *)type
{
    NSNumber *bits = nil;
    @synchronized(_authorization) {
        bits = _authorization[type.identifier];
    }
    return bits.unsignedIntegerValue;
}

- (BOOL)mayShareType:(HKObjectType *)type
{
    return ([self charon_bitsForType:type] & CharonHKAuthorizationShare) != 0;
}

- (BOOL)mayReadType:(HKObjectType *)type
{
    return ([self charon_bitsForType:type] & CharonHKAuthorizationRead) != 0;
}

- (HKAuthorizationStatus)authorizationStatusForType:(HKObjectType *)type
{
    NSUInteger bits = [self charon_bitsForType:type];
    if (!bits)
        return HKAuthorizationStatusNotDetermined;
    if (bits & CharonHKAuthorizationShare)
        return HKAuthorizationStatusSharingAuthorized;
    // Asked for and refused: the store records the refusal where a release's own sheet records it.
    return HKAuthorizationStatusSharingDenied;
}

#pragma mark Characteristics

- (nullable id)characteristicForIdentifier:(NSString *)identifier
{
    __block id value = nil;
    [_lock lock];
    @try {
        if (![self charon_openLocked:NULL])
            return nil;
        NSData *data = [self charon_rowsLocked:@"SELECT value FROM characteristic WHERE identifier = ?"
                                     bindings:@[identifier]].firstObject[@"value"];
        if (![data isKindOfClass:[NSData class]])
            return nil;
        value = [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:NULL error:NULL];
    } @finally {
        [_lock unlock];
    }
    return value;
}

- (BOOL)setCharacteristic:(nullable id)value forIdentifier:(NSString *)identifier error:(NSError **)error
{
    NSData *data = nil;
    if (value) {
        if (![NSPropertyListSerialization propertyList:value isValidForFormat:NSPropertyListBinaryFormat_v1_0]) {
            if (error)
                *error = CharonHKError(HKErrorInvalidArgument,
                                       [NSString stringWithFormat:@"A %@ is not a value this database can keep.",
                                                                  NSStringFromClass([value class])], nil);
            return NO;
        }
        data = [NSPropertyListSerialization dataWithPropertyList:value
                                                    format:NSPropertyListBinaryFormat_v1_0
                                                   options:0
                                                     error:NULL];
    }
    __block BOOL ok = NO;
    __block NSError *failure = nil;
    [_lock lock];
    @try {
        ok = [self charon_runLocked:@"INSERT OR REPLACE INTO characteristic (identifier, value) VALUES (?, ?)"
                          bindings:@[identifier, data ?: [NSData data]]
                             error:&failure];
    } @finally {
        [_lock unlock];
    }
    if (!ok && error)
        *error = failure;
    return ok;
}

#pragma mark Writing

- (BOOL)saveObjects:(NSArray *)objects error:(NSError **)error
{
    if (!objects.count)
        return YES;
    NSMutableArray<NSString *> *changed = [NSMutableArray array];
    __block BOOL ok = NO;
    __block NSError *failure = nil;
    [_lock lock];
    @try {
        ok = [self charon_transactionLocked:^BOOL(NSError **inner) {
            for (id object in objects) {
                if (![object conformsToProtocol:@protocol(CharonHKStorable)]) {
                    *inner = CharonHKError(HKErrorInvalidArgument,
                                           [NSString stringWithFormat:@"A %@ is not a health object this database can keep.",
                                                                      NSStringFromClass([object class])], nil);
                    return NO;
                }
                id<CharonHKStorable> storable = (id<CharonHKStorable>)object;
                NSString *identifier = [storable charon_storeTypeIdentifier];
                if (!identifier.length) {
                    *inner = CharonHKError(HKErrorInvalidArgument,
                                           [NSString stringWithFormat:@"A %@ has no type, and a sample is saved under one.",
                                                                      NSStringFromClass([object class])], nil);
                    return NO;
                }
                // The gate is asked about the type the object carries, not about the row this save has
                // not written yet. -typeWithIdentifier: returns nil for a type the type table has no row
                // for, and that row is inserted further down, after this check - so a type the store had
                // never seen was asked about as nil and refused as unauthorised, and could then never be
                // saved at all. The workout path below already asks with the type the object carries; this
                // is the same question asked the same way.
                HKObjectType *type = [storable respondsToSelector:@selector(charon_typeForSaving)]
                                       ? [(id)storable charon_typeForSaving]
                                       : [self typeWithIdentifier:identifier];
                if (![self mayShareType:type]) {
                    *inner = CharonHKError(HKErrorAuthorizationDenied,
                                           [NSString stringWithFormat:@"Sharing %@ data has not been authorized.", identifier],
                                           nil);
                    return NO;
                }
                if (![self charon_runLocked:@"INSERT OR REPLACE INTO type (identifier, kind, unit, aggregation) VALUES (?, ?, ?, ?)"
                                  bindings:@[identifier, @([storable charon_storeKind]), [NSNull null], @0]
                                     error:inner])
                    return NO;
                NSString *uuid = [(HKObject *)object UUID].UUIDString;
                NSInteger sequence = [self charon_nextSequenceLocked];
                if (![self charon_runLocked:@"INSERT OR REPLACE INTO object (uuid, type, kind, start, end, source_bundle, source_name, source_version, sequence, created, archive) "
                                            "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
                                  bindings:@[uuid, identifier, @([storable charon_storeKind]),
                                             @([(HKSample *)object startDate].timeIntervalSince1970),
                                             @([(HKSample *)object endDate].timeIntervalSince1970),
                                             [(HKObject *)object source].bundleIdentifier ?: @"",
                                             [(HKObject *)object source].name ?: @"",
                                             [HKSource charon_processVersion] ?: [NSNull null],
                                             @(sequence), @([[NSDate date] timeIntervalSince1970]),
                                             [storable charon_storeArchive]]
                                     error:inner])
                    return NO;
                if (![self charon_runLocked:@"DELETE FROM deleted WHERE uuid = ?" bindings:@[uuid] error:inner])
                    return NO;
                if ([object isKindOfClass:[HKCorrelation class]]) {
                    if (![self charon_runLocked:@"DELETE FROM correlated WHERE correlation = ?" bindings:@[uuid] error:inner])
                        return NO;
                    NSUInteger position = 0;
                    for (HKObject *member in [(HKCorrelation *)object charon_allObjects])
                        if (![self charon_runLocked:@"INSERT OR REPLACE INTO correlated (correlation, member, position) VALUES (?, ?, ?)"
                                          bindings:@[uuid, member.UUID.UUIDString, @(position++)]
                                             error:inner])
                            return NO;
                }
                [changed addObject:uuid];
            }
            return YES;
        } error:&failure];
        if (ok)
            [self charon_runLocked:@"INSERT OR REPLACE INTO meta (key, value) VALUES ('sequence', ?)"
                          bindings:@[[[NSNumber numberWithInteger:_sequence] stringValue]] error:NULL];
    } @finally {
        [_lock unlock];
    }
    if (ok)
        [self charon_publishChanged:changed];
    else if (error)
        *error = failure;
    return ok;
}

- (BOOL)addSamples:(NSArray *)samples toWorkout:(HKObject *)workout error:(NSError **)error
{
    if (![self mayShareType:[(HKSample *)workout charon_typeForSaving]]) {
        if (error)
            *error = CharonHKError(HKErrorAuthorizationDenied,
                                   [NSString stringWithFormat:@"Sharing %@ data has not been authorized.",
                                                              [(HKSample *)workout charon_typeForSaving].identifier],
                                   nil);
        return NO;
    }
    __block BOOL ok = NO;
    __block NSError *failure = nil;
    [_lock lock];
    @try {
        ok = [self charon_transactionLocked:^BOOL(NSError **inner) {
            for (HKObject *sample in samples)
                if (![self charon_runLocked:@"INSERT OR REPLACE INTO correlated (correlation, member, position) VALUES (?, ?, ?)"
                                  bindings:@[workout.UUID.UUIDString, sample.UUID.UUIDString, @0]
                                     error:inner])
                    return NO;
            return YES;
        } error:&failure];
    } @finally {
        [_lock unlock];
    }
    if (ok)
        [self charon_publishChanged:[samples valueForKey:@"UUID"]];
    else if (error)
        *error = failure;
    return ok;
}

- (BOOL)deleteObjects:(NSArray *)objects error:(NSError **)error
{
    if (!objects.count)
        return YES;
    NSMutableArray<NSString *> *changed = [NSMutableArray array];
    __block BOOL ok = NO;
    __block NSError *failure = nil;
    [_lock lock];
    @try {
        ok = [self charon_transactionLocked:^BOOL(NSError **inner) {
            for (HKObject *object in objects) {
                if (![self charon_removeLocked:object.UUID.UUIDString error:inner])
                    return NO;
                [changed addObject:object.UUID.UUIDString];
            }
            return YES;
        } error:&failure];
        if (ok)
            [self charon_runLocked:@"INSERT OR REPLACE INTO meta (key, value) VALUES ('sequence', ?)"
                          bindings:@[[[NSNumber numberWithInteger:_sequence] stringValue]] error:NULL];
    } @finally {
        [_lock unlock];
    }
    if (ok)
        [self charon_publishChanged:changed];
    else if (error)
        *error = failure;
    return ok;
}

- (BOOL)charon_removeLocked:(NSString *)uuid error:(NSError **)error
{
    if (![self charon_runLocked:@"DELETE FROM object WHERE uuid = ?" bindings:@[uuid] error:error])
        return NO;
    if (![self charon_runLocked:@"DELETE FROM correlated WHERE correlation = ? OR member = ?" bindings:@[uuid, uuid] error:error])
        return NO;
    return [self charon_runLocked:@"INSERT OR REPLACE INTO deleted (uuid, sequence) VALUES (?, ?)"
                        bindings:@[uuid, @([self charon_nextSequenceLocked])]
                           error:error];
}

- (NSUInteger)deleteObjectsOfType:(HKObjectType *)type predicate:(nullable NSPredicate *)predicate error:(NSError **)error
{
    NSArray *found = [self objectsOfType:type
                                predicate:predicate
                                startDate:nil
                                  endDate:nil
                        strictStartDate:NO
                          strictEndDate:NO
                                 limit:0
                         sortDescriptors:nil
                           fromSequence:0
                                  error:error];
    if (!found)
        return 0;
    if (![self deleteObjects:found error:error])
        return 0;
    return found.count;
}

#pragma mark Reading

- (CharonHKRow *)charon_rowFrom:(NSDictionary *)raw
{
    CharonHKRow *row = [[CharonHKRow alloc] init];
    NSString *uuid = [raw objectForKey:@"uuid"];
    id version = [raw objectForKey:@"source_version"];
    [row setValue:[[[NSUUID alloc] initWithUUIDString:uuid] copy] forKey:@"uuid"];
    [row setValue:[raw objectForKey:@"type"] forKey:@"type"];
    [row setValue:@([[raw objectForKey:@"kind"] integerValue]) forKey:@"kind"];
    [row setValue:@([[raw objectForKey:@"start"] doubleValue]) forKey:@"start"];
    [row setValue:@([[raw objectForKey:@"end"] doubleValue]) forKey:@"end"];
    [row setValue:@([[raw objectForKey:@"sequence"] integerValue]) forKey:@"sequence"];
    [row setValue:@([[raw objectForKey:@"created"] doubleValue]) forKey:@"created"];
    [row setValue:[raw objectForKey:@"source_bundle"] forKey:@"sourceBundle"];
    [row setValue:[raw objectForKey:@"source_name"] forKey:@"sourceName"];
    [row setValue:[version isKindOfClass:[NSString class]] ? version : nil forKey:@"sourceVersion"];
    [row setValue:[raw objectForKey:@"archive"] forKey:@"archive"];
    return row;
}

// The source revision and the device a read object is given, from the row it was read from: the
// revision is the source the object was saved with and the version the process was at when it saved it,
// which is what the header says a retrieved object's sourceRevision is, and the device is the one the
// sample named.
- (void)charon_annotate:(id)object source:(CharonHKRow *)row
{
    if (![object respondsToSelector:@selector(charon_setSourceRevision:device:)])
        return;
    HKSourceRevision *revision = [[HKSourceRevision alloc] charon_initWithSource:[HKSource charon_sourceWithName:row.sourceName
                                                                                          bundleIdentifier:row.sourceBundle]
                                                                        version:row.sourceVersion];
    [object charon_setSourceRevision:revision device:nil];
}

// The correlation or the workout a sample belongs to, filled in from the table that records it, so
// that a predicate built with HKPredicateKeyPathCorrelation or HKPredicateKeyPathWorkout walks a
// real relationship over the objects the store read back.
- (void)charon_linkMembershipOf:(id)object uuid:(NSString *)uuid
{
    if (![object respondsToSelector:@selector(charon_setCorrelation:)])
        return;
    for (NSDictionary *row in [self charon_rowsLocked:@"SELECT correlation FROM correlated WHERE member = ?"
                                          bindings:@[uuid]]) {
        NSString *owner = [row objectForKey:@"correlation"];
        NSDictionary *raw = [self charon_rowsLocked:@"SELECT * FROM object WHERE uuid = ?" bindings:@[owner]].firstObject;
        if (!raw)
            continue;
        CharonHKRow *ownerRow = [self charon_rowFrom:raw];
        id parent = [CharonHKClassForObjectKind(ownerRow.kind) charon_objectFromArchive:ownerRow.archive
                                                                                   type:[self typeWithIdentifier:ownerRow.type]
                                                                                  store:self];
        if (parent)
            [object charon_setCorrelation:parent];
    }
}

- (nullable NSArray *)objectsOfType:(HKObjectType *)type
                          predicate:(nullable NSPredicate *)predicate
                          startDate:(nullable NSDate *)startDate
                            endDate:(nullable NSDate *)endDate
                  strictStartDate:(BOOL)strictStartDate
                    strictEndDate:(BOOL)strictEndDate
                           limit:(NSUInteger)limit
                   sortDescriptors:(nullable NSArray *)sortDescriptors
                     fromSequence:(NSInteger)fromSequence
                             error:(NSError **)error
{
    if (![self charon_openLocked:error])
        return nil;
    if (![self mayReadType:type]) {
        if (error)
            *error = CharonHKError(HKErrorAuthorizationDenied,
                                   [NSString stringWithFormat:@"Reading %@ data has not been authorized.", type.identifier],
                                   nil);
        return nil;
    }
    __block NSMutableArray *objects = [NSMutableArray array];
    [_lock lock];
    @try {
        NSMutableString *sql = [NSMutableString stringWithString:@"SELECT * FROM object WHERE type = ?"];
        NSMutableArray *bindings = [NSMutableArray arrayWithObject:type.identifier];
        if (startDate && endDate) {
            // A sample is inside the period when its end is at or after the start of the period and
            // its start before the end of it. The strict options ask for one of the two dates to be
            // in the period on its own, which is what the header says they change.
            if (strictStartDate)
                [sql appendString:@" AND start >= ? AND start < ?"];
            else if (strictEndDate)
                [sql appendString:@" AND end >= ? AND end < ?"];
            else
                [sql appendString:@" AND end >= ? AND start < ?"];
            [bindings addObject:@([startDate timeIntervalSince1970])];
            [bindings addObject:@([endDate timeIntervalSince1970])];
        }
        if (fromSequence > 0) {
            [sql appendString:@" AND sequence > ?"];
            [bindings addObject:@(fromSequence)];
        }
        [sql appendString:@" ORDER BY start, uuid"];
        for (NSDictionary *raw in [self charon_rowsLocked:sql bindings:bindings]) {
            CharonHKRow *row = [self charon_rowFrom:raw];
            id object = [CharonHKClassForObjectKind(row.kind) charon_objectFromArchive:row.archive type:type store:self];
            if (!object)
                continue;
            [self charon_linkMembershipOf:object uuid:row.uuid.UUIDString];
            [self charon_annotate:object source:row];
            if (predicate && ![predicate evaluateWithObject:object])
                continue;
            [objects addObject:object];
        }
        if (sortDescriptors.count)
            [objects sortUsingDescriptors:sortDescriptors];
        if (limit && objects.count > limit)
            [objects removeObjectsInRange:NSMakeRange(limit, objects.count - limit)];
    } @finally {
        [_lock unlock];
    }
    return objects;
}

- (nullable NSArray *)objectsWithUUIDs:(NSArray<NSUUID *> *)uuids ofType:(HKObjectType *)type error:(NSError **)error
{
    if (![self charon_openLocked:error])
        return nil;
    if (![self mayReadType:type]) {
        if (error)
            *error = CharonHKError(HKErrorAuthorizationDenied,
                                   [NSString stringWithFormat:@"Reading %@ data has not been authorized.", type.identifier],
                                   nil);
        return nil;
    }
    NSMutableArray *objects = [NSMutableArray array];
    __block NSError *failure = nil;
    [_lock lock];
    @try {
        for (NSUUID *uuid in uuids) {
            NSDictionary *raw = [self charon_rowsLocked:@"SELECT * FROM object WHERE uuid = ? AND type = ?"
                                             bindings:@[uuid.UUIDString, type.identifier]].firstObject;
            if (!raw)
                continue;
            id object = [CharonHKClassForObjectKind([[raw objectForKey:@"kind"] integerValue])
                             charon_objectFromArchive:[raw objectForKey:@"archive"] type:type store:self];
            if (object)
                [objects addObject:object];
        }
    } @finally {
        [_lock unlock];
    }
    if (!objects && failure)
        if (error)
            *error = failure;
    return objects;
}

- (NSInteger)highestSequence
{
    __block NSInteger sequence = 0;
    [_lock lock];
    @try {
        if (![self charon_openLocked:NULL])
            return 0;
        sequence = [[self charon_rowsLocked:@"SELECT MAX(sequence) AS top FROM object" bindings:@[]].firstObject[@"top"] integerValue];
    } @finally {
        [_lock unlock];
    }
    return sequence;
}

- (nullable NSArray *)deletedObjectsSinceSequence:(NSInteger)sequence
{
    NSMutableArray *deleted = [NSMutableArray array];
    for (NSUUID *uuid in [self deletedUUIDsSinceSequence:sequence])
        [deleted addObject:[[HKDeletedObject alloc] charon_initWithUUID:uuid]];
    return deleted;
}

- (NSArray *)deletedUUIDsSinceSequence:(NSInteger)sequence
{
    __block NSMutableArray *uuids = [NSMutableArray array];
    [_lock lock];
    @try {
        if (![self charon_openLocked:NULL])
            return @[];
        for (NSDictionary *row in [self charon_rowsLocked:@"SELECT uuid FROM deleted WHERE sequence > ? ORDER BY sequence"
                                        bindings:@[@(sequence)]]) {
            NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:[row objectForKey:@"uuid"]];
            if (uuid)
                [uuids addObject:uuid];
        }
    } @finally {
        [_lock unlock];
    }
    return uuids;
}

#pragma mark Workout routes

// The metadata of a route, as a property list, or NULL where it is not one - the header types the
// dictionary as strings, and anything else is not a route's metadata and is not stored.
static NSData *CharonHKRouteMetadataArchive(NSDictionary *metadata)
{
    if (!metadata)
        return nil;
    if (![NSPropertyListSerialization propertyList:metadata isValidForFormat:NSPropertyListBinaryFormat_v1_0])
        return nil;
    return [NSPropertyListSerialization dataWithPropertyList:metadata
                                                     format:NSPropertyListBinaryFormat_v1_0
                                                    options:0
                                                      error:NULL];
}

- (void)setWorkoutRoute:(HKWorkoutRoute *)route
             forWorkout:(HKWorkout *)workout
                 device:(nullable HKDevice *)device
              metadata:(nullable NSDictionary *)metadata
                 error:(NSError **)error
{
    if (![route isKindOfClass:[HKWorkoutRoute class]] || ![workout isKindOfClass:[HKWorkout class]]) {
        if (error)
            *error = CharonHKError(HKErrorInvalidArgument, @"A route and a workout are both needed.", nil);
        return;
    }
    NSMutableData *joined = [NSMutableData data];
    NSData *bytes = [CharonHKStore charon_routeDataOf:route];
    [joined appendData:bytes];
    NSString *key = device.localIdentifier ?: @"";
    __block BOOL ok = NO;
    __block NSError *failure = nil;
    [_lock lock];
    @try {
        ok = [self charon_runLocked:@"INSERT OR REPLACE INTO workout_route (workout, device, route, metadata) VALUES (?, ?, ?, ?)"
                            bindings:@[workout.UUID.UUIDString, key, joined, CharonHKRouteMetadataArchive(metadata) ?: [NSNull null]]
                               error:&failure];
    } @finally {
        [_lock unlock];
    }
    if (!ok && error)
        *error = failure;
}

// The bytes of a route, read back out of the archive it was made with, so that what a query hands its
// caller is what the builder inserted.
+ (NSData *)charon_routeDataOf:(HKWorkoutRoute *)route
{
    // The bytes are read back out of the route's own archive, which is the same round trip the release
    // makes, so what a query hands its caller is what the builder inserted.
    NSData *archive = [NSKeyedArchiver archivedDataWithRootObject:route];
    if (!archive.length)
        return [NSData data];
    NSKeyedUnarchiver *reader = [[NSKeyedUnarchiver alloc] initForReadingWithData:archive];
    NSData *bytes = [reader decodeObjectOfClass:[NSData class] forKey:@"routeData"];
    [reader finishDecoding];
    return bytes ?: [NSData data];
}

- (NSData *)routeDataOf:(HKWorkoutRoute *)route
{
    return [CharonHKStore charon_routeDataOf:route];
}

#pragma mark Documents

// The documents of one type. A document sample is a sample, so it is read back out of the same table
// through the same archive; what a document query adds is the flag that says whether the data of the
// document comes back with it, which the header's -includeDocumentData asks for and which a caller
// that reads the data needs.
- (NSArray *)documentsOfType:(HKDocumentType *)type
                   predicate:(nullable NSPredicate *)predicate
                      limit:(NSUInteger)limit
           sortDescriptors:(nullable NSArray *)sortDescriptors
        includeDocumentData:(BOOL)includeDocumentData
                    error:(NSError **)error
{
    NSArray *found = [self objectsOfType:type
                    predicate:predicate
                    startDate:nil
                      endDate:nil
            strictStartDate:NO
              strictEndDate:NO
                     limit:limit
             sortDescriptors:sortDescriptors
               fromSequence:0
                      error:error];
    if (!found)
        return nil;
    if (includeDocumentData)
        return found;
    NSMutableArray *without = [NSMutableArray arrayWithCapacity:found.count];
    for (HKDocumentSample *sample in found) {
        // The same sample with its document's facts left out, which is what the flag asks for: the
        // sample and its type are kept, and the data, the title and the three names are not sent.
        NSMutableDictionary *facts = [NSMutableDictionary dictionaryWithDictionary:[sample metadata]];
        [facts removeObjectForKey:@"_charon_document"];
        [without addObject:[sample charon_copyWithoutDocument:facts]];
    }
    return without;
}

#pragma mark Activity summaries

// The days the store holds a ring for. Nothing writes that table on this release - see the header's
// note on it - and it is read the same way every other object is: the archive of the object, beside the
// day it is for so that a query can be narrowed by date before anything is read back.
- (NSArray *)activitySummariesMatching:(nullable NSPredicate *)predicate error:(NSError **)error
{
    __block NSMutableArray *summaries = [NSMutableArray array];
    [_lock lock];
    @try {
        if (![self charon_openLocked:error])
            return nil;
        for (NSDictionary *raw in [self charon_rowsLocked:@"SELECT * FROM activity_summary ORDER BY start" bindings:@[]]) {
            id summary = [HKActivitySummary charon_objectFromArchive:[raw objectForKey:@"archive"]
                                                                type:[HKObjectType activitySummaryType]
                                                               store:self];
            if (!summary)
                continue;
            if (predicate && ![predicate evaluateWithObject:summary])
                continue;
            [summaries addObject:summary];
        }
    } @finally {
        [_lock unlock];
    }
    return summaries;
}

#pragma mark Sources

- (HKSource *)charon_sourceFrom:(NSDictionary *)raw
{
    return [HKSource charon_sourceWithName:[raw objectForKey:@"source_name"]
                          bundleIdentifier:[raw objectForKey:@"source_bundle"]];
}

- (NSArray *)allSources
{
    __block NSMutableArray *sources = [NSMutableArray array];
    [_lock lock];
    @try {
        if (![self charon_openLocked:NULL])
            return @[];
        for (NSDictionary *raw in [self charon_rowsLocked:@"SELECT DISTINCT source_bundle, source_name, source_version FROM object WHERE source_name <> '' ORDER BY source_name"
                                         bindings:@[]])
            [sources addObject:[self charon_sourceFrom:raw]];
    } @finally {
        [_lock unlock];
    }
    return sources;
}

- (NSArray *)sourcesForType:(HKObjectType *)type
{
    __block NSMutableArray *sources = [NSMutableArray array];
    [_lock lock];
    @try {
        if (![self charon_openLocked:NULL])
            return @[];
        NSMutableDictionary<NSString *, NSNumber *> *order = [NSMutableDictionary dictionary];
        for (NSDictionary *row in [self charon_rowsLocked:@"SELECT bundle, position FROM source_order WHERE type = ? ORDER BY position"
                                        bindings:@[type.identifier]])
            order[[row objectForKey:@"bundle"]] = @([[row objectForKey:@"position"] integerValue]);
        for (NSDictionary *raw in [self charon_rowsLocked:@"SELECT DISTINCT source_bundle, source_name, source_version FROM object WHERE type = ? AND source_name <> '' ORDER BY source_name"
                                         bindings:@[type.identifier]])
            [sources addObject:[self charon_sourceFrom:raw]];
        [sources sortUsingComparator:^NSComparisonResult(HKSource *left, HKSource *right) {
            NSNumber *l = order[left.bundleIdentifier ?: @""], *r = order[right.bundleIdentifier ?: @""];
            if (l && r)
                return [l compare:r];
            if (l)
                return NSOrderedAscending;
            if (r)
                return NSOrderedDescending;
            return [left.name compare:right.name];
        }];
    } @finally {
        [_lock unlock];
    }
    return sources;
}

- (BOOL)deleteSourceWithBundleIdentifier:(NSString *)bundleIdentifier error:(NSError **)error
{
    __block BOOL ok = NO;
    __block NSError *failure = nil;
    [_lock lock];
    @try {
        ok = [self charon_transactionLocked:^BOOL(NSError **inner) {
            for (NSDictionary *row in [self charon_rowsLocked:@"SELECT uuid FROM object WHERE source_bundle = ?"
                                        bindings:@[bundleIdentifier]])
                if (![self charon_removeLocked:[row objectForKey:@"uuid"] error:inner])
                    return NO;
            if (![self charon_runLocked:@"DELETE FROM source_order WHERE bundle = ?" bindings:@[bundleIdentifier] error:inner])
                return NO;
            return YES;
        } error:&failure];
    } @finally {
        [_lock unlock];
    }
    if (!ok && error)
        *error = failure;
    return ok;
}

- (BOOL)setOrderedSources:(NSArray *)sources forType:(HKObjectType *)type error:(NSError **)error
{
    __block BOOL ok = NO;
    __block NSError *failure = nil;
    [_lock lock];
    @try {
        ok = [self charon_transactionLocked:^BOOL(NSError **inner) {
            if (![self charon_runLocked:@"DELETE FROM source_order WHERE type = ?" bindings:@[type.identifier] error:inner])
                return NO;
            NSUInteger position = 0;
            for (HKSource *source in sources)
                if (![self charon_runLocked:@"INSERT OR REPLACE INTO source_order (type, bundle, position) VALUES (?, ?, ?)"
                                  bindings:@[type.identifier, source.bundleIdentifier ?: @"", @(position++)]
                                     error:inner])
                    return NO;
            return YES;
        } error:&failure];
    } @finally {
        [_lock unlock];
    }
    if (!ok && error)
        *error = failure;
    return ok;
}

#pragma mark Background delivery

- (BOOL)setBackgroundDelivery:(BOOL)enabled forType:(HKObjectType *)type frequency:(NSUInteger)frequency error:(NSError **)error
{
    __block BOOL ok = NO;
    __block NSError *failure = nil;
    [_lock lock];
    @try {
        if (![self charon_openLocked:&failure])
            return NO;
        ok = enabled ? [self charon_runLocked:@"INSERT OR REPLACE INTO background_delivery (type, frequency) VALUES (?, ?)"
                                        bindings:@[type.identifier, @(frequency)]
                                           error:&failure]
                     : [self charon_runLocked:@"DELETE FROM background_delivery WHERE type = ? AND frequency = ?"
                                        bindings:@[type.identifier, @(frequency)]
                                           error:&failure];
    } @finally {
        [_lock unlock];
    }
    if (!ok && error)
        *error = failure;
    return ok;
}

- (BOOL)disableAllBackgroundDeliveryWithError:(NSError **)error
{
    __block BOOL ok = NO;
    __block NSError *failure = nil;
    [_lock lock];
    @try {
        ok = [self charon_openLocked:NULL]
             && [self charon_runLocked:@"DELETE FROM background_delivery" bindings:@[] error:&failure];
    } @finally {
        [_lock unlock];
    }
    if (!ok && error)
        *error = failure;
    return ok;
}

#pragma mark Anchors

- (nullable id)anchorForActivationUUID:(NSUUID *)uuid
{
    __block id anchor = nil;
    [_lock lock];
    @try {
        if (![self charon_openLocked:NULL])
            return nil;
        NSData *data = [self charon_rowsLocked:@"SELECT data FROM anchor WHERE uuid = ?" bindings:@[uuid.UUIDString]].firstObject[@"data"];
        if (![data isKindOfClass:[NSData class]])
            return nil;
        anchor = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    } @finally {
        [_lock unlock];
    }
    return anchor;
}

- (void)setAnchor:(nullable id)anchor forActivationUUID:(NSUUID *)uuid
{
    NSData *data = anchor ? [NSKeyedArchiver archivedDataWithRootObject:anchor] : nil;
    [_lock lock];
    @try {
        if (![self charon_openLocked:NULL])
            return;
        if (data)
            [self charon_runLocked:@"INSERT OR REPLACE INTO anchor (uuid, data) VALUES (?, ?)" bindings:@[uuid.UUIDString, data] error:NULL];
        else
            [self charon_runLocked:@"DELETE FROM anchor WHERE uuid = ?" bindings:@[uuid.UUIDString] error:NULL];
    } @finally {
        [_lock unlock];
    }
}

#pragma mark Observers

- (void)addObserver:(id)observer forTypes:(nullable NSSet *)types
{
    @synchronized(_observers) {
        [_observers addObject:@{@"observer": observer, @"types": types ?: [NSSet set]}];
    }
}

- (void)removeObserver:(id)observer
{
    @synchronized(_observers) {
        NSMutableArray *kept = [NSMutableArray array];
        for (NSDictionary *entry in _observers)
            if (entry[@"observer"] != observer)
                [kept addObject:entry];
        [_observers setArray:kept];
    }
}

// Every write and every delete tells the observers what changed, as this database's own did: an
// observer query is answered with everything written since it last ran, an anchored query with the
// objects that changed and the sequence past them.
- (void)charon_publishChanged:(NSArray<NSString *> *)uuids
{
    if (!uuids.count)
        return;
    NSMutableArray<NSUUID *> *identifiers = [NSMutableArray arrayWithCapacity:uuids.count];
    for (NSString *uuid in uuids) {
        NSUUID *parsed = [[NSUUID alloc] initWithUUIDString:uuid];
        if (parsed)
            [identifiers addObject:parsed];
    }
    NSArray *observers = nil;
    @synchronized(_observers) {
        observers = [_observers copy];
    }
    for (NSDictionary *entry in observers) {
        id observer = entry[@"observer"];
        if ([observer respondsToSelector:@selector(charon_storeDidChange:)])
            [observer charon_storeDidChange:identifiers];
    }
}

@end
