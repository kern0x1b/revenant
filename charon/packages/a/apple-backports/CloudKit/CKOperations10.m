// The sharing operations iOS 10 added: discovering who a user is, resolving a share URL to the
// metadata it stands for, asking who the participants of a share are, and accepting a share.
//
// They are all one request and one answer over the same transport, and they are together here because
// the band machinery puts an object in the band of the release its API arrived in and iOS 10 brought
// all five.
//
// What they have in common, and what the operations of the first release already established, is
// repeated: the per-item block is called on the transport's queue in the order the service answered,
// the completion is called last and exactly once, and an item the service refused arrives as that
// item's own error rather than as the operation's. A batch where some items failed is
// CKErrorPartialFailure with the per-item errors under CKPartialErrorsByItemIDKey.
//
// Two of the five are about an identity and three about a share, and the difference is the endpoint:
// an identity is looked up under the container's own users root, a share under the shares root.

#import "CharonCloudKit.h"
#import "CharonCKConstants.h"
#import "CharonCKSubscription.h"

#pragma mark - CKDiscoverUserIdentitiesOperation

@implementation CKDiscoverUserIdentitiesOperation

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self charon_setUp];
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

// The document of a lookup: an email address, a phone number or a record identifier, and which of
// the three it is, under the names the service reads.
static NSDictionary *CharonCKLookupDocument(CKUserIdentityLookupInfo *lookupInfo)
{
    if (lookupInfo.emailAddress) {
        return @{@"email": lookupInfo.emailAddress};
    }
    if (lookupInfo.phoneNumber) {
        return @{@"phoneNumber": lookupInfo.phoneNumber};
    }
    if (lookupInfo.userRecordID) {
        return @{@"userRecordID": CharonCKRecordIDDocument(lookupInfo.userRecordID)};
    }
    return nil;
}

- (void)main
{
    if (!self.userIdentityLookupInfos.count) {
        if (self.discoverUserIdentitiesCompletionBlock) {
            self.discoverUserIdentitiesCompletionBlock(CharonCKError(CKErrorInvalidArguments, @"Nothing to look up", nil));
        }
        [self charon_finish];
        return;
    }
    NSMutableArray *lookups = [NSMutableArray array];
    for (CKUserIdentityLookupInfo *lookupInfo in self.userIdentityLookupInfos) {
        NSDictionary *document = CharonCKLookupDocument(lookupInfo);
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
                ? CharonCKErrorFromPayload(document[@"serverError"], nil) : nil;
            CKUserIdentity *identity = CharonCKUserIdentityWithDocument(document);
            if (itemError) {
                failures[document[@"email"] ?: document[@"phoneNumber"] ?: @"?"] = itemError;
                continue;
            }
            if (identity && strongSelf.userIdentityDiscoveredBlock) {
                strongSelf.userIdentityDiscoveredBlock(identity, CharonCKLookupInfoWithDocument(document));
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
        [self charon_setUp];
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
    // Every identity the container knows is a lookup of no particular person, which is the service's
    // own `users/lookup` with nothing in it rather than a different endpoint.
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
            CKUserIdentity *identity = CharonCKUserIdentityWithDocument(document);
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
        [self charon_setUp];
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
            self.fetchShareMetadataCompletionBlock(CharonCKError(CKErrorInvalidArguments, @"No share URL", nil));
        }
        [self charon_finish];
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
                ? CharonCKErrorFromPayload(document[@"serverError"], nil) : nil;
            CKShareMetadata *metadata = itemError ? nil : CharonCKShareMetadataWithDocument(document, self.container);
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
        [self charon_setUp];
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
            self.fetchShareParticipantsCompletionBlock(CharonCKError(CKErrorInvalidArguments, @"Nothing to look up", nil));
        }
        [self charon_finish];
        return;
    }
    NSMutableArray *lookups = [NSMutableArray array];
    for (CKUserIdentityLookupInfo *lookupInfo in self.userIdentityLookupInfos) {
        NSDictionary *document = CharonCKLookupDocument(lookupInfo);
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
                ? CharonCKErrorFromPayload(document[@"serverError"], nil) : nil;
            CKShareParticipant *participant = itemError ? nil : CharonCKShareParticipantWithDocument(document);
            CKUserIdentityLookupInfo *lookupInfo = CharonCKLookupInfoWithDocument(document);
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
