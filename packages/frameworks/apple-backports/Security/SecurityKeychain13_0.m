#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <CoreFoundation/CoreFoundation.h>
#import <dispatch/dispatch.h>

OSStatus SecTrustEvaluateAsyncWithError(SecTrustRef trust, dispatch_queue_t queue,
                                        SecTrustWithErrorCallback result)
{
    if (!trust || !result)
        return errSecParam;
    SecTrustResultType verdict = kSecTrustResultInvalid;
    OSStatus status = SecTrustEvaluate(trust, &verdict);
    bool trusted = (status == errSecSuccess) &&
                   (verdict == kSecTrustResultProceed || verdict == kSecTrustResultUnspecified);
    NSError *failure = trusted ? nil : [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
    CFErrorRef error = (__bridge_retained CFErrorRef)failure;
    SecTrustRef held = (SecTrustRef)CFRetain(trust);
    void (^deliver)(void) = ^{
        result(held, trusted, error);
        CFRelease(held);
    };
    if (queue)
        dispatch_async(queue, deliver);
    else
        deliver();
    return errSecSuccess;
}

const CFStringRef kSecUseDataProtectionKeychain = CFSTR("nleg");
