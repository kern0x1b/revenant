#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <CoreFoundation/CoreFoundation.h>
#import <string.h>

#include "port-shims.h"

static SecKeyRef CharonShimPortKey = NULL;
static SecKeyRef CharonShimPortPublicKey = NULL;
static uint8_t CharonShimPortScalar[32];
static size_t CharonShimPortScalarLength = 0;

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
        return errSecParam;
    }
    CFStringRef type = NULL;
    CFDictionaryRef attributes = CharonShimKeyType((SecKeyRef)wanted, &type);
    if (attributes == NULL) {
        return errSecItemNotFound;
    }
    *result = (CFTypeRef)attributes;
    return errSecSuccess;
}

CFDictionaryRef charonHost_SecKeyCopyAttributeDictionary(SecKeyRef key)
{
    CFDictionaryRef hostAttributes = SecKeyCopyAttributes(key);
    if (key != CharonShimPortKey && key != CharonShimPortPublicKey) {
        return hostAttributes;
    }
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
