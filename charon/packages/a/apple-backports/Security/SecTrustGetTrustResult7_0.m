#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <CoreFoundation/CoreFoundation.h>

// SecTrustGetTrustResult.
//
//    456  OSStatus SecTrustGetTrustResult(SecTrustRef trust, SecTrustResultType *result)
//         __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_7_0);
//
// THE OBVIOUS COUNTERPART IS NOT ON iOS, and that is the whole of this file's reason to exist. The
// header's deprecation message points at SecTrustGetResult, and a reader would take that as the release
// having the call - but its availability line is:
//
//    758  OSStatus SecTrustGetResult(SecTrustRef trustRef, SecTrustResultType *result, ...)
//         __OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_2, __MAC_10_7, __IPHONE_NA, __IPHONE_NA);
//                             ^^^^^^^^^^^^^ iOS: NEVER, in any release
//
// __IPHONE_NA is not "old" or "deprecated on iOS": the function has never been part of iOS. So the claim
// that this is a one-call wrapper around the release's own SecTrustGetResult is false, and a wrapper for
// it would not link on a 6.1.3 band at all.
//
// WHAT iOS 6.1.3 HAS is the evaluation itself:
//
//    359  OSStatus SecTrustEvaluate(SecTrustRef trust, SecTrustResultType *result)
//         API_DEPRECATED_WITH_REPLACEMENT("SecTrustEvaluateWithError", macos(10.3, 10.15), ios(2.0, 10.0))
//
// so the port evaluates and reports the release's own verdict. THE EFFECT IS STATED BECAUSE IT IS A REAL
// DIFFERENCE: this function's contract is to return the result of an EARLIER evaluation, and on 6.1.3
// there is no stored result to read, so the verdict is COMPUTED ON THE CALL. A caller that trusted the
// trust, changed a policy, and asked again gets a freshly evaluated answer rather than the stale one a
// later release would hand back - which is a difference in what the caller can conclude, and saying so
// is the honest version of this port.
OSStatus SecTrustGetTrustResult(SecTrustRef trust, SecTrustResultType *result)
{
    if (!trust || !result)
        return errSecParam;
    return SecTrustEvaluate(trust, result);   // the release's own, iOS 2.0
}
