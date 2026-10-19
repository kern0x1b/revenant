// PKPaymentAuthorizationViewController's 9.0 member, in an object of its own release.
//
// The class is 8.0 and +canMakePaymentsUsingNetworks:capabilities: is 9.0, so the two cannot be in
// one object -- the release-split gate refuses an object carrying API of two releases, which is the
// gate's own rule about what a per-release object means. The class and its 8.0 members are in
// PKPaymentAuthorizationViewController8.m; this is the 9.0 one, and it is a CATEGORY on the class the
// release does not have, so it is written here against the port's own declaration.
//
// The answer is NO for the reason the sibling object's is: the device has no Secure Element, and this
// question is the capability question. The type is the header's own PKMerchantCapability.
#import <Foundation/Foundation.h>
#if defined(CHARON_PASSKIT_STANDIN)
#import "CharonPassKitStandin.h"
#else
#import <PassKit/PassKit.h>
#import <UIKit/UIKit.h>
#endif

@implementation PKPaymentAuthorizationViewController (CharonSecureElement9)

+ (BOOL)canMakePaymentsUsingNetworks:(NSArray *)networks capabilities:(PKMerchantCapability)capabilities
{
    (void)networks;
    (void)capabilities;
    return NO;
}

@end
