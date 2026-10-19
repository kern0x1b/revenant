// The rest of CloudKit's sync engine surface: the engine and its configuration, the twelve events,
// the three pending changes, the batch, and the two classes of what the service refused.
//
// The declarations are in CharonCKSyncEngine26.h beside the state group's, and every @implementation
// here carries an explicit @synthesize for each of its properties - the build compiles with
// -Werror=objc-missing-property-synthesis, which fires on implicit synthesis.
//
// The engine's own refusals are the header's, and one of them is measured and worse: the host's
// +[CKSyncEngine new] and -[CKSyncEngine init] call __builtin_trap behind its private class, so a
// caller who writes them loses the process. This port raises instead, which is the one written-down
// difference in this family and one in the port's favour.
//
// What the engine does with a request is the operations this package already carries: a fetch of the
// database is CKFetchDatabaseChangesOperation, a fetch of a zone is CKFetchRecordZoneChangesOperation,
// and a send is CKModifyRecordsOperation. What is here is the walk - the state, the events and the
// order - and the four requests that drive it.

#import "CharonCloudKit.h"
#import "CharonCKConstants.h"
#import "CharonCKSubscription.h"
#import "CharonCKSyncEngine26.h"

@implementation CKSyncEnginePendingRecordZoneChange
@synthesize recordID = _recordID;
@synthesize zoneID = _zoneID;
@synthesize type = _type;
- (instancetype)initWithRecordID:(CKRecordID *)recordID type:(CKSyncEnginePendingRecordZoneChangeType)type
{
    self = [super init];
    if (self) {
        _recordID = [recordID copy];
        _zoneID = [recordID.zoneID copy];
        _type = type;
    }
    return self;
}

- (instancetype)initWithZone:(CKRecordZone *)zone
{
    self = [super init];
    if (self) {
        _zoneID = [zone.zoneID copy];
        _type = CKSyncEnginePendingRecordZoneChangeTypeSaveZone;
    }
    return self;
}

- (instancetype)initWithZoneID:(CKRecordZoneID *)zoneID
{
    self = [super init];
    if (self) {
        _zoneID = [zoneID copy];
        _type = CKSyncEnginePendingRecordZoneChangeTypeDeleteZone;
    }
    return self;
}

+ (instancetype)new
{
    [NSException raise:NSInvalidArgumentException
                format:@"You must use -initWithRecordID:type:, -initWithZone: or -initWithZoneID:", nil];
    return nil;
}
@end
@implementation CKSyncEnginePendingDatabaseChange
@synthesize zoneID = _zoneID;
@synthesize type = _type;
- (instancetype)initWithZone:(CKRecordZone *)zone
{
    self = [super init];
    if (self) {
        _zoneID = [zone.zoneID copy];
        _type = CKSyncEnginePendingDatabaseChangeTypeSaveZone;
    }
    return self;
}

- (instancetype)initWithZoneID:(CKRecordZoneID *)zoneID
{
    self = [super init];
    if (self) {
        _zoneID = [zoneID copy];
        _type = CKSyncEnginePendingDatabaseChangeTypeDeleteZone;
    }
    return self;
}

+ (instancetype)new
{
    [NSException raise:NSInvalidArgumentException
                format:@"You must use -initWithZone: or -initWithZoneID:", nil];
    return nil;
}
@end
@implementation CKSyncEnginePendingZoneSave
@synthesize zone = _zone;
- (instancetype)initWithZone:(CKRecordZone *)zone
{
    // The base class's -initWithZone: is the one that knows how a zone change is held, and the zone
    // itself is this subclass's own addition, so it is written after the base class has set up.
    self = [super initWithZone:zone];
    if (self) {
        _zone = zone;
    }
    return self;
}
@end
@implementation CKSyncEnginePendingZoneDelete

- (instancetype)initWithZoneID:(CKRecordZoneID *)zoneID
{
    self = [super initWithZoneID:zoneID];
    return self;
}

@end
@implementation CKSyncEngineRecordZoneChangeBatch
@synthesize recordsToSave = _recordsToSave;
@synthesize recordIDsToDelete = _recordIDsToDelete;
@synthesize atomicByZone = _atomicByZone;
- (instancetype)initWithPendingChanges:(NSArray<CKSyncEnginePendingRecordZoneChange *> *)pendingChanges
                     recordProvider:(id)recordProvider
{
    self = [super init];
    if (self) {
        // A batch is a set of pending changes plus the records they name, and the records are asked
        // for of the provider the delegate gave. A caller decides what a record it has not read is
        // worth, and a port that sent a record it had invented would be overwriting one it never saw.
        NSMutableArray *records = [NSMutableArray array];
        NSMutableArray *deletions = [NSMutableArray array];
        for (CKSyncEnginePendingRecordZoneChange *change in pendingChanges) {
            if (!change.recordID) {
                continue;
            }
            if (change.type == CKSyncEnginePendingRecordZoneChangeTypeDeleteRecord) {
                [deletions addObject:change.recordID];
            } else if ([recordProvider respondsToSelector:@selector(charon_recordForRecordID:)]) {
                CKRecord *record = [recordProvider charon_recordForRecordID:change.recordID];
                if (record) {
                    [records addObject:record];
                }
            }
        }
        _recordsToSave = records;
        _recordIDsToDelete = deletions;
    }
    return self;
}

