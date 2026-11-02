#include "../revenant_impl.h"
#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <CoreFoundation/CoreFoundation.h>

OSStatus BACKPORT_IMPL(SecTrustGetTrustResult)(SecTrustRef trust, SecTrustResultType *result)
{
    if (!trust || !result)
        return errSecParam;
    return SecTrustEvaluate(trust, result);
}
