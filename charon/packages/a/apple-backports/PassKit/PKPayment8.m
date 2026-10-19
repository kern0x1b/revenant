// PKPaymentRequest and PKPaymentSummaryItem, the two classes of the 8.0 payment request that hold
// THE CALLER'S OWN DATA, carried as classes because the release has neither of them.
//
// WHY THESE TWO AND NOT THE OTHER THREE OF 8.0. apple.objc.inventory against the armv7 dyld shared
// cache of 6.1.3 finds 64 classes beginning PK and none of them begins PKPayment (control in the same
// run: 590 class rows beginning NS and one beginning PKA, PKAddPassesViewController), and
// tools/cache-index/first-rung.lua answers 8.0 for PKPayment, PKPaymentPass, PKPaymentRequest,
// PKPaymentSummaryItem and PKPaymentToken. So all five arrived after the release. What separates
// them is what a member can answer, and this file is the line:
//
//   A VALUE THE CALLER PUT IN. Every member of these two is a property the application sets and
//   reads back: a line item's label and decimal amount, a request's merchant identifier, country
//   code, currency, networks, capability bits, address-field bits and the summary items themselves.
//   None of it is produced by the Secure Element or by Apple's service, so all of it is real here and
//   is answered by keeping what it was given.
//
//   THE CALLER'S OWN COPY OF A TRANSACTION'S VALUES, and this is the correction the 2026-10-16 pass
//   carries. PKPaymentToken and PKPayment were carried as `absent` on the reading that every member of
//   them reads the result of a transaction. The 8.0 cache says otherwise: both classes exist there with
//   the members listed in facts/PassKit/PassKit.md, and an object of either is a holder of what it was
//   given. A token built from nothing answers nil in every member, which is what the host answers for a
//   fresh one (tests/backports/host/payment-value), and nothing here authorizes, signs or decrypts a
//   credential: the token a device produced is the Secure Element's, and this class does not make one.
//   PKPaymentPass is NOT carried here. It is a PKPass subclass whose members read the Secure Element, and
//   PKPass14.m says what its payment members answer.
//
// ONE OBJECT PER RELEASE, and this is the 8.0 one. The 8.0 members only: PKPaymentSummaryItem's -type
// and +summaryItemWithLabel:amount:type: are 9.0, and PKPaymentRequest's -shippingType is 8.3 and
// its two PKContact members are 9.0, so none of them is here - an object carrying API of two
// releases is what tools/release-split.lua refuses, and it can only see the two class symbols, so
// the split is this file's job and not the tool's. The ledger in registry/PassKit/ios8.json carries
// a row for each of the two classes and none for their members, which is what check_registry's
// entry_of expects: a class row answers for the members of a class the port defines wholly.
//
// What a caller gets is the object, not a payment: the request reads back exactly what was set on it,
// and presenting it is what cannot happen - -[PKPaymentAuthorizationViewController initWithRequest:]
// needs a PKPaymentPass, which the release has not got and this port declines to invent.
#import <Foundation/Foundation.h>
#if defined(CHARON_PASSKIT_STANDIN)
#import "CharonPassKitStandin.h"
#else
#import <PassKit/PassKit.h>
#endif
// ABRecordRef is the AddressBook record reference that PKPayment's deprecated address members are declared with.
#import <AddressBook/AddressBook.h>

// PKShippingMethod is named by PKPayment's -shippingMethod; this port does not carry the class, so it is
// declared here only as a name. A message to it is never sent by this file.
@class PKShippingMethod;

@implementation PKPaymentSummaryItem {
    NSString *_label;
    NSDecimalNumber *_amount;
}

// +summaryItemWithLabel:amount:, 8.0: the header's own factory, and the whole of what a line item
// holds. Both properties are `copy`, so the object keeps a copy of what it was handed and not the
// caller's mutable string, which is what the declaration says.
+ (instancetype)summaryItemWithLabel:(NSString *)label amount:(NSDecimalNumber *)amount
{
    PKPaymentSummaryItem *item = [[self alloc] init];
    item.label = label;
    item.amount = amount;
    return item;
}

