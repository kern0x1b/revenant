#import <PassKit/PassKit.h>
#import <UIKit/UIKit.h>
#import "RevenantPassKit.h"

@implementation PKPassLibrary (RevenantSecureElement)

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

- (void)activatePaymentPass:(PKPaymentPass *)paymentPass
         withActivationCode:(NSString *)activationCode
                completion:(void (^)(BOOL success, NSError * _Nullable error))completion
{
    if (completion) {
        completion(NO, RevenantPassKitNoHardwareError());
    }
}

- (void)activatePaymentPass:(PKPaymentPass *)paymentPass
       withActivationData:(NSData *)activationData
                completion:(void (^)(BOOL success, NSError * _Nullable error))completion
{
    (void)paymentPass;
    (void)activationData;
    if (completion) {
        completion(NO, RevenantPassKitNoHardwareError());
    }
}

- (void)activateSecureElementPass:(PKSecureElementPass *)secureElementPass
             withActivationData:(NSData *)activationData
                      completion:(void (^)(BOOL success, NSError * _Nullable error))completion
{
    (void)secureElementPass;
    (void)activationData;
    if (completion) {
        completion(NO, RevenantPassKitNoHardwareError());
    }
}

- (void)signData:(NSData *)signatureData
 withSecureElementPass:(PKSecureElementPass *)secureElementPass
        completion:(void (^)(NSData * _Nullable signedData, NSData * _Nullable signature, NSError * _Nullable error))completion
{
    (void)signatureData;
    (void)secureElementPass;
    if (completion) {
        completion(nil, nil, RevenantPassKitNoHardwareError());
    }
}

- (void)serviceProviderDataForSecureElementPass:(PKSecureElementPass *)secureElementPass
                                   completion:(void (^)(NSData * _Nullable serviceProviderData, NSError * _Nullable error))completion
{
    (void)secureElementPass;
    if (completion) {
        completion(nil, RevenantPassKitNoHardwareError());
    }
}

- (void)encryptedServiceProviderDataForSecureElementPass:(PKSecureElementPass *)secureElementPass
                                             completion:(void (^)(NSDictionary * _Nullable encryptedServiceProviderData, NSError * _Nullable error))completion
{
    (void)secureElementPass;
    if (completion) {
        completion(nil, RevenantPassKitNoHardwareError());
    }
}

- (BOOL)presentSecureElementPass:(PKSecureElementPass *)secureElementPass
{
    (void)secureElementPass;
    return NO;
}

@end
