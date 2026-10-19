// PKPaymentAuthorizationController, carried as a CLASS, because the release does not have it.
//
// The 6.1.3 gate said what was wrong and it was right: this class's six members were built as a
// CATEGORY, and "a category on a class nobody carries is dead code -- the loader has nothing to
// attach it to". The registry said the CLASS was absent (10.0, with a reason that blamed the Secure
// Element) while its members were implemented, and that contradiction is what the gate found.
//
// The class EXISTS on a device without a Secure Element. A 4S-era iPod answers +canMakePayments NO,
// and the 26.2 header's own comment on the class is about presenting a payment, not about whether the
// hardware is there. So the class is carried, and the CAPABILITY questions answer NO, which is
// Apple's documented answer for a device that cannot make payments:
//
//   The header's four answers are the class's own: +canMakePayments, +canMakePaymentsUsingNetworks:
//   and +canMakePaymentsUsingNetworks:capabilities: are NS_CLASS_AVAILABLE, and the way a device
//   without the hardware answers them is NO.
//
// ONE OBJECT PER RELEASE: this is the 10.0 object and it carries the class and +canMakePayments and
// +canMakePaymentsUsingNetworks:. The header dates the class 10.0 and both of those 10.0; the
// -capabilities: pair is 10.0 as well, so it stays here. What is 9.0 lives in its own object.
//
// What the hardware makes IMPOSSIBLE stays absent, and the reason is the hardware and not the
// backlog: -initWithRequest: takes a PKPaymentPass, and there is no PKPaymentPass in this release at
// all (measured absent from the armv7 cache of 6.1.3), so a payment sheet over a pass that cannot
// exist is a sheet with nothing in it. Those are the absent rows, and they name this.
//
// THE STAND-IN, for the host and contract builds only. On a host where Apple's PassKit declares this
// class, a second @implementation of the name is a duplicate SYMBOL and the probe would be measuring
// Apple's class rather than the port's. Under CHARON_PASSKIT_STANDIN the port compiles against its own
// declaration with no framework, exactly the pattern MediaPlayer's command-event files use
// (CHARON_MEDIAPLAYER_STANDIN / MPMediaItemStandin.h), so the measurement is of the port's code.
#import <Foundation/Foundation.h>
#if defined(CHARON_PASSKIT_STANDIN)
#import "CharonPassKitStandin.h"
#else
#import <PassKit/PassKit.h>
#import <UIKit/UIKit.h>
#endif

@implementation PKPaymentAuthorizationController

// Apple's own documentation, and the whole of what a device without a Secure Element can answer here.
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