// "Tax", "Gift Card": the caller's own string, kept. Nothing shortens or localizes it, because the
// caller has already localized it - the header calls it "a short localized description of the item".
- (NSString *)label
{
    return _label;
}

- (void)setLabel:(NSString *)label
{
    _label = [label copy];
}

// The amount, in the currency of the enclosing request, negatives permitted (a redeemed coupon).
// NSDecimalNumber is the release's own since 1.0, so the decimal arithmetic behind it is Apple's and
// not this port's; nothing here rounds, scales or compares it.
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

// Every accessor below is the caller's own value read back, and each is spelled as the SDK 16.4's own
// PKPaymentRequest.h spells it (measured against the headers of
// iphoneos-sdk/16.4/*/iPhoneOS16.4.sdk/System/Library/Frameworks/PassKit.framework/Headers): the four
// strings and the data `copy`, the two arrays `copy`, the two bitfields and the capability `assign`.
//
// The two PKAddressField properties are the 8.0 spellings the header deprecated at 11.0 in favour of
// the requiredBilling/ShippingContactFields NSSet. They are carried because they ARE the 8.0 API and
// their own header says the default is PKAddressFieldNone, which is 0 - so an ivar that starts at
// zero already carries Apple's own default and no initializer has to invent one.
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

// The merchant's networks, as the NSArray of PKPaymentNetwork strings it gave (PKPaymentNetwork is
// the header's own NSString typedef, so the array holds strings and no object this port lacks).
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

// The line items, which are PKPaymentSummaryItem objects of this same object file. The last one is
// the total, which the header requires and the port does not second-guess.
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

// The shipping methods the merchant offers. PKShippingMethod is a class this port does not carry and
// does not pretend to: the array is kept exactly as given, and a caller that has none passes an empty
// one, which is the honest state of a device whose request is never presented.
- (NSArray *)shippingMethods
{
    return _shippingMethods;
}

- (void)setShippingMethods:(NSArray *)shippingMethods
{
    _shippingMethods = [shippingMethods copy];
}

// The merchant's own bytes, which the header says are signed into the resulting PKPaymentToken. The
// bytes are kept; nothing signs them, because signing them is the Secure Element's operation and it
// is what makes the resulting token absent from this port.
- (NSData *)applicationData
{
    return _applicationData;
}

- (void)setApplicationData:(NSData *)applicationData
{
    _applicationData = [applicationData copy];
}

@end
// PKPaymentToken, 8.0: the four members the release's own class carries. The header declares
// paymentData and transactionIdentifier readwrite and paymentInstrumentName and paymentNetwork readonly;
// the 8.0 class has a setter for all four (measured: -setPaymentNetwork: and -setPaymentInstrumentName:
// are in its own list), so all four are settable here, and each one is a copy of what it was given.
// The header declares PKPaymentToken an NSObject with no protocol, and the release's own class adopts NSSecureCoding (the
// host's does). The extension adds the adoption here, so the coder accepts the object as it accepts the release's.
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

// The keys are this port's own. The release's archive keys are not measured, so an archive written by one
// is not read by the other; what is measured is that a token round-trips through its own coder.
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

// PKPayment, 8.0: the token it was built with, and the addresses and shipping method the caller set. The
// release's class has -initWithToken: and -initWithCoder:, and its plain -init is NSObject's. The token is
// kept as it was given and not copied, which is what the header's strong property declares and what the
// host answers (the same object comes back). The two addresses are ABRecordRef values the header declares
// assign, so the object keeps the reference and does not own the record.
//
// What the coder writes is the token. The shipping method and the addresses are not written: the class
// that would carry the method is not in this port, and a record reference has no archive form this port
// has measured against the release's own coder. Both gaps are named here and not filled with a guess.
// As for PKPaymentToken above: the header declares no protocol on PKPayment, and the release's class adopts NSSecureCoding.
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
