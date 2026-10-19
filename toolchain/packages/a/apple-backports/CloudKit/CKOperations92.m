#import "RevenantCloudKit.h"
#import "RevenantCKConstants.h"
#import "RevenantCKSubscription.h"

@implementation CKFetchWebAuthTokenOperation

- (instancetype)init
{
    return [super init];
}

- (instancetype)initWithAPIToken:(NSString *)APIToken
{
    self = [self init];
    if (self) {
        _APIToken = [APIToken copy];
    }
    return self;
}

+ (instancetype)new
{
    return [[self alloc] init];
}

- (void)main
{
    if (!self.APIToken) {
        if (self.fetchWebAuthTokenCompletionBlock) {
            self.fetchWebAuthTokenCompletionBlock(nil, RevenantCKNotAuthenticated());
        }
        [self revenant_finish];
        return;
    }
    __unsafe_unretained CKFetchWebAuthTokenOperation *weakSelf = self;
    [self runMethod:@"POST" path:@"users/login" body:@{@"apiToken": self.APIToken}
       completion:^(id answer, NSError *error) {
        CKFetchWebAuthTokenOperation *strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        if (error) {
            if (strongSelf.fetchWebAuthTokenCompletionBlock) {
                strongSelf.fetchWebAuthTokenCompletionBlock(nil, error);
            }
            return;
        }
        NSString *token = nil;
        if ([answer[@"webAuthToken"] isKindOfClass:[NSString class]]) {
            token = answer[@"webAuthToken"];
        } else if ([answer[@"token"] isKindOfClass:[NSString class]]) {
            token = answer[@"token"];
        }
        if (strongSelf.fetchWebAuthTokenCompletionBlock) {
            strongSelf.fetchWebAuthTokenCompletionBlock(token,
                token ? nil : RevenantCKError(CKErrorInternalError, @"The exchange answered no token", nil));
        }
    }];
}

@end
