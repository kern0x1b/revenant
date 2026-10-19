#import <Foundation/Foundation.h>
#import <Security/SecProtocolTypes.h>
#import <Security/SecProtocolOptions.h>
#import <CoreFoundation/CoreFoundation.h>

// The two SSLProtocol setters, from Security/SecProtocolOptions.h:
//
//   183  void sec_protocol_options_set_tls_min_version(sec_protocol_options_t options, SSLProtocol version)
//   240  void sec_protocol_options_set_tls_max_version(sec_protocol_options_t options, SSLProtocol version)
//
// THE VALUE IS HELD IN THE CALLER'S OWN ENUM AND IS NOT TRANSLATED, and that is the decision in this
// file. The two setters here take SSLProtocol, and the rest of the family takes tls_protocol_version_t,
// and THE SAME CONCEPT HAS TWO NUMBERS:
//
//     kSSLProtocol3  = 2          kTLSProtocol1  = 4        kTLSProtocol11 = 7
//     kTLSProtocol12 = 8          kDTLSProtocol1 = 9
//     tls_protocol_version_TLSv10 = 0x0301   TLSv12 = 0x0303   DTLSv10 = 0xfeff
//
// so TLS 1.0 is 4 in one and 0x0301 in the other. Translating between them would be the port asserting
// a correspondence NO HEADER MAKES - the two enums are separate CF_ENUMs with separate values, and
// nothing in either says "these are the same thing". So the port holds what it was given, and the row
// says the held value is in the caller's enum and no handshake reads it.
//
// BOTH ENUMS ARE DEPRECATED IN THE SAME DIRECTION, which the header states and which agrees with the
// decision: kSSLProtocol3 and kTLSProtocol1 are both CF_ENUM_DEPRECATED(... 5_0, 13_0), and the whole
// SSLProtocol family is replaced by tls_protocol_version_t. A port that translated would be preferring
// the enum the header tells callers to stop using.

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

//   183
void sec_protocol_options_set_tls_min_version(sec_protocol_options_t options, SSLProtocol version)
{
    if (![options isKindOfClass:CharonSecProtocolSSLProtocol.class])
        return;
    [(CharonSecProtocolSSLProtocol *)options charonSetMin:version];
}

//   240
void sec_protocol_options_set_tls_max_version(sec_protocol_options_t options, SSLProtocol version)
{
    if (![options isKindOfClass:CharonSecProtocolSSLProtocol.class])
        return;
    [(CharonSecProtocolSSLProtocol *)options charonSetMax:version];
}
