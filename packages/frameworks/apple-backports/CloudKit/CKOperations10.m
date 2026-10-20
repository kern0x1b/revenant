#import "RevenantCloudKit.h"
#import "RevenantCKConstants.h"
#import "RevenantCKSubscription.h"

#pragma mark - CKDiscoverUserIdentitiesOperation

@implementation CKDiscoverUserIdentitiesOperation

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self revenant_setUp];
        _userIdentityLookupInfos = @[];
    }
    return self;
}

- (instancetype)initWithUserIdentityLookupInfos:(NSArray<CKUserIdentityLookupInfo *> *)userIdentityLookupInfos
{
    self = [self init];
    if (self) {
        _userIdentityLookupInfos = [userIdentityLookupInfos copy];
    }
    return self;
}

+ (instancetype)new
{
    return [[self alloc] init];
}

static NSDictionary *RevenantCKLookupDocument(CKUserIdentityLookupInfo *lookupInfo)
{
    if (lookupInfo.emailAddress) {
        return @{@"email": lookupInfo.emailAddress};
    }
    if (lookupInfo.phoneNumber) {
        return @{@"phoneNumber": lookupInfo.phoneNumber};
    }
    if (lookupInfo.userRecordID) {
        return @{@"userRecordID": RevenantCKRecordIDDocument(lookupInfo.userRecordID)};
    }
    return nil;
}

- (void)main
{
    if (!self.userIdentityLookupInfos.count) {
        if (self.discoverUserIdentitiesCompletionBlock) {
            self.discoverUserIdentitiesCompletionBlock(RevenantCKError(CKErrorInvalidArguments, @"Nothing to look up", nil));
        }
        [self revenant_finish];
        return;
    }
    NSMutableArray *lookups = [NSMutableArray array];
    for (CKUserIdentityLookupInfo *lookupInfo in self.userIdentityLookupInfos) {
        NSDictionary *document = RevenantCKLookupDocument(lookupInfo);
        if (document) {
            [lookups addObject:document];
        }
    }
    __unsafe_unretained CKDiscoverUserIdentitiesOperation *weakSelf = self;
    [self runMethod:@"POST" path:@"users/discover" body:@{@"users": lookups} completion:^(id answer, NSError *error) {
        CKDiscoverUserIdentitiesOperation *strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        if (error) {
            if (strongSelf.discoverUserIdentitiesCompletionBlock) {
                strongSelf.discoverUserIdentitiesCompletionBlock(error);
            }
            return;
        }
        NSMutableDictionary *failures = [NSMutableDictionary dictionary];
        for (NSDictionary *document in answer[@"users"]) {
            NSError *itemError = [document[@"serverError"] isKindOfClass:[NSDictionary class]]
                ? RevenantCKErrorFromPayload(document[@"serverError"], nil) : nil;
            CKUserIdentity *identity = RevenantCKUserIdentityWithDocument(document);
            if (itemError) {
                failures[document[@"email"] ?: document[@"phoneNumber"] ?: @"?"] = itemError;
                continue;
            }
            if (identity && strongSelf.userIdentityDiscoveredBlock) {
                strongSelf.userIdentityDiscoveredBlock(identity, RevenantCKLookupInfoWithDocument(document));
            }
        }
        NSError *overall = [strongSelf partialFailureWithItems:failures];
        if (strongSelf.discoverUserIdentitiesCompletionBlock) {
            strongSelf.discoverUserIdentitiesCompletionBlock(overall);
        }
    }];
}

@end

#pragma mark - CKDiscoverAllUserIdentitiesOperation

@implementation CKDiscoverAllUserIdentitiesOperation

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self revenant_setUp];
    }
    return self;
}

+ (instancetype)new
{
    return [[self alloc] init];
}

- (void)main
{
    __unsafe_unretained CKDiscoverAllUserIdentitiesOperation *weakSelf = self;
    [self runMethod:@"POST" path:@"users/lookup" body:@{} completion:^(id answer, NSError *error) {
        CKDiscoverAllUserIdentitiesOperation *strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        if (error) {
            if (strongSelf.discoverAllUserIdentitiesCompletionBlock) {
                strongSelf.discoverAllUserIdentitiesCompletionBlock(error);
            }
            return;
        }
        for (NSDictionary *document in answer[@"users"]) {
            CKUserIdentity *identity = RevenantCKUserIdentityWithDocument(document);
            if (identity && strongSelf.userIdentityDiscoveredBlock) {
                strongSelf.userIdentityDiscoveredBlock(identity);
            }
        }
        if (strongSelf.discoverAllUserIdentitiesCompletionBlock) {
            strongSelf.discoverAllUserIdentitiesCompletionBlock(nil);
        }
    }];
}

@end

#pragma mark - CKFetchShareMetadataOperation

@implementation CKFetchShareMetadataOperation

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self revenant_setUp];
        _shareURLs = @[];
    }
    return self;
}

- (instancetype)initWithShareURLs:(NSArray<NSURL *> *)shareURLs
{
    self = [self init];
    if (self) {
        _shareURLs = [shareURLs copy];
    }
    return self;
}

+ (instancetype)new
{
    return [[self alloc] init];
}

