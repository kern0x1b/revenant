#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <CoreFoundation/CoreFoundation.h>
#import <dispatch/dispatch.h>

// SecTrustSetOCSPResponse, SecTrust.h:603-616, __OSX_AVAILABLE_STARTING(__MAC_10_9, __IPHONE_7_0).
//
//   615  OSStatus SecTrustSetOCSPResponse(SecTrustRef trust, CFTypeRef responseData)
//        __OSX_AVAILABLE_STARTING(__MAC_10_9, __IPHONE_7_0);
//   359  OSStatus SecTrustEvaluate(SecTrustRef trust, SecTrustResultType *result)  -- iOS 2.0
//
// WHAT 6.1.3 ANSWERS. It has no OCSP setter and nothing for one to feed: the only evaluation call on
// this release is SecTrustEvaluate (iOS 2.0, exported by 6.1.3 and 4.3), it takes no responder data,
// and 6.1.3 has no revocation-checking call this function could hand a response to. Measured: the
// symbol is absent from the armv7 caches of both releases (first rung 7.0), and the literal "OCSP" is
// in no armv7 cache below 9.0 either.
//
// SO THE PORT ACCEPTS the response and holds nothing, and says so. THE EFFECT IS THE WHOLE ROW:
// 6.1.3 does not consult a caller-supplied OCSP response at evaluation time, so a revocation that the
// response would have proved is NOT proved by it. That is a failure a caller can be misled about - the
// call succeeds and the chain verifies - which is why this is registered `inert` with the effect
// stated rather than left as a silent success.
//
// The host answers errSecSuccess here too (measured, NULL responseData), so the STATUS matches and
// only the consequence differs; a caller that passes a real response and then evaluates gets on 6.1.3
// the same verdict it would have got by passing nothing.
//
// A NULL trust is errSecParam, the release's own code for a bad parameter. A NULL responseData is
// accepted, because the header's own @param reads "This may be either a CFData object ... or a CFArray
// of these" and a caller clearing a response it set earlier must be able to pass NULL.
OSStatus SecTrustSetOCSPResponse(SecTrustRef trust, CFTypeRef responseData)
{
    (void)responseData;   // 6.1.3 has no OCSP input to SecTrustEvaluate, so there is nothing to hold it for
    if (!trust)
        return errSecParam;
    return errSecSuccess;   // the release's own success code; what it enabled is the effect above
}