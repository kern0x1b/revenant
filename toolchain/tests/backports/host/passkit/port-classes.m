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

@interface charonHost_PKPaymentAuthorizationController : NSObject
@end

@interface charonHost_PKPaymentAuthorizationViewController : UIViewController
@end

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
