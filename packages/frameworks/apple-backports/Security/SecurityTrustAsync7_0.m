#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <CoreFoundation/CoreFoundation.h>
#import <dispatch/dispatch.h>

OSStatus SecTrustEvaluateAsync(SecTrustRef trust, dispatch_queue_t queue, SecTrustCallback result)
{
    if (!trust || !result)
        return errSecParam;
    SecTrustResultType verdict = kSecTrustResultInvalid;
    OSStatus status = SecTrustEvaluate(trust, &verdict);
    if (status != errSecSuccess)
        return status;
    SecTrustRef held = (SecTrustRef)CFRetain(trust);
    void (^deliver)(void) = ^{
        result(held, verdict);
        CFRelease(held);
    };
    if (queue)
        dispatch_async(queue, deliver);
    else
        deliver();
    return errSecSuccess;
}
