#import "CharonCloudKit.h"
#import "CharonCKConstants.h"
#import "CharonCKSubscription.h"
#import "CharonCKIOS26.h"

@implementation CKShareRequestAccessOperation

@synthesize shareURLs = _shareURLs;
@synthesize perShareAccessRequestCompletionBlock = _perShareAccessRequestCompletionBlock;
@synthesize shareRequestAccessCompletionBlock = _shareRequestAccessCompletionBlock;

- (instancetype)init
{
    self = [super init];
    if (self) {
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
        if (self.shareRequestAccessCompletionBlock) {
            self.shareRequestAccessCompletionBlock(CharonCKError(CKErrorInvalidArguments, @"No share URL", nil));
        }
        [self charon_finish];
        return;
    }
    NSMutableArray *urls = [NSMutableArray array];
    for (NSURL *url in self.shareURLs) {
        [urls addObject:url.absoluteString];
    }
    __unsafe_unretained CKShareRequestAccessOperation *weakSelf = self;
    [self runMethod:@"POST" path:@"shares/requestAccess" body:@{@"shareURLs": urls}
       completion:^(id answer, NSError *error) {
        CKShareRequestAccessOperation *strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        if (error) {
            if (strongSelf.shareRequestAccessCompletionBlock) {
                strongSelf.shareRequestAccessCompletionBlock(error);
            }
            return;
        }
        NSMutableDictionary *failures = [NSMutableDictionary dictionary];
        for (NSDictionary *document in answer[@"shares"]) {
            NSString *url = document[@"shareURL"];
            NSError *itemError = [document[@"serverError"] isKindOfClass:[NSDictionary class]]
                ? CharonCKErrorFromPayload(document[@"serverError"], nil) : nil;
            if (itemError) {
                failures[url ?: @"?"] = itemError;
            }
            if (strongSelf.perShareAccessRequestCompletionBlock) {
                strongSelf.perShareAccessRequestCompletionBlock(url ? [NSURL URLWithString:url] : nil,
                                                                 itemError);
            }
        }
        NSError *overall = [strongSelf partialFailureWithItems:failures];
        if (strongSelf.shareRequestAccessCompletionBlock) {
            strongSelf.shareRequestAccessCompletionBlock(overall);
        }
    }];
}

@end
