#import <Foundation/Foundation.h>
#if defined(CHARON_PASSKIT_STANDIN)
#import "CharonPassKitStandin.h"
#else
#import <PassKit/PassKit.h>
#endif
#import <AddressBook/AddressBook.h>

@class PKShippingMethod;

@implementation PKPaymentSummaryItem {
    NSString *_label;
    NSDecimalNumber *_amount;
}

+ (instancetype)summaryItemWithLabel:(NSString *)label amount:(NSDecimalNumber *)amount
{
    PKPaymentSummaryItem *item = [[self alloc] init];
    item.label = label;
    item.amount = amount;
    return item;
}

- (NSString *)label
{
    return _label;
}

- (void)setLabel:(NSString *)label
{
    _label = [label copy];
}

- (NSDecimalNumber *)amount
{
    return _amount;
}

- (void)setAmount:(NSDecimalNumber *)amount
{
    _amount = [amount copy];
}

@end

@implementation PKPaymentRequest {
    NSString *_merchantIdentifier;
    NSString *_countryCode;
    NSArray *_supportedNetworks;
    PKMerchantCapability _merchantCapabilities;
    NSArray *_paymentSummaryItems;
    NSString *_currencyCode;
    PKAddressField _requiredBillingAddressFields;
    PKAddressField _requiredShippingAddressFields;
    NSArray *_shippingMethods;
    NSData *_applicationData;
}

- (NSString *)merchantIdentifier
{
    return _merchantIdentifier;
}

- (void)setMerchantIdentifier:(NSString *)merchantIdentifier
{
    _merchantIdentifier = [merchantIdentifier copy];
}

- (NSString *)countryCode
{
    return _countryCode;
}

- (void)setCountryCode:(NSString *)countryCode
{
    _countryCode = [countryCode copy];
}

- (NSArray *)supportedNetworks
{
    return _supportedNetworks;
}

- (void)setSupportedNetworks:(NSArray *)supportedNetworks
{
    _supportedNetworks = [supportedNetworks copy];
}

- (PKMerchantCapability)merchantCapabilities
{
    return _merchantCapabilities;
}

- (void)setMerchantCapabilities:(PKMerchantCapability)merchantCapabilities
{
    _merchantCapabilities = merchantCapabilities;
}

- (NSArray *)paymentSummaryItems
{
    return _paymentSummaryItems;
}

- (void)setPaymentSummaryItems:(NSArray *)paymentSummaryItems
{
    _paymentSummaryItems = [paymentSummaryItems copy];
}

- (NSString *)currencyCode
{
    return _currencyCode;
}

- (void)setCurrencyCode:(NSString *)currencyCode
{
    _currencyCode = [currencyCode copy];
}

- (PKAddressField)requiredBillingAddressFields
{
    return _requiredBillingAddressFields;
}

- (void)setRequiredBillingAddressFields:(PKAddressField)requiredBillingAddressFields
{
    _requiredBillingAddressFields = requiredBillingAddressFields;
}

- (PKAddressField)requiredShippingAddressFields
{
    return _requiredShippingAddressFields;
}

- (void)setRequiredShippingAddressFields:(PKAddressField)requiredShippingAddressFields
{
    _requiredShippingAddressFields = requiredShippingAddressFields;
}

- (NSArray *)shippingMethods
{
    return _shippingMethods;
}

- (void)setShippingMethods:(NSArray *)shippingMethods
{
    _shippingMethods = [shippingMethods copy];
}

- (NSData *)applicationData
{
    return _applicationData;
}

- (void)setApplicationData:(NSData *)applicationData
{
    _applicationData = [applicationData copy];
}

@end
@interface PKPaymentToken () <NSSecureCoding>
@end

@implementation PKPaymentToken {
    NSData *_paymentData;
    NSString *_transactionIdentifier;
    NSString *_paymentInstrumentName;
    NSString *_paymentNetwork;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (NSData *)paymentData
{
    return _paymentData;
}

- (void)setPaymentData:(NSData *)paymentData
{
    _paymentData = [paymentData copy];
}

- (NSString *)transactionIdentifier
{
    return _transactionIdentifier;
}

- (void)setTransactionIdentifier:(NSString *)transactionIdentifier
{
    _transactionIdentifier = [transactionIdentifier copy];
}

- (NSString *)paymentInstrumentName
{
    return _paymentInstrumentName;
}

- (void)setPaymentInstrumentName:(NSString *)paymentInstrumentName
{
    _paymentInstrumentName = [paymentInstrumentName copy];
}

- (NSString *)paymentNetwork
{
    return _paymentNetwork;
}

- (void)setPaymentNetwork:(NSString *)paymentNetwork
{
    _paymentNetwork = [paymentNetwork copy];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self) {
        _paymentData = [[coder decodeObjectOfClass:[NSData class] forKey:@"paymentData"] copy];
        _transactionIdentifier = [[coder decodeObjectOfClass:[NSString class] forKey:@"transactionIdentifier"] copy];
        _paymentInstrumentName = [[coder decodeObjectOfClass:[NSString class] forKey:@"paymentInstrumentName"] copy];
        _paymentNetwork = [[coder decodeObjectOfClass:[NSString class] forKey:@"paymentNetwork"] copy];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_paymentData forKey:@"paymentData"];
    [coder encodeObject:_transactionIdentifier forKey:@"transactionIdentifier"];
    [coder encodeObject:_paymentInstrumentName forKey:@"paymentInstrumentName"];
    [coder encodeObject:_paymentNetwork forKey:@"paymentNetwork"];
}

@end

@interface PKPayment () <NSSecureCoding>
@end

@implementation PKPayment {
    PKPaymentToken *_token;
    ABRecordRef _billingAddress;
    ABRecordRef _shippingAddress;
    PKShippingMethod *_shippingMethod;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithToken:(PKPaymentToken *)token
{
    self = [super init];
    if (self)
        _token = token;
    return self;
}

- (PKPaymentToken *)token
{
    return _token;
}

- (void)setToken:(PKPaymentToken *)token
{
    _token = token;
}

- (ABRecordRef)billingAddress
{
    return _billingAddress;
}

- (void)setBillingAddress:(ABRecordRef)billingAddress
{
    _billingAddress = billingAddress;
}

- (ABRecordRef)shippingAddress
{
    return _shippingAddress;
}

- (void)setShippingAddress:(ABRecordRef)shippingAddress
{
    _shippingAddress = shippingAddress;
}

- (PKShippingMethod *)shippingMethod
{
    return _shippingMethod;
}

- (void)setShippingMethod:(PKShippingMethod *)shippingMethod
{
    _shippingMethod = shippingMethod;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self)
        _token = [coder decodeObjectOfClass:[PKPaymentToken class] forKey:@"token"];
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_token forKey:@"token"];
}

@end
