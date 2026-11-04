#include "../revenant_impl.h"
#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <CoreFoundation/CoreFoundation.h>
#import <dispatch/dispatch.h>

OSStatus BACKPORT_IMPL(SecTrustSetOCSPResponse)(SecTrustRef trust, CFTypeRef responseData)
{
    (void)responseData;
    if (!trust)
        return errSecParam;
    return errSecSuccess;
}
