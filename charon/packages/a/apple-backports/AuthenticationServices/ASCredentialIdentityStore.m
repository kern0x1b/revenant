// ASCredentialIdentityStore, of iOS 12.0: where a password manager's credentials are kept.
//
// **The writing half is never run against the host, and this file says why.** On a Mac,
// `saveCredentialIdentities:`, `removeCredentialIdentities:`, `removeAllCredentialIdentities` and
// `replaceCredentialIdentitiesWithIdentities:` change the *user's* AutoFill state on that machine. A
// differential that called them to see what they return would be writing to the reviewer's passwords.
// The host side of this family is therefore read-only — only
// `getCredentialIdentityStoreStateWithCompletion:`, and only because it asks the system what it
// already holds — and the writing half's behaviour is documented from the header, not measured on the
// Mac. `tests/backports/host/authservices/values.m` greps for the four names before it runs and refuses
// to start if any of them is in the host half.
//
// **What backs it here.** A property list under `.agent-work/runs/`, beside the port's other run
// output, holding one record per identity: the service identifier's identifier and type, the user, the
// record identifier and the rank. The directory is chosen by `AS_CREDENTIAL_STORE_PATH` when it is set,
// and there is a deliberate difference from the system store: there is no daemon behind this one, and
// nothing outside the process reads it. That is what -getCredentialIdentityStoreStateWithCompletion: has
// to report, and it is why the port says the store is enabled for the application that owns it rather
// than claiming to be the system's autofill database.
#import <AuthenticationServices/AuthenticationServices.h>
#import "CharonASConstruction.h"

// A class extension, not a category: a property declared in a category cannot be implemented in the
// class's own @implementation, which is the error the constructor header's version produced.
@interface ASCredentialIdentityStore ()
@property (nonatomic, copy) NSString *charon_storePath;
@end

@implementation ASCredentialIdentityStore

@synthesize charon_storePath = _charon_storePath;

- (instancetype)charon_initWithStorePath:(NSString *)path
{
    // -init is unavailable in the release's header; the store is a shared object there, and here the
    // shared object is +sharedStore and the path is where its file goes.
    self = [super init];
    if (self)
        _charon_storePath = [path copy];
    return self;
}

// The error the header names for a failed write, in the header's own domain and code.
- (NSError *)charon_storeError
{
    return [NSError errorWithDomain:ASCredentialIdentityStoreErrorDomain
                               code:ASCredentialIdentityStoreErrorCodeInternalError
                           userInfo:@{NSLocalizedDescriptionKey: @"the credential identity store could not be written"}];
}

- (NSString *)charon_storePath
{
    if (!_charon_storePath) {
        NSString *base = NSProcessInfo.processInfo.environment[@"AS_CREDENTIAL_STORE_PATH"];
        if (!base) {
            // Beside the port's other run output, never in the user's own Library: this is the
            // process's store and nothing else reads it.
            base = [NSString stringWithFormat:@"%@/authservices-store",
                    NSProcessInfo.processInfo.environment[@"CHICON_RUNS"]
                        ?: [NSTemporaryDirectory() stringByAppendingPathComponent:@"charon-runs"]];
        }
        _charon_storePath = base;
    }
    return _charon_storePath;
}

#pragma mark - the shared store

+ (ASCredentialIdentityStore *)sharedStore
{
    static ASCredentialIdentityStore *shared;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        shared = [[ASCredentialIdentityStore alloc] charon_initWithStorePath:nil];
    });
    return shared;
}

#pragma mark - the identities, as they are held

// A record is a property list: service identifier, service type, user, record identifier, rank. The
// service identifier is stored as its two parts and rebuilt on the way out, because a class does not
// cross a property list and the two parts are what the value is.
- (NSMutableArray *)charon_records
{
    NSMutableArray *records = [NSMutableArray array];
    NSData *data = [NSData dataWithContentsOfFile:self.charon_storePath];
    id held = data ? [NSPropertyListSerialization propertyListWithData:data options:0 format:NULL error:NULL] : nil;
    if ([held isKindOfClass:[NSArray class]])
        [records addObjectsFromArray:held];
    return records;
}

- (BOOL)charon_writeRecords:(NSArray *)records
{
    [[NSFileManager defaultManager] createDirectoryAtPath:[self.charon_storePath stringByDeletingLastPathComponent]
                              withIntermediateDirectories:YES attributes:nil error:NULL];
    NSData *data = [NSPropertyListSerialization dataWithPropertyList:records format:NSPropertyListBinaryFormat_v1_0
                                                              options:0 error:NULL];
    if (!data)
        return NO;
    return [data writeToFile:self.charon_storePath atomically:YES];
}

// The record of one identity, or nil when the store does not hold it. The identity is matched on the
// service identifier, the user and the record identifier -- the three the header says identify it --
// and NOT on the rank, which is the order the system offers them in and not part of what they are.
- (NSDictionary *)charon_recordFor:(ASPasswordCredentialIdentity *)identity
{
    ASCredentialServiceIdentifier *service = identity.serviceIdentifier;
    for (NSDictionary *record in [self charon_records]) {
        if ([record[@"identifier"] isEqual:service.identifier] &&
            [record[@"type"] integerValue] == (NSInteger)service.type &&
            [record[@"user"] isEqual:identity.user] &&
            ((record[@"recordIdentifier"] == nil && identity.recordIdentifier == nil) ||
             [record[@"recordIdentifier"] isEqual:identity.recordIdentifier]))
            return record;
    }
    return nil;
}

