#import <Foundation/Foundation.h>
#import <Security/SecProtocolTypes.h>
#import <Security/SecProtocolOptions.h>
#import <CoreFoundation/CoreFoundation.h>

// The eight boolean setters, from Security/SecProtocolOptions.h. One shape, eight rows, and each is
// INERT in the registry's sense: callable, the flag held, effect stated.
//
//   457  set_tls_tickets_enabled(bool)          495  set_tls_resumption_enabled(bool)
//   479  set_tls_is_fallback_attempt(bool)      511  set_tls_false_start_enabled(bool)
//   527  set_tls_ocsp_enabled(bool)             543  set_tls_sct_enabled(bool)
//   559  set_tls_renegotiation_enabled(bool)    575  set_peer_authentication_required(bool)
//
// The reason is one sentence, the same as the rest of this family: 6.1.3 HAS NO STACK THAT TAKES A
// sec_protocol_options_t, so nothing ever reads a flag the port holds. Two of the eight are worth
// naming in the effect, because a caller who sets them and is told nothing is worse off than one who is:
//
//   OCSP and SCT - 6.1.3 stapled neither, so a peer whose certificate is revoked, or whose SCTs are
//     absent, is not detected as such. The flag is held; the check is NOT performed.
//   resumption and tickets - the release's own TLS resumes through SecureTransport, not through
//     anything a sec_protocol_options_t can reach, so a caller asking for resumption does not get it.
//
// A BOOL IS NOT A SINGLE BIT HERE: each gets its OWN ivar, because a shared "flags" word would make
// set_tls_ocsp_enabled and set_tls_sct_enabled the same setting wearing two names, and reading one back
// would report the other.

@interface CharonSecProtocolFlags : NSObject <OS_sec_protocol_options>
{
    BOOL _ticketsEnabled, _isFallbackAttempt, _resumptionEnabled, _falseStartEnabled;
    BOOL _ocspEnabled, _sctEnabled, _renegotiationEnabled, _peerAuthenticationRequired;
}
- (void)charonSet:(int)flag to:(BOOL)value;
- (BOOL)charonGet:(int)flag;
@end

// the flag numbers, so the storage and the eight functions below cannot drift apart
enum {
    CharonFlagTickets = 0, CharonFlagFallback, CharonFlagResumption, CharonFlagFalseStart,
    CharonFlagOCSP, CharonFlagSCT, CharonFlagRenegotiation, CharonFlagPeerAuthenticationRequired,
};

@implementation CharonSecProtocolFlags
- (void)charonSet:(int)flag to:(BOOL)value
{
    switch (flag) {
        case CharonFlagTickets:      _ticketsEnabled = value; break;
        case CharonFlagFallback:    _isFallbackAttempt = value; break;
        case CharonFlagResumption:  _resumptionEnabled = value; break;
        case CharonFlagFalseStart:  _falseStartEnabled = value; break;
        case CharonFlagOCSP:        _ocspEnabled = value; break;
        case CharonFlagSCT:         _sctEnabled = value; break;
        case CharonFlagRenegotiation: _renegotiationEnabled = value; break;
        case CharonFlagPeerAuthenticationRequired: _peerAuthenticationRequired = value; break;
        default: break;                            // an unknown flag holds nothing rather than a stray bit
    }
}
- (BOOL)charonGet:(int)flag
{
    switch (flag) {
        case CharonFlagTickets:      return _ticketsEnabled;
        case CharonFlagFallback:    return _isFallbackAttempt;
        case CharonFlagResumption:  return _resumptionEnabled;
        case CharonFlagFalseStart:  return _falseStartEnabled;
        case CharonFlagOCSP:        return _ocspEnabled;
        case CharonFlagSCT:         return _sctEnabled;
        case CharonFlagRenegotiation: return _renegotiationEnabled;
        case CharonFlagPeerAuthenticationRequired: return _peerAuthenticationRequired;
        default: return NO;
    }
}
@end

// Each of the eight is the header's own signature, and each holds its OWN flag. NONE OF THEM ERRORS: a
// port that returned an error would break a caller that sets options before it connects, and a port that
// pretended the setting took effect would be a lie about a handshake it cannot perform.

void sec_protocol_options_set_tls_tickets_enabled(sec_protocol_options_t options, bool ticketsEnabled)
{ if ([options isKindOfClass:CharonSecProtocolFlags.class]) [(CharonSecProtocolFlags *)options charonSet:CharonFlagTickets to:ticketsEnabled]; }

void sec_protocol_options_set_tls_is_fallback_attempt(sec_protocol_options_t options, bool isFallback)
{ if ([options isKindOfClass:CharonSecProtocolFlags.class]) [(CharonSecProtocolFlags *)options charonSet:CharonFlagFallback to:isFallback]; }

void sec_protocol_options_set_tls_resumption_enabled(sec_protocol_options_t options, bool enabled)
{ if ([options isKindOfClass:CharonSecProtocolFlags.class]) [(CharonSecProtocolFlags *)options charonSet:CharonFlagResumption to:enabled]; }

void sec_protocol_options_set_tls_false_start_enabled(sec_protocol_options_t options, bool enabled)
{ if ([options isKindOfClass:CharonSecProtocolFlags.class]) [(CharonSecProtocolFlags *)options charonSet:CharonFlagFalseStart to:enabled]; }

void sec_protocol_options_set_tls_ocsp_enabled(sec_protocol_options_t options, bool ocspEnabled)
{ if ([options isKindOfClass:CharonSecProtocolFlags.class]) [(CharonSecProtocolFlags *)options charonSet:CharonFlagOCSP to:ocspEnabled]; }

void sec_protocol_options_set_tls_sct_enabled(sec_protocol_options_t options, bool sctEnabled)
{ if ([options isKindOfClass:CharonSecProtocolFlags.class]) [(CharonSecProtocolFlags *)options charonSet:CharonFlagSCT to:sctEnabled]; }

void sec_protocol_options_set_tls_renegotiation_enabled(sec_protocol_options_t options, bool enabled)
{ if ([options isKindOfClass:CharonSecProtocolFlags.class]) [(CharonSecProtocolFlags *)options charonSet:CharonFlagRenegotiation to:enabled]; }

void sec_protocol_options_set_peer_authentication_required(sec_protocol_options_t options, bool required)
{ if ([options isKindOfClass:CharonSecProtocolFlags.class]) [(CharonSecProtocolFlags *)options charonSet:CharonFlagPeerAuthenticationRequired to:required]; }
