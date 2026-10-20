#import <Foundation/Foundation.h>
#import <Security/SecProtocolTypes.h>
#import <Security/SecProtocolOptions.h>
#import <CoreFoundation/CoreFoundation.h>
#import <dispatch/dispatch.h>
#include <stdlib.h>

@interface RevenantSecProtocolOptions : NSObject <OS_sec_protocol_options>
{
    tls_protocol_version_t _minTLS, _maxTLS, _minDTLS, _maxDTLS;
    BOOL _hasMinTLS, _hasMaxTLS;
}
- (void)revenantSetMinTLS:(tls_protocol_version_t)version;
- (void)revenantSetMaxTLS:(tls_protocol_version_t)version;
- (tls_protocol_version_t)revenantMinTLS;
- (tls_protocol_version_t)revenantMaxTLS;
- (BOOL)revenantHasVersionSettings;
@end

@implementation RevenantSecProtocolOptions
- (void)revenantSetMinTLS:(tls_protocol_version_t)version { _minTLS = version; _hasMinTLS = YES; }
- (void)revenantSetMaxTLS:(tls_protocol_version_t)version { _maxTLS = version; _hasMaxTLS = YES; }
- (tls_protocol_version_t)revenantMinTLS { return _minTLS; }
- (tls_protocol_version_t)revenantMaxTLS { return _maxTLS; }
- (BOOL)revenantHasVersionSettings { return _hasMinTLS && _hasMaxTLS; }
@end

tls_protocol_version_t sec_protocol_options_get_default_min_tls_protocol_version(void)
{
    return tls_protocol_version_TLSv10;
}

tls_protocol_version_t sec_protocol_options_get_default_min_dtls_protocol_version(void)
{
    return tls_protocol_version_DTLSv10;
}

tls_protocol_version_t sec_protocol_options_get_default_max_tls_protocol_version(void)
{
    return tls_protocol_version_TLSv12;
}

tls_protocol_version_t sec_protocol_options_get_default_max_dtls_protocol_version(void)
{
    return tls_protocol_version_DTLSv10;
}

bool sec_protocol_options_are_equal(sec_protocol_options_t optionsA, sec_protocol_options_t optionsB)
{
    if (optionsA == optionsB)
        return true;
    if (!optionsA || !optionsB)
        return false;
    if (![optionsA conformsToProtocol:@protocol(OS_sec_protocol_options)]
        || ![optionsB conformsToProtocol:@protocol(OS_sec_protocol_options)])
        return false;
    RevenantSecProtocolOptions *a = (RevenantSecProtocolOptions *)optionsA;
    RevenantSecProtocolOptions *b = (RevenantSecProtocolOptions *)optionsB;
    if (a.revenantHasVersionSettings != b.revenantHasVersionSettings)
        return false;
    if (!a.revenantHasVersionSettings)
        return true;
    return a.revenantMinTLS == b.revenantMinTLS && a.revenantMaxTLS == b.revenantMaxTLS;
}

@interface RevenantSecProtocolOptionsHeld : RevenantSecProtocolOptions
{
    tls_ciphersuite_t *_ciphersuites;
    size_t _ciphersuiteCount, _ciphersuiteCapacity;
    tls_ciphersuite_group_t *_groups;
    size_t _groupCount, _groupCapacity;
    __strong dispatch_data_t _pskIdentityHint;
    __strong sec_protocol_pre_shared_key_selection_t _pskSelection;
    __strong dispatch_queue_t _pskQueue;
}
- (void)revenantAppendCiphersuite:(tls_ciphersuite_t)ciphersuite;
- (void)revenantAppendCiphersuiteGroup:(tls_ciphersuite_group_t)group;
- (size_t)revenantCiphersuiteCount;
- (size_t)revenantGroupCount;
- (void)revenantSetPSKIdentityHint:(dispatch_data_t)hint;
- (void)revenantSetPSKSelection:(sec_protocol_pre_shared_key_selection_t)block
                             queue:(dispatch_queue_t)queue;
