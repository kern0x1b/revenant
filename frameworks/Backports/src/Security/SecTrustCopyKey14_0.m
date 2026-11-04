#include "../revenant_impl.h"
#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <CoreFoundation/CoreFoundation.h>

SecKeyRef BACKPORT_IMPL(SecTrustCopyKey)(SecTrustRef trust)
{
    if (!trust)
        return NULL;
    return SecTrustCopyPublicKey(trust);
}
