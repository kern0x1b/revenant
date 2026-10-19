// The AuthenticationServices string constants of iOS 15.0. Every value here was read out of a real
// AuthenticationServices.framework: AuthenticationServices.framework of the 16.0, 18.0 shared caches, read with the project's own dyld cache reader: the symbol's pointer resolved through the cache's slide information, then the __CFConstantString's char* and its length, with the bytes agreeing with the length
// One release's API per object file, which is what the band machinery needs.
#import <Foundation/Foundation.h>

NSString *const ASAuthorizationPublicKeyCredentialAttestationKindDirect = @"direct";
NSString *const ASAuthorizationPublicKeyCredentialAttestationKindEnterprise = @"enterprise";
NSString *const ASAuthorizationPublicKeyCredentialAttestationKindIndirect = @"indirect";
NSString *const ASAuthorizationPublicKeyCredentialAttestationKindNone = @"none";
NSString *const ASAuthorizationPublicKeyCredentialResidentKeyPreferenceDiscouraged = @"discouraged";
NSString *const ASAuthorizationPublicKeyCredentialResidentKeyPreferencePreferred = @"preferred";
NSString *const ASAuthorizationPublicKeyCredentialResidentKeyPreferenceRequired = @"required";
NSString *const ASAuthorizationPublicKeyCredentialUserVerificationPreferenceDiscouraged = @"discouraged";
NSString *const ASAuthorizationPublicKeyCredentialUserVerificationPreferencePreferred = @"preferred";
NSString *const ASAuthorizationPublicKeyCredentialUserVerificationPreferenceRequired = @"required";
NSString *const ASAuthorizationSecurityKeyPublicKeyCredentialDescriptorTransportBluetooth = @"ble";
NSString *const ASAuthorizationSecurityKeyPublicKeyCredentialDescriptorTransportNFC = @"nfc";
NSString *const ASAuthorizationSecurityKeyPublicKeyCredentialDescriptorTransportUSB = @"usb";
