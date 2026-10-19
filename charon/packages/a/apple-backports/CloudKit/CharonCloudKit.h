// The CloudKit Web Services layer, and the few helpers the CloudKit classes above it share.
//
// Nothing here is API: no class or symbol this header declares is in the registry, and the classes it
// names carry a CharonCK prefix, so no release ever exports them and no band ever leaves them out.
//
// The wire shapes are the ones of Apple's documented CloudKit Web Services interface and the value
// classes above them are measured against the host's own CloudKit; facts/CloudKit/Values.md names
// both, and facts/CloudKit/WebServices.md the endpoints.

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import <CloudKit/CloudKit.h>

@class CKContainer, CKDatabase, CKRecord, CKRecordID, CKRecordZone, CKRecordZoneID, CKQuery, CKQueryCursor;

NS_ASSUME_NONNULL_BEGIN

extern NSString *const CharonCKHost;
extern NSString *const CharonCKDevelopmentEnvironment;
extern NSString *const CharonCKProductionEnvironment;

// MARK: - Errors

// A CKError built as Apple's own builds it: the domain, the code, and the description the payload
// carries. The codes are CloudKit's own `CKErrorCode`, so a caller that switches on the number
// switches on the number Apple's header gives.
extern NSError *CharonCKError(CKErrorCode code, NSString *_Nullable message, NSDictionary *_Nullable extra);
extern NSError *CharonCKErrorFromPayload(NSDictionary *payload, NSDictionary *_Nullable extra);
// The two errors the header names for a client that never got there, and for one whose container is
// not provisioned. A device with an iCloud account and a container that is not provisioned is the
// first of these; a process with no `com.apple.developer.icloud-container-identifiers` entitlement
// is the second, and the host's own answer for that case is to raise, which would take the process
// down rather than let the caller do anything about it.
extern NSError *CharonCKNotAuthenticated(void);
extern NSError *CharonCKBadContainer(NSString *_Nullable containerIdentifier);
extern NSError *CharonCKTransportError(NSError *underlying);

// MARK: - The credentials
//
// A request carries a bearer token. There are two documented ways to have one: a developer token the
// application minted, which it hands over with -setDeveloperToken:, or a token the port signs with
// the container's web services authentication key, the ES256 key a `.p8` in the bundle holds. The
// second is the one a client that has only a key can use, and its signature is charon@micro-ecc's.
//
// A token is cached until shortly before the hour it is good for and minted again when there is a key
// to mint it with. With neither, every request answers CKErrorNotAuthenticated.
@interface CharonCKCredentials : NSObject
+ (instancetype)shared;
// The token the requests go out with, or nil with the error to answer with instead.
- (nullable NSString *)tokenForContainer:(NSString *)containerIdentifier error:(NSError **)error;
- (void)setDeveloperToken:(nullable NSString *)token;
// The key an application ships: a `.p8` in its bundle, or the PEM in the Info.plist key CloudKit's
// own tooling writes. The key identifier is `iCloud.com.apple.developer.<container>` and the payload
// is the three members of the authentication key's own format.
- (void)setSigningKey:(nullable NSString *)pem forContainer:(NSString *)containerIdentifier;
// The PEM the given key identifier resolves to: the one the application handed over under the
// container's name, or the one in its bundle.
- (nullable NSString *)signingKeyForContainer:(NSString *)containerIdentifier;
// The record of the signed-in user, which every request's zone owner name comes from.
- (nullable NSString *)userRecordIDForContainer:(NSString *)containerIdentifier;
- (void)setUserRecordID:(nullable NSString *)userRecordID forContainer:(NSString *)containerIdentifier;
@end

// The JWT a web services authentication key signs. The header and the payload are CloudKit's own
// format and the signature is made by charon@micro-ecc, which is the part iOS 6 cannot do.
extern NSString *CharonCKWebAuthToken(NSString *keyID, NSString *teamID, NSDate *now);
extern NSString *CharonCKBase64URL(NSData *data);
extern NSData *_Nullable CharonCKPEMPrivateKey(NSString *pem);

// MARK: - The transport

typedef void (^CharonCKCompletion)(id _Nullable body, NSError *_Nullable error);

