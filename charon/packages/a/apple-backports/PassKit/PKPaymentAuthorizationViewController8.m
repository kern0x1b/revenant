#import <Foundation/Foundation.h>
#if defined(CHARON_PASSKIT_STANDIN)
#import "CharonPassKitStandin.h"
#else
#import <PassKit/PassKit.h>
#import <UIKit/UIKit.h>
#endif

@implementation PKPaymentAuthorizationViewController

+ (BOOL)canMakePayments
{
    return NO;
}

+ (BOOL)canMakePaymentsUsingNetworks:(NSArray *)networks
{
    (void)networks;
    return NO;
}

@end
