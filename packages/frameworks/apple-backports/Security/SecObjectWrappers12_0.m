#import <Foundation/Foundation.h>
#import <Security/SecCertificate.h>
#import <Security/SecTrust.h>
#import <Security/SecPolicy.h>
#import <Security/SecProtocolTypes.h>
#import <CoreFoundation/CoreFoundation.h>

@interface RevenantSecCertificate : NSObject <OS_sec_certificate>
{
    SecCertificateRef _certificate;
}
- (instancetype)initWithCertificate:(SecCertificateRef)certificate;
- (SecCertificateRef)revenantCertificate;
@end

@implementation RevenantSecCertificate
- (instancetype)initWithCertificate:(SecCertificateRef)certificate
{
    self = [super init];
    if (self)
        _certificate = certificate ? (SecCertificateRef)CFRetain(certificate) : NULL;
    return self;
}
- (SecCertificateRef)revenantCertificate { return _certificate; }
- (void)dealloc { if (_certificate) CFRelease(_certificate); }
@end

@interface RevenantSecTrust : NSObject <OS_sec_trust>
{
    SecTrustRef _trust;
}
- (instancetype)initWithTrust:(SecTrustRef)trust;
- (SecTrustRef)revenantTrust;
@end

@implementation RevenantSecTrust
- (instancetype)initWithTrust:(SecTrustRef)trust
{
    self = [super init];
    if (self)
        _trust = trust ? (SecTrustRef)CFRetain(trust) : NULL;
    return self;
}
- (SecTrustRef)revenantTrust { return _trust; }
- (void)dealloc { if (_trust) CFRelease(_trust); }
@end

sec_certificate_t sec_certificate_create(SecCertificateRef certificate)
{
    return (sec_certificate_t)[[RevenantSecCertificate alloc] initWithCertificate:certificate];
}

SecCertificateRef sec_certificate_copy_ref(sec_certificate_t certificate)
{
    if (![certificate isKindOfClass:RevenantSecCertificate.class])
        return NULL;
    SecCertificateRef held = [(RevenantSecCertificate *)certificate revenantCertificate];
    return held ? (SecCertificateRef)CFRetain(held) : NULL;
}

sec_trust_t sec_trust_create(SecTrustRef trust)
{
    return (sec_trust_t)[[RevenantSecTrust alloc] initWithTrust:trust];
}

SecTrustRef sec_trust_copy_ref(sec_trust_t trust)
{
    if (![trust isKindOfClass:RevenantSecTrust.class])
        return NULL;
    SecTrustRef held = [(RevenantSecTrust *)trust revenantTrust];
    return held ? (SecTrustRef)CFRetain(held) : NULL;
}
