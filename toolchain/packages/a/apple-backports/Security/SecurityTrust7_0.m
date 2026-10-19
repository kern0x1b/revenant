#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <CoreFoundation/CoreFoundation.h>
#import <pthread.h>

typedef struct RevenantSecurityPolicyHeld {
    const void *policy;
    CFStringRef oid;
    CFDictionaryRef properties;
} RevenantSecurityPolicyHeld;

static pthread_mutex_t RevenantSecurityHoldLock = PTHREAD_MUTEX_INITIALIZER;
static CFMutableArrayRef RevenantSecurityPolicyHolds;

static RevenantSecurityPolicyHeld *RevenantSecurityPolicyHeldFor(const void *policy)
{
    if (!RevenantSecurityPolicyHolds)
        return NULL;
    for (CFIndex i = 0; i < CFArrayGetCount(RevenantSecurityPolicyHolds); i++) {
        RevenantSecurityPolicyHeld *held = (RevenantSecurityPolicyHeld *)CFArrayGetValueAtIndex(RevenantSecurityPolicyHolds, i);
        if (held->policy == policy)
            return held;
    }
    return NULL;
}

static CFMutableArrayRef RevenantSecurityEmptyList(void)
{
    return CFArrayCreateMutable(kCFAllocatorDefault, 0, &kCFTypeArrayCallBacks);
}

static CFMutableArrayRef RevenantSecurityEmptyRecords(void)
{
    return CFArrayCreateMutable(kCFAllocatorDefault, 0, NULL);
}

static void RevenantSecurityRecordPolicy(SecPolicyRef policy, CFStringRef oid, CFDictionaryRef properties)
{
    if (!policy || !oid)
        return;
    pthread_mutex_lock(&RevenantSecurityHoldLock);
    if (!RevenantSecurityPolicyHolds)
        RevenantSecurityPolicyHolds = RevenantSecurityEmptyRecords();
    RevenantSecurityPolicyHeld *held = RevenantSecurityPolicyHeldFor(policy);
    if (!held && RevenantSecurityPolicyHolds) {
        held = (RevenantSecurityPolicyHeld *)calloc(1, sizeof(RevenantSecurityPolicyHeld));
        if (held) {
            held->policy = policy;
            held->oid = (CFStringRef)CFRetain(oid);
            held->properties = properties ? (CFDictionaryRef)CFRetain(properties) : NULL;
            CFArrayAppendValue(RevenantSecurityPolicyHolds, (const void *)held);
        }
    }
    pthread_mutex_unlock(&RevenantSecurityHoldLock);
}

OSStatus SecTrustCopyPolicies(SecTrustRef trust, CFArrayRef *policies)
{
    if (!trust || !policies)
        return errSecParam;
    CFMutableArrayRef copy = RevenantSecurityEmptyList();
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
    pthread_mutex_lock(&RevenantSecurityHoldLock);
    RevenantSecurityPolicyHeld *held = RevenantSecurityPolicyHeldFor(policyRef);
    CFStringRef oid = held ? (CFStringRef)CFRetain(held->oid) : NULL;
    CFDictionaryRef properties = held && held->properties ? (CFDictionaryRef)CFRetain(held->properties) : NULL;
    pthread_mutex_unlock(&RevenantSecurityHoldLock);
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
        RevenantSecurityRecordPolicy(policy, oid, properties);
    return policy;
}
