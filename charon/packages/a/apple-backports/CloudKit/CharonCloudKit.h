#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import <CloudKit/CloudKit.h>

@class CKContainer, CKDatabase, CKRecord, CKRecordID, CKRecordZone, CKRecordZoneID, CKQuery, CKQueryCursor;

NS_ASSUME_NONNULL_BEGIN

extern NSString *const CharonCKHost;
extern NSString *const CharonCKDevelopmentEnvironment;
extern NSString *const CharonCKProductionEnvironment;

extern NSError *CharonCKError(CKErrorCode code, NSString *_Nullable message, NSDictionary *_Nullable extra);
extern NSError *CharonCKErrorFromPayload(NSDictionary *payload, NSDictionary *_Nullable extra);
extern NSError *CharonCKNotAuthenticated(void);
extern NSError *CharonCKBadContainer(NSString *_Nullable containerIdentifier);
extern NSError *CharonCKTransportError(NSError *underlying);

@interface CharonCKCredentials : NSObject
+ (instancetype)shared;
- (nullable NSString *)tokenForContainer:(NSString *)containerIdentifier error:(NSError **)error;
- (void)setDeveloperToken:(nullable NSString *)token;
- (void)setSigningKey:(nullable NSString *)pem forContainer:(NSString *)containerIdentifier;
- (nullable NSString *)signingKeyForContainer:(NSString *)containerIdentifier;
- (nullable NSString *)userRecordIDForContainer:(NSString *)containerIdentifier;
- (void)setUserRecordID:(nullable NSString *)userRecordID forContainer:(NSString *)containerIdentifier;
@end

extern NSString *CharonCKWebAuthToken(NSString *keyID, NSString *teamID, NSDate *now);
extern NSString *CharonCKBase64URL(NSData *data);
extern NSData *_Nullable CharonCKPEMPrivateKey(NSString *pem);

typedef void (^CharonCKCompletion)(id _Nullable body, NSError *_Nullable error);

@interface CharonCKTransport : NSObject
+ (instancetype)shared;
- (void)performContainer:(CKContainer *)container
                database:(nullable CKDatabase *)database
             environment:(NSString *)environment
                  method:(NSString *)method
                    path:(NSString *)path
                    body:(nullable NSDictionary *)body
              completion:(CharonCKCompletion)completion;
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

extern NSDictionary *CharonCKSubscriptionDocument(CKSubscription *subscription);
extern CKRecordZone *_Nullable CharonCKZoneWithDocument(NSDictionary *document);
extern CKSubscription *_Nullable CharonCKSubscriptionWithDocument(NSDictionary *document);
extern NSDictionary *CharonCKFieldsSnapshot(CKRecord *record);
extern NSData *_Nullable CharonCKSystemFieldsSnapshotToken(CKServerChangeToken *_Nullable token);
extern CKServerChangeToken *_Nullable CharonCKServerTokenFromData(NSData *data);
extern NSDictionary *CharonCKSystemFieldsSnapshot(CKRecord *record);

extern CKUserIdentity *_Nullable CharonCKUserIdentityWithDocument(NSDictionary *document);
extern CKUserIdentityLookupInfo *_Nullable CharonCKLookupInfoWithDocument(NSDictionary *document);
extern CKShareParticipant *_Nullable CharonCKShareParticipantWithDocument(NSDictionary *document);
extern CKShareMetadata *_Nullable CharonCKShareMetadataWithDocument(NSDictionary *document, CKContainer *_Nullable container);

@interface CharonCKOPScheduler : NSObject
+ (void)add:(NSOperation *)operation;
+ (void)complete:(NSOperation *)operation;
+ (void)cancelAll;
@end

@interface CKDatabase (CharonCKPrivate)
- (nullable CKContainer *)ck_container;
@end

@interface CKContainer (CharonCKPrivate)
- (nullable CKRecordID *)currentUserRecordID;
@end

@interface CKOperation (CharonCKShared)
- (void)charon_setUp;
- (void)charon_finish;
- (nullable NSError *)partialFailureWithItems:(NSDictionary *)items;
- (void)runMethod:(NSString *)method path:(NSString *)path body:(nullable NSDictionary *)body
      completion:(void (^)(id _Nullable body, NSError *_Nullable error))completion;
@end

extern CKUserIdentity *_Nullable CharonCKUserIdentityWithDocument(NSDictionary *document);
extern CKUserIdentityLookupInfo *_Nullable CharonCKLookupInfoWithDocument(NSDictionary *document);
extern CKShareParticipant *_Nullable CharonCKShareParticipantWithDocument(NSDictionary *document);
extern CKShareMetadata *_Nullable CharonCKShareMetadataWithDocument(NSDictionary *document, CKContainer *_Nullable container);

extern NSString *CharonCKDatabaseRoot(CKDatabase *database);
extern NSString *CharonCKZonePath(CKRecordZoneID *zoneID);
extern NSDictionary *CharonCKRecordIDDocument(CKRecordID *recordID);
extern CKRecordZoneID *_Nullable CharonCKZoneIDFromDocument(NSDictionary *_Nullable json);
extern NSDictionary *CharonCKZoneIDDocument(CKRecordZoneID *zoneID);
extern CKRecordID *_Nullable CharonCKRecordIDFromDocument(NSDictionary *_Nullable json);

extern NSDictionary *_Nullable CharonCKQueryDocument(CKQuery *query, NSString *_Nullable zoneID,
                                                      NSArray *_Nullable desiredKeys, NSUInteger resultsLimit,
                                                      NSError **error);
extern CKQueryCursor *_Nullable CharonCKCursorFromToken(NSData *token);
extern NSData *_Nullable CharonCKTokenFromCursor(CKQueryCursor *_Nullable cursor);
extern NSArray<CKRecord *> *CharonCKRecordsFromResults(NSArray *results, NSSet *_Nullable desiredKeys);
extern CKRecord *_Nullable CharonCKRecordFromResult(NSDictionary *result, NSSet *_Nullable desiredKeys);

extern id _Nullable CharonCKValueFromJSON(id _Nullable json, Class _Nullable *_Nullable kind);
extern id _Nullable CharonCKValueToJSON(id _Nullable value);
extern NSDictionary *CharonCKFieldsToJSON(NSDictionary *fields);
extern NSDictionary *CharonCKFieldsFromJSON(NSDictionary *_Nullable json);
extern NSDate *_Nullable CharonCKDateFromJSON(id json);
extern NSString *CharonCKMD5Hex(NSData *data);
extern double CharonCKMilliseconds(NSDate *date);

NS_ASSUME_NONNULL_END
