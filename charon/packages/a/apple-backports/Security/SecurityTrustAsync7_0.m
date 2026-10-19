#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <CoreFoundation/CoreFoundation.h>
#import <dispatch/dispatch.h>

// SecTrustEvaluateAsync, SecTrust.h:366-383, API_DEPRECATED_WITH_REPLACEMENT("SecTrustEvaluateAsyncWithError",
// macos(10.7, 10.15), ios(7.0, 13.0), ...).
//
// WHAT 6.1.3 ANSWERS. It has no asynchronous evaluation at all: the only evaluation call on this
// release is
//
//   359  OSStatus SecTrustEvaluate(SecTrustRef trust, SecTrustResultType *result)
//        API_DEPRECATED_WITH_REPLACATION(..., ios(2.0, 13.0), ...);
//        ^^^^^^^^^^^^^^ "Evaluates a trust reference synchronously" - SecTrust.h:347-348
//
// which is iOS 2.0 and exported by both 6.1.3 and 4.3. So the port runs the release's own
// evaluation and hands the release's own verdict to the block. There is nothing to queue: the work
// the header describes as asynchronous is a property of a later release's implementation, and 6.1.3
// evaluates where it is called.
//
// THE EFFECT, STATED because the ORDERING is the contract and the port cannot keep it:
// SecTrust.h:371-375 documents the queue argument as the dispatch queue that runs the result callback,
// with NULL meaning the current dispatch queue. This port delivers the callback on
// the caller's queue when one is given, so the caller sees the callback AFTER this function returns -
// which is the ordering the contract promises - and the evaluation itself has already run by then.
// The difference is therefore visible only as blocking: a caller that relies on this call returning
// before the evaluation has happened gets a caller that has already waited for it, which is why
// SecTrust.h:354-357 tells a caller to put this work on a queue of its own.
//
// MEASURED ON THE HOST, because the difference is worth a number: over the committed fixture
// certificate the host's own SecTrustEvaluateAsync answers errSecSuccess, does NOT call the block
// before it returns, and delivers a kSecTrustResultUnspecified verdict. The port answers
// errSecSuccess and the same verdict, through the release's own SecTrustEvaluate.
//
// A NULL trust or a NULL block is errSecParam, which is the release's own code for a bad parameter
// and not this port's invention.
OSStatus SecTrustEvaluateAsync(SecTrustRef trust, dispatch_queue_t queue, SecTrustCallback result)
{
    if (!trust || !result)
        return errSecParam;
    SecTrustResultType verdict = kSecTrustResultInvalid;
    OSStatus status = SecTrustEvaluate(trust, &verdict);   // the release's own, iOS 2.0
    if (status != errSecSuccess)
        return status;
    // the caller keeps ownership of the trust, so the block holds it for as long as it may run
    SecTrustRef held = (SecTrustRef)CFRetain(trust);
    void (^deliver)(void) = ^{
        result(held, verdict);
        CFRelease(held);
    };
    if (queue)
        dispatch_async(queue, deliver);
    else
        deliver();   // NULL means the caller's own queue, which is where the caller already is
    return errSecSuccess;
}