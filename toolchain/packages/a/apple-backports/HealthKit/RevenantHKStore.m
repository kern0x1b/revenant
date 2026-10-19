#import <sqlite3.h>

#import "RevenantHKStore.h"
#import "../RevenantSayOnce.h"

#pragma mark - Errors

NSError *RevenantHKError(NSInteger code, NSString *description, NSString *debug)
{
    NSMutableDictionary *info = [NSMutableDictionary dictionaryWithObject:description forKey:NSLocalizedDescriptionKey];
    if (debug)
        info[NSDebugDescriptionErrorKey] = debug;
    return [NSError errorWithDomain:HKErrorDomain code:code userInfo:info];
}

void revenant_hk_say_once(NSString *key, NSString *text)
{
    revenant_say_once_for(key, text);
}

#pragma mark - Where the database is

NSString *RevenantHKStorePath(void)
{
    static NSString *path;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSArray *folders = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
        NSString *root = folders.count ? [folders objectAtIndex:0] : NSTemporaryDirectory();
        NSString *folder = [root stringByAppendingPathComponent:@"RevenantHealthKit"];
        NSFileManager *files = [NSFileManager defaultManager];
        if (![files fileExistsAtPath:folder])
            [files createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:NULL];
        path = [folder stringByAppendingPathComponent:@"healthkit.sqlite3"];
    });
    return path;
}

#pragma mark - The row

@interface RevenantHKRow ()
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

@implementation RevenantHKRow
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

typedef NS_ENUM(NSUInteger, RevenantHKAuthorizationBits) {
    RevenantHKAuthorizationShare = 1u << 0,
    RevenantHKAuthorizationRead = 1u << 1,
};

@implementation RevenantHKStore {
    sqlite3 *_database;
    NSRecursiveLock *_lock;
    NSMutableDictionary<NSString *, NSNumber *> *_authorization;
    NSMutableArray *_observers;
    NSInteger _sequence;
    BOOL _opened;
}

@synthesize path = _path;
@synthesize open = _open;

+ (RevenantHKStore *)sharedStore
{
    static RevenantHKStore *store;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        store = [[RevenantHKStore alloc] init];
    });
    return store;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _path = [RevenantHKStorePath() copy];
        _lock = [[NSRecursiveLock alloc] init];
        _lock.name = @"org.revenant.healthkit.store";
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

- (BOOL)revenant_openLocked:(NSError **)error
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
            *error = RevenantHKError(HKErrorHealthDataUnavailable,
                                   [NSString stringWithFormat:@"The health database at %@ could not be opened: %s.", _path,
                                                              _database ? sqlite3_errmsg(_database) : "no database"], nil);
        if (_database) {
            sqlite3_close(_database);
            _database = NULL;
        }
        return NO;
    }
    sqlite3_busy_timeout(_database, 5000);
    if (![self revenant_schemaLocked:error]) {
        sqlite3_close(_database);
        _database = NULL;
        return NO;
    }
    [self revenant_loadLocked];
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
        ok = [self revenant_openLocked:&failure];
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

- (void)revenant_loadLocked
{
    for (NSDictionary *row in [self revenant_rowsLocked:@"SELECT type, share, read FROM authorization" bindings:@[]])
        _authorization[[row objectForKey:@"type"]] = @([[row objectForKey:@"share"] integerValue] * RevenantHKAuthorizationShare
                                                       | [[row objectForKey:@"read"] integerValue] * RevenantHKAuthorizationRead);
    NSArray *rows = [self revenant_rowsLocked:@"SELECT value FROM meta WHERE key = 'sequence'" bindings:@[]];
    _sequence = [[rows.firstObject objectForKey:@"value"] integerValue];
}

#pragma mark SQL

