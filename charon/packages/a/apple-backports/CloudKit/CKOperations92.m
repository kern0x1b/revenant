// CKFetchWebAuthTokenOperation, the one operation iOS 9.2 added.
//
// It is the one operation in this package whose answer is not a request of the port's own making: a
// web authentication token is what the caller already holds, presented to CloudKit so the service can
// exchange it for a session, and the answer is the exchange. The port signs and holds a token of its
// own (CharonCKCredentials), and this operation is the path that a client which was handed one - by a
// server, or by a share flow - uses instead.
//
// It is in a file of its own because the band machinery puts an object in the band of the release
// its API arrived in, and this arrived in 9.2. The 16.4 headers declare the class and its three
// members, so nothing here is transcribed.
//
// What the host answers for the base class and for each of the sixteen concrete subclasses is measured,
// with both spellings, by tests/backports/host/cloudkit/initializers-host.m: the base refuses, and every
// concrete subclass answers with a working instance because CKOperation's -init does the set-up for
// anything below it.

#import "CharonCloudKit.h"
#import "CharonCKConstants.h"
#import "CharonCKSubscription.h"

@implementation CKFetchWebAuthTokenOperation

// There is no default of its own to add here: the header's -init is the designated initializer and the
// base class's -init is what builds a CKFetchWebAuthTokenOperation. APIToken stays nil until a caller
// sets it, and -main answers CKErrorNotAuthenticated for that, which is the code the header names for a
// client that is not signed in. The override is written because the header declares it
// (CKFetchWebAuthTokenOperation.h:19), not because it has anything to do.
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
        // A token this operation was not given is a client with nothing to present, and the code the
        // header names for a client that is not signed in is the one that fits: there is no account
        // behind the answer, because there was no token to exchange.
        if (self.fetchWebAuthTokenCompletionBlock) {
            self.fetchWebAuthTokenCompletionBlock(nil, CharonCKNotAuthenticated());
        }
        [self charon_finish];
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
        // The service's answer is the token it minted, and what a caller needs is the whole of it: it
        // presents the token again on every later request. Both spellings of the field are read, and
        // neither is guessed at: the one the service sends is the answer, and a body with neither is
        // CKErrorInternalError rather than a nil token a caller would present.
        NSString *token = nil;
        if ([answer[@"webAuthToken"] isKindOfClass:[NSString class]]) {
            token = answer[@"webAuthToken"];
        } else if ([answer[@"token"] isKindOfClass:[NSString class]]) {
            token = answer[@"token"];
        }
        if (strongSelf.fetchWebAuthTokenCompletionBlock) {
            strongSelf.fetchWebAuthTokenCompletionBlock(token,
                token ? nil : CharonCKError(CKErrorInternalError, @"The exchange answered no token", nil));
        }
    }];
}

@end