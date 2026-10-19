#import <Foundation/Foundation.h>
#import <Security/SecCertificate.h>
#import <Security/SecIdentity.h>
#import <Security/SecProtocolTypes.h>
#import <CoreFoundation/CoreFoundation.h>

@interface CharonSecIdentity : NSObject <OS_sec_identity>
- (CFArrayRef)charonCertificates;
@end

@interface CharonSecProtocolCertificateMaker : NSObject
+ (SecCertificateRef)charonRefForCertificate:(SecCertificateRef)certificate;
@end
bool sec_identity_access_certificates(sec_identity_t identity, void (^handler)(sec_certificate_t))
{
    if (![identity isKindOfClass:CharonSecIdentity.class] || !handler)
        return false;
    CFArrayRef held = [(CharonSecIdentity *)identity charonCertificates];
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