- (ASPasswordCredentialIdentity *)charon_identityFor:(NSDictionary *)record
{
    NSString *identifier = record[@"identifier"];
    if (!identifier)
        return nil;
    return [ASPasswordCredentialIdentity identityWithServiceIdentifier:
                [[ASCredentialServiceIdentifier alloc] initWithIdentifier:identifier
                                                                     type:(ASCredentialServiceIdentifierType)[record[@"type"] integerValue]]
                                                              user:record[@"user"]
                                                  recordIdentifier:record[@"recordIdentifier"]];
}

#pragma mark - the header's six

- (void)getCredentialIdentityStoreStateWithCompletion:(void (^)(ASCredentialIdentityStoreState *state))completion
{
    // The one method the host differential is allowed to call, and this is the port's own answer:
    // enabled, because the application's own store can be written; and it takes changes only, because
    // this store appends and removes records and has no whole-set notion of its own.
    if (completion)
        completion([[ASCredentialIdentityStoreState alloc] charon_initWithEnabled:YES
                                                  supportsIncrementalUpdates:YES]);
}

- (void)saveCredentialIdentities:(NSArray<ASPasswordCredentialIdentity *> *)credentialIdentities
                      completion:(void (^)(BOOL success, NSError * _Nullable error))completion
{
    // The header: an identity already in the store is REPLACED by the one in the array, and on failure
    // none of the identities is saved and an ASCredentialIdentityStoreErrorDomain error arrives. So the
    // whole write is built and only then committed, and a failure anywhere leaves the store as it was.
    NSMutableArray *records = [self charon_records];
    for (ASPasswordCredentialIdentity *identity in credentialIdentities) {
        NSDictionary *existing = [self charon_recordFor:identity];
        if (existing)
            [records removeObject:existing];
        NSMutableDictionary *record = [@{@"identifier": identity.serviceIdentifier.identifier ?: @"",
                                         @"type": @(identity.serviceIdentifier.type),
                                         @"user": identity.user ?: @"",
                                         @"rank": @(identity.rank)} mutableCopy];
        // Omitted, not [NSNull null]: NSNull is not a property-list value, and one of them in a record
        // made the whole write unserializable, so the store saved nothing and the completion reported
        // the failure it exists for. "No record identifier" is the absence of the key.
        if (identity.recordIdentifier)
            record[@"recordIdentifier"] = identity.recordIdentifier;
        [records addObject:record];
    }
    BOOL written = [self charon_writeRecords:records];
    if (completion)
        completion(written, written ? nil : [self charon_storeError]);
}

- (void)removeCredentialIdentities:(NSArray<ASPasswordCredentialIdentity *> *)credentialIdentities
                       completion:(void (^)(BOOL success, NSError * _Nullable error))completion
{
    // The header restricts this to incremental stores, and this store is one: only the named records
    // go, and everything else is left exactly as it was.
    NSMutableArray *records = [self charon_records];
    for (ASPasswordCredentialIdentity *identity in credentialIdentities) {
        NSDictionary *existing = [self charon_recordFor:identity];
        if (existing)
            [records removeObject:existing];
    }
    BOOL written = [self charon_writeRecords:records];
    if (completion)
        completion(written, written ? nil : [self charon_storeError]);
}

- (void)removeAllCredentialIdentitiesWithCompletion:(void (^)(BOOL success, NSError * _Nullable error))completion
{
    BOOL written = [self charon_writeRecords:@[]];
    if (completion)
        completion(written, written ? nil : [self charon_storeError]);
}

- (void)replaceCredentialIdentitiesWithIdentities:(NSArray<ASPasswordCredentialIdentity *> *)newCredentialIdentities
                                       completion:(void (^)(BOOL success, NSError * _Nullable error))completion
{
    // The store's set is EXACTLY the array after this call. That is what the caller asked for and the
    // port does not second-guess it. My first version saved the new identities as a superset and left
    // anything not in the array alone, on the reading that the header confines this method to a store
    // that does not take incremental updates -- and that reading was wrong: the restriction is a rule
    // for the caller about which method to call, not permission for the callee to do something else.
    // An application that calls this is saying "these and only these", and a port that keeps the rest
    // would be handing back a set the caller did not ask for and cannot see.
    NSMutableArray *records = [NSMutableArray array];
    for (ASPasswordCredentialIdentity *identity in newCredentialIdentities) {
        NSMutableDictionary *record = [@{@"identifier": identity.serviceIdentifier.identifier ?: @"",
                                         @"type": @(identity.serviceIdentifier.type),
                                         @"user": identity.user ?: @"",
                                         @"rank": @(identity.rank)} mutableCopy];
        // Omitted, not [NSNull null]: NSNull is not a property-list value, and one of them in a record
        // made the whole write unserializable, so the store saved nothing and the completion reported
        // the failure it exists for. "No record identifier" is the absence of the key.
        if (identity.recordIdentifier)
            record[@"recordIdentifier"] = identity.recordIdentifier;
        [records addObject:record];
    }
    BOOL written = [self charon_writeRecords:records];
    if (completion)
        completion(written, written ? nil : [self charon_storeError]);
}

@end
