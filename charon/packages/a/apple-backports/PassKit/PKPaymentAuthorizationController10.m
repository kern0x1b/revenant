#import <Foundation/Foundation.h>
#if defined(CHARON_PASSKIT_STANDIN)
#import "CharonPassKitStandin.h"
#else
#import <PassKit/PassKit.h>
#import <UIKit/UIKit.h>
#endif

@implementation PKPaymentAuthorizationController

+ (BOOL)canMakePayments
{
    return NO;
}

+ (BOOL)canMakePaymentsUsingNetworks:(NSArray *)networks
{
    (void)networks;
    return NO;
}

+ (BOOL)canMakePaymentsUsingNetworks:(NSArray *)networks capabilities:(PKMerchantCapability)capabilities
{
    (void)networks;
    (void)capabilities;
    return NO;
}

@end
