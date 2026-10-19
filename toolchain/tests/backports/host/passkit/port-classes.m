#import <Foundation/Foundation.h>
#import <PassKit/PassKit.h>

@interface revenantHost_PKPassLibrary : PKPassLibrary
@end
@implementation revenantHost_PKPassLibrary
@end

@interface revenantHost_PKAddPassesViewController : PKAddPassesViewController
@end
@implementation revenantHost_PKAddPassesViewController
@end

@interface revenantHost_PKPaymentAuthorizationController : NSObject
@end

@interface revenantHost_PKPaymentAuthorizationViewController : UIViewController
@end

@interface revenantHost_PKPaymentAuthorizationResult : NSObject
@end

@interface revenantHost_PKPaymentRequestUpdate : NSObject
@end

@interface revenantHost_PKPaymentRequestShippingMethodUpdate : revenantHost_PKPaymentRequestUpdate
@end

@interface revenantHost_PKPaymentRequestPaymentMethodUpdate : revenantHost_PKPaymentRequestUpdate
@end

@interface revenantHost_PKPaymentRequestShippingContactUpdate : revenantHost_PKPaymentRequestUpdate
@end
