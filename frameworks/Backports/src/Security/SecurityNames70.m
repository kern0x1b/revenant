#include "../revenant_impl.h"
#import <Security/Security.h>

const CFStringRef BACKPORT_IMPL(kSecPolicyAppleCodeSigning) = CFSTR("1.2.840.113635.100.1.16");
const CFStringRef BACKPORT_IMPL(kSecPolicyAppleEAP) = CFSTR("1.2.840.113635.100.1.9");
const CFStringRef BACKPORT_IMPL(kSecPolicyAppleIDValidation) = CFSTR("1.2.840.113635.100.1.18");
const CFStringRef BACKPORT_IMPL(kSecPolicyAppleIPsec) = CFSTR("1.2.840.113635.100.1.11");
const CFStringRef BACKPORT_IMPL(kSecPolicyApplePassbookSigning) = CFSTR("1.2.840.113635.100.1.22");
const CFStringRef BACKPORT_IMPL(kSecPolicyAppleRevocation) = CFSTR("1.2.840.113635.100.1.21");
const CFStringRef BACKPORT_IMPL(kSecPolicyAppleSMIME) = CFSTR("1.2.840.113635.100.1.8");
const CFStringRef BACKPORT_IMPL(kSecPolicyAppleSSL) = CFSTR("1.2.840.113635.100.1.3");
const CFStringRef BACKPORT_IMPL(kSecPolicyAppleTimeStamping) = CFSTR("1.2.840.113635.100.1.20");
const CFStringRef BACKPORT_IMPL(kSecPolicyAppleX509Basic) = CFSTR("1.2.840.113635.100.1.2");
const CFStringRef BACKPORT_IMPL(kSecPolicyClient) = CFSTR("SecPolicyClient");
const CFStringRef BACKPORT_IMPL(kSecPolicyName) = CFSTR("SecPolicyName");
const CFStringRef BACKPORT_IMPL(kSecPolicyOid) = CFSTR("SecPolicyOid");
const CFStringRef BACKPORT_IMPL(kSecPolicyRevocationFlags) = CFSTR("SecPolicyRevocationFlags");
const CFStringRef BACKPORT_IMPL(kSecPolicyTeamIdentifier) = CFSTR("SecPolicyTeamIdentifier");
const CFStringRef BACKPORT_IMPL(kSecTrustEvaluationDate) = CFSTR("TrustEvaluationDate");
const CFStringRef BACKPORT_IMPL(kSecTrustExtendedValidation) = CFSTR("TrustExtendedValidation");
const CFStringRef BACKPORT_IMPL(kSecTrustOrganizationName) = CFSTR("Organization");
const CFStringRef BACKPORT_IMPL(kSecTrustResultValue) = CFSTR("TrustResultValue");
const CFStringRef BACKPORT_IMPL(kSecTrustRevocationChecked) = CFSTR("TrustRevocationChecked");
const CFStringRef BACKPORT_IMPL(kSecTrustRevocationValidUntilDate) = CFSTR("TrustExpirationDate");
