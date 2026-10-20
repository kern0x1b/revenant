#import <AuthenticationServices/AuthenticationServices.h>
#import <Foundation/Foundation.h>
#import "ASPortCredentialExchange.h"



@interface ASCredentialProviderExtensionContext ()
@property (nonatomic, strong) ASPortCredentialExchange *lastExchange;
@end

@implementation ASCredentialProviderExtensionContext

@synthesize lastExchange = _lastExchange;

- (void)completeRequestWithSelectedCredential:(ASPasswordCredential *)credential
                           completionHandler:(void (^ _Nullable)(BOOL expired))completionHandler
{
    if (completionHandler) {
        completionHandler(NO);
        _lastExchange = [ASPortCredentialExchange exchangeWithCredential:credential
                                                                  expired:NO
                                                              expiryAsked:YES];
    } else {
        _lastExchange = [ASPortCredentialExchange exchangeWithCredential:credential
                                                                  expired:NO
                                                              expiryAsked:NO];
    }
}

- (void)completeExtensionConfigurationRequest
{
    _lastExchange = [ASPortCredentialExchange configurationExchange];
}

- (void)cancelRequestWithError:(NSError *)error
{
    _lastExchange = [ASPortCredentialExchange cancelledExchangeWithError:error];
}

@end