- (sec_protocol_pre_shared_key_selection_t)revenantPSKSelection;
@end

@implementation RevenantSecProtocolOptionsHeld
- (void)revenantAppendCiphersuite:(tls_ciphersuite_t)ciphersuite
{
    if (_ciphersuiteCount == _ciphersuiteCapacity) {
        size_t room = _ciphersuiteCapacity ? _ciphersuiteCapacity * 2 : 4;
        tls_ciphersuite_t *bigger = realloc(_ciphersuites, room * sizeof(tls_ciphersuite_t));
        if (!bigger)
            return;
        _ciphersuites = bigger;
        _ciphersuiteCapacity = room;
    }
    _ciphersuites[_ciphersuiteCount++] = ciphersuite;
}
- (void)revenantAppendCiphersuiteGroup:(tls_ciphersuite_group_t)group
{
    if (_groupCount == _groupCapacity) {
        size_t room = _groupCapacity ? _groupCapacity * 2 : 4;
        tls_ciphersuite_group_t *bigger = realloc(_groups, room * sizeof(tls_ciphersuite_group_t));
        if (!bigger)
            return;
        _groups = bigger;
        _groupCapacity = room;
    }
    _groups[_groupCount++] = group;
}
- (size_t)revenantCiphersuiteCount { return _ciphersuiteCount; }
- (size_t)revenantGroupCount { return _groupCount; }
- (void)revenantSetPSKIdentityHint:(dispatch_data_t)hint
{
    _pskIdentityHint = hint;
}
- (void)revenantSetPSKSelection:(sec_protocol_pre_shared_key_selection_t)block
                        queue:(dispatch_queue_t)queue
{
    _pskSelection = block;
    _pskQueue = queue;
}
- (sec_protocol_pre_shared_key_selection_t)revenantPSKSelection { return _pskSelection; }
- (void)dealloc
{
    free(_ciphersuites);
    free(_groups);
}
@end

void sec_protocol_options_append_tls_ciphersuite(sec_protocol_options_t options,
                                                tls_ciphersuite_t ciphersuite)
{
    if (![options isKindOfClass:RevenantSecProtocolOptionsHeld.class])
        return;
    [(RevenantSecProtocolOptionsHeld *)options revenantAppendCiphersuite:ciphersuite];
}

void sec_protocol_options_append_tls_ciphersuite_group(sec_protocol_options_t options,
                                                      tls_ciphersuite_group_t group)
{
    if (![options isKindOfClass:RevenantSecProtocolOptionsHeld.class])
        return;
    [(RevenantSecProtocolOptionsHeld *)options revenantAppendCiphersuiteGroup:group];
}

void sec_protocol_options_set_min_tls_protocol_version(sec_protocol_options_t options,
                                                       tls_protocol_version_t version)
{
    if (![options isKindOfClass:RevenantSecProtocolOptions.class])
        return;
    [(RevenantSecProtocolOptions *)options revenantSetMinTLS:version];
}

void sec_protocol_options_set_max_tls_protocol_version(sec_protocol_options_t options,
                                                       tls_protocol_version_t version)
{
    if (![options isKindOfClass:RevenantSecProtocolOptions.class])
        return;
    [(RevenantSecProtocolOptions *)options revenantSetMaxTLS:version];
}

void sec_protocol_options_set_tls_pre_shared_key_identity_hint(sec_protocol_options_t options,
                                                               dispatch_data_t hint)
{
    if (![options isKindOfClass:RevenantSecProtocolOptionsHeld.class])
        return;
    [(RevenantSecProtocolOptionsHeld *)options revenantSetPSKIdentityHint:hint];
}

void sec_protocol_options_set_pre_shared_key_selection_block(
    sec_protocol_options_t options, sec_protocol_pre_shared_key_selection_t block,
    dispatch_queue_t queue)
{
    if (![options isKindOfClass:RevenantSecProtocolOptionsHeld.class])
        return;
    [(RevenantSecProtocolOptionsHeld *)options revenantSetPSKSelection:block queue:queue];
}
