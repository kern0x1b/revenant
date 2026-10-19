#import <Foundation/Foundation.h>
#import <Security/SecProtocolTypes.h>
#import <Security/SecProtocolOptions.h>
#import <CoreFoundation/CoreFoundation.h>

@interface CharonSecProtocolFlags : NSObject <OS_sec_protocol_options>
{
    BOOL _ticketsEnabled, _isFallbackAttempt, _resumptionEnabled, _falseStartEnabled;
    BOOL _ocspEnabled, _sctEnabled, _renegotiationEnabled, _peerAuthenticationRequired;
}
- (void)charonSet:(int)flag to:(BOOL)value;
- (BOOL)charonGet:(int)flag;
@end

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
        default: break;
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
