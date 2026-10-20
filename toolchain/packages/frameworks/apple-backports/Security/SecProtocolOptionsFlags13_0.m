#import <Foundation/Foundation.h>
#import <Security/SecProtocolTypes.h>
#import <Security/SecProtocolOptions.h>
#import <CoreFoundation/CoreFoundation.h>

@interface RevenantSecProtocolFlags : NSObject <OS_sec_protocol_options>
{
    BOOL _ticketsEnabled, _isFallbackAttempt, _resumptionEnabled, _falseStartEnabled;
    BOOL _ocspEnabled, _sctEnabled, _renegotiationEnabled, _peerAuthenticationRequired;
}
- (void)revenantSet:(int)flag to:(BOOL)value;
- (BOOL)revenantGet:(int)flag;
@end

enum {
    RevenantFlagTickets = 0, RevenantFlagFallback, RevenantFlagResumption, RevenantFlagFalseStart,
    RevenantFlagOCSP, RevenantFlagSCT, RevenantFlagRenegotiation, RevenantFlagPeerAuthenticationRequired,
};

@implementation RevenantSecProtocolFlags
- (void)revenantSet:(int)flag to:(BOOL)value
{
    switch (flag) {
        case RevenantFlagTickets:      _ticketsEnabled = value; break;
        case RevenantFlagFallback:    _isFallbackAttempt = value; break;
        case RevenantFlagResumption:  _resumptionEnabled = value; break;
        case RevenantFlagFalseStart:  _falseStartEnabled = value; break;
        case RevenantFlagOCSP:        _ocspEnabled = value; break;
        case RevenantFlagSCT:         _sctEnabled = value; break;
        case RevenantFlagRenegotiation: _renegotiationEnabled = value; break;
        case RevenantFlagPeerAuthenticationRequired: _peerAuthenticationRequired = value; break;
        default: break;
    }
}
- (BOOL)revenantGet:(int)flag
{
    switch (flag) {
        case RevenantFlagTickets:      return _ticketsEnabled;
        case RevenantFlagFallback:    return _isFallbackAttempt;
        case RevenantFlagResumption:  return _resumptionEnabled;
        case RevenantFlagFalseStart:  return _falseStartEnabled;
        case RevenantFlagOCSP:        return _ocspEnabled;
        case RevenantFlagSCT:         return _sctEnabled;
        case RevenantFlagRenegotiation: return _renegotiationEnabled;
        case RevenantFlagPeerAuthenticationRequired: return _peerAuthenticationRequired;
        default: return NO;
    }
}
@end

void sec_protocol_options_set_tls_tickets_enabled(sec_protocol_options_t options, bool ticketsEnabled)
{ if ([options isKindOfClass:RevenantSecProtocolFlags.class]) [(RevenantSecProtocolFlags *)options revenantSet:RevenantFlagTickets to:ticketsEnabled]; }

void sec_protocol_options_set_tls_is_fallback_attempt(sec_protocol_options_t options, bool isFallback)
{ if ([options isKindOfClass:RevenantSecProtocolFlags.class]) [(RevenantSecProtocolFlags *)options revenantSet:RevenantFlagFallback to:isFallback]; }

void sec_protocol_options_set_tls_resumption_enabled(sec_protocol_options_t options, bool enabled)
{ if ([options isKindOfClass:RevenantSecProtocolFlags.class]) [(RevenantSecProtocolFlags *)options revenantSet:RevenantFlagResumption to:enabled]; }

void sec_protocol_options_set_tls_false_start_enabled(sec_protocol_options_t options, bool enabled)
{ if ([options isKindOfClass:RevenantSecProtocolFlags.class]) [(RevenantSecProtocolFlags *)options revenantSet:RevenantFlagFalseStart to:enabled]; }

void sec_protocol_options_set_tls_ocsp_enabled(sec_protocol_options_t options, bool ocspEnabled)
{ if ([options isKindOfClass:RevenantSecProtocolFlags.class]) [(RevenantSecProtocolFlags *)options revenantSet:RevenantFlagOCSP to:ocspEnabled]; }

void sec_protocol_options_set_tls_sct_enabled(sec_protocol_options_t options, bool sctEnabled)
{ if ([options isKindOfClass:RevenantSecProtocolFlags.class]) [(RevenantSecProtocolFlags *)options revenantSet:RevenantFlagSCT to:sctEnabled]; }

void sec_protocol_options_set_tls_renegotiation_enabled(sec_protocol_options_t options, bool enabled)
{ if ([options isKindOfClass:RevenantSecProtocolFlags.class]) [(RevenantSecProtocolFlags *)options revenantSet:RevenantFlagRenegotiation to:enabled]; }

void sec_protocol_options_set_peer_authentication_required(sec_protocol_options_t options, bool required)
{ if ([options isKindOfClass:RevenantSecProtocolFlags.class]) [(RevenantSecProtocolFlags *)options revenantSet:RevenantFlagPeerAuthenticationRequired to:required]; }
