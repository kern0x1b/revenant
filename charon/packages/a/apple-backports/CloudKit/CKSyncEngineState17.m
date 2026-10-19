// The state group of CloudKit's sync engine: the two scopes, the two options, the two contexts, the
// state and its serialization.
//
// This is the bookkeeping CKSyncEngine adds over the operations below it, and it is all values: a
// scope says which zones a fetch or a send is about, the options carry it and the group, the contexts
// are what the delegate is handed, and the state is what survives a process being killed mid-sync.
//
// The refusals are the header's own, and one of them is measured and worse than a refusal: the host's
// +[CKSyncEngineState new] and -[CKSyncEngineState init] call __builtin_trap behind its private
// __CKSyncEngine class, so a caller who writes them loses the process. This port raises instead, which
// is the one written-down difference in this family and one in the port's favour.
//
// Every @implementation carries an explicit @synthesize for each of its properties: the build
// compiles with -Werror=objc-missing-property-synthesis, which fires on implicit synthesis, and the
// declarations live in CharonCKSyncEngine26.h with the implementations of the other groups.

#import "CharonCloudKit.h"
#import "CharonCKConstants.h"
#import "CharonCKSubscription.h"
#import "CharonCKSyncEngine26.h"

#pragma mark - CKSyncEngineFetchChangesScope

@implementation CKSyncEngineFetchChangesScope

@synthesize zoneIDs = _zoneIDs;
@synthesize excludedZoneIDs = _excludedZoneIDs;

- (instancetype)initWithZoneIDs:(NSSet<CKRecordZoneID *> *)zoneIDs
{
    self = [super init];
    if (self) {
        _zoneIDs = [zoneIDs copy];
        _excludedZoneIDs = [NSSet set];
    }
    return self;
}

- (instancetype)initWithExcludedZoneIDs:(NSSet<CKRecordZoneID *> *)zoneIDs
{
    self = [super init];
    if (self) {
        _zoneIDs = nil;
        _excludedZoneIDs = [zoneIDs copy];
    }
    return self;
}

+ (instancetype)new
{
    return [[self alloc] initWithZoneIDs:nil];
}

- (BOOL)containsZoneID:(CKRecordZoneID *)zoneID
{
    if (!zoneID) {
        return NO;
    }
    // A scope of zones says whether that zone is in it, and a scope of exclusions says whether it is
    // out of it. There is no third case: a scope is one or the other, never both.
    return _zoneIDs ? [_zoneIDs containsObject:zoneID] : ![_excludedZoneIDs containsObject:zoneID];
}

- (id)copyWithZone:(NSZone *)zone
{
    return _zoneIDs ? [[[self class] allocWithZone:zone] initWithZoneIDs:_zoneIDs]
                    : [[[self class] allocWithZone:zone] initWithExcludedZoneIDs:_excludedZoneIDs];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p; zoneIDs=%@, excludedZoneIDs=%@>",
            NSStringFromClass([self class]), self, _zoneIDs, _excludedZoneIDs];
}

@end

#pragma mark - CKSyncEngineSendChangesScope

@implementation CKSyncEngineSendChangesScope

@synthesize zoneIDs = _zoneIDs;
@synthesize excludedZoneIDs = _excludedZoneIDs;
@synthesize recordIDs = _recordIDs;

- (instancetype)initWithZoneIDs:(NSSet<CKRecordZoneID *> *)zoneIDs
{
    self = [super init];
    if (self) {
        _zoneIDs = [zoneIDs copy];
        _excludedZoneIDs = [NSSet set];
    }
    return self;
}

- (instancetype)initWithExcludedZoneIDs:(NSSet<CKRecordZoneID *> *)zoneIDs
{
    self = [super init];
    if (self) {
        _zoneIDs = nil;
        _excludedZoneIDs = [zoneIDs copy];
    }
    return self;
}

- (instancetype)initWithRecordIDs:(NSSet<CKRecordID *> *)recordIDs
{
    self = [super init];
    if (self) {
        _recordIDs = [recordIDs copy];
        _excludedZoneIDs = [NSSet set];
    }
    return self;
}

+ (instancetype)new
{
    return [[self alloc] initWithZoneIDs:nil];
}

- (BOOL)containsRecordID:(CKRecordID *)recordID
{
    if (!recordID) {
        return NO;
    }
    if (_recordIDs) {
        return [_recordIDs containsObject:recordID];
    }
    return _zoneIDs ? [_zoneIDs containsObject:recordID.zoneID]
                    : ![_excludedZoneIDs containsObject:recordID.zoneID];
}

- (BOOL)containsPendingRecordZoneChange:(CKSyncEnginePendingRecordZoneChange *)pendingRecordZoneChange
{
    if (!pendingRecordZoneChange) {
        return NO;
    }
    if (pendingRecordZoneChange.recordID) {
        return [self containsRecordID:pendingRecordZoneChange.recordID];
    }
    // A zone save or a zone delete is about a zone and not about a record, so a scope of records
    // does not contain it: there is no record to be in the set of.
    return _zoneIDs ? [_zoneIDs containsObject:pendingRecordZoneChange.zoneID] : NO;
}

