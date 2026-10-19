#import <AuthenticationServices/AuthenticationServices.h>
#import "CharonASConstruction.h"

@interface ASCredentialIdentityStore ()
@property (nonatomic, copy) NSString *charon_storePath;
@end

@implementation ASCredentialIdentityStore

@synthesize charon_storePath = _charon_storePath;

- (instancetype)charon_initWithStorePath:(NSString *)path
{
    self = [super init];
    if (self)
        _charon_storePath = [path copy];
    return self;
}

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
    if (completion)
        completion([[ASCredentialIdentityStoreState alloc] charon_initWithEnabled:YES
                                                  supportsIncrementalUpdates:YES]);
}

- (void)saveCredentialIdentities:(NSArray<ASPasswordCredentialIdentity *> *)credentialIdentities
                      completion:(void (^)(BOOL success, NSError * _Nullable error))completion
{
    NSMutableArray *records = [self charon_records];
    for (ASPasswordCredentialIdentity *identity in credentialIdentities) {
        NSDictionary *existing = [self charon_recordFor:identity];
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
    BOOL written = [self charon_writeRecords:records];
    if (completion)
        completion(written, written ? nil : [self charon_storeError]);
}

- (void)removeCredentialIdentities:(NSArray<ASPasswordCredentialIdentity *> *)credentialIdentities
                       completion:(void (^)(BOOL success, NSError * _Nullable error))completion
{
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
    BOOL written = [self charon_writeRecords:records];
    if (completion)
        completion(written, written ? nil : [self charon_storeError]);
}

@end