- (BOOL)revenant_runLocked:(NSString *)sql bindings:(NSArray *)bindings error:(NSError **)error
{
    sqlite3_stmt *statement = NULL;
    if (!_database) {
        if (error)
            *error = RevenantHKError(HKErrorHealthDataUnavailable, @"The health database is not open.", nil);
        return NO;
    }
    if (sqlite3_prepare_v2(_database, [sql UTF8String], -1, &statement, NULL) != SQLITE_OK) {
        if (error)
            *error = RevenantHKError(HKErrorHealthDataUnavailable,
                                   [NSString stringWithFormat:@"The health database refused a statement: %s.",
                                                              sqlite3_errmsg(_database)], sql);
        return NO;
    }
    [self revenant_bindLocked:statement bindings:bindings];
    int stepped = sqlite3_step(statement);
    sqlite3_finalize(statement);
    if (stepped != SQLITE_DONE) {
        if (error)
            *error = RevenantHKError(HKErrorHealthDataUnavailable,
                                   [NSString stringWithFormat:@"The health database refused a write: %s.",
                                                              sqlite3_errmsg(_database)], nil);
        return NO;
    }
    return YES;
}

- (void)revenant_bindLocked:(sqlite3_stmt *)statement bindings:(NSArray *)bindings
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

- (NSArray *)revenant_rowsLocked:(NSString *)sql bindings:(NSArray *)bindings
{
    if (!_database)
        return @[];
    sqlite3_stmt *statement = NULL;
    if (sqlite3_prepare_v2(_database, [sql UTF8String], -1, &statement, NULL) != SQLITE_OK)
        return @[];
    [self revenant_bindLocked:statement bindings:bindings];
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

- (BOOL)revenant_schemaLocked:(NSError **)error
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
        if (![self revenant_runLocked:sql bindings:@[] error:error])
            return NO;
    return [self revenant_runLocked:@"INSERT OR IGNORE INTO meta (key, value) VALUES ('sequence', '0')" bindings:@[] error:error];
}

- (BOOL)revenant_transactionLocked:(BOOL (^)(NSError **))body error:(NSError **)error
{
    if (![self revenant_openLocked:error])
        return NO;
    if (![self revenant_runLocked:@"BEGIN IMMEDIATE" bindings:@[] error:error])
        return NO;
    NSError *failure = nil;
    if (!body(&failure)) {
        [self revenant_runLocked:@"ROLLBACK" bindings:@[] error:NULL];
        if (error)
            *error = failure;
        return NO;
    }
    return [self revenant_runLocked:@"COMMIT" bindings:@[] error:error];
}

- (NSInteger)revenant_nextSequenceLocked
{
    return ++_sequence;
}

#pragma mark Types