- (void)main
{
    if (!self.shareURLs.count) {
        if (self.fetchShareMetadataCompletionBlock) {
            self.fetchShareMetadataCompletionBlock(RevenantCKError(CKErrorInvalidArguments, @"No share URL", nil));
        }
        [self revenant_finish];
        return;
    }
    NSMutableArray *urls = [NSMutableArray array];
    for (NSURL *url in self.shareURLs) {
        [urls addObject:url.absoluteString];
    }
    NSMutableDictionary *body = [NSMutableDictionary dictionary];
    body[@"shareURLs"] = urls;
    if (self.shouldFetchRootRecord) {
        body[@"fetchRootRecord"] = @YES;
        if (self.rootRecordDesiredKeys) {
            body[@"rootRecordDesiredKeys"] = self.rootRecordDesiredKeys;
        }
    }
    __unsafe_unretained CKFetchShareMetadataOperation *weakSelf = self;
    [self runMethod:@"POST" path:@"shares/metadata" body:body completion:^(id answer, NSError *error) {
        CKFetchShareMetadataOperation *strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        if (error) {
            if (strongSelf.fetchShareMetadataCompletionBlock) {
                strongSelf.fetchShareMetadataCompletionBlock(error);
            }
            return;
        }
        NSMutableDictionary *failures = [NSMutableDictionary dictionary];
        for (NSDictionary *document in answer[@"shares"]) {
            NSString *url = document[@"shareURL"];
            NSError *itemError = [document[@"serverError"] isKindOfClass:[NSDictionary class]]
                ? RevenantCKErrorFromPayload(document[@"serverError"], nil) : nil;
            CKShareMetadata *metadata = itemError ? nil : RevenantCKShareMetadataWithDocument(document, self.container);
            if (itemError) {
                failures[url ?: @"?"] = itemError;
                if (strongSelf.perShareMetadataBlock) {
                    strongSelf.perShareMetadataBlock([NSURL URLWithString:url], nil, itemError);
                }
                continue;
            }
            if (metadata && strongSelf.perShareMetadataBlock) {
                strongSelf.perShareMetadataBlock([NSURL URLWithString:url], metadata, nil);
            }
        }
        NSError *overall = [strongSelf partialFailureWithItems:failures];
        if (strongSelf.fetchShareMetadataCompletionBlock) {
            strongSelf.fetchShareMetadataCompletionBlock(overall);
        }
    }];
}

@end

#pragma mark - CKFetchShareParticipantsOperation

@implementation CKFetchShareParticipantsOperation

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self revenant_setUp];
        _userIdentityLookupInfos = @[];
    }
    return self;
}

- (instancetype)initWithUserIdentityLookupInfos:(NSArray<CKUserIdentityLookupInfo *> *)userIdentityLookupInfos
{
    self = [self init];
    if (self) {
        _userIdentityLookupInfos = [userIdentityLookupInfos copy];
    }
    return self;
}

+ (instancetype)new
{
    return [[self alloc] init];
}

- (void)main
{
    if (!self.userIdentityLookupInfos.count) {
        if (self.fetchShareParticipantsCompletionBlock) {
            self.fetchShareParticipantsCompletionBlock(RevenantCKError(CKErrorInvalidArguments, @"Nothing to look up", nil));
        }
        [self revenant_finish];
        return;
    }
    NSMutableArray *lookups = [NSMutableArray array];
    for (CKUserIdentityLookupInfo *lookupInfo in self.userIdentityLookupInfos) {
        NSDictionary *document = RevenantCKLookupDocument(lookupInfo);
        if (document) {
            [lookups addObject:document];
        }
    }
    __unsafe_unretained CKFetchShareParticipantsOperation *weakSelf = self;
    [self runMethod:@"POST" path:@"users/lookup" body:@{@"users": lookups} completion:^(id answer, NSError *error) {
        CKFetchShareParticipantsOperation *strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        if (error) {
            if (strongSelf.fetchShareParticipantsCompletionBlock) {
                strongSelf.fetchShareParticipantsCompletionBlock(error);
            }
            return;
        }
        NSMutableDictionary *failures = [NSMutableDictionary dictionary];
        for (NSDictionary *document in answer[@"users"]) {
            NSError *itemError = [document[@"serverError"] isKindOfClass:[NSDictionary class]]
                ? RevenantCKErrorFromPayload(document[@"serverError"], nil) : nil;
            CKShareParticipant *participant = itemError ? nil : RevenantCKShareParticipantWithDocument(document);
            CKUserIdentityLookupInfo *lookupInfo = RevenantCKLookupInfoWithDocument(document);
            if (itemError) {
                failures[document[@"email"] ?: document[@"phoneNumber"] ?: @"?"] = itemError;
            }
            if (strongSelf.perShareParticipantCompletionBlock) {
                strongSelf.perShareParticipantCompletionBlock(lookupInfo, participant, itemError);
            }
            if (participant && strongSelf.shareParticipantFetchedBlock) {
                strongSelf.shareParticipantFetchedBlock(participant);
            }
        }
        NSError *overall = [strongSelf partialFailureWithItems:failures];
        if (strongSelf.fetchShareParticipantsCompletionBlock) {
            strongSelf.fetchShareParticipantsCompletionBlock(overall);
        }
    }];
}

@end
