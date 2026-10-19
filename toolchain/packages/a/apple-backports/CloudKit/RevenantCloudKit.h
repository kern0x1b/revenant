#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import <CloudKit/CloudKit.h>

@class CKContainer, CKDatabase, CKRecord, CKRecordID, CKRecordZone, CKRecordZoneID, CKQuery, CKQueryCursor;

NS_ASSUME_NONNULL_BEGIN

extern NSString *const RevenantCKHost;
extern NSString *const RevenantCKDevelopmentEnvironment;
extern NSString *const RevenantCKProductionEnvironment;

extern NSError *RevenantCKError(CKErrorCode code, NSString *_Nullable message, NSDictionary *_Nullable extra);
extern NSError *RevenantCKErrorFromPayload(NSDictionary *payload, NSDictionary *_Nullable extra);
extern NSError *RevenantCKNotAuthenticated(void);
extern NSError *RevenantCKBadContainer(NSString *_Nullable containerIdentifier);
extern NSError *RevenantCKTransportError(NSError *underlying);

@interface RevenantCKCredentials : NSObject
+ (instancetype)shared;
- (nullable NSString *)tokenForContainer:(NSString *)containerIdentifier error:(NSError **)error;
- (void)setDeveloperToken:(nullable NSString *)token;
- (void)setSigningKey:(nullable NSString *)pem forContainer:(NSString *)containerIdentifier;
- (nullable NSString *)signingKeyForContainer:(NSString *)containerIdentifier;
- (nullable NSString *)userRecordIDForContainer:(NSString *)containerIdentifier;
- (void)setUserRecordID:(nullable NSString *)userRecordID forContainer:(NSString *)containerIdentifier;
@end

extern NSString *RevenantCKWebAuthToken(NSString *keyID, NSString *teamID, NSDate *now);
extern NSString *RevenantCKBase64URL(NSData *data);
extern NSData *_Nullable RevenantCKPEMPrivateKey(NSString *pem);

typedef void (^RevenantCKCompletion)(id _Nullable body, NSError *_Nullable error);

@interface RevenantCKTransport : NSObject
+ (instancetype)shared;
- (void)performContainer:(CKContainer *)container
                database:(nullable CKDatabase *)database
             environment:(NSString *)environment
                  method:(NSString *)method
                    path:(NSString *)path
                    body:(nullable NSDictionary *)body
              completion:(RevenantCKCompletion)completion;
- (NSString *)environmentForContainer:(CKContainer *)container;
- (NSString *)databaseRootForContainer:(NSString *)containerIdentifier
                              database:(CKDatabase *)database
                           environment:(NSString *)environment;
- (void)setContainer:(CKContainer *)container forDatabase:(CKDatabase *)database environment:(NSString *)environment;
- (NSMapTable *)containerForDatabase;
- (NSMapTable *)environmentForDatabase;
@property (nonatomic, strong, nullable) NSMapTable *containers;
@property (nonatomic, strong, nullable) NSMapTable *environments;
@end

extern NSDictionary *RevenantCKSubscriptionDocument(CKSubscription *subscription);
extern CKRecordZone *_Nullable RevenantCKZoneWithDocument(NSDictionary *document);
extern CKSubscription *_Nullable RevenantCKSubscriptionWithDocument(NSDictionary *document);
extern NSDictionary *RevenantCKFieldsSnapshot(CKRecord *record);
extern NSData *_Nullable RevenantCKSystemFieldsSnapshotToken(CKServerChangeToken *_Nullable token);
extern CKServerChangeToken *_Nullable RevenantCKServerTokenFromData(NSData *data);
extern NSDictionary *RevenantCKSystemFieldsSnapshot(CKRecord *record);

extern CKUserIdentity *_Nullable RevenantCKUserIdentityWithDocument(NSDictionary *document);
extern CKUserIdentityLookupInfo *_Nullable RevenantCKLookupInfoWithDocument(NSDictionary *document);
extern CKShareParticipant *_Nullable RevenantCKShareParticipantWithDocument(NSDictionary *document);
extern CKShareMetadata *_Nullable RevenantCKShareMetadataWithDocument(NSDictionary *document, CKContainer *_Nullable container);

@interface RevenantCKOPScheduler : NSObject
+ (void)add:(NSOperation *)operation;
+ (void)complete:(NSOperation *)operation;
+ (void)cancelAll;
@end

@interface CKDatabase (RevenantCKPrivate)
- (nullable CKContainer *)ck_container;
@end

@interface CKContainer (RevenantCKPrivate)
- (nullable CKRecordID *)currentUserRecordID;
@end

@interface CKOperation (RevenantCKShared)
- (void)revenant_setUp;
- (void)revenant_finish;
- (nullable NSError *)partialFailureWithItems:(NSDictionary *)items;
- (void)runMethod:(NSString *)method path:(NSString *)path body:(nullable NSDictionary *)body
      completion:(void (^)(id _Nullable body, NSError *_Nullable error))completion;
@end

extern CKUserIdentity *_Nullable RevenantCKUserIdentityWithDocument(NSDictionary *document);
extern CKUserIdentityLookupInfo *_Nullable RevenantCKLookupInfoWithDocument(NSDictionary *document);
extern CKShareParticipant *_Nullable RevenantCKShareParticipantWithDocument(NSDictionary *document);
extern CKShareMetadata *_Nullable RevenantCKShareMetadataWithDocument(NSDictionary *document, CKContainer *_Nullable container);

extern NSString *RevenantCKDatabaseRoot(CKDatabase *database);
extern NSString *RevenantCKZonePath(CKRecordZoneID *zoneID);
extern NSDictionary *RevenantCKRecordIDDocument(CKRecordID *recordID);
extern CKRecordZoneID *_Nullable RevenantCKZoneIDFromDocument(NSDictionary *_Nullable json);
extern NSDictionary *RevenantCKZoneIDDocument(CKRecordZoneID *zoneID);
extern CKRecordID *_Nullable RevenantCKRecordIDFromDocument(NSDictionary *_Nullable json);

extern NSDictionary *_Nullable RevenantCKQueryDocument(CKQuery *query, NSString *_Nullable zoneID,
                                                      NSArray *_Nullable desiredKeys, NSUInteger resultsLimit,
                                                      NSError **error);
extern CKQueryCursor *_Nullable RevenantCKCursorFromToken(NSData *token);
extern NSData *_Nullable RevenantCKTokenFromCursor(CKQueryCursor *_Nullable cursor);
extern NSArray<CKRecord *> *RevenantCKRecordsFromResults(NSArray *results, NSSet *_Nullable desiredKeys);
extern CKRecord *_Nullable RevenantCKRecordFromResult(NSDictionary *result, NSSet *_Nullable desiredKeys);

extern id _Nullable RevenantCKValueFromJSON(id _Nullable json, Class _Nullable *_Nullable kind);
extern id _Nullable RevenantCKValueToJSON(id _Nullable value);
extern NSDictionary *RevenantCKFieldsToJSON(NSDictionary *fields);
extern NSDictionary *RevenantCKFieldsFromJSON(NSDictionary *_Nullable json);
extern NSDate *_Nullable RevenantCKDateFromJSON(id json);
extern NSString *RevenantCKMD5Hex(NSData *data);
extern double RevenantCKMilliseconds(NSDate *date);

NS_ASSUME_NONNULL_END
