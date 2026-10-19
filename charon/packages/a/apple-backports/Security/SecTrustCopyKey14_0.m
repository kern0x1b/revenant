#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <CoreFoundation/CoreFoundation.h>

SecKeyRef SecTrustCopyKey(SecTrustRef trust)
{
    if (!trust)
        return NULL;
    return SecTrustCopyPublicKey(trust);
}
