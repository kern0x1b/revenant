#ifndef CHARON_CK_SYNC_ENGINE_26_H
#define CHARON_CK_SYNC_ENGINE_26_H

#import <Foundation/Foundation.h>
#import <CloudKit/CloudKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, CKSyncEngineSyncReason) {
    CKSyncEngineSyncReasonScheduled,
    CKSyncEngineSyncReasonManual,
};

typedef NS_ENUM(NSInteger, CKSyncEnginePendingRecordZoneChangeType) {
    CKSyncEnginePendingRecordZoneChangeTypeSaveRecord,
    CKSyncEnginePendingRecordZoneChangeTypeDeleteRecord,
    CKSyncEnginePendingRecordZoneChangeTypeSaveZone,
    CKSyncEnginePendingRecordZoneChangeTypeDeleteZone,
};

typedef NS_ENUM(NSInteger, CKSyncEnginePendingDatabaseChangeType) {
    CKSyncEnginePendingDatabaseChangeTypeSaveZone,
    CKSyncEnginePendingDatabaseChangeTypeDeleteZone,
};

typedef NS_ENUM(NSInteger, CKSyncEngineEventType) {
    CKSyncEngineEventTypeStateUpdate,
    CKSyncEngineEventTypeAccountChange,
    CKSyncEngineEventTypeFetchedDatabaseChanges,
    CKSyncEngineEventTypeFetchedRecordZoneChanges,
    CKSyncEngineEventTypeSentDatabaseChanges,
    CKSyncEngineEventTypeSentRecordZoneChanges,
    CKSyncEngineEventTypeWillFetchChanges,
    CKSyncEngineEventTypeWillFetchRecordZoneChanges,
    CKSyncEngineEventTypeDidFetchRecordZoneChanges,
    CKSyncEngineEventTypeDidFetchChanges,
    CKSyncEngineEventTypeWillSendChanges,
    CKSyncEngineEventTypeDidSendChanges,
};

typedef NS_ENUM(NSInteger, CKSyncEngineAccountChangeType) {
    CKSyncEngineAccountChangeTypeSignIn,
    CKSyncEngineAccountChangeTypeSignOut,
};

typedef NS_ENUM(NSInteger, CKSyncEngineZoneDeletionReason) {
    CKSyncEngineZoneDeletionReasonDeleted,
    CKSyncEngineZoneDeletionReasonEncryptedDataReset,
    CKSyncEngineZoneDeletionReasonPurged,
};

@interface CKSyncEnginePendingRecordZoneChange : NSObject
@property (nullable, readonly, copy) CKRecordID *recordID;
@property (nullable, readonly, copy) CKRecordZoneID *zoneID;
@property (readonly, assign) CKSyncEnginePendingRecordZoneChangeType type;
- (instancetype)initWithRecordID:(CKRecordID *)recordID
                            type:(CKSyncEnginePendingRecordZoneChangeType)type;
- (instancetype)initWithZone:(CKRecordZone *)zone;
- (instancetype)initWithZoneID:(CKRecordZoneID *)zoneID;
@end

@interface CKSyncEnginePendingDatabaseChange : NSObject
@property (nullable, readonly, copy) CKRecordZoneID *zoneID;
@property (readonly, assign) CKSyncEnginePendingDatabaseChangeType type;
- (instancetype)initWithZone:(CKRecordZone *)zone;
- (instancetype)initWithZoneID:(CKRecordZoneID *)zoneID;
@end


@interface CKSyncEngineFetchChangesScope : NSObject <NSCopying>
- (instancetype)initWithZoneIDs:(nullable NSSet<CKRecordZoneID *> *)zoneIDs;
- (instancetype)initWithExcludedZoneIDs:(NSSet<CKRecordZoneID *> *)zoneIDs;
@property (nullable, readonly, copy) NSSet<CKRecordZoneID *> *zoneIDs;
@property (readonly, copy) NSSet<CKRecordZoneID *> *excludedZoneIDs;
- (BOOL)containsZoneID:(CKRecordZoneID *)zoneID;
@end

