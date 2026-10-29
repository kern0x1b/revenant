#import <Security/Security.h>

const CFStringRef kSecAttrSyncViewHint __attribute__((section("__DATA,__data"))) = CFSTR("vwht");
const CFStringRef kSecAttrTokenID __attribute__((section("__DATA,__data"))) = CFSTR("tkid");
const CFStringRef kSecAttrTokenIDSecureEnclave __attribute__((section("__DATA,__data"))) = CFSTR("com.apple.setoken");
const CFStringRef kSecPolicyApplePayIssuerEncryption __attribute__((section("__DATA,__data"))) = CFSTR("1.2.840.113635.100.1.39");
const CFStringRef kSecPolicyMacAppStoreReceipt __attribute__((section("__DATA,__data"))) = CFSTR("1.2.840.113635.100.1.19");
const CFStringRef kSecTrustCertificateTransparency __attribute__((section("__DATA,__data"))) = CFSTR("TrustCertificateTransparency");
