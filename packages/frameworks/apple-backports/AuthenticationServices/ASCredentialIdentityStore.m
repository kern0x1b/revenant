#import <AuthenticationServices/AuthenticationServices.h>
#import "RevenantASConstruction.h"

@interface ASCredentialIdentityStore ()
@property (nonatomic, copy) NSString *revenant_storePath;
@end

@implementation ASCredentialIdentityStore

@synthesize revenant_storePath = _revenant_storePath;

- (instancetype)revenant_initWithStorePath:(NSString *)path
{
    self = [super init];
    if (self)
        _revenant_storePath = [path copy];
    return self;
}

- (NSError *)revenant_storeError
{
    return [NSError errorWithDomain:ASCredentialIdentityStoreErrorDomain
                               code:ASCredentialIdentityStoreErrorCodeInternalError
                           userInfo:@{NSLocalizedDescriptionKey: @"the credential identity store could not be written"}];
}

- (NSString *)revenant_storePath
{
    if (!_revenant_storePath) {
        NSString *base = NSProcessInfo.processInfo.environment[@"AS_CREDENTIAL_STORE_PATH"];
        if (!base) {
            base = [NSString stringWithFormat:@"%@/authservices-store",
                    NSProcessInfo.processInfo.environment[@"CHICON_RUNS"]
                        ?: [NSTemporaryDirectory() stringByAppendingPathComponent:@"revenant-runs"]];
        }
        _revenant_storePath = base;
    }
    return _revenant_storePath;
}

#pragma mark - the shared store

+ (ASCredentialIdentityStore *)sharedStore
{
    static ASCredentialIdentityStore *shared;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        shared = [[ASCredentialIdentityStore alloc] revenant_initWithStorePath:nil];
    });
    return shared;
}

#pragma mark - the identities, as they are held

- (NSMutableArray *)revenant_records
{
    NSMutableArray *records = [NSMutableArray array];
    NSData *data = [NSData dataWithContentsOfFile:self.revenant_storePath];
    id held = data ? [NSPropertyListSerialization propertyListWithData:data options:0 format:NULL error:NULL] : nil;
    if ([held isKindOfClass:[NSArray class]])
        [records addObjectsFromArray:held];
    return records;
}

- (BOOL)revenant_writeRecords:(NSArray *)records
{
    [[NSFileManager defaultManager] createDirectoryAtPath:[self.revenant_storePath stringByDeletingLastPathComponent]
                              withIntermediateDirectories:YES attributes:nil error:NULL];
    NSData *data = [NSPropertyListSerialization dataWithPropertyList:records format:NSPropertyListBinaryFormat_v1_0
                                                              options:0 error:NULL];
    if (!data)
        return NO;
    return [data writeToFile:self.revenant_storePath atomically:YES];
}

- (NSDictionary *)revenant_recordFor:(ASPasswordCredentialIdentity *)identity
{
    ASCredentialServiceIdentifier *service = identity.serviceIdentifier;
    for (NSDictionary *record in [self revenant_records]) {
        if ([record[@"identifier"] isEqual:service.identifier] &&
            [record[@"type"] integerValue] == (NSInteger)service.type &&
            [record[@"user"] isEqual:identity.user] &&
            ((record[@"recordIdentifier"] == nil && identity.recordIdentifier == nil) ||
             [record[@"recordIdentifier"] isEqual:identity.recordIdentifier]))
            return record;
    }
    return nil;
}

- (ASPasswordCredentialIdentity *)revenant_identityFor:(NSDictionary *)record
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
    if (completion)
        completion([[ASCredentialIdentityStoreState alloc] revenant_initWithEnabled:YES
                                                  supportsIncrementalUpdates:YES]);
}

- (void)saveCredentialIdentities:(NSArray<ASPasswordCredentialIdentity *> *)credentialIdentities
                      completion:(void (^)(BOOL success, NSError * _Nullable error))completion
{
    NSMutableArray *records = [self revenant_records];
    for (ASPasswordCredentialIdentity *identity in credentialIdentities) {
        NSDictionary *existing = [self revenant_recordFor:identity];
        if (existing)
            [records removeObject:existing];
        NSMutableDictionary *record = [@{@"identifier": identity.serviceIdentifier.identifier ?: @"",
                                         @"type": @(identity.serviceIdentifier.type),
                                         @"user": identity.user ?: @"",
                                         @"rank": @(identity.rank)} mutableCopy];
        if (identity.recordIdentifier)
            record[@"recordIdentifier"] = identity.recordIdentifier;
        [records addObject:record];
    }
    BOOL written = [self revenant_writeRecords:records];
    if (completion)
        completion(written, written ? nil : [self revenant_storeError]);
}

- (void)removeCredentialIdentities:(NSArray<ASPasswordCredentialIdentity *> *)credentialIdentities
                       completion:(void (^)(BOOL success, NSError * _Nullable error))completion
{
    NSMutableArray *records = [self revenant_records];
    for (ASPasswordCredentialIdentity *identity in credentialIdentities) {
        NSDictionary *existing = [self revenant_recordFor:identity];
        if (existing)
            [records removeObject:existing];
    }
    BOOL written = [self revenant_writeRecords:records];
    if (completion)
        completion(written, written ? nil : [self revenant_storeError]);
}

- (void)removeAllCredentialIdentitiesWithCompletion:(void (^)(BOOL success, NSError * _Nullable error))completion
{
    BOOL written = [self revenant_writeRecords:@[]];
    if (completion)
        completion(written, written ? nil : [self revenant_storeError]);
}

- (void)replaceCredentialIdentitiesWithIdentities:(NSArray<ASPasswordCredentialIdentity *> *)newCredentialIdentities
                                       completion:(void (^)(BOOL success, NSError * _Nullable error))completion
{
    NSMutableArray *records = [NSMutableArray array];
    for (ASPasswordCredentialIdentity *identity in newCredentialIdentities) {
        NSMutableDictionary *record = [@{@"identifier": identity.serviceIdentifier.identifier ?: @"",
                                         @"type": @(identity.serviceIdentifier.type),
                                         @"user": identity.user ?: @"",
                                         @"rank": @(identity.rank)} mutableCopy];
        if (identity.recordIdentifier)
            record[@"recordIdentifier"] = identity.recordIdentifier;
        [records addObject:record];
    }
    BOOL written = [self revenant_writeRecords:records];
    if (completion)
        completion(written, written ? nil : [self revenant_storeError]);
}

@end
