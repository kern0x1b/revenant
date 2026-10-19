// port-shims-impl.m - the state and the definitions behind port-shims.h's five declarations, in one
// object. The header is included by both of the port's Security files, and a non-static definition in a
// header that two translation units include is defined twice, which the link refuses with
// "duplicate symbol" - the same class of defect the 6.1.3 gate found in the port itself, and the
// reason it is one file here and not six functions in the header.
//
// Four things live here, and each is a statement about the host, not about the port:
//
//   * the two registrations for a key of the PORT'S OWN KIND: the marker and the 32 private-scalar
//     bytes, which is what SecKeyCreateWithData would leave behind and what the port reads out of
//     SecKeyCopyAttributeDictionary.
//   * the registration for a key of the RELEASE'S OWN KEYCHAIN, and the class its keychain item
//     carries - which is the answer the release-key path reads, since an in-memory key is in no
//     keychain and the host says errSecItemNotFound (-25300) for every one of them.
//   * charonHost_SecItemCopyMatching, the release's keychain call, which the port reaches through -D.
//   * charonHost_SecKeyCopyAttributeDictionary, the release's private attribute call, likewise.
//
// Nothing here replaces the port's own code: the port's SecKeyCopyAttributes, its SecKeyRawSign call
// and its marker test all run unchanged, and only the facilities under them are the host's.
#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <CoreFoundation/CoreFoundation.h>
#import <string.h>

#include "port-shims.h"

// A key of this package's own kind: the marker and the scalar, read by the port's own test.
static SecKeyRef CharonShimPortKey = NULL;
static SecKeyRef CharonShimPortPublicKey = NULL;
static uint8_t CharonShimPortScalar[32];
static size_t CharonShimPortScalarLength = 0;

// A key of the release's own keychain, and the class its keychain item carries. A table and not three
// slots, because a key pair is two keys of ONE class and a slot per class can hold only one of them: the
// differential registers the private and the public half of a pair, and with a slot per class the second
// registration overwrote the first, so every signing through the merged symbol answered "no such item".
#define CHARON_SHIM_RELEASE_KEYS 6
static SecKeyRef CharonShimReleaseKey[CHARON_SHIM_RELEASE_KEYS];
static CFStringRef CharonShimReleaseType[CHARON_SHIM_RELEASE_KEYS];
static size_t CharonShimReleaseCount = 0;

void CharonShimMarkPortKey(SecKeyRef privateKey, const uint8_t *scalar, size_t length)
{
    CharonShimPortKey = privateKey;
    if (scalar && length == sizeof CharonShimPortScalar) {
        memcpy(CharonShimPortScalar, scalar, sizeof CharonShimPortScalar);
        CharonShimPortScalarLength = length;
    }
}

void CharonShimMarkPortPublicKey(SecKeyRef publicKey)
{
    CharonShimPortPublicKey = publicKey;
}

void CharonShimMarkReleaseKey(SecKeyRef key, CFStringRef type)
{
    if (key == NULL || CharonShimReleaseCount >= CHARON_SHIM_RELEASE_KEYS) {
        return;
    }
    CharonShimReleaseKey[CharonShimReleaseCount] = key;
    CharonShimReleaseType[CharonShimReleaseCount] = type;
    CharonShimReleaseCount++;
}

static CFDictionaryRef CharonShimKeyType(SecKeyRef key, CFStringRef *typeOut)
{
    for (size_t index = 0; index < CharonShimReleaseCount; index++) {
        if (key != NULL && key == CharonShimReleaseKey[index]) {
            *typeOut = CharonShimReleaseType[index];
            return CFDictionaryCreate(kCFAllocatorDefault, (const void *[]){kSecAttrKeyType},
                                      (const void *[]){*typeOut}, 1, &kCFTypeDictionaryKeyCallBacks,
                                      &kCFTypeDictionaryValueCallBacks);
        }
    }
    return NULL;
}

OSStatus charonHost_SecItemCopyMatching(CFDictionaryRef query, CFTypeRef *result)
{
    if (query == NULL || result == NULL) {
        return errSecParam;
    }
    CFTypeRef wanted = CFDictionaryGetValue(query, kSecValueRef);
    if (wanted == NULL || CFDictionaryGetValue(query, kSecReturnAttributes) == NULL) {
        return errSecParam;   // the only query shape the port builds, and nothing else is answered
    }
    // A keychain item answers a CFDictionaryRef of attributes and the signature says CFTypeRef, so the
    // two are the same object and no conversion is involved.
    CFStringRef type = NULL;
    CFDictionaryRef attributes = CharonShimKeyType((SecKeyRef)wanted, &type);
    if (attributes == NULL) {
        return errSecItemNotFound;   // what the host answers for a key in no keychain
    }
    *result = (CFTypeRef)attributes;
    return errSecSuccess;
}

CFDictionaryRef charonHost_SecKeyCopyAttributeDictionary(SecKeyRef key)
{
    // The host's own attributes for every key the harness was not told about, so nothing the port reads
    // of them changes: a key of the release's keychain is a key of the release's keychain here.
    CFDictionaryRef hostAttributes = SecKeyCopyAttributes(key);
    if (key != CharonShimPortKey && key != CharonShimPortPublicKey) {
        return hostAttributes;
    }
    // A key of the port's own kind holds its own scalar: the marker the port reads, and beside it the
    // 32 bytes of kSecValueData that SecKeyCreateWithData would have left, because the port's sign and
    // exchange paths read the scalar from there and nowhere else. A public key gets the marker and no
    // scalar - the port's verify path asks it only for the point, which SecKeyCopyPublicBytes answers
    // from the host's own key.
    CFMutableDictionaryRef attributes = hostAttributes
        ? CFDictionaryCreateMutableCopy(kCFAllocatorDefault, 0, hostAttributes)
        : CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks,
                                    &kCFTypeDictionaryValueCallBacks);
    if (attributes == NULL) {
        if (hostAttributes) {
            CFRelease(hostAttributes);
        }
        return NULL;
    }
    CFDictionarySetValue(attributes, CFSTR(CHARON_SHIM_SECKEY_MARKER), kCFBooleanTrue);
    if (key == CharonShimPortKey && CharonShimPortScalarLength == sizeof CharonShimPortScalar) {
        CFDataRef scalar = CFDataCreate(kCFAllocatorDefault, CharonShimPortScalar,
                                        (CFIndex)CharonShimPortScalarLength);
        if (scalar) {
            CFDictionarySetValue(attributes, kSecValueData, scalar);
            CFRelease(scalar);
        }
    }
    if (hostAttributes) {
        CFRelease(hostAttributes);
    }
    return attributes;
}
