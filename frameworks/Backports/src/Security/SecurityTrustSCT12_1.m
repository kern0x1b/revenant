#include "../revenant_impl.h"
#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <CoreFoundation/CoreFoundation.h>

OSStatus BACKPORT_IMPL(SecTrustSetSignedCertificateTimestamps)(SecTrustRef trust, CFArrayRef sctArray)
{
    (void)sctArray;
    if (!trust)
        return errSecParam;
    return errSecSuccess;
}