- (id)copyWithZone:(NSZone *)zone
{
    if (_recordIDs) {
        return [[[self class] allocWithZone:zone] initWithRecordIDs:_recordIDs];
    }
    return _zoneIDs ? [[[self class] allocWithZone:zone] initWithZoneIDs:_zoneIDs]
                    : [[[self class] allocWithZone:zone] initWithExcludedZoneIDs:_excludedZoneIDs];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p; zoneIDs=%@, excludedZoneIDs=%@, recordIDs=%@>",
            NSStringFromClass([self class]), self, _zoneIDs, _excludedZoneIDs, _recordIDs];
}

@end

#pragma mark - The options

@implementation CKSyncEngineFetchChangesOptions

@synthesize scope = _scope;
@synthesize operationGroup = _operationGroup;
@synthesize prioritizedZoneIDs = _prioritizedZoneIDs;

- (instancetype)initWithScope:(CKSyncEngineFetchChangesScope *)scope
{
    self = [super init];
    if (self) {
        _scope = scope;
        _operationGroup = [[CKOperationGroup alloc] init];
        _prioritizedZoneIDs = @[];
    }
    return self;
}

+ (instancetype)new
{
    return [[self alloc] initWithScope:nil];
}

- (id)copyWithZone:(NSZone *)zone
{
    CKSyncEngineFetchChangesOptions *copy = [[[self class] allocWithZone:zone] initWithScope:_scope];
    copy.operationGroup = _operationGroup;
    copy.prioritizedZoneIDs = _prioritizedZoneIDs;
    return copy;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p; scope=%@, operationGroup=%@, prioritizedZoneIDs=%@>",
            NSStringFromClass([self class]), self, _scope, _operationGroup, _prioritizedZoneIDs];
}

@end

@implementation CKSyncEngineSendChangesOptions

@synthesize scope = _scope;
@synthesize operationGroup = _operationGroup;

- (instancetype)initWithScope:(CKSyncEngineSendChangesScope *)scope
{
    self = [super init];
    if (self) {
        _scope = scope;
        _operationGroup = [[CKOperationGroup alloc] init];
    }
    return self;
}

+ (instancetype)new
{
    return [[self alloc] initWithScope:nil];
}

- (id)copyWithZone:(NSZone *)zone
{
    CKSyncEngineSendChangesOptions *copy = [[[self class] allocWithZone:zone] initWithScope:_scope];
    copy.operationGroup = _operationGroup;
    return copy;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p; scope=%@, operationGroup=%@>",
            NSStringFromClass([self class]), self, _scope, _operationGroup];
}

@end

#pragma mark - The contexts

@implementation CKSyncEngineFetchChangesContext

@synthesize reason = _reason;
@synthesize options = _options;

- (instancetype)charon_contextWithReason:(CKSyncEngineSyncReason)reason
                                  options:(CKSyncEngineFetchChangesOptions *)options
{
    CKSyncEngineFetchChangesContext *made = [[CKSyncEngineFetchChangesContext alloc] init];
    made.reason = reason;
    made.options = options;
    return made;
}

+ (instancetype)new
{
    // The header marks both spellings unavailable: a context is made by the engine and handed to the
    // delegate, and one a caller made would be a context the engine never ran.
    [NSException raise:NSInvalidArgumentException
                format:@"You must not make a CKSyncEngineFetchChangesContext; one is handed to the delegate", nil];
    return nil;
}

- (instancetype)init
{
    [NSException raise:NSInvalidArgumentException
                format:@"You must not make a CKSyncEngineFetchChangesContext; one is handed to the delegate", nil];
    return nil;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p; reason=%ld, options=%@>",
            NSStringFromClass([self class]), self, (long)_reason, _options];
}

@end

@implementation CKSyncEngineSendChangesContext

@synthesize reason = _reason;
@synthesize options = _options;

- (instancetype)charon_contextWithReason:(CKSyncEngineSyncReason)reason
                                 options:(CKSyncEngineSendChangesOptions *)options
{
    CKSyncEngineSendChangesContext *made = [[CKSyncEngineSendChangesContext alloc] init];
    made.reason = reason;
    made.options = options;
    return made;
}

+ (instancetype)new
{
    [NSException raise:NSInvalidArgumentException
                format:@"You must not make a CKSyncEngineSendChangesContext; one is handed to the delegate", nil];
    return nil;
}

- (instancetype)init
{
    [NSException raise:NSInvalidArgumentException
                format:@"You must not make a CKSyncEngineSendChangesContext; one is handed to the delegate", nil];
    return nil;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p; reason=%ld, options=%@>",
            NSStringFromClass([self class]), self, (long)_reason, _options];
}

@end

#pragma mark - CKSyncEngineState

@implementation CKSyncEngineState
{
    NSMutableArray<CKSyncEnginePendingRecordZoneChange *> *_pendingRecordZoneChanges;
    NSMutableArray<CKSyncEnginePendingDatabaseChange *> *_pendingDatabaseChanges;
    NSMutableArray<CKRecordZoneID *> *_zoneIDsWithUnfetchedServerChanges;
}

@synthesize hasPendingUntrackedChanges = _hasPendingUntrackedChanges;

