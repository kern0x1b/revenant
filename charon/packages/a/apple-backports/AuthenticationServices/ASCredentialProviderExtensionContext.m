// ASCredentialProviderExtensionContext, of iOS 12.0: the object a password-manager extension's
// provider calls when it has a credential for the system.
//
// **What this is for.** The system instantiates a credential-provider extension, its controller
// prepares a credential, and then it calls one of the three methods here to finish the exchange:
// -completeRequestWithSelectedCredential:completionHandler: with the credential it chose,
// -completeExtensionConfigurationRequest when the extension's settings are done, and
// -cancelRequestWithError: when the exchange is abandoned.
//
// **What the port does instead, and why that is the port and not a stub.** On a device the counterpart
// of a completion is the system: it takes the credential, it presents, and the user sees a filled
// field. The port has no system to hand a credential to, and the part a test can actually observe is
// what the extension DECIDED — so the port's context records the decision and keeps it, and the
// application reading the context is how it learns what its own extension did. A context that threw the
// completion away would be the stub, because then nothing anywhere would know the exchange finished.
//
// So every completion here is recorded, and the record is the port's own, in memory, with nothing
// written to this machine's AutoFill state: the same static scan and the same runtime refusal in
// tests/backports/host/authservices/ stand between this Mac and a real ASCredentialIdentityStore, and
// the port's own store is a different object in a different namespace.
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
        // The handler's question is "has this credential expired", and the port can answer it rather
        // than guess: ASPasswordCredential carries a user and a password and no expiry at all, so
        // within the port a credential that was just handed over is not expired. Were the port to
        // carry an expiry, this would have to read it, and this line is where it would change.
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
    // The settings exchange has no payload to carry, so the record is the fact that it finished; an
    // application that wants to know its settings screen was dismissed reads that flag rather than
    // being told by a completion that went nowhere.
    _lastExchange = [ASPortCredentialExchange configurationExchange];
}

- (void)cancelRequestWithError:(NSError *)error
{
    // A cancellation is a result, and dropping the error would make a failed exchange look like one
    // that simply stopped: the record keeps what the extension said went wrong.
    _lastExchange = [ASPortCredentialExchange cancelledExchangeWithError:error];
}

// -completeRequestReturningItems:completionHandler: is NOT implemented, and that is the header's own
// request: it is declared NS_UNAVAILABLE, so the release refuses to compile a call to it. The port
// carries three of this class's four members and refuses the fourth for the same reason the release
// does, which is not a gap and is recorded as its own row rather than left silent.

@end
