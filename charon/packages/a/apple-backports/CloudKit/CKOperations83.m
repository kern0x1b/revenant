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
