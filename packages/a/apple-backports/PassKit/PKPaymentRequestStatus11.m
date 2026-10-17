// The five value classes of iOS 11's PassKit, in ONE object because all five arrived in 11.0: the
// release-split gate refuses an object carrying two releases' API, and these five first export at
// 11.0 together (measured, `xmake l tools/cache-index/first-rung.lua` over the held ladder: 11.0 for
// all five, and they are in no earlier rung).
//
// The five are the completion blocks' own value types, which is what decides they are CARRIED rather
// than absent, and the port's own carried classes are what decides it:
// PKPaymentAuthorizationViewController (8.0, PKPaymentAuthorizationViewController8.m) and
// PKPaymentAuthorizationController (10.0, PKPaymentAuthorizationController10.m) are classes this
// package already exports, and in iOS 11 Apple gave each delegate a `handler:` taking one of these
// five in place of the 8.0 `-completion:(void (^)(PKPaymentAuthorizationStatus))`. Every one of those
// five delegate methods is API_AVAILABLE(macos(11.0), ios(11.0), watchos(4.0)) in the SDK 26.2's own
// PKPaymentAuthorizationViewControllerDelegate.h:60, :86, :97, :107 and PKPaymentAuthorizationController.h:64,
// :92, :97, :108 -- the same 11.0 as the classes. So without this object the port exports a
// controller whose delegate cannot be written: the SDK's own header names a type the port has not got.
//
// The standing rule the siblings' facts page records, applied here: `absent` is for absent HARDWARE,
// and the Secure Element is hardware whose absence is not why a class is missing -- a 4S-era iPod
// answers +canMakePayments NO, it does not lack the class. These five are further from the hardware
// than the controllers: none of them touches a Secure Element, a card or a payment at all. They hold
// a status, a list of errors, a list of summary items and a list of shipping methods, and they give
// them back. What the hardware makes IMPOSSIBLE - the pass, the payment, the sheet - stays absent in
// the rows that say so, and this object does not touch them.
//
// WHAT A CALLER GETS ON THIS RELEASE, which is the honest half and is in facts/PassKit/PassKit.md:
// the object stores what the delegate put in it and hands the same values back, `status` defaults to
// PKPaymentAuthorizationStatusSuccess and the two null_resettable error lists answer the EMPTY list
// rather than nil. The lists of SUMMARY ITEMS and SHIPPING METHODS can only ever hold what a caller
// can build here: there is no PKPaymentSummaryItem in this release at all (registry row, 8.0,
// absent) and no PKShippingMethod either (tools/cache-index/first-rung.lua puts
// _OBJC_CLASS_$_PKShippingMethod at 8.0, so no release this port deploys on has it), so in practice
// they are the empty array on this device. That is the release's own limit and this object does not
// paper over it: it copies what it is given, and it is given an empty array.
//
// NOTHING OF ANOTHER RELEASE IS HERE, and that is not tidiness, it is the gate. The SDK this package
// is built against is 16.4, and its PKPaymentRequestStatus.h declares every property of these classes
// up to 16.4. Auto-synthesis would put the later ones' accessors in THIS object -- a 15.0
// `shippingMethods` and four 16.x properties in an 11.0 object -- so each one is @dynamic, which is
// what the tree uses for a property this release's object does not own (PDFAnnotation11.m's -bounds,
// MPSImageThreshold13.m). The accessors belong to the objects of their own releases.
//
// THE STAND-IN, for the host probe: see CharonPassKitStandin.h. Every line number in this file is the
// SDK 26.2's own, which is the SDK the registry's `introduced` column is measured from
// (coordination/corpus/sdk-26.2-surface.tsv); the 16.4 header this package compiles against declares the
// same members a few lines away.
#import <Foundation/Foundation.h>
#if defined(CHARON_PASSKIT_STANDIN)
#import "CharonPassKitStandin.h"
#else
#import <PassKit/PassKit.h>
#endif

