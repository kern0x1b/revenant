#import <Foundation/Foundation.h>
#import <Security/SecCertificate.h>
#import <Security/SecIdentity.h>
#import <Security/SecProtocolTypes.h>
#import <CoreFoundation/CoreFoundation.h>

@interface CharonSecIdentity : NSObject <OS_sec_identity>
{
    SecIdentityRef _identity;
    CFArrayRef _certificates;
}
- (instancetype)initWithIdentity:(SecIdentityRef)identity;
- (void)charonSetCertificates:(CFArrayRef)certificates;
- (CFArrayRef)charonCertificates;
@end

@implementation CharonSecIdentity
- (instancetype)initWithIdentity:(SecIdentityRef)identity
{
    self = [super init];
    if (self)
        _identity = identity ? (SecIdentityRef)CFRetain(identity) : NULL;
    return self;
}
- (void)charonSetCertificates:(CFArrayRef)certificates
{
    if (_certificates)
        CFRelease(_certificates);
    _certificates = certificates ? (CFArrayRef)CFArrayCreateCopy(kCFAllocatorDefault, certificates) : NULL;
}
- (CFArrayRef)charonCertificates { return _certificates; }
- (SecIdentityRef)charonIdentity { return _identity; }
- (void)dealloc
{
    if (_identity) CFRelease(_identity);
    if (_certificates) CFRelease(_certificates);
}
@end

sec_identity_t sec_identity_create(SecIdentityRef identity)
{
    return (sec_identity_t)[[CharonSecIdentity alloc] initWithIdentity:identity];
}

sec_identity_t sec_identity_create_with_certificates(SecIdentityRef identity, CFArrayRef certificates)
{
    CharonSecIdentity *wrapper = [[CharonSecIdentity alloc] initWithIdentity:identity];
    [wrapper charonSetCertificates:certificates];
    return (sec_identity_t)wrapper;
}

SecIdentityRef sec_identity_copy_ref(sec_identity_t identity)
{
    if (![identity isKindOfClass:CharonSecIdentity.class])
        return NULL;
    SecIdentityRef held = [(CharonSecIdentity *)identity charonIdentity];
    return held ? (SecIdentityRef)CFRetain(held) : NULL;
}

CFArrayRef sec_identity_copy_certificates_ref(sec_identity_t identity)
{
    if (![identity isKindOfClass:CharonSecIdentity.class])
        return NULL;
    CFArrayRef held = [(CharonSecIdentity *)identity charonCertificates];
    return held ? (CFArrayRef)CFRetain(held) : NULL;
}