- (BOOL)declareType:(HKObjectType *)type error:(NSError **)error
{
    if (![type conformsToProtocol:@protocol(RevenantHKTyped)]) {
        if (error)
            *error = RevenantHKError(HKErrorInvalidArgument,
                                   [NSString stringWithFormat:@"A %@ is not a type this database can keep.",
                                                              NSStringFromClass([type class])], nil);
        return NO;
    }
    id<RevenantHKTyped> typed = (id<RevenantHKTyped>)type;
    __block BOOL ok = NO;
    __block NSError *failure = nil;
    [_lock lock];
    @try {
        ok = [self revenant_transactionLocked:^BOOL(NSError **inner) {
            return [self revenant_runLocked:@"INSERT OR REPLACE INTO type (identifier, kind, unit, aggregation) VALUES (?, ?, ?, ?)"
                                 bindings:@[type.identifier, @([typed revenant_storeKind]),
                                            [typed revenant_canonicalUnitString] ?: [NSNull null],
                                            @([typed revenant_aggregationStyleValue])]
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
        if (![self revenant_openLocked:NULL])
            return nil;
        NSDictionary *row = [self revenant_rowsLocked:@"SELECT kind, unit, aggregation FROM type WHERE identifier = ?"
                                         bindings:@[identifier]].firstObject;
        if (!row)
            return nil;
        NSInteger kind = [[row objectForKey:@"kind"] integerValue];
        Class cls = RevenantHKClassForTypeKind(kind);
        if (!cls)
            return nil;
        HKObjectType *type = [cls revenant_typeWithIdentifier:identifier];
        id unit = [row objectForKey:@"unit"];
        if ([unit isKindOfClass:[NSString class]])
            [(id<RevenantHKTyped>)type revenant_setCanonicalUnitString:unit aggregationStyle:[[row objectForKey:@"aggregation"] integerValue]];
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
        asked[type.identifier] = @(RevenantHKAuthorizationShare);
    for (HKObjectType *type in typesToRead)
        asked[type.identifier] = @([asked[type.identifier] unsignedIntegerValue] | RevenantHKAuthorizationRead);
    __block BOOL ok = NO;
    __block NSError *failure = nil;
    [_lock lock];
    @try {
        ok = [self revenant_transactionLocked:^BOOL(NSError **inner) {
            for (NSString *identifier in asked) {
                NSUInteger bits = [asked[identifier] unsignedIntegerValue];
                if (![self revenant_runLocked:@"INSERT OR REPLACE INTO authorization (type, share, read) VALUES (?, ?, ?)"
                                  bindings:@[identifier, @((bits & RevenantHKAuthorizationShare) ? 1 : 0),
                                             @((bits & RevenantHKAuthorizationRead) ? 1 : 0)]
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

- (NSUInteger)revenant_bitsForType:(HKObjectType *)type
{
    NSNumber *bits = nil;
    @synchronized(_authorization) {
        bits = _authorization[type.identifier];
    }
    return bits.unsignedIntegerValue;
}

- (BOOL)mayShareType:(HKObjectType *)type
{
    return ([self revenant_bitsForType:type] & RevenantHKAuthorizationShare) != 0;
}

- (BOOL)mayReadType:(HKObjectType *)type
{
    return ([self revenant_bitsForType:type] & RevenantHKAuthorizationRead) != 0;
}

- (HKAuthorizationStatus)authorizationStatusForType:(HKObjectType *)type
{
    NSUInteger bits = [self revenant_bitsForType:type];
    if (!bits)
        return HKAuthorizationStatusNotDetermined;
    if (bits & RevenantHKAuthorizationShare)
        return HKAuthorizationStatusSharingAuthorized;
    return HKAuthorizationStatusSharingDenied;
}

#pragma mark Characteristics

- (nullable id)characteristicForIdentifier:(NSString *)identifier
{
    __block id value = nil;
    [_lock lock];
    @try {
        if (![self revenant_openLocked:NULL])
            return nil;
        NSData *data = [self revenant_rowsLocked:@"SELECT value FROM characteristic WHERE identifier = ?"
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
                *error = RevenantHKError(HKErrorInvalidArgument,
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
        ok = [self revenant_runLocked:@"INSERT OR REPLACE INTO characteristic (identifier, value) VALUES (?, ?)"
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
        ok = [self revenant_transactionLocked:^BOOL(NSError **inner) {
            for (id object in objects) {
                if (![object conformsToProtocol:@protocol(RevenantHKStorable)]) {
                    *inner = RevenantHKError(HKErrorInvalidArgument,
                                           [NSString stringWithFormat:@"A %@ is not a health object this database can keep.",
                                                                      NSStringFromClass([object class])], nil);
                    return NO;
                }
                id<RevenantHKStorable> storable = (id<RevenantHKStorable>)object;
                NSString *identifier = [storable revenant_storeTypeIdentifier];
                if (!identifier.length) {
                    *inner = RevenantHKError(HKErrorInvalidArgument,
                                           [NSString stringWithFormat:@"A %@ has no type, and a sample is saved under one.",
                                                                      NSStringFromClass([object class])], nil);
                    return NO;
                }
                HKObjectType *type = [storable respondsToSelector:@selector(revenant_typeForSaving)]
                                       ? [(id)storable revenant_typeForSaving]
                                       : [self typeWithIdentifier:identifier];
                if (![self mayShareType:type]) {
                    *inner = RevenantHKError(HKErrorAuthorizationDenied,
                                           [NSString stringWithFormat:@"Sharing %@ data has not been authorized.", identifier],
                                           nil);
                    return NO;
                }
                if (![self revenant_runLocked:@"INSERT OR REPLACE INTO type (identifier, kind, unit, aggregation) VALUES (?, ?, ?, ?)"
                                  bindings:@[identifier, @([storable revenant_storeKind]), [NSNull null], @0]
                                     error:inner])
                    return NO;
                NSString *uuid = [(HKObject *)object UUID].UUIDString;
                NSInteger sequence = [self revenant_nextSequenceLocked];
                if (![self revenant_runLocked:@"INSERT OR REPLACE INTO object (uuid, type, kind, start, end, source_bundle, source_name, source_version, sequence, created, archive) "
                                            "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
                                  bindings:@[uuid, identifier, @([storable revenant_storeKind]),
                                             @([(HKSample *)object startDate].timeIntervalSince1970),
                                             @([(HKSample *)object endDate].timeIntervalSince1970),
                                             [(HKObject *)object source].bundleIdentifier ?: @"",
                                             [(HKObject *)object source].name ?: @"",
                                             [HKSource revenant_processVersion] ?: [NSNull null],
                                             @(sequence), @([[NSDate date] timeIntervalSince1970]),
                                             [storable revenant_storeArchive]]
                                     error:inner])
                    return NO;
                if (![self revenant_runLocked:@"DELETE FROM deleted WHERE uuid = ?" bindings:@[uuid] error:inner])
                    return NO;
                if ([object isKindOfClass:[HKCorrelation class]]) {
                    if (![self revenant_runLocked:@"DELETE FROM correlated WHERE correlation = ?" bindings:@[uuid] error:inner])
                        return NO;
                    NSUInteger position = 0;
                    for (HKObject *member in [(HKCorrelation *)object revenant_allObjects])
                        if (![self revenant_runLocked:@"INSERT OR REPLACE INTO correlated (correlation, member, position) VALUES (?, ?, ?)"
                                          bindings:@[uuid, member.UUID.UUIDString, @(position++)]
                                             error:inner])
                            return NO;
                }
                [changed addObject:uuid];
            }
            return YES;
        } error:&failure];
        if (ok)
            [self revenant_runLocked:@"INSERT OR REPLACE INTO meta (key, value) VALUES ('sequence', ?)"
                          bindings:@[[[NSNumber numberWithInteger:_sequence] stringValue]] error:NULL];
    } @finally {
        [_lock unlock];
    }
    if (ok)
        [self revenant_publishChanged:changed];
    else if (error)
        *error = failure;
    return ok;
}

- (BOOL)addSamples:(NSArray *)samples toWorkout:(HKObject *)workout error:(NSError **)error
{
    if (![self mayShareType:[(HKSample *)workout revenant_typeForSaving]]) {
        if (error)
            *error = RevenantHKError(HKErrorAuthorizationDenied,
                                   [NSString stringWithFormat:@"Sharing %@ data has not been authorized.",
                                                              [(HKSample *)workout revenant_typeForSaving].identifier],
                                   nil);
        return NO;
    }
    __block BOOL ok = NO;
    __block NSError *failure = nil;
    [_lock lock];
    @try {
        ok = [self revenant_transactionLocked:^BOOL(NSError **inner) {
            for (HKObject *sample in samples)
                if (![self revenant_runLocked:@"INSERT OR REPLACE INTO correlated (correlation, member, position) VALUES (?, ?, ?)"
                                  bindings:@[workout.UUID.UUIDString, sample.UUID.UUIDString, @0]
                                     error:inner])
                    return NO;
            return YES;
        } error:&failure];
    } @finally {
        [_lock unlock];
    }
    if (ok)
        [self revenant_publishChanged:[samples valueForKey:@"UUID"]];
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
        ok = [self revenant_transactionLocked:^BOOL(NSError **inner) {
            for (HKObject *object in objects) {
                if (![self revenant_removeLocked:object.UUID.UUIDString error:inner])
                    return NO;
                [changed addObject:object.UUID.UUIDString];
            }
            return YES;
        } error:&failure];
        if (ok)
            [self revenant_runLocked:@"INSERT OR REPLACE INTO meta (key, value) VALUES ('sequence', ?)"
                          bindings:@[[[NSNumber numberWithInteger:_sequence] stringValue]] error:NULL];
    } @finally {
        [_lock unlock];
    }
    if (ok)
        [self revenant_publishChanged:changed];
    else if (error)
        *error = failure;
    return ok;
}

- (BOOL)revenant_removeLocked:(NSString *)uuid error:(NSError **)error
{
    if (![self revenant_runLocked:@"DELETE FROM object WHERE uuid = ?" bindings:@[uuid] error:error])
        return NO;
    if (![self revenant_runLocked:@"DELETE FROM correlated WHERE correlation = ? OR member = ?" bindings:@[uuid, uuid] error:error])
        return NO;
    return [self revenant_runLocked:@"INSERT OR REPLACE INTO deleted (uuid, sequence) VALUES (?, ?)"
                        bindings:@[uuid, @([self revenant_nextSequenceLocked])]
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

- (RevenantHKRow *)revenant_rowFrom:(NSDictionary *)raw
{
    RevenantHKRow *row = [[RevenantHKRow alloc] init];
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

- (void)revenant_annotate:(id)object source:(RevenantHKRow *)row
{
    if (![object respondsToSelector:@selector(revenant_setSourceRevision:device:)])
        return;
    HKSourceRevision *revision = [[HKSourceRevision alloc] revenant_initWithSource:[HKSource revenant_sourceWithName:row.sourceName
                                                                                          bundleIdentifier:row.sourceBundle]
                                                                        version:row.sourceVersion];
    [object revenant_setSourceRevision:revision device:nil];
}

- (void)revenant_linkMembershipOf:(id)object uuid:(NSString *)uuid
{
    if (![object respondsToSelector:@selector(revenant_setCorrelation:)])
        return;
    for (NSDictionary *row in [self revenant_rowsLocked:@"SELECT correlation FROM correlated WHERE member = ?"
                                          bindings:@[uuid]]) {
        NSString *owner = [row objectForKey:@"correlation"];
        NSDictionary *raw = [self revenant_rowsLocked:@"SELECT * FROM object WHERE uuid = ?" bindings:@[owner]].firstObject;
        if (!raw)
            continue;
        RevenantHKRow *ownerRow = [self revenant_rowFrom:raw];
        id parent = [RevenantHKClassForObjectKind(ownerRow.kind) revenant_objectFromArchive:ownerRow.archive
                                                                                   type:[self typeWithIdentifier:ownerRow.type]
                                                                                  store:self];
        if (parent)
            [object revenant_setCorrelation:parent];
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
    if (![self revenant_openLocked:error])
        return nil;
    if (![self mayReadType:type]) {
        if (error)
            *error = RevenantHKError(HKErrorAuthorizationDenied,
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
        for (NSDictionary *raw in [self revenant_rowsLocked:sql bindings:bindings]) {
            RevenantHKRow *row = [self revenant_rowFrom:raw];
            id object = [RevenantHKClassForObjectKind(row.kind) revenant_objectFromArchive:row.archive type:type store:self];
            if (!object)
                continue;
            [self revenant_linkMembershipOf:object uuid:row.uuid.UUIDString];
            [self revenant_annotate:object source:row];
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
    if (![self revenant_openLocked:error])
        return nil;
    if (![self mayReadType:type]) {
        if (error)
            *error = RevenantHKError(HKErrorAuthorizationDenied,
                                   [NSString stringWithFormat:@"Reading %@ data has not been authorized.", type.identifier],
                                   nil);
        return nil;
    }
    NSMutableArray *objects = [NSMutableArray array];
    __block NSError *failure = nil;
    [_lock lock];
    @try {
        for (NSUUID *uuid in uuids) {
            NSDictionary *raw = [self revenant_rowsLocked:@"SELECT * FROM object WHERE uuid = ? AND type = ?"
                                             bindings:@[uuid.UUIDString, type.identifier]].firstObject;
            if (!raw)
                continue;
            id object = [RevenantHKClassForObjectKind([[raw objectForKey:@"kind"] integerValue])
                             revenant_objectFromArchive:[raw objectForKey:@"archive"] type:type store:self];
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
        if (![self revenant_openLocked:NULL])
            return 0;
        sequence = [[self revenant_rowsLocked:@"SELECT MAX(sequence) AS top FROM object" bindings:@[]].firstObject[@"top"] integerValue];
    } @finally {
        [_lock unlock];
    }
    return sequence;
}

- (nullable NSArray *)deletedObjectsSinceSequence:(NSInteger)sequence
{
    NSMutableArray *deleted = [NSMutableArray array];
    for (NSUUID *uuid in [self deletedUUIDsSinceSequence:sequence])
        [deleted addObject:[[HKDeletedObject alloc] revenant_initWithUUID:uuid]];
    return deleted;
}

- (NSArray *)deletedUUIDsSinceSequence:(NSInteger)sequence
{
    __block NSMutableArray *uuids = [NSMutableArray array];
    [_lock lock];
    @try {
        if (![self revenant_openLocked:NULL])
            return @[];
        for (NSDictionary *row in [self revenant_rowsLocked:@"SELECT uuid FROM deleted WHERE sequence > ? ORDER BY sequence"
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

static NSData *RevenantHKRouteMetadataArchive(NSDictionary *metadata)
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
            *error = RevenantHKError(HKErrorInvalidArgument, @"A route and a workout are both needed.", nil);
        return;
    }
    NSMutableData *joined = [NSMutableData data];
    NSData *bytes = [RevenantHKStore revenant_routeDataOf:route];
    [joined appendData:bytes];
    NSString *key = device.localIdentifier ?: @"";
    __block BOOL ok = NO;
    __block NSError *failure = nil;
    [_lock lock];
    @try {
        ok = [self revenant_runLocked:@"INSERT OR REPLACE INTO workout_route (workout, device, route, metadata) VALUES (?, ?, ?, ?)"
                            bindings:@[workout.UUID.UUIDString, key, joined, RevenantHKRouteMetadataArchive(metadata) ?: [NSNull null]]
                               error:&failure];
    } @finally {
        [_lock unlock];
    }
    if (!ok && error)
        *error = failure;
}

+ (NSData *)revenant_routeDataOf:(HKWorkoutRoute *)route
{
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
    return [RevenantHKStore revenant_routeDataOf:route];
}

#pragma mark Documents

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
        NSMutableDictionary *facts = [NSMutableDictionary dictionaryWithDictionary:[sample metadata]];
        [facts removeObjectForKey:@"_revenant_document"];
        [without addObject:[sample revenant_copyWithoutDocument:facts]];
    }
    return without;
}

#pragma mark Activity summaries

- (NSArray *)activitySummariesMatching:(nullable NSPredicate *)predicate error:(NSError **)error
{
    __block NSMutableArray *summaries = [NSMutableArray array];
    [_lock lock];
    @try {
        if (![self revenant_openLocked:error])
            return nil;
        for (NSDictionary *raw in [self revenant_rowsLocked:@"SELECT * FROM activity_summary ORDER BY start" bindings:@[]]) {
            id summary = [HKActivitySummary revenant_objectFromArchive:[raw objectForKey:@"archive"]
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

- (HKSource *)revenant_sourceFrom:(NSDictionary *)raw
{
    return [HKSource revenant_sourceWithName:[raw objectForKey:@"source_name"]
                          bundleIdentifier:[raw objectForKey:@"source_bundle"]];
}

- (NSArray *)allSources
{
    __block NSMutableArray *sources = [NSMutableArray array];
    [_lock lock];
    @try {
        if (![self revenant_openLocked:NULL])
            return @[];
        for (NSDictionary *raw in [self revenant_rowsLocked:@"SELECT DISTINCT source_bundle, source_name, source_version FROM object WHERE source_name <> '' ORDER BY source_name"
                                         bindings:@[]])
            [sources addObject:[self revenant_sourceFrom:raw]];
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
        if (![self revenant_openLocked:NULL])
            return @[];
        NSMutableDictionary<NSString *, NSNumber *> *order = [NSMutableDictionary dictionary];
        for (NSDictionary *row in [self revenant_rowsLocked:@"SELECT bundle, position FROM source_order WHERE type = ? ORDER BY position"
                                        bindings:@[type.identifier]])
            order[[row objectForKey:@"bundle"]] = @([[row objectForKey:@"position"] integerValue]);
        for (NSDictionary *raw in [self revenant_rowsLocked:@"SELECT DISTINCT source_bundle, source_name, source_version FROM object WHERE type = ? AND source_name <> '' ORDER BY source_name"
                                         bindings:@[type.identifier]])
            [sources addObject:[self revenant_sourceFrom:raw]];
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
        ok = [self revenant_transactionLocked:^BOOL(NSError **inner) {
            for (NSDictionary *row in [self revenant_rowsLocked:@"SELECT uuid FROM object WHERE source_bundle = ?"
                                        bindings:@[bundleIdentifier]])
                if (![self revenant_removeLocked:[row objectForKey:@"uuid"] error:inner])
                    return NO;
            if (![self revenant_runLocked:@"DELETE FROM source_order WHERE bundle = ?" bindings:@[bundleIdentifier] error:inner])
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
        ok = [self revenant_transactionLocked:^BOOL(NSError **inner) {
            if (![self revenant_runLocked:@"DELETE FROM source_order WHERE type = ?" bindings:@[type.identifier] error:inner])
                return NO;
            NSUInteger position = 0;
            for (HKSource *source in sources)
                if (![self revenant_runLocked:@"INSERT OR REPLACE INTO source_order (type, bundle, position) VALUES (?, ?, ?)"
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
        if (![self revenant_openLocked:&failure])
            return NO;
        ok = enabled ? [self revenant_runLocked:@"INSERT OR REPLACE INTO background_delivery (type, frequency) VALUES (?, ?)"
                                        bindings:@[type.identifier, @(frequency)]
                                           error:&failure]
                     : [self revenant_runLocked:@"DELETE FROM background_delivery WHERE type = ? AND frequency = ?"
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
        ok = [self revenant_openLocked:NULL]
             && [self revenant_runLocked:@"DELETE FROM background_delivery" bindings:@[] error:&failure];
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
        if (![self revenant_openLocked:NULL])
            return nil;
        NSData *data = [self revenant_rowsLocked:@"SELECT data FROM anchor WHERE uuid = ?" bindings:@[uuid.UUIDString]].firstObject[@"data"];
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
        if (![self revenant_openLocked:NULL])
            return;
        if (data)
            [self revenant_runLocked:@"INSERT OR REPLACE INTO anchor (uuid, data) VALUES (?, ?)" bindings:@[uuid.UUIDString, data] error:NULL];
        else
            [self revenant_runLocked:@"DELETE FROM anchor WHERE uuid = ?" bindings:@[uuid.UUIDString] error:NULL];
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

- (void)revenant_publishChanged:(NSArray<NSString *> *)uuids
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
        if ([observer respondsToSelector:@selector(revenant_storeDidChange:)])
            [observer revenant_storeDidChange:identifiers];
    }
}

@end
