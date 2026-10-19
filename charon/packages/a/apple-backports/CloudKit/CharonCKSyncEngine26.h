// CloudKit's sync engine surface, transcribed from the iOS 26.2 headers, one group at a time.
//
// The SDK this package builds against is 16.4 and declares none of it, so the port declares it here
// and **every class and every property below is a rule R4 case**.
//
// Why a plain transcription can live in a header at all: the build compiles with
// -Werror=objc-missing-property-synthesis, and that check fires on *implicit* synthesis. Each
// @implementation in this family therefore carries an explicit @synthesize for each of its
// properties, so a declaration in a header and an implementation in another file is fine.
//
// It holds the whole of the surface: the engine and its configuration, the state group of the
// scopes, the options and the contexts, the twelve events, the pending changes, the batch and the
// two classes of what the service refused.

#ifndef CHARON_CK_SYNC_ENGINE_26_H
#define CHARON_CK_SYNC_ENGINE_26_H

#import <Foundation/Foundation.h>
#import <CloudKit/CloudKit.h>

NS_ASSUME_NONNULL_BEGIN

// Which of the two reasons a sync began: the engine scheduled it, or a caller asked for it.
typedef NS_ENUM(NSInteger, CKSyncEngineSyncReason) {
    // The engine scheduled this sync itself.
    CKSyncEngineSyncReasonScheduled,
    // This sync was requested by a caller through -fetchChangesWithCompletionHandler: or
    // -sendChangesWithCompletionHandler:.
    CKSyncEngineSyncReasonManual,
};

// What kind of change a pending record zone change is. A record that moved and a record to delete
// are two; a zone that is to be saved and a zone that is to be deleted are the two the database
// changes are made of.
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

// Which of the twelve moments of a sync an event is about. The value is the one the enum of the
// iOS 26.2 headers gives, in that order, so a caller that switches on it is switching on what the
// event is rather than on a number this port chose.
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

// Why an account changed, and why a zone is gone: the three reasons the service gives are that it
// was deleted, that the user reset their encrypted data, and that it was purged.
typedef NS_ENUM(NSInteger, CKSyncEngineAccountChangeType) {
    CKSyncEngineAccountChangeTypeSignIn,
    CKSyncEngineAccountChangeTypeSignOut,
};

typedef NS_ENUM(NSInteger, CKSyncEngineZoneDeletionReason) {
    CKSyncEngineZoneDeletionReasonDeleted,
    CKSyncEngineZoneDeletionReasonEncryptedDataReset,
    CKSyncEngineZoneDeletionReasonPurged,
};

// A change to a record in a zone that the state is holding until it has been sent.
@interface CKSyncEnginePendingRecordZoneChange : NSObject
@property (nullable, readonly, copy) CKRecordID *recordID;
@property (nullable, readonly, copy) CKRecordZoneID *zoneID;
@property (readonly, assign) CKSyncEnginePendingRecordZoneChangeType type;
- (instancetype)initWithRecordID:(CKRecordID *)recordID
                            type:(CKSyncEnginePendingRecordZoneChangeType)type;
- (instancetype)initWithZone:(CKRecordZone *)zone;
- (instancetype)initWithZoneID:(CKRecordZoneID *)zoneID;
@end

// A change to the database itself - a zone to save or to delete - that the state is holding.
@interface CKSyncEnginePendingDatabaseChange : NSObject
@property (nullable, readonly, copy) CKRecordZoneID *zoneID;
@property (readonly, assign) CKSyncEnginePendingDatabaseChangeType type;
- (instancetype)initWithZone:(CKRecordZone *)zone;
- (instancetype)initWithZoneID:(CKRecordZoneID *)zoneID;
@end


// Which zones a fetch is about: some of them, or all but some of them. A scope with neither is every
// zone, which is what the nullable zoneIDs and the non-null excludedZoneIDs between them say.
@interface CKSyncEngineFetchChangesScope : NSObject <NSCopying>
- (instancetype)initWithZoneIDs:(nullable NSSet<CKRecordZoneID *> *)zoneIDs;
- (instancetype)initWithExcludedZoneIDs:(NSSet<CKRecordZoneID *> *)zoneIDs;
@property (nullable, readonly, copy) NSSet<CKRecordZoneID *> *zoneIDs;
@property (readonly, copy) NSSet<CKRecordZoneID *> *excludedZoneIDs;
- (BOOL)containsZoneID:(CKRecordZoneID *)zoneID;
@end

