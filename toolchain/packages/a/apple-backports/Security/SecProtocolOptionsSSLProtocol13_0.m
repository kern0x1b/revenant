#import <Foundation/Foundation.h>
#import <Security/SecProtocolTypes.h>
#import <Security/SecProtocolOptions.h>
#import <CoreFoundation/CoreFoundation.h>

@interface CharonSecProtocolSSLProtocol : NSObject <OS_sec_protocol_options>
{
    SSLProtocol _minVersion, _maxVersion;
    BOOL _hasMin, _hasMax;
}
- (void)charonSetMin:(SSLProtocol)version;
- (void)charonSetMax:(SSLProtocol)version;
- (SSLProtocol)charonMin;
- (SSLProtocol)charonMax;
- (BOOL)charonHasRange;
@end

@implementation CharonSecProtocolSSLProtocol
- (void)charonSetMin:(SSLProtocol)version { _minVersion = version; _hasMin = YES; }
- (void)charonSetMax:(SSLProtocol)version { _maxVersion = version; _hasMax = YES; }
- (SSLProtocol)charonMin { return _minVersion; }
- (SSLProtocol)charonMax { return _maxVersion; }
- (BOOL)charonHasRange { return _hasMin && _hasMax; }
@end

void sec_protocol_options_set_tls_min_version(sec_protocol_options_t options, SSLProtocol version)
{
    if (![options isKindOfClass:CharonSecProtocolSSLProtocol.class])
        return;
    [(CharonSecProtocolSSLProtocol *)options charonSetMin:version];
}

void sec_protocol_options_set_tls_max_version(sec_protocol_options_t options, SSLProtocol version)
{
    if (![options isKindOfClass:CharonSecProtocolSSLProtocol.class])
        return;
    [(CharonSecProtocolSSLProtocol *)options charonSetMax:version];
}
