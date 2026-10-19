// PKPaymentAuthorizationViewController, carried as a CLASS, because the release does not have it.
//
// The same finding as its sibling's, from the same 6.1.3 gate: the class's members were built as a
// CATEGORY, and a category on a class the release does not carry has nothing to attach to. The
// class row said absent (8.0) while the three member rows said implemented.
//
// The class EXISTS on a device without a Secure Element -- it is a UIViewController that presents a
// payment sheet, and the sheet is presented by a caller that first asks whether payments can be made
// at all, which here is NO. So the class is carried and the three capability questions answer NO.
//
// ONE OBJECT PER RELEASE, and this is the 8.0 object: the class is 8.0 and
// +canMakePaymentsUsingNetworks:capabilities: is 9.0, so that member is NOT here -- an object with API
// of two releases is what the release-split gate refuses. It is in PKPaymentAuthorizationViewController9.m.
// The per-symbol release is what the cache ladder says, measured by tools/release-split.lua after a
// build; nothing is held between 12.0 and 16.0, so a member the ladder cannot place is not asserted here.
//
// What the hardware makes impossible stays absent: -initWithRequest: needs a PKPaymentPass, which
// this release does not have at all, and the delegate callbacks need a delegate that would have been
// told about a sheet that cannot be presented.
#import <Foundation/Foundation.h>
#if defined(CHARON_PASSKIT_STANDIN)
#import "CharonPassKitStandin.h"
#else
#import <PassKit/PassKit.h>
#import <UIKit/UIKit.h>
#endif

@implementation PKPaymentAuthorizationViewController

// 8.0's own: the capability question, NO, like the controller's.
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