@interface CharonCKTransport : NSObject
+ (instancetype)shared;
// A request under a database root: `records/lookup`, `zones/modify`, `subscriptions/list`, and the
// rest. The body is JSON and the answer is either the decoded payload or a CKError.
- (void)performContainer:(CKContainer *)container
                database:(nullable CKDatabase *)database
             environment:(NSString *)environment
                  method:(NSString *)method
                    path:(NSString *)path
                    body:(nullable NSDictionary *)body
              completion:(CharonCKCompletion)completion;
// The same for a path that is not under a database root: the user, share and asset endpoints.
// The environment a container is in: production for a container provisioned for it, development
// otherwise, which is the environment CloudKit creates a container in.
// A database is only ever made by a container, and neither names the other, so the transport is
// told: the container a database belongs to and the environment it is reached in.
- (NSString *)environmentForContainer:(CKContainer *)container;
// The database root of the interface for one container and one database: `database/1/<container>/
// <environment>/<scope>`, with 1 the development environment and 2 production.
- (NSString *)databaseRootForContainer:(NSString *)containerIdentifier
                              database:(CKDatabase *)database
                           environment:(NSString *)environment;
// A database is only ever made by a container, and neither names the other, so the transport is
// told: the container a database belongs to and the environment it is reached in. This is a private
// table and not a property of either object, which is why the database root is built here.
- (void)setContainer:(CKContainer *)container forDatabase:(CKDatabase *)database environment:(NSString *)environment;
- (NSMapTable *)containerForDatabase;
- (NSMapTable *)environmentForDatabase;
// The two private tables are set once, by the singleton's own +initialize, through their ivars, and are
// read through -containerForDatabase and -environmentForDatabase. So they are @dynamic: the port
// synthesises neither, and the library's flags make an auto-synthesised property an error rather than a
// silent second definition of something the class does not own.
@property (nonatomic, strong, nullable) NSMapTable *containers;
@property (nonatomic, strong, nullable) NSMapTable *environments;
@end

// MARK: - The documents
//
// A subscription and a record, and the JSON the service reads and writes for each. The record's
// snapshot is the fields it holds as they go up: a save sends what is there now, not what was there
// before, and the change token the service holds is what says which of the two a caller means.
extern NSDictionary *CharonCKSubscriptionDocument(CKSubscription *subscription);
extern CKRecordZone *_Nullable CharonCKZoneWithDocument(NSDictionary *document);
extern CKSubscription *_Nullable CharonCKSubscriptionWithDocument(NSDictionary *document);
extern NSDictionary *CharonCKFieldsSnapshot(CKRecord *record);
// The token of a server change token and the change token of a token, which the service carries as
// the continuation marker of a changes answer.
extern NSData *_Nullable CharonCKSystemFieldsSnapshotToken(CKServerChangeToken *_Nullable token);
extern CKServerChangeToken *_Nullable CharonCKServerTokenFromData(NSData *data);
// The system's fields of a record, which a caller cannot write and a save must not send.
extern NSDictionary *CharonCKSystemFieldsSnapshot(CKRecord *record);

// The sharing values as the service sends them and as the objects above them are made of. A share's
// metadata is never instantiated by an application, so these are the only way one is built here.
extern CKUserIdentity *_Nullable CharonCKUserIdentityWithDocument(NSDictionary *document);
extern CKUserIdentityLookupInfo *_Nullable CharonCKLookupInfoWithDocument(NSDictionary *document);
extern CKShareParticipant *_Nullable CharonCKShareParticipantWithDocument(NSDictionary *document);
extern CKShareMetadata *_Nullable CharonCKShareMetadataWithDocument(NSDictionary *document, CKContainer *_Nullable container);

// MARK: - The operations
//
// An operation is an NSOperation of the scheduler this package carries, and CKDatabaseOperation adds
// the database to run it against. The scheduler is the port's own rather than the release's
// NSOperationQueue, so that an operation's priority, its quality of service and its cancellation are
// its own and a caller that adds one to a database does not inherit a queue's state.
@interface CharonCKOPScheduler : NSObject
+ (void)add:(NSOperation *)operation;
// The end of one: the operation is taken out of the queue and the operation's own -finish is what
// the caller waiting on it is released by, which is why this release's NSOperation needs no -finish
// of its own for the port to end one.
+ (void)complete:(NSOperation *)operation;
+ (void)cancelAll;
@end

// The container a database belongs to. Neither the header's CKDatabase nor its CKContainer names
// the other and the service's path is under a container, so this is the port's own state and the one
// thing the transport and the operations both read to find out where a request goes.
@interface CKDatabase (CharonCKPrivate)
- (nullable CKContainer *)ck_container;
@end

