#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <CoreFoundation/CoreFoundation.h>
#import <dispatch/dispatch.h>

// SecTrustEvaluateAsyncWithError, SecTrust.h:421-443,
// API_AVAILABLE(macos(10.15), ios(13.0), tvos(13.0), watchos(6.0)),
// and the kSecUseDataProtectionKeychain constant of the same release, SecItem.h:1043-1044
// API_AVAILABLE(macos(10.15), ios(13.0)).
//
// ONE OBJECT PER RELEASE: both arrived in iOS 13.0, and nothing in this file arrived earlier or
// later, which is what tools/release-split.lua checks.

// ---------------------------------------------------------------------------------------------
// SecTrustEvaluateAsyncWithError.
//
//   442  OSStatus SecTrustEvaluateAsyncWithError(SecTrustRef trust, dispatch_queue_t queue,
//                                                 SecTrustWithErrorCallback result)
//        API_AVAILABLE(macos(10.15), ios(13.0), ...);
//   359  OSStatus SecTrustEvaluate(SecTrustRef trust, SecTrustResultType *result)  -- iOS 2.0
//
// WHAT 6.1.3 ANSWERS. No asynchronous evaluation, and no error-reporting evaluation: the only
// evaluation call on this release is SecTrustEvaluate, iOS 2.0, exported by both 6.1.3 and 4.3, and it
// reports through an OSStatus and a SecTrustResultType rather than through a bool and a CFError. The
// verdict is therefore the release's own, and the error is this port's translation of the release's
// OSStatus - errSecSuccess becomes `true` with a NULL error, which is what the header promises at
// :433-436 (a trusted certificate gets true with its error set to NULL), and any other OSStatus becomes
// `false` with an NSError in
// NSOSStatusErrorDomain carrying that same code.
//
// THE TWO EFFECTS, both stated because the header's own words say the port cannot keep them:
//
//  1. THE ORDERING. :427-431 requires that this function is called from that queue, and says the
//     block may run synchronously inline when no asynchronous operations are needed. This port
//     evaluates on the CALLING thread and delivers the callback on the queue the caller named, so the
//     callback arrives after this function returns rather than during it - which the header permits -
//     and the cost is that the evaluation has already happened by then. MEASURED ON THE HOST over the
//     committed fixture: the host answers errSecSuccess, does NOT call back inline, and delivers
//     `false` (the fixture is expired, so it does not verify), which is the same pair this port
//     produces from the release's own verdict.
//
//  2. THE QUEUE PRECONDITION. The host TRAPS if this is called off the queue it is handed - measured,
//     exit 133 with a __NSRangeException-style abort from inside Security.framework - so the header's
//     "MUST be called from that queue" is enforced by the host and not merely documented. This port
//     does NOT enforce it: the evaluation is synchronous, so calling it from any thread is safe here.
//     A caller that depends on the trap to catch its own mistake will find it does not fire, and that
//     is named rather than left to be found.
OSStatus SecTrustEvaluateAsyncWithError(SecTrustRef trust, dispatch_queue_t queue,
                                        SecTrustWithErrorCallback result)
{
    if (!trust || !result)
        return errSecParam;
    SecTrustResultType verdict = kSecTrustResultInvalid;
    OSStatus status = SecTrustEvaluate(trust, &verdict);   // the release's own, iOS 2.0
    bool trusted = (status == errSecSuccess) &&
                   (verdict == kSecTrustResultProceed || verdict == kSecTrustResultUnspecified);
    // The error carries the release's OWN OSStatus as its code, in the domain a caller already knows
    // from this port's SecTrustEvaluateWithError (SecTrustEvaluateWithError.m:26 builds the same
    // NSError for the same status). That function is not called here on purpose: it lives in a file
    // that exports API symbols, and a call across two such files survives only while both are carried
    // in the same band - the shape charon/AGENTS.md's "A C function shared between backport files"
    // entry is about. SecTrustEvaluate is iOS 2.0 and is on every band this port builds.
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

// ---------------------------------------------------------------------------------------------
// kSecUseDataProtectionKeychain, SecItem.h:1043-1044, API_AVAILABLE(macos(10.15), ios(13.0)).
//
//   1043 extern const CFStringRef kSecUseDataProtectionKeychain
//   1044     API_AVAILABLE(macos(10.15), ios(13.0));
//
// THE VALUE IS THE HOST'S, measured by dlsym off this Mac's own Security.framework: the CFString
// "nleg". That is not a guess and not the four-character code one might expect - it is what the
// framework really exports, and the port carries that string so a caller that compares keys, or logs
// the dictionary it built, sees what it would see on a newer release.
//
// WHAT 6.1.3 ANSWERS: nothing, and the port says so. This key selects a data-protection keychain,
// which is the keychain SecItem writes into when the item carries kSecAttrAccessControl or a
// per-item protection class - and 6.1.3 HAS NEITHER: kSecAttrAccessControl first appears at 8.0 and
// SecAccessControlCreateWithFlags with it, both measured absent from the armv7 caches of 6.1.3 and 4.3.
// There is one keychain on this release and no second one for this key to select.
//
// THE EFFECT: the port declares the constant so that a caller which passes it COMPILES and passes the
// key the newer release expects, and 6.1.3 IGNORES it - a SecItem call carrying it addresses the same
// keychain a call without it addresses. That is registered `inert` with the effect stated, because a
// constant whose value is right but which selects nothing is exactly what `inert` is for; claiming
// `implemented` would claim the keychain was selected.
//
// So a caller that passes kCFBooleanTrue for this key gets a query that behaves as though it had not
// passed it, and one that also passes kSecAttrAccessGroup or kSecAttrAccessible gets them against the
// file keychain, which is where 6.1.3 keeps everything.
const CFStringRef kSecUseDataProtectionKeychain = CFSTR("nleg");