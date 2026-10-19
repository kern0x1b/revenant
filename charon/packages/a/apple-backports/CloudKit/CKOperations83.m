// CKAcceptSharesOperation, which arrived in iOS 8.3 and not in iOS 10 with the rest of this file's
// operations. The band machinery puts an object in the band of the release its API arrived in, so an
// object carrying both 8.3's and 10.0.1's symbols belongs to no band at all: the gate refuses it as
// "an object carries API that arrived in one release, so split it", and release-split reads the same
// two releases out of the compiled symbols. It is its own file, and it is the same request and the
// same answer as the operations beside it, over the same transport.

#import "CharonCloudKit.h"
#import "CharonCKConstants.h"
#import "CharonCKSubscription.h"

#pragma mark - CKAcceptSharesOperation

@implementation CKAcceptSharesOperation

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self charon_setUp];
        _shareMetadatas = @[];
    }
    return self;
}

- (instancetype)initWithShareMetadatas:(NSArray<CKShareMetadata *> *)shareMetadatas
{
    self = [self init];
    if (self) {
        _shareMetadatas = [shareMetadatas copy];
    }
    return self;
}

+ (instancetype)new
{
    return [[self alloc] init];
}

- (void)main
{
    if (!self.shareMetadatas.count) {
        if (self.acceptSharesCompletionBlock) {
            self.acceptSharesCompletionBlock(CharonCKError(CKErrorInvalidArguments, @"No share to accept", nil));
        }
        [self charon_finish];
        return;
    }
    NSMutableArray *metadatas = [NSMutableArray array];
    for (CKShareMetadata *metadata in self.shareMetadatas) {
        if (metadata.shareURL) {
            [metadatas addObject:metadata.shareURL.absoluteString];
        }
    }
    __unsafe_unretained CKAcceptSharesOperation *weakSelf = self;
    // Accepting a share is the service taking the inviter into the share's own database, and the
    // share that comes back is the one the caller now has: the record it is of, the participants and
    // the zone it lives in.
    [self runMethod:@"POST" path:@"shares/accept" body:@{@"shareURLs": metadatas}
       completion:^(id answer, NSError *error) {
        CKAcceptSharesOperation *strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        if (error) {
            if (strongSelf.acceptSharesCompletionBlock) {
                strongSelf.acceptSharesCompletionBlock(error);
            }
            return;
        }
        NSMutableDictionary *failures = [NSMutableDictionary dictionary];
        NSMutableArray *byURL = [NSMutableArray arrayWithArray:strongSelf.shareMetadatas];
        for (NSDictionary *document in answer[@"shares"]) {
            NSString *url = document[@"shareURL"];
            NSError *itemError = [document[@"serverError"] isKindOfClass:[NSDictionary class]]
                ? CharonCKErrorFromPayload(document[@"serverError"], nil) : nil;
            CKShareMetadata *metadata = nil;
            if (!itemError) {
                for (CKShareMetadata *candidate in byURL) {
                    if ([candidate.shareURL.absoluteString isEqualToString:url]) {
                        metadata = candidate;
                        break;
                    }
                }
            }
            if (itemError) {
                failures[url ?: @"?"] = itemError;
            }
            if (strongSelf.perShareCompletionBlock) {
                strongSelf.perShareCompletionBlock(metadata, nil, itemError);
            }
        }
        NSError *overall = [strongSelf partialFailureWithItems:failures];
        if (strongSelf.acceptSharesCompletionBlock) {
            strongSelf.acceptSharesCompletionBlock(overall);
        }
    }];
}

@end
