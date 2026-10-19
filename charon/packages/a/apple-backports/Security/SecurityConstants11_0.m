#import <Foundation/Foundation.h>
#import <Security/Security.h>

// The kSecKeyAlgorithm* constants, all eighteen of which the held cache ladder first EXPORTS at
// iOS 11.0 - measured with tools/vt-ladder-names.lua over dyld.first_releases, the same module
// tools/release-split.lua uses. iOS 6.1.3 exports none of them, so the port carries all eighteen, and
// an object holds the API of ONE release, so they are one object rather than two.
//
// THE VALUES ARE THE HOST'S Security.framework's, printed by tests/backports/host/security and
// copied out of its diff. A constant is a NAME; the value is what a key signature answers with,
// and only the host knows that.

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

// kSecAttrPersistentReference and its misspelled twin, SecItem.h:553-556,
// API_AVAILABLE(macos(10.13), ios(11.0), tvos(11.0), watchos(4.0)). They join this file because they
// arrived in the same release as the eighteen constants above.
//
// BOTH NAMES, ONE VALUE, and that is measured rather than assumed: dlsym of each name off this Mac's
// own Security.framework hands back the same CFString, "persistref". SecItem.h:555-556 declares the
// two spellings on consecutive lines with the same availability, which is Apple's own shape for a
// deprecated alias kept for source compatibility - the second is the misspelling the first replaced -
// and the framework confirms it by giving both the same string. The port carries both names with that
// one value, so a caller using either spelling passes the key the release expects.
//
// WHAT 6.1.3 ANSWERS: it does not read this attribute. The value string "persistref" is in NO held
// rung below 11.0 - read out of all fifty per-release indexes in ~/.charon/cache-index, present in
// 11.0, 12.0, 16.0 and 18.0 and in none of the other forty-six - and the symbol is in none of them
// either. A keychain matches an attribute against the very string the caller passes, so an attribute
// whose name appears nowhere in the release cannot be one it compares against: there is no code path
// in 6.1.3 that acts on it.
//
// So the port declares the constant so a caller that passes it COMPILES and passes the release's own
// key, and 6.1.3 IGNORES it: a SecItem query carrying kSecAttrPersistentReference addresses the same
// items as one without it. THAT IS THE EFFECT, and it is registered `inert` with it stated rather than
// left to be discovered by a caller whose persistent reference silently matches nothing.
//
// A caller that adds an item with this attribute and later queries for it by that attribute gets no
// match back on 6.1.3, while the item is still there to be found by its other attributes - a
// persistent reference that does not persist a reference.
const CFStringRef kSecAttrPersistantReference = CFSTR("persistref");   // the misspelled spelling, kept
const CFStringRef kSecAttrPersistentReference = CFSTR("persistref");    // the spelling that replaced it
