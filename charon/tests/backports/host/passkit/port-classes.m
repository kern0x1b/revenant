// The classes the port's categories hang on, under the names the probe build gives them.
//
// The run compiles the port with -DPKPassLibrary=charonHost_PKPassLibrary and the rest, so the port's
// categories attach to THESE classes and never to the host framework's own -- a category on the
// host's class would be a second implementation of a class the host already has, and the runner
// would be measuring Apple rather than the port.
//
// PKPassLibrary and PKAddPassesViewController are the release's own (in 6.1.3, measured), so here
// they are the host's, subclassed, which is what lets a category add to them without re-implementing
// what the host has.
//
// The two payment controllers are the port's own and are declared EMPTY here rather than subclassed:
// they are absent from 6.1.3, the port now CARRIES them as classes, and a subclass of the host's
// would be a class the release never had -- the exact thing the release-split gate and the 6.1.3
// gate both object to. So the probe measures a class the port defines, with the host's own
// untouched and reachable by its header name.
#import <Foundation/Foundation.h>
#import <PassKit/PassKit.h>

@interface charonHost_PKPassLibrary : PKPassLibrary
@end
@implementation charonHost_PKPassLibrary
@end

@interface charonHost_PKAddPassesViewController : PKAddPassesViewController
@end
@implementation charonHost_PKAddPassesViewController
@end

// Declared, and NOT implemented: the port's own PKPaymentAuthorizationController10.m and
// PKPaymentAuthorizationViewController8.m implement them, and a second @implementation of either
// name here is the duplicate the stand-in exists to avoid.
//
// THE SUPERCLASS IS THE HEADER'S OWN for each, and it is spelled here as well as checked in the
// runner, because this is where a reader looks: the 26.2 header declares @interface
// PKPaymentAuthorizationController : NSObject and, under TARGET_OS_IPHONE, @interface
// PKPaymentAuthorizationViewController : UIViewController. runner.m asserts exactly these two with
// class_getSuperclass, and run.sh's fifth mutant -- a copy of CharonPassKitStandin.h, the header the
// port itself is compiled against, with the view controller's superclass changed to UIView -- must go
// red naming the case.
@interface charonHost_PKPaymentAuthorizationController : NSObject
@end

@interface charonHost_PKPaymentAuthorizationViewController : UIViewController
@end

// The five value classes of iOS 11, the same arrangement: the port's own PKPaymentRequestStatus11.m
// implements them, so they are DECLARED and NOT implemented here. They reach the runner through
// -initWithStatus:errors:, -initWithPaymentSummaryItems:, -initWithErrors:paymentSummaryItems: and
// -initWithErrors:paymentSummaryItems:shippingMethods:, all reached by NSSelectorFromString, because
// the runner is compiled against the HOST's PassKit and those classes are the host's own too: spelling
// the types here would measure Apple's class and not the port's. The three updates are declared as
// subclasses of charonHost_PKPaymentRequestUpdate, so the runner's superclass case asks the port's
// question -- and a renamed class that ignored the superclass would answer the members and still be a
// class Apple's shape is not.
@interface charonHost_PKPaymentAuthorizationResult : NSObject
@end

@interface charonHost_PKPaymentRequestUpdate : NSObject
@end

@interface charonHost_PKPaymentRequestShippingMethodUpdate : charonHost_PKPaymentRequestUpdate
@end

@interface charonHost_PKPaymentRequestPaymentMethodUpdate : charonHost_PKPaymentRequestUpdate
@end

@interface charonHost_PKPaymentRequestShippingContactUpdate : charonHost_PKPaymentRequestUpdate
@end
