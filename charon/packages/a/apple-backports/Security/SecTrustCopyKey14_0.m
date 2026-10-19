#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <CoreFoundation/CoreFoundation.h>

// SecTrustCopyKey.
//
//    486  SecKeyRef SecTrustCopyKey(SecTrustRef trust)
//         API_AVAILABLE(macos(11.0), ios(14.0), watchos(7.0), tvos(14.0));
//
// THE RELEASE ANSWERS THIS ONE, with the function that has been its name since before the port existed:
//
//    471  SecKeyRef SecTrustCopyPublicKey(SecTrustRef trust)
//    472      API_DEPRECATED_WITH_REPLACEMENT("SecTrustCopyKey", macos(10.7, 11.0), ios(2.0, 14.0), ...)
//
// So SecTrustCopyPublicKey is __IPHONE_2_0 and therefore ON 6.1.3, and SecTrustCopyKey is the name Apple
// gave it in iOS 14 - the header's own deprecation message says so in so many words, and quotes this
// function as the replacement. The two return the same thing from the same argument, so this is one call
// and not a reimplementation, and the port's answer is the release's own key.
//
// The key is the one the release hands over, unretained by the port: the header's contract for a
// Copy-style function is +1, and SecTrustCopyPublicKey already returns +1, so there is nothing to retain
// and nothing to release on the way out.
SecKeyRef SecTrustCopyKey(SecTrustRef trust)
{
    if (!trust)
        return NULL;
    return SecTrustCopyPublicKey(trust);    // the release's own, iOS 2.0
}
