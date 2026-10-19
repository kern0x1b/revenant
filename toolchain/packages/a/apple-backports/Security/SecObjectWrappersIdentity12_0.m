#import <Foundation/Foundation.h>
#import <Security/SecCertificate.h>
#import <Security/SecIdentity.h>
#import <Security/SecProtocolTypes.h>
#import <CoreFoundation/CoreFoundation.h>

@interface RevenantSecIdentity : NSObject <OS_sec_identity>
{
    SecIdentityRef _identity;
    CFArrayRef _certificates;
}
- (instancetype)initWithIdentity:(SecIdentityRef)identity;
- (void)revenantSetCertificates:(CFArrayRef)certificates;
- (CFArrayRef)revenantCertificates;
@end

@implementation RevenantSecIdentity
- (instancetype)initWithIdentity:(SecIdentityRef)identity
{
    self = [super init];
    if (self)
        _identity = identity ? (SecIdentityRef)CFRetain(identity) : NULL;
    return self;
}
- (void)revenantSetCertificates:(CFArrayRef)certificates
{
    if (_certificates)
        CFRelease(_certificates);
    _certificates = certificates ? (CFArrayRef)CFArrayCreateCopy(kCFAllocatorDefault, certificates) : NULL;
}
- (CFArrayRef)revenantCertificates { return _certificates; }
- (SecIdentityRef)revenantIdentity { return _identity; }
- (void)dealloc
{
    if (_identity) CFRelease(_identity);
    if (_certificates) CFRelease(_certificates);
}
@end

sec_identity_t sec_identity_create(SecIdentityRef identity)
{
    return (sec_identity_t)[[RevenantSecIdentity alloc] initWithIdentity:identity];
}

sec_identity_t sec_identity_create_with_certificates(SecIdentityRef identity, CFArrayRef certificates)
{
    RevenantSecIdentity *wrapper = [[RevenantSecIdentity alloc] initWithIdentity:identity];
    [wrapper revenantSetCertificates:certificates];
    return (sec_identity_t)wrapper;
}

SecIdentityRef sec_identity_copy_ref(sec_identity_t identity)
{
    if (![identity isKindOfClass:RevenantSecIdentity.class])
        return NULL;
    SecIdentityRef held = [(RevenantSecIdentity *)identity revenantIdentity];
    return held ? (SecIdentityRef)CFRetain(held) : NULL;
}

CFArrayRef sec_identity_copy_certificates_ref(sec_identity_t identity)
{
    if (![identity isKindOfClass:RevenantSecIdentity.class])
        return NULL;
    CFArrayRef held = [(RevenantSecIdentity *)identity revenantCertificates];
    return held ? (CFArrayRef)CFRetain(held) : NULL;
}
