#import <Foundation/Foundation.h>
#import <Security/SecCertificate.h>
#import <Security/SecIdentity.h>
#import <Security/SecProtocolTypes.h>
#import <CoreFoundation/CoreFoundation.h>

@interface RevenantSecIdentity : NSObject <OS_sec_identity>
- (CFArrayRef)revenantCertificates;
@end

@interface RevenantSecProtocolCertificateMaker : NSObject
+ (SecCertificateRef)revenantRefForCertificate:(SecCertificateRef)certificate;
@end
bool sec_identity_access_certificates(sec_identity_t identity, void (^handler)(sec_certificate_t))
{
    if (![identity isKindOfClass:RevenantSecIdentity.class] || !handler)
        return false;
    CFArrayRef held = [(RevenantSecIdentity *)identity revenantCertificates];
    if (!held)
        return true;
    CFIndex count = CFArrayGetCount(held);
    for (CFIndex i = 0; i < count; i++) {
        sec_certificate_t wrapper = sec_certificate_create((SecCertificateRef)CFArrayGetValueAtIndex(held, i));
        if (!wrapper)
            return false;
        handler(wrapper);
    }
    return true;
}
