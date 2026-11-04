#include "../revenant_impl.h"
#import <Foundation/Foundation.h>
#import <Security/Security.h>

const CFStringRef BACKPORT_IMPL(kSecKeyAlgorithmECIESEncryptionCofactorVariableIVX963SHA224AESGCM) = CFSTR("algid:encrypt:ECIES:ECDHC:KDFX963:SHA224:AESGCM-KDFIV");
const CFStringRef BACKPORT_IMPL(kSecKeyAlgorithmECIESEncryptionCofactorVariableIVX963SHA256AESGCM) = CFSTR("algid:encrypt:ECIES:ECDHC:KDFX963:SHA256:AESGCM-KDFIV");
const CFStringRef BACKPORT_IMPL(kSecKeyAlgorithmECIESEncryptionCofactorVariableIVX963SHA384AESGCM) = CFSTR("algid:encrypt:ECIES:ECDHC:KDFX963:SHA384:AESGCM-KDFIV");
const CFStringRef BACKPORT_IMPL(kSecKeyAlgorithmECIESEncryptionCofactorVariableIVX963SHA512AESGCM) = CFSTR("algid:encrypt:ECIES:ECDHC:KDFX963:SHA512:AESGCM-KDFIV");
const CFStringRef BACKPORT_IMPL(kSecKeyAlgorithmECIESEncryptionStandardVariableIVX963SHA224AESGCM) = CFSTR("algid:encrypt:ECIES:ECDH:KDFX963:SHA224:AESGCM-KDFIV");
const CFStringRef BACKPORT_IMPL(kSecKeyAlgorithmECIESEncryptionStandardVariableIVX963SHA256AESGCM) = CFSTR("algid:encrypt:ECIES:ECDH:KDFX963:SHA256:AESGCM-KDFIV");
const CFStringRef BACKPORT_IMPL(kSecKeyAlgorithmECIESEncryptionStandardVariableIVX963SHA384AESGCM) = CFSTR("algid:encrypt:ECIES:ECDH:KDFX963:SHA384:AESGCM-KDFIV");
const CFStringRef BACKPORT_IMPL(kSecKeyAlgorithmECIESEncryptionStandardVariableIVX963SHA512AESGCM) = CFSTR("algid:encrypt:ECIES:ECDH:KDFX963:SHA512:AESGCM-KDFIV");
const CFStringRef BACKPORT_IMPL(kSecKeyAlgorithmRSASignatureDigestPSSSHA1) = CFSTR("algid:sign:RSA:digest-PSS:SHA1:SHA1:20");
const CFStringRef BACKPORT_IMPL(kSecKeyAlgorithmRSASignatureDigestPSSSHA224) = CFSTR("algid:sign:RSA:digest-PSS:SHA224:SHA224:24");
const CFStringRef BACKPORT_IMPL(kSecKeyAlgorithmRSASignatureDigestPSSSHA256) = CFSTR("algid:sign:RSA:digest-PSS:SHA256:SHA256:32");
const CFStringRef BACKPORT_IMPL(kSecKeyAlgorithmRSASignatureDigestPSSSHA384) = CFSTR("algid:sign:RSA:digest-PSS:SHA384:SHA384:48");
const CFStringRef BACKPORT_IMPL(kSecKeyAlgorithmRSASignatureDigestPSSSHA512) = CFSTR("algid:sign:RSA:digest-PSS:SHA512:SHA512:64");
const CFStringRef BACKPORT_IMPL(kSecKeyAlgorithmRSASignatureMessagePSSSHA1) = CFSTR("algid:sign:RSA:message-PSS:SHA1:SHA1:20");
const CFStringRef BACKPORT_IMPL(kSecKeyAlgorithmRSASignatureMessagePSSSHA224) = CFSTR("algid:sign:RSA:message-PSS:SHA224:SHA224:24");
const CFStringRef BACKPORT_IMPL(kSecKeyAlgorithmRSASignatureMessagePSSSHA256) = CFSTR("algid:sign:RSA:message-PSS:SHA256:SHA256:32");
const CFStringRef BACKPORT_IMPL(kSecKeyAlgorithmRSASignatureMessagePSSSHA384) = CFSTR("algid:sign:RSA:message-PSS:SHA384:SHA384:48");
const CFStringRef BACKPORT_IMPL(kSecKeyAlgorithmRSASignatureMessagePSSSHA512) = CFSTR("algid:sign:RSA:message-PSS:SHA512:SHA512:64");

const CFStringRef BACKPORT_IMPL(kSecAttrPersistantReference) = CFSTR("persistref");
const CFStringRef BACKPORT_IMPL(kSecAttrPersistentReference) = CFSTR("persistref");