@interface CKSyncEngineSendChangesScope : NSObject <NSCopying>
- (instancetype)initWithZoneIDs:(nullable NSSet<CKRecordZoneID *> *)zoneIDs;
- (instancetype)initWithExcludedZoneIDs:(NSSet<CKRecordZoneID *> *)zoneIDs;
- (instancetype)initWithRecordIDs:(nullable NSSet<CKRecordID *> *)recordIDs;
@property (nullable, readonly, copy) NSSet<CKRecordZoneID *> *zoneIDs;
@property (readonly, copy) NSSet<CKRecordZoneID *> *excludedZoneIDs;
@property (nullable, readonly, copy) NSSet<CKRecordID *> *recordIDs;
- (BOOL)containsRecordID:(CKRecordID *)recordID;
- (BOOL)containsPendingRecordZoneChange:(CKSyncEnginePendingRecordZoneChange *)pendingRecordZoneChange;
@end

@interface CKSyncEngineFetchChangesOptions : NSObject <NSCopying>
- (instancetype)initWithScope:(nullable CKSyncEngineFetchChangesScope *)scope;
@property (copy) CKSyncEngineFetchChangesScope *scope;
@property (strong) CKOperationGroup *operationGroup;
@property (copy) NSArray<CKRecordZoneID *> *prioritizedZoneIDs;
@end

@interface CKSyncEngineSendChangesOptions : NSObject <NSCopying>
- (instancetype)initWithScope:(nullable CKSyncEngineSendChangesScope *)scope;
@property (copy) CKSyncEngineSendChangesScope *scope;
@property (strong) CKOperationGroup *operationGroup;
@end

@interface CKSyncEngineFetchChangesContext : NSObject
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@property (assign) CKSyncEngineSyncReason reason;
@property (copy) CKSyncEngineFetchChangesOptions *options;
@end

@interface CKSyncEngineSendChangesContext : NSObject
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@property (assign) CKSyncEngineSyncReason reason;
@property (copy) CKSyncEngineSendChangesOptions *options;
@end

@interface CKSyncEngineState : NSObject
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)initForSyncEngine:(id)engine;
@property (readonly, copy) NSArray<CKSyncEnginePendingRecordZoneChange *> *pendingRecordZoneChanges;
@property (readonly, copy) NSArray<CKSyncEnginePendingDatabaseChange *> *pendingDatabaseChanges;
@property (assign) BOOL hasPendingUntrackedChanges;
@property (readonly, copy) NSArray<CKRecordZoneID *> *zoneIDsWithUnfetchedServerChanges;
- (void)addPendingRecordZoneChanges:(NSArray<CKSyncEnginePendingRecordZoneChange *> *)changes;
- (void)removePendingRecordZoneChanges:(NSArray<CKSyncEnginePendingRecordZoneChange *> *)changes;
- (void)addPendingDatabaseChanges:(NSArray<CKSyncEnginePendingDatabaseChange *> *)changes;
- (void)removePendingDatabaseChanges:(NSArray<CKSyncEnginePendingDatabaseChange *> *)changes;
@end

@interface CKSyncEngineStateSerialization : NSObject <NSSecureCoding>
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)initWithState:(CKSyncEngineState *)state;
- (instancetype)initWithData:(NSData *)data;
@end

@class CKSyncEngine, CKSyncEngineConfiguration, CKSyncEngineState, CKSyncEngineStateSerialization;
@class CKSyncEngineEvent, CKSyncEngineStateUpdateEvent, CKSyncEngineAccountChangeEvent;
@class CKSyncEngineWillFetchChangesEvent, CKSyncEngineFetchedDatabaseChangesEvent;
@class CKSyncEngineDidFetchChangesEvent, CKSyncEngineWillFetchRecordZoneChangesEvent;
@class CKSyncEngineFetchedRecordZoneChangesEvent, CKSyncEngineDidFetchRecordZoneChangesEvent;
@class CKSyncEngineWillSendChangesEvent, CKSyncEngineSentDatabaseChangesEvent;
@class CKSyncEngineSentRecordZoneChangesEvent, CKSyncEngineDidSendChangesEvent;
@class CKSyncEngineFetchedRecordDeletion, CKSyncEngineFetchedZoneDeletion;
@class CKSyncEngineFailedRecordSave, CKSyncEngineFailedZoneSave;
@class CKSyncEngineFetchChangesContext, CKSyncEngineFetchChangesOptions, CKSyncEngineFetchChangesScope;
@class CKSyncEngineSendChangesContext, CKSyncEngineSendChangesOptions, CKSyncEngineSendChangesScope;
@class CKSyncEngineRecordZoneChangeBatch, CKSyncEnginePendingZoneSave, CKSyncEnginePendingZoneDelete;