@interface CKContainer (CharonCKPrivate)
// The record of the user the credentials are signed in as: the only user record a container has,
// under the current owner in the default zone, and the one the header's own
// -fetchCurrentUserRecordOperation fetches.
- (nullable CKRecordID *)currentUserRecordID;
@end

// What every operation of this package needs and none of them should decide for itself. The base
// class's own -init refuses the abstract base and nothing else, as measured, and it is that -init
// which calls -charon_setUp; these are also the one request, the one end and the partial-failure rule
// the whole family shares.
@interface CKOperation (CharonCKShared)
- (void)charon_setUp;
- (void)charon_finish;
// The per-item failures of a partial answer, and the CKError that carries them under
// CKPartialErrorsByItemIDKey.
- (nullable NSError *)partialFailureWithItems:(NSDictionary *)items;
// One request over the transport, and the operation ends when the answer is in.
- (void)runMethod:(NSString *)method path:(NSString *)path body:(nullable NSDictionary *)body
      completion:(void (^)(id _Nullable body, NSError *_Nullable error))completion;
@end

// The sharing values as the service sends them and as the objects above them are made of. A share's
// metadata is never instantiated by an application, so these are the only way one is built here.
extern CKUserIdentity *_Nullable CharonCKUserIdentityWithDocument(NSDictionary *document);
extern CKUserIdentityLookupInfo *_Nullable CharonCKLookupInfoWithDocument(NSDictionary *document);
extern CKShareParticipant *_Nullable CharonCKShareParticipantWithDocument(NSDictionary *document);
extern CKShareMetadata *_Nullable CharonCKShareMetadataWithDocument(NSDictionary *document, CKContainer *_Nullable container);

// MARK: - The paths

extern NSString *CharonCKDatabaseRoot(CKDatabase *database);
extern NSString *CharonCKZonePath(CKRecordZoneID *zoneID);
extern NSDictionary *CharonCKRecordIDDocument(CKRecordID *recordID);
extern CKRecordZoneID *_Nullable CharonCKZoneIDFromDocument(NSDictionary *_Nullable json);
extern NSDictionary *CharonCKZoneIDDocument(CKRecordZoneID *zoneID);
extern CKRecordID *_Nullable CharonCKRecordIDFromDocument(NSDictionary *_Nullable json);

// MARK: - The query
//
// A CKQuery's NSPredicate becomes the query document the service reads, and the cursor and the
// records of the answer become the objects the caller asked for. A predicate the service has no form
// for is refused with CKErrorInvalidArguments, the code the header names for a malformed predicate.
extern NSDictionary *_Nullable CharonCKQueryDocument(CKQuery *query, NSString *_Nullable zoneID,
                                                      NSArray *_Nullable desiredKeys, NSUInteger resultsLimit,
                                                      NSError **error);
extern CKQueryCursor *_Nullable CharonCKCursorFromToken(NSData *token);
extern NSData *_Nullable CharonCKTokenFromCursor(CKQueryCursor *_Nullable cursor);
extern NSArray<CKRecord *> *CharonCKRecordsFromResults(NSArray *results, NSSet *_Nullable desiredKeys);
extern CKRecord *_Nullable CharonCKRecordFromResult(NSDictionary *result, NSSet *_Nullable desiredKeys);

// MARK: - The values
//
// A record field and its wire value are the same shape in both directions, so the mapping is written
// once. A field is a string, a number, a date, data, a reference, an asset, a location, or an array
// or dictionary of those; `kind` is written with the value that came back, so a caller that needs to
// know a date from a number can.
extern id _Nullable CharonCKValueFromJSON(id _Nullable json, Class _Nullable *_Nullable kind);
extern id _Nullable CharonCKValueToJSON(id _Nullable value);
extern NSDictionary *CharonCKFieldsToJSON(NSDictionary *fields);
extern NSDictionary *CharonCKFieldsFromJSON(NSDictionary *_Nullable json);
extern NSDate *_Nullable CharonCKDateFromJSON(id json);
extern NSString *CharonCKMD5Hex(NSData *data);
// The MD5 of an asset's bytes, and the millisecond date the changes endpoints use.
extern double CharonCKMilliseconds(NSDate *date);

NS_ASSUME_NONNULL_END
