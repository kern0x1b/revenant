#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <CoreFoundation/CoreFoundation.h>
#import <pthread.h>

// SecTrustSetNetworkFetchAllowed and SecTrustGetNetworkFetchAllowed.
//
//    254  OSStatus SecTrustSetNetworkFetchAllowed(SecTrustRef trust, Boolean allowFetch)
//         __OSX_AVAILABLE_STARTING(__MAC_10_9, __IPHONE_7_0);
//    269  OSStatus SecTrustGetNetworkFetchAllowed(SecTrustRef trust, Boolean *allowFetch)
//         __OSX_AVAILABLE_STARTING(__MAC_10_9, __IPHONE_7_0);
//
// Both are __IPHONE_7_0, and 6.1.3 is iOS 6 - one release before they exist. There is no earlier
// spelling of them and no other SecTrust function that sets a network-fetch flag, so the release has
// nothing to delegate to. What the port does instead is HOLD what the caller set and READ IT BACK, and
// that is the registry's definition of inert: accepted, held, read back, with the effect stated.
//
// THE EFFECT IS THE PART THAT MATTERS, and it is not "nothing happens": on 6.1.3 the Security framework
// resolves a trust against the anchors it was given and NEVER fetches a missing intermediate over the
// network, so a caller that sets the flag and then evaluates gets a verdict computed WITHOUT the
// fetched chain - which on a chain that needs one is a failure, not a slower success. Saying that here
// is the difference between an inert row and a silent lie.
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
        // the trusts are held, not copied, and the port never owns one: a trust it did not create is
        // released by whoever made it, and holding a pointer to compare by value is the whole use
        CharonSecurityNetworkFetchAllowed = CFSetCreateMutable(kCFAllocatorDefault, 0,
                                                              &kCFTypeSetCallBacks);
    }
    if (allowFetch)
        CFSetAddValue(CharonSecurityNetworkFetchAllowed, trust);
    else
        CFSetRemoveValue(CharonSecurityNetworkFetchAllowed, trust);
    pthread_mutex_unlock(&CharonSecurityNetworkFetchLock);
    return errSecSuccess;   // the release's own success code; what it enabled is the effect above
}

OSStatus SecTrustGetNetworkFetchAllowed(SecTrustRef trust, Boolean *allowFetch)
{
    if (!trust || !allowFetch)
        return errSecParam;
    *allowFetch = CharonSecurityNetworkFetchAllowedFor(trust, false) ? true : false;
    return errSecSuccess;
}