@interface CKSyncEngine : NSObject
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)initWithConfiguration:(CKSyncEngineConfiguration *)configuration;
@property (readonly, strong) CKDatabase *database;
@property (readonly, strong) CKSyncEngineState *state;
- (void)fetchChangesWithCompletionHandler:(nullable void (^)(NSError *_Nullable error))completionHandler;
- (void)fetchChangesWithOptions:(CKSyncEngineFetchChangesOptions *)options
             completionHandler:(nullable void (^)(NSError *_Nullable error))completionHandler;
- (void)sendChangesWithCompletionHandler:(nullable void (^)(NSError *_Nullable error))completionHandler;
- (void)sendChangesWithOptions:(CKSyncEngineSendChangesOptions *)options
            completionHandler:(nullable void (^)(NSError *_Nullable error))completionHandler;
- (void)cancelOperationsWithCompletionHandler:(nullable void (^)(void))completionHandler;
@end

@interface CKSyncEngineConfiguration : NSObject
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)initWithDatabase:(CKDatabase *)database
              stateSerialization:(nullable CKSyncEngineStateSerialization *)stateSerialization
                        delegate:(nullable id)delegate;
@property (strong) CKDatabase *database;
@property (nullable, copy) CKSyncEngineStateSerialization *stateSerialization;
@property (weak) id delegate;
@property (assign) BOOL automaticallySync;
@property (nullable, copy) NSString *subscriptionID;
@end

@interface CKSyncEnginePendingZoneSave : CKSyncEnginePendingDatabaseChange
- (instancetype)initWithZone:(CKRecordZone *)zone;
@property (readonly, strong) CKRecordZone *zone;
@end

@interface CKSyncEnginePendingZoneDelete : CKSyncEnginePendingDatabaseChange
- (instancetype)initWithZoneID:(CKRecordZoneID *)zoneID;
@end

@interface CKSyncEngineRecordZoneChangeBatch : NSObject
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
- (nullable instancetype)initWithPendingChanges:(NSArray<CKSyncEnginePendingRecordZoneChange *> *)pendingChanges
                                 recordProvider:(id)recordProvider;
- (instancetype)initWithRecordsToSave:(nullable NSArray<CKRecord *> *)recordsToSave
                     recordIDsToDelete:(nullable NSArray<CKRecordID *> *)recordIDsToDelete
                       atomicByZone:(BOOL)atomicByZone;
@property (readonly, copy) NSArray<CKRecord *> *recordsToSave;
@property (readonly, copy) NSArray<CKRecordID *> *recordIDsToDelete;
@property (assign) BOOL atomicByZone;
@end

@interface CKSyncEngineEvent : NSObject
@property (readonly, assign) CKSyncEngineEventType type;
@property (readonly, strong, nullable) CKSyncEngineStateUpdateEvent *stateUpdateEvent;
@property (readonly, strong, nullable) CKSyncEngineAccountChangeEvent *accountChangeEvent;
@property (readonly, strong, nullable) CKSyncEngineWillFetchChangesEvent *willFetchChangesEvent;
@property (readonly, strong, nullable) CKSyncEngineFetchedDatabaseChangesEvent *fetchedDatabaseChangesEvent;
@property (readonly, strong, nullable) CKSyncEngineDidFetchChangesEvent *didFetchChangesEvent;
@property (readonly, strong, nullable) CKSyncEngineWillFetchRecordZoneChangesEvent *willFetchRecordZoneChangesEvent;
@property (readonly, strong, nullable) CKSyncEngineFetchedRecordZoneChangesEvent *fetchedRecordZoneChangesEvent;
@property (readonly, strong, nullable) CKSyncEngineDidFetchRecordZoneChangesEvent *didFetchRecordZoneChangesEvent;
@property (readonly, strong, nullable) CKSyncEngineWillSendChangesEvent *willSendChangesEvent;
@property (readonly, strong, nullable) CKSyncEngineSentDatabaseChangesEvent *sentDatabaseChangesEvent;
@property (readonly, strong, nullable) CKSyncEngineSentRecordZoneChangesEvent *sentRecordZoneChangesEvent;
@property (readonly, strong, nullable) CKSyncEngineDidSendChangesEvent *didSendChangesEvent;
@end

@interface CKSyncEngineStateUpdateEvent : CKSyncEngineEvent
@property (readonly, strong) CKSyncEngineStateSerialization *stateSerialization;
@end

@interface CKSyncEngineAccountChangeEvent : CKSyncEngineEvent
@property (readonly, assign) CKSyncEngineAccountChangeType changeType;
@property (readonly, strong, nullable) CKUserIdentity *currentUser;
@property (readonly, strong, nullable) CKUserIdentity *previousUser;
@end

