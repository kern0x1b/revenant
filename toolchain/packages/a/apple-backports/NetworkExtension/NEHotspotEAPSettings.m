#import "RevenantNEHotspot.h"

@implementation NEHotspotEAPSettings {
    NSArray<NSNumber *> *_supportedEAPTypes;
    NSString *_username;
    NSString *_outerIdentity;
    NEHotspotConfigurationTTLSInnerAuthenticationType _ttlsInnerAuthenticationType;
    NSString *_password;
    NSArray<NSString *> *_trustedServerNames;
    BOOL _tlsClientCertificateRequired;
    NEHotspotConfigurationEAPTLSVersion _preferredTLSVersion;
}

@synthesize supportedEAPTypes = _supportedEAPTypes;
@synthesize username = _username;
@synthesize outerIdentity = _outerIdentity;
@synthesize ttlsInnerAuthenticationType = _ttlsInnerAuthenticationType;
@synthesize password = _password;
@synthesize trustedServerNames = _trustedServerNames;
@synthesize tlsClientCertificateRequired = _tlsClientCertificateRequired;
@synthesize preferredTLSVersion = _preferredTLSVersion;

- (BOOL)setIdentity:(SecIdentityRef)identity
{
    return NO;
}

- (BOOL)setTrustedServerCertificates:(NSArray *)certificates
{
    return NO;
}

- (id)copyWithZone:(NSZone *)zone
{
    NEHotspotEAPSettings *copy = [[NEHotspotEAPSettings allocWithZone:zone] init];
    copy.supportedEAPTypes = _supportedEAPTypes;
    copy.username = _username;
    copy.outerIdentity = _outerIdentity;
    copy.ttlsInnerAuthenticationType = _ttlsInnerAuthenticationType;
    copy.password = _password;
    copy.trustedServerNames = _trustedServerNames;
    copy.tlsClientCertificateRequired = _tlsClientCertificateRequired;
    copy.preferredTLSVersion = _preferredTLSVersion;
    return copy;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self) {
        _supportedEAPTypes = [[coder decodeObjectOfClasses:[NSSet setWithObjects:[NSArray class], [NSNumber class], nil]
                                                    forKey:@"supportedEAPTypes"] copy];
        _username = [[coder decodeObjectOfClass:[NSString class] forKey:@"username"] copy];
        _outerIdentity = [[coder decodeObjectOfClass:[NSString class] forKey:@"outerIdentity"] copy];
        _ttlsInnerAuthenticationType = [coder decodeIntegerForKey:@"ttlsInnerAuthenticationType"];
        _password = [[coder decodeObjectOfClass:[NSString class] forKey:@"password"] copy];
        _trustedServerNames = [[coder decodeObjectOfClasses:[NSSet setWithObjects:[NSArray class], [NSString class], nil]
                                                     forKey:@"trustedServerNames"] copy];
        _tlsClientCertificateRequired = [coder decodeBoolForKey:@"tlsClientCertificateRequired"];
        _preferredTLSVersion = [coder decodeIntegerForKey:@"preferredTLSVersion"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_supportedEAPTypes forKey:@"supportedEAPTypes"];
    [coder encodeObject:_username forKey:@"username"];
    [coder encodeObject:_outerIdentity forKey:@"outerIdentity"];
    [coder encodeInteger:_ttlsInnerAuthenticationType forKey:@"ttlsInnerAuthenticationType"];
    [coder encodeObject:_password forKey:@"password"];
    [coder encodeObject:_trustedServerNames forKey:@"trustedServerNames"];
    [coder encodeBool:_tlsClientCertificateRequired forKey:@"tlsClientCertificateRequired"];
    [coder encodeInteger:_preferredTLSVersion forKey:@"preferredTLSVersion"];
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

@end
