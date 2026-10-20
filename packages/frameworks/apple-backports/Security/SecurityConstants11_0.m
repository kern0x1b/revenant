#import <Foundation/Foundation.h>
#import <Security/Security.h>

const CFStringRef kSecKeyAlgorithmECIESEncryptionCofactorVariableIVX963SHA224AESGCM = CFSTR("algid:encrypt:ECIES:ECDHC:KDFX963:SHA224:AESGCM-KDFIV");
const CFStringRef kSecKeyAlgorithmECIESEncryptionCofactorVariableIVX963SHA256AESGCM = CFSTR("algid:encrypt:ECIES:ECDHC:KDFX963:SHA256:AESGCM-KDFIV");
const CFStringRef kSecKeyAlgorithmECIESEncryptionCofactorVariableIVX963SHA384AESGCM = CFSTR("algid:encrypt:ECIES:ECDHC:KDFX963:SHA384:AESGCM-KDFIV");
const CFStringRef kSecKeyAlgorithmECIESEncryptionCofactorVariableIVX963SHA512AESGCM = CFSTR("algid:encrypt:ECIES:ECDHC:KDFX963:SHA512:AESGCM-KDFIV");
const CFStringRef kSecKeyAlgorithmECIESEncryptionStandardVariableIVX963SHA224AESGCM = CFSTR("algid:encrypt:ECIES:ECDH:KDFX963:SHA224:AESGCM-KDFIV");
const CFStringRef kSecKeyAlgorithmECIESEncryptionStandardVariableIVX963SHA256AESGCM = CFSTR("algid:encrypt:ECIES:ECDH:KDFX963:SHA256:AESGCM-KDFIV");
const CFStringRef kSecKeyAlgorithmECIESEncryptionStandardVariableIVX963SHA384AESGCM = CFSTR("algid:encrypt:ECIES:ECDH:KDFX963:SHA384:AESGCM-KDFIV");
const CFStringRef kSecKeyAlgorithmECIESEncryptionStandardVariableIVX963SHA512AESGCM = CFSTR("algid:encrypt:ECIES:ECDH:KDFX963:SHA512:AESGCM-KDFIV");
const CFStringRef kSecKeyAlgorithmRSASignatureDigestPSSSHA1 = CFSTR("algid:sign:RSA:digest-PSS:SHA1:SHA1:20");
const CFStringRef kSecKeyAlgorithmRSASignatureDigestPSSSHA224 = CFSTR("algid:sign:RSA:digest-PSS:SHA224:SHA224:24");
const CFStringRef kSecKeyAlgorithmRSASignatureDigestPSSSHA256 = CFSTR("algid:sign:RSA:digest-PSS:SHA256:SHA256:32");
const CFStringRef kSecKeyAlgorithmRSASignatureDigestPSSSHA384 = CFSTR("algid:sign:RSA:digest-PSS:SHA384:SHA384:48");
const CFStringRef kSecKeyAlgorithmRSASignatureDigestPSSSHA512 = CFSTR("algid:sign:RSA:digest-PSS:SHA512:SHA512:64");
const CFStringRef kSecKeyAlgorithmRSASignatureMessagePSSSHA1 = CFSTR("algid:sign:RSA:message-PSS:SHA1:SHA1:20");
const CFStringRef kSecKeyAlgorithmRSASignatureMessagePSSSHA224 = CFSTR("algid:sign:RSA:message-PSS:SHA224:SHA224:24");
const CFStringRef kSecKeyAlgorithmRSASignatureMessagePSSSHA256 = CFSTR("algid:sign:RSA:message-PSS:SHA256:SHA256:32");
const CFStringRef kSecKeyAlgorithmRSASignatureMessagePSSSHA384 = CFSTR("algid:sign:RSA:message-PSS:SHA384:SHA384:48");
const CFStringRef kSecKeyAlgorithmRSASignatureMessagePSSSHA512 = CFSTR("algid:sign:RSA:message-PSS:SHA512:SHA512:64");

const CFStringRef kSecAttrPersistantReference = CFSTR("persistref");
const CFStringRef kSecAttrPersistentReference = CFSTR("persistref");
