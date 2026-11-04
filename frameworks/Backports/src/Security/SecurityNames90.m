#include "../revenant_impl.h"
#import <Security/Security.h>

const CFStringRef BACKPORT_IMPL(kSecAttrSyncViewHint) = CFSTR("vwht");
const CFStringRef BACKPORT_IMPL(kSecAttrTokenID) = CFSTR("tkid");
const CFStringRef BACKPORT_IMPL(kSecAttrTokenIDSecureEnclave) = CFSTR("com.apple.setoken");
const CFStringRef BACKPORT_IMPL(kSecPolicyApplePayIssuerEncryption) = CFSTR("1.2.840.113635.100.1.39");
const CFStringRef BACKPORT_IMPL(kSecPolicyMacAppStoreReceipt) = CFSTR("1.2.840.113635.100.1.19");
const CFStringRef BACKPORT_IMPL(kSecTrustCertificateTransparency) = CFSTR("TrustCertificateTransparency");
