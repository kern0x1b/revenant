#import <Foundation/Foundation.h>
#import <Security/SecCertificate.h>
#import <Security/SecTrust.h>
#import <Security/SecPolicy.h>
#import <Security/SecProtocolTypes.h>
#import <CoreFoundation/CoreFoundation.h>

@interface CharonSecCertificate : NSObject <OS_sec_certificate>
{
    SecCertificateRef _certificate;
}
- (instancetype)initWithCertificate:(SecCertificateRef)certificate;
- (SecCertificateRef)charonCertificate;
@end

@implementation CharonSecCertificate
- (instancetype)initWithCertificate:(SecCertificateRef)certificate
{
    self = [super init];
    if (self)
        _certificate = certificate ? (SecCertificateRef)CFRetain(certificate) : NULL;
    return self;
}
- (SecCertificateRef)charonCertificate { return _certificate; }
- (void)dealloc { if (_certificate) CFRelease(_certificate); }
@end

@interface CharonSecTrust : NSObject <OS_sec_trust>
{
    SecTrustRef _trust;
}
- (instancetype)initWithTrust:(SecTrustRef)trust;
- (SecTrustRef)charonTrust;
@end

@implementation CharonSecTrust
- (instancetype)initWithTrust:(SecTrustRef)trust
{
    self = [super init];
    if (self)
        _trust = trust ? (SecTrustRef)CFRetain(trust) : NULL;
    return self;
}
- (SecTrustRef)charonTrust { return _trust; }
- (void)dealloc { if (_trust) CFRelease(_trust); }
@end

sec_certificate_t sec_certificate_create(SecCertificateRef certificate)
{
    return (sec_certificate_t)[[CharonSecCertificate alloc] initWithCertificate:certificate];
}

SecCertificateRef sec_certificate_copy_ref(sec_certificate_t certificate)
{
    if (![certificate isKindOfClass:CharonSecCertificate.class])
        return NULL;
    SecCertificateRef held = [(CharonSecCertificate *)certificate charonCertificate];
    return held ? (SecCertificateRef)CFRetain(held) : NULL;
}

sec_trust_t sec_trust_create(SecTrustRef trust)
{
    return (sec_trust_t)[[CharonSecTrust alloc] initWithTrust:trust];
}

SecTrustRef sec_trust_copy_ref(sec_trust_t trust)
{
    if (![trust isKindOfClass:CharonSecTrust.class])
        return NULL;
    SecTrustRef held = [(CharonSecTrust *)trust charonTrust];
    return held ? (SecTrustRef)CFRetain(held) : NULL;
}