- (instancetype)initForSyncEngine:(id)engine
{
    (void)engine;
    self = [super init];
    if (self) {
        _pendingRecordZoneChanges = [NSMutableArray array];
        _pendingDatabaseChanges = [NSMutableArray array];
        _zoneIDsWithUnfetchedServerChanges = [NSMutableArray array];
    }
    return self;
}

+ (instancetype)new
{
    // Measured: the host traps here, behind its private class. A trap takes the process down and a
    // caller can do nothing about it, so this port refuses with the words that name the two ways a
    // state is had.
    [NSException raise:NSInvalidArgumentException
                format:@"You must use the -state of a CKSyncEngine, or restore one with +[CKSyncEngineStateSerialization stateWithCoder:]", nil];
    return nil;
}

- (instancetype)init
{
    [NSException raise:NSInvalidArgumentException
                format:@"You must use the -state of a CKSyncEngine, or restore one with +[CKSyncEngineStateSerialization stateWithCoder:]", nil];
    return nil;
}

- (void)addPendingRecordZoneChanges:(NSArray<CKSyncEnginePendingRecordZoneChange *> *)changes
{
    [_pendingRecordZoneChanges addObjectsFromArray:changes];
}

- (void)removePendingRecordZoneChanges:(NSArray<CKSyncEnginePendingRecordZoneChange *> *)changes
{
    [_pendingRecordZoneChanges removeObjectsInArray:changes];
}

- (void)addPendingDatabaseChanges:(NSArray<CKSyncEnginePendingDatabaseChange *> *)changes
{
    [_pendingDatabaseChanges addObjectsFromArray:changes];
}

- (void)removePendingDatabaseChanges:(NSArray<CKSyncEnginePendingDatabaseChange *> *)changes
{
    [_pendingDatabaseChanges removeObjectsInArray:changes];
}

- (NSArray<CKSyncEnginePendingRecordZoneChange *> *)pendingRecordZoneChanges
{
    return [_pendingRecordZoneChanges copy];
}

- (NSArray<CKSyncEnginePendingDatabaseChange *> *)pendingDatabaseChanges
{
    return [_pendingDatabaseChanges copy];
}

- (NSArray<CKRecordZoneID *> *)zoneIDsWithUnfetchedServerChanges
{
    return [_zoneIDsWithUnfetchedServerChanges copy];
}

// The three collections the header declares as copies rather than as storage, so that a caller cannot
// add to the state behind the engine's back: the only way in is the four add and remove methods, and
// the only way out is the same four.
- (void)charon_setZoneIDsWithUnfetchedServerChanges:(NSArray<CKRecordZoneID *> *)zoneIDs
{
    [_zoneIDsWithUnfetchedServerChanges removeAllObjects];
    if (zoneIDs) {
        [_zoneIDsWithUnfetchedServerChanges addObjectsFromArray:zoneIDs];
    }
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p; pendingRecordZoneChanges=%@, pendingDatabaseChanges=%@, zoneIDsWithUnfetchedServerChanges=%@, hasPendingUntrackedChanges=%d>",
            NSStringFromClass([self class]), self, _pendingRecordZoneChanges, _pendingDatabaseChanges,
            _zoneIDsWithUnfetchedServerChanges, _hasPendingUntrackedChanges];
}

@end

#pragma mark - CKSyncEngineStateSerialization

@implementation CKSyncEngineStateSerialization
{
    NSData *_data;
}

+ (instancetype)new
{
    [NSException raise:NSInvalidArgumentException
                format:@"You must use +stateWithCoder: or -initWithState: to make a serialization", nil];
    return nil;
}

- (instancetype)init
{
    [NSException raise:NSInvalidArgumentException
                format:@"You must use +stateWithCoder: or -initWithState: to make a serialization", nil];
    return nil;
}

- (instancetype)initWithState:(CKSyncEngineState *)state
{
    self = [super init];
    if (self) {
        // A serialization is the state's own archive, and it is archivable so that a caller who
        // persists it with a coder of their own gets the same bytes back.
        NSMutableData *data = [NSMutableData data];
        NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:data];
        [archiver encodeObject:state.pendingRecordZoneChanges forKey:@"pendingRecordZoneChanges"];
        [archiver encodeObject:state.pendingDatabaseChanges forKey:@"pendingDatabaseChanges"];
        [archiver encodeObject:state.zoneIDsWithUnfetchedServerChanges forKey:@"zoneIDsWithUnfetchedServerChanges"];
        [archiver finishEncoding];
        _data = data;
    }
    return self;
}

+ (instancetype)stateWithCoder:(NSCoder *)coder
{
    return [[self alloc] initWithData:[coder decodeObjectOfClass:[NSData class] forKey:@"data"]];
}

- (instancetype)initWithData:(NSData *)data
{
    self = [super init];
    if (self) {
        _data = [data copy];
    }
    return self;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_data forKey:@"data"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    return [[[self class] alloc] initWithData:[coder decodeObjectOfClass:[NSData class] forKey:@"data"]];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p; %lu bytes>", NSStringFromClass([self class]), self,
            (unsigned long)_data.length];
}

@end
