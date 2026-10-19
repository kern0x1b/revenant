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
