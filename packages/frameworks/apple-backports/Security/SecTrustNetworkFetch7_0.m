#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <CoreFoundation/CoreFoundation.h>
#import <pthread.h>

static pthread_mutex_t RevenantSecurityNetworkFetchLock = PTHREAD_MUTEX_INITIALIZER;
static CFMutableSetRef RevenantSecurityNetworkFetchAllowed;

Boolean RevenantSecurityNetworkFetchAllowedFor(SecTrustRef trust, bool fallback)
{
    bool answer = fallback;
    pthread_mutex_lock(&RevenantSecurityNetworkFetchLock);
    if (RevenantSecurityNetworkFetchAllowed)
        answer = CFSetContainsValue(RevenantSecurityNetworkFetchAllowed, trust) ? true : false;
    pthread_mutex_unlock(&RevenantSecurityNetworkFetchLock);
    return answer;
}

OSStatus SecTrustSetNetworkFetchAllowed(SecTrustRef trust, Boolean allowFetch)
{
    if (!trust)
        return errSecParam;
    pthread_mutex_lock(&RevenantSecurityNetworkFetchLock);
    if (!RevenantSecurityNetworkFetchAllowed) {
        RevenantSecurityNetworkFetchAllowed = CFSetCreateMutable(kCFAllocatorDefault, 0,
                                                              &kCFTypeSetCallBacks);
    }
    if (allowFetch)
        CFSetAddValue(RevenantSecurityNetworkFetchAllowed, trust);
    else
        CFSetRemoveValue(RevenantSecurityNetworkFetchAllowed, trust);
    pthread_mutex_unlock(&RevenantSecurityNetworkFetchLock);
    return errSecSuccess;
}

OSStatus SecTrustGetNetworkFetchAllowed(SecTrustRef trust, Boolean *allowFetch)
{
    if (!trust || !allowFetch)
        return errSecParam;
    *allowFetch = RevenantSecurityNetworkFetchAllowedFor(trust, false) ? true : false;
    return errSecSuccess;
}
