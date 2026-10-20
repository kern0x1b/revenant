#import <Foundation/Foundation.h>
#import <Security/SecProtocolTypes.h>
#import <Security/SecProtocolOptions.h>
#import <CoreFoundation/CoreFoundation.h>

@interface RevenantSecProtocolSSLProtocol : NSObject <OS_sec_protocol_options>
{
    SSLProtocol _minVersion, _maxVersion;
    BOOL _hasMin, _hasMax;
}
- (void)revenantSetMin:(SSLProtocol)version;
- (void)revenantSetMax:(SSLProtocol)version;
- (SSLProtocol)revenantMin;
- (SSLProtocol)revenantMax;
- (BOOL)revenantHasRange;
@end

@implementation RevenantSecProtocolSSLProtocol
- (void)revenantSetMin:(SSLProtocol)version { _minVersion = version; _hasMin = YES; }
- (void)revenantSetMax:(SSLProtocol)version { _maxVersion = version; _hasMax = YES; }
- (SSLProtocol)revenantMin { return _minVersion; }
- (SSLProtocol)revenantMax { return _maxVersion; }
- (BOOL)revenantHasRange { return _hasMin && _hasMax; }
@end

void sec_protocol_options_set_tls_min_version(sec_protocol_options_t options, SSLProtocol version)
{
    if (![options isKindOfClass:RevenantSecProtocolSSLProtocol.class])
        return;
    [(RevenantSecProtocolSSLProtocol *)options revenantSetMin:version];
}

void sec_protocol_options_set_tls_max_version(sec_protocol_options_t options, SSLProtocol version)
{
    if (![options isKindOfClass:RevenantSecProtocolSSLProtocol.class])
        return;
    [(RevenantSecProtocolSSLProtocol *)options revenantSetMax:version];
}
