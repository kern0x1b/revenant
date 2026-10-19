#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <CoreFoundation/CoreFoundation.h>
#import <pthread.h>

typedef struct CharonSecurityPolicyHeld {
    const void *policy;
    CFStringRef oid;
    CFDictionaryRef properties;
} CharonSecurityPolicyHeld;

static pthread_mutex_t CharonSecurityHoldLock = PTHREAD_MUTEX_INITIALIZER;
static CFMutableArrayRef CharonSecurityPolicyHolds;

static CharonSecurityPolicyHeld *CharonSecurityPolicyHeldFor(const void *policy)
{
    if (!CharonSecurityPolicyHolds)
        return NULL;
    for (CFIndex i = 0; i < CFArrayGetCount(CharonSecurityPolicyHolds); i++) {
        CharonSecurityPolicyHeld *held = (CharonSecurityPolicyHeld *)CFArrayGetValueAtIndex(CharonSecurityPolicyHolds, i);
        if (held->policy == policy)
            return held;
    }
    return NULL;
}

static CFMutableArrayRef CharonSecurityEmptyList(void)
{
    return CFArrayCreateMutable(kCFAllocatorDefault, 0, &kCFTypeArrayCallBacks);
}

static CFMutableArrayRef CharonSecurityEmptyRecords(void)
{
    return CFArrayCreateMutable(kCFAllocatorDefault, 0, NULL);
}

static void CharonSecurityRecordPolicy(SecPolicyRef policy, CFStringRef oid, CFDictionaryRef properties)
{
    if (!policy || !oid)
        return;
    pthread_mutex_lock(&CharonSecurityHoldLock);
    if (!CharonSecurityPolicyHolds)
        CharonSecurityPolicyHolds = CharonSecurityEmptyRecords();
    CharonSecurityPolicyHeld *held = CharonSecurityPolicyHeldFor(policy);
    if (!held && CharonSecurityPolicyHolds) {
        held = (CharonSecurityPolicyHeld *)calloc(1, sizeof(CharonSecurityPolicyHeld));
        if (held) {
            held->policy = policy;
            held->oid = (CFStringRef)CFRetain(oid);
            held->properties = properties ? (CFDictionaryRef)CFRetain(properties) : NULL;
            CFArrayAppendValue(CharonSecurityPolicyHolds, (const void *)held);
        }
    }
    pthread_mutex_unlock(&CharonSecurityHoldLock);
}

OSStatus SecTrustCopyPolicies(SecTrustRef trust, CFArrayRef *policies)
{
    if (!trust || !policies)
        return errSecParam;
    CFMutableArrayRef copy = CharonSecurityEmptyList();
    if (!copy)
        return errSecAllocate;
    *policies = copy;
    return errSecSuccess;
}

OSStatus SecTrustCopyCustomAnchorCertificates(SecTrustRef trust, CFArrayRef *anchors)
{
    if (!trust || !anchors)
        return errSecParam;
    *anchors = NULL;
    return errSecSuccess;
}

CFDictionaryRef SecTrustCopyResult(SecTrustRef trust)
{
    if (!trust)
        return NULL;
    SecTrustResultType verdict = kSecTrustResultInvalid;
    OSStatus status = SecTrustEvaluate(trust, &verdict);
    if (status != errSecSuccess)
        return NULL;
    CFNumberRef value = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &verdict);
    CFDateRef date = CFDateCreate(kCFAllocatorDefault, CFAbsoluteTimeGetCurrent());
    if (!value || !date) {
        if (value) CFRelease(value);
        if (date) CFRelease(date);
        return NULL;
    }
    const void *keys[] = {kSecTrustResultValue, kSecTrustEvaluationDate};
    const void *values[] = {value, date};
    CFDictionaryRef result = CFDictionaryCreate(kCFAllocatorDefault, keys, values, 2,
                                               &kCFTypeDictionaryKeyCallBacks,
                                               &kCFTypeDictionaryValueCallBacks);
    CFRelease(value);
    CFRelease(date);
    return result;
}

CFDictionaryRef SecPolicyCopyProperties(SecPolicyRef policyRef)
{
    if (!policyRef)
        return NULL;
    pthread_mutex_lock(&CharonSecurityHoldLock);
    CharonSecurityPolicyHeld *held = CharonSecurityPolicyHeldFor(policyRef);
    CFStringRef oid = held ? (CFStringRef)CFRetain(held->oid) : NULL;
    CFDictionaryRef properties = held && held->properties ? (CFDictionaryRef)CFRetain(held->properties) : NULL;
    pthread_mutex_unlock(&CharonSecurityHoldLock);
    if (!oid) {
        if (properties) CFRelease(properties);
        return NULL;
    }
    CFMutableDictionaryRef result = CFDictionaryCreateMutable(kCFAllocatorDefault, 0,
                                                              &kCFTypeDictionaryKeyCallBacks,
                                                              &kCFTypeDictionaryValueCallBacks);
    if (result) {
        CFDictionarySetValue(result, kSecPolicyOid, oid);
        if (properties) {
            CFIndex count = CFDictionaryGetCount(properties);
            const void *keys = NULL;
            const void *values = NULL;
            CFDictionaryGetKeysAndValues(properties, &keys, &values);
            for (CFIndex i = 0; i < count; i++) {
                CFTypeRef key = ((const CFTypeRef *)keys)[i];
                if (!key || CFEqual(key, kSecPolicyOid))
                    continue;
                CFDictionarySetValue(result, key, ((const CFTypeRef *)values)[i]);
            }
        }
    }
    if (properties) CFRelease(properties);
    CFRelease(oid);
    return result;
}

SecPolicyRef SecPolicyCreateWithProperties(CFTypeRef policyIdentifier, CFDictionaryRef properties)
{
    if (!policyIdentifier)
        return NULL;
    CFStringRef identifier = (CFStringRef)policyIdentifier;
    SecPolicyRef policy = NULL;
    CFStringRef oid = NULL;
    if (CFEqual(identifier, kSecPolicyAppleX509Basic)) {
        policy = SecPolicyCreateBasicX509();
        oid = kSecPolicyAppleX509Basic;
    } else if (CFEqual(identifier, kSecPolicyAppleSSL)) {
        Boolean server = true;
        CFTypeRef hostname = NULL;
        if (properties) {
            CFTypeRef client = CFDictionaryGetValue(properties, kSecPolicyClient);
            if (client && CFGetTypeID(client) == CFBooleanGetTypeID() && CFBooleanGetValue((CFBooleanRef)client))
                server = false;
            CFTypeRef name = CFDictionaryGetValue(properties, kSecPolicyName);
            if (name && CFGetTypeID(name) == CFArrayGetTypeID() && CFArrayGetCount((CFArrayRef)name) > 0)
                name = CFArrayGetValueAtIndex((CFArrayRef)name, 0);
            if (name && CFGetTypeID(name) == CFStringGetTypeID())
                hostname = name;
        }
        policy = SecPolicyCreateSSL(server, (CFStringRef)hostname);
        oid = kSecPolicyAppleSSL;
    }
    if (policy)
        CharonSecurityRecordPolicy(policy, oid, properties);
    return policy;
}