// Four -Wobjc-designated-initializers, one per class that has a designated initializer, and they are
// inherent to this object's shape rather than to anything left undone: the SDK's own header marks the
// designated initializer of each of these classes (PKPaymentRequestStatus.h:25, :47, :98, :118), and
// marking one is what makes the INHERITED -init unavailable to a caller -- so the port cannot answer
// that warning by declaring -init in an interface the SDK owns, which is the same reason
// MTLRasterizationRate13.m and PHObject8.m silence theirs. Each designated initializer below calls the
// superclass's, which is the half of the rule that IS the port's own.
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

@implementation PKPaymentAuthorizationResult {
    PKPaymentAuthorizationStatus _status;
    NSArray<NSError *> *_errors;
}

// Apple's own designated initializer, and the whole of what a result is: the status the delegate
// decided on, and the errors to show for it. The header says the errors are ordered most serious
// first (PKPaymentRequestStatus.h:31-33), so they are stored in the order given and not sorted here.
- (instancetype)initWithStatus:(PKPaymentAuthorizationStatus)status errors:(nullable NSArray<NSError *> *)errors
{
    self = [super init];
    if (self == nil) {
        return nil;
    }
    _status = status;
    // Copied, as the header's `copy` says, so an array the delegate mutates afterwards cannot change
    // what it already reported.
    _errors = [errors copy];
    return self;
}

@synthesize status = _status;

// null_resettable: the header promises the getter never answers nil (PKPaymentRequestStatus.h:34), so
// an unset list answers the EMPTY list. A delegate that reports one error and reads back the count
// gets 1; a delegate that reports none gets 0, and not a nil it would have to test for.
- (NSArray<NSError *> *)errors
{
    return _errors ?: @[];
}

- (void)setErrors:(nullable NSArray<NSError *> *)errors
{
    _errors = [errors copy];
}

// 16.0, and therefore not this object's: -orderDetails is metadata for an order the device fetches in
// the background, and the device has neither the orders nor the fetch.
@dynamic orderDetails;

@end

@implementation PKPaymentRequestUpdate {
    PKPaymentAuthorizationStatus _status;
    NSArray<PKPaymentSummaryItem *> *_paymentSummaryItems;
}

// The base update, and Apple's designated initializer for it. `status` starts at
// PKPaymentAuthorizationStatusSuccess: the header's own comment on the property says so
// (PKPaymentRequestStatus.h:49-51), and it is also the enumeration's own zero -- PKConstants.h:65
// declares PKPaymentAuthorizationStatus with no explicit values, so Success is 0.
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

// NOT this object's, and @dynamic is what keeps them out of it: shippingMethods is 15.0
// (PKPaymentRequestStatus.h:59) and the three request objects are 16.0 and 16.4 (:65, :73, :81, :89).
// Auto-synthesis would put all five accessors in an 11.0 object, which is the one thing release-split
// refuses; the objects of their own releases carry them.
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

// A delegate that rejected or changed a shipping address hands back the errors to show and the new
// list of shipping methods, on top of the base update's summary items. The base's designated
// initializer is what stores those summary items, so the whole of the base's state comes from it.
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

// null_resettable, as the base's errors is: unset answers the empty list and never nil.
- (NSArray<NSError *> *)errors
{
    return _errors ?: @[];
}

- (void)setErrors:(nullable NSArray<NSError *> *)errors
{
    _errors = [errors copy];
}

@end

// The update a delegate returns after the user picked a different shipping METHOD. The header gives
// this class no member of its own (PKPaymentRequestStatus.h:108-110) -- the summary items the delegate
// recomputed for the new method are the base class's -- so what this object adds is the class itself
// and nothing else, which is what @implementation with an empty body is.
@implementation PKPaymentRequestShippingMethodUpdate
@end

@implementation PKPaymentRequestPaymentMethodUpdate {
    NSArray<NSError *> *_errors;
}

// A delegate that changed the payment method hands back the errors to show, on top of the base
// update's summary items -- the ones recomputed for the card type, which is what this update is for.
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

// null_resettable, as the other two are: unset answers the empty list and never nil.
- (NSArray<NSError *> *)errors
{
    return _errors ?: @[];
}

- (void)setErrors:(nullable NSArray<NSError *> *)errors
{
    _errors = [errors copy];
}

@end