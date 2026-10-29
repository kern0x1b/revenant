#import <Security/Security.h>

const CFStringRef kSecPolicyAppleCodeSigning __attribute__((section("__DATA,__data"))) = CFSTR("1.2.840.113635.100.1.16");
const CFStringRef kSecPolicyAppleEAP __attribute__((section("__DATA,__data"))) = CFSTR("1.2.840.113635.100.1.9");
const CFStringRef kSecPolicyAppleIDValidation __attribute__((section("__DATA,__data"))) = CFSTR("1.2.840.113635.100.1.18");
const CFStringRef kSecPolicyAppleIPsec __attribute__((section("__DATA,__data"))) = CFSTR("1.2.840.113635.100.1.11");
const CFStringRef kSecPolicyApplePassbookSigning __attribute__((section("__DATA,__data"))) = CFSTR("1.2.840.113635.100.1.22");
const CFStringRef kSecPolicyAppleRevocation __attribute__((section("__DATA,__data"))) = CFSTR("1.2.840.113635.100.1.21");
const CFStringRef kSecPolicyAppleSMIME __attribute__((section("__DATA,__data"))) = CFSTR("1.2.840.113635.100.1.8");
const CFStringRef kSecPolicyAppleSSL __attribute__((section("__DATA,__data"))) = CFSTR("1.2.840.113635.100.1.3");
const CFStringRef kSecPolicyAppleTimeStamping __attribute__((section("__DATA,__data"))) = CFSTR("1.2.840.113635.100.1.20");
const CFStringRef kSecPolicyAppleX509Basic __attribute__((section("__DATA,__data"))) = CFSTR("1.2.840.113635.100.1.2");
const CFStringRef kSecPolicyClient __attribute__((section("__DATA,__data"))) = CFSTR("SecPolicyClient");
const CFStringRef kSecPolicyName __attribute__((section("__DATA,__data"))) = CFSTR("SecPolicyName");
const CFStringRef kSecPolicyOid __attribute__((section("__DATA,__data"))) = CFSTR("SecPolicyOid");
const CFStringRef kSecPolicyRevocationFlags __attribute__((section("__DATA,__data"))) = CFSTR("SecPolicyRevocationFlags");
const CFStringRef kSecPolicyTeamIdentifier __attribute__((section("__DATA,__data"))) = CFSTR("SecPolicyTeamIdentifier");
const CFStringRef kSecTrustEvaluationDate __attribute__((section("__DATA,__data"))) = CFSTR("TrustEvaluationDate");
const CFStringRef kSecTrustExtendedValidation __attribute__((section("__DATA,__data"))) = CFSTR("TrustExtendedValidation");
const CFStringRef kSecTrustOrganizationName __attribute__((section("__DATA,__data"))) = CFSTR("Organization");
const CFStringRef kSecTrustResultValue __attribute__((section("__DATA,__data"))) = CFSTR("TrustResultValue");
const CFStringRef kSecTrustRevocationChecked __attribute__((section("__DATA,__data"))) = CFSTR("TrustRevocationChecked");
const CFStringRef kSecTrustRevocationValidUntilDate __attribute__((section("__DATA,__data"))) = CFSTR("TrustExpirationDate");
