#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <CoreFoundation/CoreFoundation.h>
#import <string.h>

#include "port-shims.h"

static SecKeyRef RevenantShimPortKey = NULL;
static SecKeyRef RevenantShimPortPublicKey = NULL;
static uint8_t RevenantShimPortScalar[32];
static size_t RevenantShimPortScalarLength = 0;

#define REVENANT_SHIM_RELEASE_KEYS 6
static SecKeyRef RevenantShimReleaseKey[REVENANT_SHIM_RELEASE_KEYS];
static CFStringRef RevenantShimReleaseType[REVENANT_SHIM_RELEASE_KEYS];
static size_t RevenantShimReleaseCount = 0;

void RevenantShimMarkPortKey(SecKeyRef privateKey, const uint8_t *scalar, size_t length)
{
    RevenantShimPortKey = privateKey;
    if (scalar && length == sizeof RevenantShimPortScalar) {
        memcpy(RevenantShimPortScalar, scalar, sizeof RevenantShimPortScalar);
        RevenantShimPortScalarLength = length;
    }
}

void RevenantShimMarkPortPublicKey(SecKeyRef publicKey)
{
    RevenantShimPortPublicKey = publicKey;
}

void RevenantShimMarkReleaseKey(SecKeyRef key, CFStringRef type)
{
    if (key == NULL || RevenantShimReleaseCount >= REVENANT_SHIM_RELEASE_KEYS) {
        return;
    }
    RevenantShimReleaseKey[RevenantShimReleaseCount] = key;
    RevenantShimReleaseType[RevenantShimReleaseCount] = type;
    RevenantShimReleaseCount++;
}

static CFDictionaryRef RevenantShimKeyType(SecKeyRef key, CFStringRef *typeOut)
{
    for (size_t index = 0; index < RevenantShimReleaseCount; index++) {
        if (key != NULL && key == RevenantShimReleaseKey[index]) {
            *typeOut = RevenantShimReleaseType[index];
            return CFDictionaryCreate(kCFAllocatorDefault, (const void *[]){kSecAttrKeyType},
                                      (const void *[]){*typeOut}, 1, &kCFTypeDictionaryKeyCallBacks,
                                      &kCFTypeDictionaryValueCallBacks);
        }
    }
    return NULL;
}

OSStatus revenantHost_SecItemCopyMatching(CFDictionaryRef query, CFTypeRef *result)
{
    if (query == NULL || result == NULL) {
        return errSecParam;
    }
    CFTypeRef wanted = CFDictionaryGetValue(query, kSecValueRef);
    if (wanted == NULL || CFDictionaryGetValue(query, kSecReturnAttributes) == NULL) {
        return errSecParam;
    }
    CFStringRef type = NULL;
    CFDictionaryRef attributes = RevenantShimKeyType((SecKeyRef)wanted, &type);
    if (attributes == NULL) {
        return errSecItemNotFound;
    }
    *result = (CFTypeRef)attributes;
    return errSecSuccess;
}

CFDictionaryRef revenantHost_SecKeyCopyAttributeDictionary(SecKeyRef key)
{
    CFDictionaryRef hostAttributes = SecKeyCopyAttributes(key);
    if (key != RevenantShimPortKey && key != RevenantShimPortPublicKey) {
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
    CFDictionarySetValue(attributes, CFSTR(REVENANT_SHIM_SECKEY_MARKER), kCFBooleanTrue);
    if (key == RevenantShimPortKey && RevenantShimPortScalarLength == sizeof RevenantShimPortScalar) {
        CFDataRef scalar = CFDataCreate(kCFAllocatorDefault, RevenantShimPortScalar,
                                        (CFIndex)RevenantShimPortScalarLength);
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
