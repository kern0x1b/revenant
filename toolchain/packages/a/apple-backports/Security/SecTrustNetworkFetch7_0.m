#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <CoreFoundation/CoreFoundation.h>
#import <pthread.h>

static pthread_mutex_t CharonSecurityNetworkFetchLock = PTHREAD_MUTEX_INITIALIZER;
static CFMutableSetRef CharonSecurityNetworkFetchAllowed;

Boolean CharonSecurityNetworkFetchAllowedFor(SecTrustRef trust, bool fallback)
{
    bool answer = fallback;
    pthread_mutex_lock(&CharonSecurityNetworkFetchLock);
    if (CharonSecurityNetworkFetchAllowed)
        answer = CFSetContainsValue(CharonSecurityNetworkFetchAllowed, trust) ? true : false;
    pthread_mutex_unlock(&CharonSecurityNetworkFetchLock);
    return answer;
}

OSStatus SecTrustSetNetworkFetchAllowed(SecTrustRef trust, Boolean allowFetch)
{
    if (!trust)
        return errSecParam;
    pthread_mutex_lock(&CharonSecurityNetworkFetchLock);
    if (!CharonSecurityNetworkFetchAllowed) {
        CharonSecurityNetworkFetchAllowed = CFSetCreateMutable(kCFAllocatorDefault, 0,
                                                              &kCFTypeSetCallBacks);
    }
    if (allowFetch)
        CFSetAddValue(CharonSecurityNetworkFetchAllowed, trust);
    else
        CFSetRemoveValue(CharonSecurityNetworkFetchAllowed, trust);
    pthread_mutex_unlock(&CharonSecurityNetworkFetchLock);
    return errSecSuccess;
}

OSStatus SecTrustGetNetworkFetchAllowed(SecTrustRef trust, Boolean *allowFetch)
{
    if (!trust || !allowFetch)
        return errSecParam;
    *allowFetch = CharonSecurityNetworkFetchAllowedFor(trust, false) ? true : false;
    return errSecSuccess;
}