@interface CKSyncEngineWillFetchChangesEvent : CKSyncEngineEvent
@property (readonly, strong) CKSyncEngineFetchChangesContext *context;
@end

@interface CKSyncEngineDidFetchChangesEvent : CKSyncEngineEvent
@property (readonly, strong) CKSyncEngineFetchChangesContext *context;
@end

@interface CKSyncEngineWillFetchRecordZoneChangesEvent : CKSyncEngineEvent
@property (readonly, strong) CKRecordZoneID *zoneID;
@end

@interface CKSyncEngineFetchedRecordZoneChangesEvent : CKSyncEngineEvent
@property (readonly, strong) CKRecordZoneID *zoneID;
@property (readonly, strong, nullable) NSError *error;
@end

@interface CKSyncEngineDidFetchRecordZoneChangesEvent : CKSyncEngineEvent
@property (readonly, strong) CKRecordZoneID *zoneID;
@property (readonly, strong, nullable) NSError *error;
@end

@interface CKSyncEngineWillSendChangesEvent : CKSyncEngineEvent
@property (readonly, strong) CKSyncEngineSendChangesContext *context;
@end

@interface CKSyncEngineDidSendChangesEvent : CKSyncEngineEvent
@property (readonly, strong) CKSyncEngineSendChangesContext *context;
@end

@interface CKSyncEngineFetchedDatabaseChangesEvent : CKSyncEngineEvent
@property (readonly, copy) NSArray<CKSyncEngineFetchedRecordDeletion *> *deletions;
@property (readonly, copy) NSArray<CKSyncEngineFetchedZoneDeletion *> *zoneDeletions;
@end

@interface CKSyncEngineFetchedRecordDeletion : NSObject
@property (readonly, copy) CKRecordID *recordID;
@property (readonly, copy) CKRecordType recordType;
@end

@interface CKSyncEngineFetchedZoneDeletion : NSObject
@property (readonly, copy) CKRecordZoneID *zoneID;
@property (readonly, assign) CKSyncEngineZoneDeletionReason reason;
@end

@interface CKSyncEngineFailedRecordSave : NSObject
@property (readonly, strong) CKRecord *record;
@property (readonly, strong, nullable) NSError *error;
@end

@interface CKSyncEngineFailedZoneSave : NSObject
@property (readonly, strong) CKRecordZone *recordZone;
@property (readonly, strong, nullable) NSError *error;
@end

@interface CKSyncEngineSentDatabaseChangesEvent : CKSyncEngineEvent
@property (readonly, copy) NSArray<CKRecordZone *> *savedZones;
@property (readonly, copy) NSArray<CKSyncEngineFailedZoneSave *> *failedZoneSaves;
@property (readonly, copy) NSArray<CKRecordZoneID *> *deletedZoneIDs;
@property (readonly, copy) NSDictionary<CKRecordZoneID *, NSError *> *failedZoneDeletes;
@end

@interface CKSyncEngineSentRecordZoneChangesEvent : CKSyncEngineEvent
@property (readonly, copy) NSArray<CKRecord *> *savedRecords;
@property (readonly, copy) NSArray<CKSyncEngineFailedRecordSave *> *failedRecordSaves;
@property (readonly, copy) NSArray<CKRecordID *> *deletedRecordIDs;
@property (readonly, copy) NSDictionary<CKRecordID *, NSError *> *failedRecordDeletes;
@end

@protocol CKSyncEngineRecordProvider <NSObject>
- (nullable CKRecord *)charon_recordForRecordID:(CKRecordID *)recordID;
@end

@protocol CKSyncEngineDelegate <NSObject>
@optional
- (void)syncEngine:(CKSyncEngine *)syncEngine handleEvent:(CKSyncEngineEvent *)event;
- (nullable CKSyncEngineFetchChangesScope *)syncEngine:(CKSyncEngine *)syncEngine
                    nextFetchChangesOptionsForContext:(CKSyncEngineFetchChangesContext *)context;
- (nullable CKSyncEngineSendChangesScope *)syncEngine:(CKSyncEngine *)syncEngine
                     nextSendChangesOptionsForContext:(CKSyncEngineSendChangesContext *)context;
- (nullable CKSyncEngineRecordZoneChangeBatch *)syncEngine:(CKSyncEngine *)syncEngine
                             nextRecordZoneChangeBatchForZoneID:(CKRecordZoneID *)zoneID;
@end

NS_ASSUME_NONNULL_END

#endif
