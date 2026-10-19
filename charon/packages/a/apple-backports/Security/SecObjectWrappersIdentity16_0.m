#import <Foundation/Foundation.h>
#import <Security/SecCertificate.h>
#import <Security/SecIdentity.h>
#import <Security/SecProtocolTypes.h>
#import <CoreFoundation/CoreFoundation.h>

// sec_identity_access_certificates, in its OWN object at 16.0, because release-split says so and not
// because I guessed: run on the pair, it reported
//
//   SecObjectWrappersIdentity.o  MIXED-RELEASES  12.0,16.0
//
// with _sec_identity_access_certificates first appearing at 16.0 and the other four at 12.0. One release
// per object is the rule, so the family splits, and the split is between these two files rather than
// inside one. The 12.0 file is SecObjectWrappersIdentity12_0.m; this is the 16.0 half.
//
//   SecProtocolTypes.h:256  bool sec_identity_access_certificates(sec_identity_t identity,
//                                                                  void (^handler)(sec_certificate_t certificate))
//
// The class is DECLARED here and IMPLEMENTED in the 12.0 file. That is not a duplicate definition: a
// second @implementation would be, and there is none - the same shape the sibling uses to reach a class
// another object owns.

@interface CharonSecIdentity : NSObject <OS_sec_identity>
- (CFArrayRef)charonCertificates;
@end

@interface CharonSecProtocolCertificateMaker : NSObject
+ (SecCertificateRef)charonRefForCertificate:(SecCertificateRef)certificate;
@end
//   256  bool sec_identity_access_certificates(sec_identity_t identity,
//                                               void (^handler)(sec_certificate_t certificate))
bool sec_identity_access_certificates(sec_identity_t identity, void (^handler)(sec_certificate_t))
{
    if (![identity isKindOfClass:CharonSecIdentity.class] || !handler)
        return false;
    CFArrayRef held = [(CharonSecIdentity *)identity charonCertificates];
    if (!held)
        return true;   // nothing to visit is not a failure; the handler simply runs zero times
    CFIndex count = CFArrayGetCount(held);
    for (CFIndex i = 0; i < count; i++) {
        // the wrapper is a strong local, so ARC releases it when the iteration ends
        sec_certificate_t wrapper = sec_certificate_create((SecCertificateRef)CFArrayGetValueAtIndex(held, i));
        if (!wrapper)
            return false;
        handler(wrapper);
    }
    return true;
}
