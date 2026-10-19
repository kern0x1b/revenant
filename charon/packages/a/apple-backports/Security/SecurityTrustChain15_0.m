#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <CoreFoundation/CoreFoundation.h>

// SecTrustCopyCertificateChain, SecTrust.h:632-640,
// API_AVAILABLE(macos(12.0), ios(15.0), tvos(15.0), watchos(8.0)).
//
// THE RELEASE ANSWERS THIS ONE, with two accessors it has carried since iOS 2.0:
//
//   500  CFIndex SecTrustGetCertificateCount(SecTrustRef trust)
//        __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_2_0);
//   518  SecCertificateRef SecTrustGetCertificateAtIndex(SecTrustRef trust, CFIndex ix)
//        API_DEPRECATED_WITH_REPLACEMENT("SecTrustCopyCertificateChain", macos(10.7, 12.0), ios(2.0, 15.0), ...);
//        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ the header names THIS function as its replacement
//
// Both are on 6.1.3 and on 4.3 (first rung 3.0 each), and the header's own deprecation message says the
// chain they walk is the one this function returns: :511-512 says the indices run from the leaf, index 0, to the anchor
// (or to the last certificate found when there is no anchor). So this is one loop over the release's OWN
// accessors and not a reconstruction of anything.
//
// MEASURED ON THE HOST for the shape, because a chain that came out in a different order would be a
// different answer: over the committed fixture certificate the host's own SecTrustCopyCertificateChain
// returns an array of one whose element CFEquals the fixture, before an evaluation and after one, and
// the release's SecTrustGetCertificateCount over the same trust returns 1 with the fixture as its leaf.
// The port's loop is what produces that shape here, from the release's own accessors.
//
// THE EFFECT IS STATED because THE HEADER SAYS THE TWO DIFFER, at :514-515:
//   The header says this API is not thread-safe: threads sharing one trust object can trigger
//   evaluations that free the returned certificate or alter the chain while a thread is walking it, and
//   the replacement, SecTrustCopyCertificateChain, provides thread-safe results.
// So the chain the caller receives is the RELEASE'S OWN evaluated chain, walked through two accessors
// the header calls not thread-safe: a concurrent evaluation on another thread can change the chain
// under this loop, and what the caller gets is what the release held while the loop ran rather than a
// snapshot of one instant. Each certificate is retained by the array's kCFTypeArrayCallBacks, so it
// outlives the walk even where the release drops its own reference on a re-evaluation.
//
// A count that SHRINKS mid-walk is the same race the header names, and the loop stops rather than
// reading past it: SecTrustGetCertificateAtIndex is __nullable, and a NULL there means the chain this
// release holds is shorter than the count it reported a moment ago.
CFArrayRef SecTrustCopyCertificateChain(SecTrustRef trust)
{
    if (!trust)
        return NULL;
    CFIndex count = SecTrustGetCertificateCount(trust);        // the release's own, iOS 2.0
    if (count < 1)
        return NULL;
    CFMutableArrayRef chain = CFArrayCreateMutable(kCFAllocatorDefault, 0, &kCFTypeArrayCallBacks);
    if (!chain)
        return NULL;
    for (CFIndex index = 0; index < count; index++) {
        SecCertificateRef certificate = SecTrustGetCertificateAtIndex(trust, index);   // the release's own
        if (!certificate)
            break;   // the chain shortened under the walk, which is the race the header names
        CFArrayAppendValue(chain, certificate);   // +1: the array keeps each alive past the walk
    }
    return chain;
}