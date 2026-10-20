#import <Foundation/Foundation.h>
#if defined(REVENANT_PASSKIT_STANDIN)
#import "RevenantPassKitStandin.h"
#else
#import <PassKit/PassKit.h>
#endif

#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

@implementation PKPaymentAuthorizationResult {
    PKPaymentAuthorizationStatus _status;
    NSArray<NSError *> *_errors;
}

- (instancetype)initWithStatus:(PKPaymentAuthorizationStatus)status errors:(nullable NSArray<NSError *> *)errors
{
    self = [super init];
    if (self == nil) {
        return nil;
    }
    _status = status;
    _errors = [errors copy];
    return self;
}

@synthesize status = _status;

- (NSArray<NSError *> *)errors
{
    return _errors ?: @[];
}

- (void)setErrors:(nullable NSArray<NSError *> *)errors
{
    _errors = [errors copy];
}

@dynamic orderDetails;

@end

@implementation PKPaymentRequestUpdate {
    PKPaymentAuthorizationStatus _status;
    NSArray<PKPaymentSummaryItem *> *_paymentSummaryItems;
}

- (instancetype)initWithPaymentSummaryItems:(NSArray<PKPaymentSummaryItem *> *)paymentSummaryItems
{
    self = [super init];
    if (self == nil) {
        return nil;
    }
    _status = PKPaymentAuthorizationStatusSuccess;
    _paymentSummaryItems = [paymentSummaryItems copy];
    return self;
}

@synthesize status = _status;
@synthesize paymentSummaryItems = _paymentSummaryItems;

@dynamic shippingMethods;
@dynamic multiTokenContexts;
@dynamic recurringPaymentRequest;
@dynamic automaticReloadPaymentRequest;
@dynamic deferredPaymentRequest;

@end

@implementation PKPaymentRequestShippingContactUpdate {
    NSArray<NSError *> *_errors;
    NSArray<PKShippingMethod *> *_shippingMethods;
}

- (instancetype)initWithErrors:(nullable NSArray<NSError *> *)errors
           paymentSummaryItems:(NSArray<PKPaymentSummaryItem *> *)paymentSummaryItems
               shippingMethods:(NSArray<PKShippingMethod *> *)shippingMethods
{
    self = [super initWithPaymentSummaryItems:paymentSummaryItems];
    if (self == nil) {
        return nil;
    }
    _errors = [errors copy];
    _shippingMethods = [shippingMethods copy];
    return self;
}

@synthesize shippingMethods = _shippingMethods;

- (NSArray<NSError *> *)errors
{
    return _errors ?: @[];
}

- (void)setErrors:(nullable NSArray<NSError *> *)errors
{
    _errors = [errors copy];
}

@end

@implementation PKPaymentRequestShippingMethodUpdate
@end

@implementation PKPaymentRequestPaymentMethodUpdate {
    NSArray<NSError *> *_errors;
}

- (instancetype)initWithErrors:(nullable NSArray<NSError *> *)errors
           paymentSummaryItems:(NSArray<PKPaymentSummaryItem *> *)paymentSummaryItems
{
    self = [super initWithPaymentSummaryItems:paymentSummaryItems];
    if (self == nil) {
        return nil;
    }
    _errors = [errors copy];
    return self;
}

- (NSArray<NSError *> *)errors
{
    return _errors ?: @[];
}

- (void)setErrors:(nullable NSArray<NSError *> *)errors
{
    _errors = [errors copy];
}

@end