// The same for a send, which is also about the records themselves: a scope of records says which
// records, whatever zone they are in.
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

// What a fetch or a send is run with: the scope, the group it belongs to, and - for a fetch - the
// zones to ask about first.
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

// The two contexts the delegate is handed: which of the two reasons a sync began, and the options it
// began with. A caller cannot make one - both initialisers refuse, which is the header's own
// marking - and the two members are therefore the port's own, written by the engine that makes one
// and read by the delegate it is handed to. A context a caller could write would be a context the
// engine never ran, so the properties are not readonly here but the initialisers still refuse.
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

// What the engine remembers between one sync and the next: the changes it has not sent, the database
// changes it has not acted on, and the zones whose server changes it has not fetched. A caller reads
// it and a caller adds to it; the engine is what removes them, when it has sent or fetched them.
@interface CKSyncEngineState : NSObject
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
// The engine's own way in. It is an initializer in the family and not -init, because -init refuses:
// the state is made by a CKSyncEngine or restored by a serialization, and a caller who makes one
// directly has a state the engine does not know about.
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

// A state a caller persists and hands back, so that a process which is killed mid-sync resumes
// where it was. The port's own archive is the state itself: the pending changes, the database
// changes and the unfetched zones, written as the documents the service already uses for them.
@interface CKSyncEngineStateSerialization : NSObject <NSSecureCoding>
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
// The two ways a serialization is made: from a state, and from the bytes a caller persisted. Both
// are initializers in the family for the same reason -init refuses.
- (instancetype)initWithState:(CKSyncEngineState *)state;
- (instancetype)initWithData:(NSData *)data;
@end

// Forward declarations, so a class may name one that comes later in the header. These are the same
// names the 26.2 headers forward-declare, and the engine's configuration and the twelve events refer
// to one another.
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

// MARK: - The engine and its configuration

// The walk: a fetch of what the service has changed, a send of what the state is holding, and the
// cancellation of whatever is in flight. Every request underneath is one of the operations this
// package already carries - a CKFetchDatabaseChangesOperation, a CKFetchRecordZoneChangesOperation
// or a CKModifyRecordsOperation - and what the engine adds is the state and the twelve events.
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

// MARK: - The pending changes and the batch

// A zone the state is holding to be saved, and one it is holding to be deleted.
@interface CKSyncEnginePendingZoneSave : CKSyncEnginePendingDatabaseChange
- (instancetype)initWithZone:(CKRecordZone *)zone;
@property (readonly, strong) CKRecordZone *zone;
@end

@interface CKSyncEnginePendingZoneDelete : CKSyncEnginePendingDatabaseChange
- (instancetype)initWithZoneID:(CKRecordZoneID *)zoneID;
@end

// What a send is made of: the records to save, the identifiers to delete, and whether each zone is
// all of it or none of it. A batch is the delegate's answer to what the engine should send next for a
// zone, which is why a caller builds one and never receives one.
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

// MARK: - The events

// One event carries a type and, of the twelve, whichever one the type names. The engine tells its
// delegate of each of them in turn and the delegate answers with a scope or a batch.
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

// The state was persisted, and this is what was persisted.
@interface CKSyncEngineStateUpdateEvent : CKSyncEngineEvent
@property (readonly, strong) CKSyncEngineStateSerialization *stateSerialization;
@end

// The account moved: who it was and who it is.
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

// What the service took off the server: the records and the zones that are gone, and why a zone is.
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

// What the service refused: a record or a zone and the error, and nothing else. A refusal is handed
// to the delegate with the record it was about, because a caller has to decide what to do about that
// record and cannot find it again by itself.
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

// What a batch asks the delegate's record provider for: the record of an identifier, when the
// delegate has read one, and nil when it has not. It is the port's own selector and not the SDK's,
// because the 26.2 headers type the provider as `id` and declare no selector for it.
@protocol CKSyncEngineRecordProvider <NSObject>
- (nullable CKRecord *)charon_recordForRecordID:(CKRecordID *)recordID;
@end

// What the engine asks the delegate to fill in. A delegate that answers nothing is asked nothing
// further for that step, which is what the optional answers mean and what a port that invented an
// answer would break.
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