- (instancetype)initWithRecordsToSave:(NSArray<CKRecord *> *)recordsToSave
                     recordIDsToDelete:(NSArray<CKRecordID *> *)recordIDsToDelete
                       atomicByZone:(BOOL)atomicByZone
{
    self = [super init];
    if (self) {
        _recordsToSave = [recordsToSave copy];
        _recordIDsToDelete = [recordIDsToDelete copy];
        _atomicByZone = atomicByZone;
    }
    return self;
}

+ (instancetype)new
{
    [NSException raise:NSInvalidArgumentException
                format:@"You must call -initWithPendingChanges:recordProvider: or -initWithRecordsToSave:recordIDsToDelete:atomicByZone:",
                nil];
    return nil;
}
@end
@implementation CKSyncEngineEvent
@synthesize type = _type;
@synthesize stateUpdateEvent = _stateUpdateEvent;
@synthesize accountChangeEvent = _accountChangeEvent;
@synthesize willFetchChangesEvent = _willFetchChangesEvent;
@synthesize fetchedDatabaseChangesEvent = _fetchedDatabaseChangesEvent;
@synthesize didFetchChangesEvent = _didFetchChangesEvent;
@synthesize willFetchRecordZoneChangesEvent = _willFetchRecordZoneChangesEvent;
@synthesize fetchedRecordZoneChangesEvent = _fetchedRecordZoneChangesEvent;
@synthesize didFetchRecordZoneChangesEvent = _didFetchRecordZoneChangesEvent;
@synthesize willSendChangesEvent = _willSendChangesEvent;
@synthesize sentDatabaseChangesEvent = _sentDatabaseChangesEvent;
@synthesize sentRecordZoneChangesEvent = _sentRecordZoneChangesEvent;
@synthesize didSendChangesEvent = _didSendChangesEvent;
// An event carries a type and, of the twelve, whichever one the type names. The eleven the port
// builds are handed to the delegate through -handleEvent: and a delegate that is handed one with a
// member that is nil is being told a moment of the walk that has nothing further in it.
@end
@implementation CKSyncEngineStateUpdateEvent
@synthesize stateSerialization = _stateSerialization;
@end
@implementation CKSyncEngineAccountChangeEvent
@synthesize changeType = _changeType;
@synthesize currentUser = _currentUser;
@synthesize previousUser = _previousUser;
@end
@implementation CKSyncEngineWillFetchChangesEvent
@synthesize context = _context;
@end
@implementation CKSyncEngineDidFetchChangesEvent
@synthesize context = _context;
@end
@implementation CKSyncEngineWillFetchRecordZoneChangesEvent
@synthesize zoneID = _zoneID;
@end
@implementation CKSyncEngineFetchedRecordZoneChangesEvent
@synthesize zoneID = _zoneID;
@synthesize error = _error;
@end
@implementation CKSyncEngineDidFetchRecordZoneChangesEvent
@synthesize zoneID = _zoneID;
@synthesize error = _error;
@end
@implementation CKSyncEngineWillSendChangesEvent
@synthesize context = _context;
@end
@implementation CKSyncEngineDidSendChangesEvent
@synthesize context = _context;
@end
@implementation CKSyncEngineFetchedDatabaseChangesEvent
@synthesize deletions = _deletions;
@synthesize zoneDeletions = _zoneDeletions;
@end
@implementation CKSyncEngineFetchedRecordDeletion
@synthesize recordID = _recordID;
@synthesize recordType = _recordType;
@end
@implementation CKSyncEngineFetchedZoneDeletion
@synthesize zoneID = _zoneID;
@synthesize reason = _reason;
@end
@implementation CKSyncEngineFailedRecordSave
@synthesize record = _record;
@synthesize error = _error;
@end
@implementation CKSyncEngineFailedZoneSave
@synthesize recordZone = _recordZone;
@synthesize error = _error;
@end
@implementation CKSyncEngineSentDatabaseChangesEvent
@synthesize savedZones = _savedZones;
@synthesize failedZoneSaves = _failedZoneSaves;
@synthesize deletedZoneIDs = _deletedZoneIDs;
@synthesize failedZoneDeletes = _failedZoneDeletes;
@end
@implementation CKSyncEngineSentRecordZoneChangesEvent
@synthesize savedRecords = _savedRecords;
@synthesize failedRecordSaves = _failedRecordSaves;
@synthesize deletedRecordIDs = _deletedRecordIDs;
@synthesize failedRecordDeletes = _failedRecordDeletes;
@end

