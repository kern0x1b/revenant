// The fifteen Secure Element members of PKPassLibrary and the payment controllers, carried and
// answered the way Apple's documentation says for a device that has no Secure Element.
//
// **The hardware is absent, and the API is not.** A 4S has no Secure Element, so every one of these
// is answered rather than left out: a missing symbol crashes an application on a selector, and these
// are selectors Apple's own headers declare. What each one answers, by kind:
//
//   a CAPABILITY question      NO. +[PKPaymentAuthorizationController canMakePayments],
//                              -isPaymentPassActivationAvailable, -canAddPaymentPass…,
//                              -canAddSecureElementPass…, -canAddFelicaPass and the
//                              +[PKPaymentAuthorizationViewController canMakePaymentsUsingNetworks…]
//                              pairs: Apple's own documentation says these are NO where the
//                              hardware cannot do it, and they are NO here.
//
//   an OPERATION               a completion carrying PKPassKitErrorDomain, whose STRING IS THE
//                              RELEASE'S: -PKPassKitErrorDomain is first exported at 6.0 (measured
//                              through the gate's own first_releases over the armv7 cache of 6.1.3),
//                              so this file links the release's symbol and defines no string of its
//                              own. The CODE is PKUnsupportedVersionError, which is 2 and is the
//                              nearest the header's own PKPassKitErrorCode has to "this device does
//                              not do that": the enumeration is PKUnknownError = -1,
//                              PKInvalidDataError = 1, PKUnsupportedVersionError = 2,
//                              PKInvalidSignature = 3, PKNotEntitledError = 4, and there is no
//                              "unsupported hardware" beside them. The reason is in the facts.
//
//   presentSecureElementPass:  nothing is presented, and the method says so.
//
// The wallet's own members -- -passesOfType:, -addPasses:withCompletionHandler: and the rest over
// the release's own three classes -- are in the objects of their own releases, beside this one.
#import <PassKit/PassKit.h>
#import <UIKit/UIKit.h>
#import "CharonPassKit.h"

@implementation PKPassLibrary (CharonSecureElement)

// The capability questions, NO, and the two activation-availability ones NO -- a device with no
// Secure Element cannot activate a payment pass on one.
- (BOOL)isPaymentPassActivationAvailable
{
    return NO;
}

+ (BOOL)isPaymentPassActivationAvailable
{
    return NO;
}

- (BOOL)canAddPaymentPassWithPrimaryAccountIdentifier:(NSString *)primaryAccountIdentifier
{
    (void)primaryAccountIdentifier;
    return NO;
}

- (BOOL)canAddSecureElementPassWithPrimaryAccountIdentifier:(NSString *)primaryAccountIdentifier
{
    (void)primaryAccountIdentifier;
    return NO;
}

- (BOOL)canAddFelicaPass
{
    return NO;
}

// The operations, each answering with the release's own error domain and the header's own nearest
// code, so a caller is told rather than left waiting.
- (void)activatePaymentPass:(PKPaymentPass *)paymentPass
         withActivationCode:(NSString *)activationCode
                completion:(void (^)(BOOL success, NSError * _Nullable error))completion
{
    if (completion) {
        completion(NO, CharonPassKitNoHardwareError());
    }
}

- (void)activatePaymentPass:(PKPaymentPass *)paymentPass
       withActivationData:(NSData *)activationData
                completion:(void (^)(BOOL success, NSError * _Nullable error))completion
{
    (void)paymentPass;
    (void)activationData;
    if (completion) {
        completion(NO, CharonPassKitNoHardwareError());
    }
}

- (void)activateSecureElementPass:(PKSecureElementPass *)secureElementPass
             withActivationData:(NSData *)activationData
                      completion:(void (^)(BOOL success, NSError * _Nullable error))completion
{
    (void)secureElementPass;
    (void)activationData;
    if (completion) {
        completion(NO, CharonPassKitNoHardwareError());
    }
}

- (void)signData:(NSData *)signatureData
 withSecureElementPass:(PKSecureElementPass *)secureElementPass
        completion:(void (^)(NSData * _Nullable signedData, NSData * _Nullable signature, NSError * _Nullable error))completion
{
    (void)signatureData;
    (void)secureElementPass;
    if (completion) {
        completion(nil, nil, CharonPassKitNoHardwareError());
    }
}

- (void)serviceProviderDataForSecureElementPass:(PKSecureElementPass *)secureElementPass
                                   completion:(void (^)(NSData * _Nullable serviceProviderData, NSError * _Nullable error))completion
{
    (void)secureElementPass;
    if (completion) {
        completion(nil, CharonPassKitNoHardwareError());
    }
}

- (void)encryptedServiceProviderDataForSecureElementPass:(PKSecureElementPass *)secureElementPass
                                             completion:(void (^)(NSDictionary * _Nullable encryptedServiceProviderData, NSError * _Nullable error))completion
{
    (void)secureElementPass;
    if (completion) {
        completion(nil, CharonPassKitNoHardwareError());
    }
}

// Nothing is presented, and the method says so rather than pretending a sheet appeared.
- (BOOL)presentSecureElementPass:(PKSecureElementPass *)secureElementPass
{
    (void)secureElementPass;
    return NO;
}

@end

