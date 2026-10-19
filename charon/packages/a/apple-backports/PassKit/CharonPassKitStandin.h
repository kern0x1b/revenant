// PKPaymentAuthorizationController and PKPaymentAuthorizationViewController, as the PORT declares
// them, for the builds that cannot see Apple's: the host probe and the contract check. No framework
// is imported, so what is compiled is this port's code and not this Mac's PassKit -- whose
// PKPaymentAuthorizationController exists, so a second @implementation of the name is a duplicate
// symbol and the measurement would be of Apple's class.
//
// The two types the members are spelled with are here too, because the release's headers do not
// declare them either: PKMerchantCapability is the header's own option set and NSArray is what the
// two -canMakePaymentsUsingNetworks: methods take. Without them the class methods do not compile, and
// a port whose members cannot be compiled is not carried.
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

typedef NS_OPTIONS(NSUInteger, PKMerchantCapability) {
    PKMerchantCapability3DS = 1 << 0,
    PKMerchantCapabilityCredit = 1 << 1,
    PKMerchantCapabilityDebit = 1 << 2,
};

@interface PKPaymentAuthorizationController : NSObject
+ (BOOL)canMakePayments;
+ (BOOL)canMakePaymentsUsingNetworks:(NSArray *)networks;
+ (BOOL)canMakePaymentsUsingNetworks:(NSArray *)networks capabilities:(PKMerchantCapability)capabilities;
@end

// The view controller, a UIViewController subclass as the SDK declares it, 8.0.
@interface PKPaymentAuthorizationViewController : UIViewController
+ (BOOL)canMakePayments;
+ (BOOL)canMakePaymentsUsingNetworks:(NSArray *)networks;
+ (BOOL)canMakePaymentsUsingNetworks:(NSArray *)networks capabilities:(PKMerchantCapability)capabilities;
@end

// The five value classes of iOS 11, which PKPaymentRequestStatus11.m implements. Additive: the
// controllers above are declared and NOT implemented here, and these are the same kind of declaration.
//
// Their properties are spelled as the SDK's PKPaymentRequestStatus.h spells them, because the object
// implements them by hand and @dynamic's the later ones -- and a stand-in that declared less than the
// object implements would have the object's own accessors claiming properties that are not there.
//
// The enumeration is Apple's own and only the two cases the object names: PKConstants.h:65 declares
// PKPaymentAuthorizationStatus with no explicit values, so Success is 0 and Failure is 1. The three
// PIN cases are 9.2 and the three Invalid* cases are 8.0, which this port does not carry -- and the
// probe's runner is compiled against the REAL PassKit, so it has the whole enumeration to compare
// against; what needs declaring here is only what the port's own code has to compile.
typedef NS_ENUM(NSInteger, PKPaymentAuthorizationStatus) {
    PKPaymentAuthorizationStatusSuccess = 0,
    PKPaymentAuthorizationStatusFailure = 1,
};

// Named for the six types the properties below are spelled with. Not one of them exists on this
// release -- there is no PKPaymentSummaryItem in 6.1.3 at all, and no PKShippingMethod, no
// PKPaymentTokenContext, no PKRecurringPaymentRequest, no PKAutomaticReloadPaymentRequest and no
// PKDeferredPaymentRequest either -- and the port carries none of them. The objects need the NAMES to
// declare the properties, not the classes: that is what a @class line is, and it is why a caller can
// only ever put an empty array in the summary-item and shipping-method lists here.
@class PKPaymentSummaryItem;
@class PKShippingMethod;
@class PKPaymentTokenContext;
@class PKRecurringPaymentRequest;
@class PKAutomaticReloadPaymentRequest;
@class PKDeferredPaymentRequest;
@class PKPaymentOrderDetails;

@interface PKPaymentAuthorizationResult : NSObject
- (instancetype)initWithStatus:(PKPaymentAuthorizationStatus)status
                        errors:(nullable NSArray<NSError *> *)errors;
@property (nonatomic, assign) PKPaymentAuthorizationStatus status;
@property (null_resettable, nonatomic, copy) NSArray<NSError *> *errors;
// 16.0, so the object declares it @dynamic and implements no accessor for it. Declared because @dynamic
// names a property that has to exist, and every one of the later releases' properties below is here
// for the same reason.
@property (nonatomic, strong, nullable) PKPaymentOrderDetails *orderDetails;
@end

@interface PKPaymentRequestUpdate : NSObject
- (instancetype)initWithPaymentSummaryItems:(NSArray<PKPaymentSummaryItem *> *)paymentSummaryItems;
@property (nonatomic, assign) PKPaymentAuthorizationStatus status;
@property (nonatomic, copy) NSArray<PKPaymentSummaryItem *> *paymentSummaryItems;
// 15.0 and the three 16.x, each @dynamic in the object: auto-synthesis would otherwise put all five
// accessors in an 11.0 object.
@property (nonatomic, copy) NSArray<PKShippingMethod *> *shippingMethods;
@property (nonatomic, copy, nullable) NSArray<PKPaymentTokenContext *> *multiTokenContexts;
@property (nonatomic, strong, nullable) PKRecurringPaymentRequest *recurringPaymentRequest;
@property (nonatomic, strong, nullable) PKAutomaticReloadPaymentRequest *automaticReloadPaymentRequest;
@property (nonatomic, strong, nullable) PKDeferredPaymentRequest *deferredPaymentRequest;
@end

@interface PKPaymentRequestShippingContactUpdate : PKPaymentRequestUpdate
- (instancetype)initWithErrors:(nullable NSArray<NSError *> *)errors
           paymentSummaryItems:(NSArray<PKPaymentSummaryItem *> *)paymentSummaryItems
               shippingMethods:(NSArray<PKShippingMethod *> *)shippingMethods;
@property (nonatomic, copy) NSArray<PKShippingMethod *> *shippingMethods;
@property (null_resettable, nonatomic, copy) NSArray<NSError *> *errors;
@end

@interface PKPaymentRequestShippingMethodUpdate : PKPaymentRequestUpdate
@end

@interface PKPaymentRequestPaymentMethodUpdate : PKPaymentRequestUpdate
- (instancetype)initWithErrors:(nullable NSArray<NSError *> *)errors
           paymentSummaryItems:(NSArray<PKPaymentSummaryItem *> *)paymentSummaryItems;
@property (null_resettable, nonatomic, copy) NSArray<NSError *> *errors;
@end
