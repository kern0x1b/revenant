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

@interface PKPaymentAuthorizationViewController : UIViewController
+ (BOOL)canMakePayments;
+ (BOOL)canMakePaymentsUsingNetworks:(NSArray *)networks;
+ (BOOL)canMakePaymentsUsingNetworks:(NSArray *)networks capabilities:(PKMerchantCapability)capabilities;
@end

typedef NS_ENUM(NSInteger, PKPaymentAuthorizationStatus) {
    PKPaymentAuthorizationStatusSuccess = 0,
    PKPaymentAuthorizationStatusFailure = 1,
};

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
@property (nonatomic, strong, nullable) PKPaymentOrderDetails *orderDetails;
@end

@interface PKPaymentRequestUpdate : NSObject
- (instancetype)initWithPaymentSummaryItems:(NSArray<PKPaymentSummaryItem *> *)paymentSummaryItems;
@property (nonatomic, assign) PKPaymentAuthorizationStatus status;
@property (nonatomic, copy) NSArray<PKPaymentSummaryItem *> *paymentSummaryItems;
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
