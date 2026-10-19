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
