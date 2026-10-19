#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <CoreFoundation/CoreFoundation.h>

// SecTrustSetSignedCertificateTimestamps, SecTrust.h:619-629,
// API_AVAILABLE(macos(10.14.2), ios(12.1.1), tvos(12.1.1), watchos(5.1.1)).
//
// WHAT 6.1.3 ANSWERS. It has no certificate transparency at all - no SCT parser, no place in an
// evaluation where a timestamp is consulted, and no call that reads a stapled SCT back. Measured: the
// symbol is absent from the armv7 caches of both releases the port supports.
//
// Note the ladder's own caveat, which is why the row's `introduced` is the header's 12.1.1 and not a
// rung: first-rung.lua answers 9.0 for this symbol, because the held ladder has a hole above 12.0
// (there is no 12.1.1, 13.0 or 14.0 armv7 cache in ~/.charon/dyld) and the index is a PRESENCE answer
// over the rungs that exist. The header's availability is the declaration and the registry carries it.
//
// SO THE PORT ACCEPTS the array and holds nothing, and says so. THE EFFECT IS THE WHOLE ROW: a caller
// that staples timestamps here gets NO additional scrutiny and NO error. A chain that only validates
// with certificate transparency will verify here when it should not, and that is the difference a
// caller has to know about. It is stated rather than left to be discovered.
//
// The host answers errSecSuccess over the same NULL (measured), so the STATUS matches; only the
// consequence on the evaluation differs.
OSStatus SecTrustSetSignedCertificateTimestamps(SecTrustRef trust, CFArrayRef sctArray)
{
    (void)sctArray;   // 6.1.3 has no certificate transparency in its evaluation, so there is nothing to hold it for
    if (!trust)
        return errSecParam;
    return errSecSuccess;   // the release's own success code; what it enabled is the effect above
}