#import <Foundation/Foundation.h>
#import <Security/SecProtocolTypes.h>
#import <Security/SecProtocolOptions.h>
#import <CoreFoundation/CoreFoundation.h>
#import <dispatch/dispatch.h>
#include <stdlib.h>

// The sec_protocol_options family, from Security/SecProtocolOptions.h. This file carries the five
// functions whose answer is a FACT rather than a setting: the four defaults and the comparator.
//
// THE OBJECT IS THE PORT'S OWN, as clang -E emits the type:
//
//     @protocol OS_sec_protocol_options <NSObject> @end
//     typedef NSObject<OS_sec_protocol_options> * __attribute__((objc_independent_class))
//         sec_protocol_options_t;
//
// and its state is the SETTINGS a caller put on it. Nothing in 6.1.3 ever reads that state: this API's
// stack does not exist on the release, which negotiates through SecureTransport. So every setter here is
// inert - callable, holding, with the effect stated as "the handshake ignores it" - while a GETTER that
// reads back what was put is implemented, because that is the one thing the port can answer truthfully.

@interface CharonSecProtocolOptions : NSObject <OS_sec_protocol_options>
{
    tls_protocol_version_t _minTLS, _maxTLS, _minDTLS, _maxDTLS;
    BOOL _hasMinTLS, _hasMaxTLS;
}
- (void)charonSetMinTLS:(tls_protocol_version_t)version;
- (void)charonSetMaxTLS:(tls_protocol_version_t)version;
- (tls_protocol_version_t)charonMinTLS;
- (tls_protocol_version_t)charonMaxTLS;
- (BOOL)charonHasVersionSettings;
@end

@implementation CharonSecProtocolOptions
- (void)charonSetMinTLS:(tls_protocol_version_t)version { _minTLS = version; _hasMinTLS = YES; }
- (void)charonSetMaxTLS:(tls_protocol_version_t)version { _maxTLS = version; _hasMaxTLS = YES; }
- (tls_protocol_version_t)charonMinTLS { return _minTLS; }
- (tls_protocol_version_t)charonMaxTLS { return _maxTLS; }
- (BOOL)charonHasVersionSettings { return _hasMinTLS && _hasMaxTLS; }
@end

// THE FOUR DEFAULTS. The @return above each of them in the header reads "The default minimum TLS
// version", "The default maximum DTLS version" and so on - it NAMES THE QUANTITY and does not state a
// number, so the value is not the header's to read. A caller asking "what would I get by default" must
// hear something 6.1.3 can HONOUR, and the rule applied is: the release's own stack's range.
//
//     tls_protocol_version_TLSv10  = 0x0301     tls_protocol_version_TLSv12  = 0x0303
//     tls_protocol_version_TLSv13  = 0x0304     tls_protocol_version_DTLSv10 = 0xfeff
//     tls_protocol_version_DTLSv12 = 0xfefd
//
// min TLS 0x0301 (TLSv10), max TLS 0x0303 (TLSv12), min DTLS 0xfeff, max DTLS 0xfeff - the release's
// stack has kTLSProtocol12 as its top and DTLS 1.0 only.
//
// MEASURED, on 6.1.3 and on 6.0, and the two runs agree exactly. The probe asked the release: a fresh
// SSLCreateContext STREAM context and SSLGetProtocolVersionMin/Max for TLS, a DATAGRAM context for DTLS
// (a stream context answers about TLS only, so asking it about DTLS would have measured nothing), and
// SSLSetProtocolVersionMax(kTLSProtocol13) for the 1.3 question. The logs' sha256 are in
// facts/Security/SecProtocolDefaults.md.
//
// WHAT IT FOUND, and one of these contradicted the numbers this file used to carry:
//
//   min TLS   2  = kSSLProtocol3, i.e. the release's default floor is SSL 3.0. tls_protocol_version_t has
//                 NO SSLv3 member, so the row returns the enum's LOWEST member, TLSv10, and the
//                 difference is recorded as a crutch rather than papered over.
//   max TLS   8  = kTLSProtocol12, and 1.3 is REFUSED: SSLSetProtocolVersionMax(kTLSProtocol13) returns
//                 -9830 errSSLIllegalParam and the maximum still reads 8 afterwards.
//   min DTLS  9  = kDTLSProtocol1        max DTLS 9 = kDTLSProtocol1 - one version, at both ends.

//    211  tls_protocol_version_t sec_protocol_options_get_default_min_tls_protocol_version(void);
tls_protocol_version_t sec_protocol_options_get_default_min_tls_protocol_version(void)
{
    return tls_protocol_version_TLSv10;
}

//    223  tls_protocol_version_t sec_protocol_options_get_default_min_dtls_protocol_version(void);
tls_protocol_version_t sec_protocol_options_get_default_min_dtls_protocol_version(void)
{
    return tls_protocol_version_DTLSv10;
}

//    268  tls_protocol_version_t sec_protocol_options_get_default_max_tls_protocol_version(void);
tls_protocol_version_t sec_protocol_options_get_default_max_tls_protocol_version(void)
{
    return tls_protocol_version_TLSv12;   // measured; 1.3 is refused by the release (errSSLIllegalParam): 6.1.3 cannot negotiate it
}

//    280  tls_protocol_version_t sec_protocol_options_get_default_max_dtls_protocol_version(void);
tls_protocol_version_t sec_protocol_options_get_default_max_dtls_protocol_version(void)
{
    return tls_protocol_version_DTLSv10;  // measured at both ends: DTLS 1.0, and only 1.0: the release has DTLS 1.0 only
}

//    86   bool sec_protocol_options_are_equal(sec_protocol_options_t optionsA,
//                                              sec_protocol_options_t optionsB)
//
// THE COMPARATOR IS A REAL ANSWER rather than a setting nobody reads: it compares the settings the port
// HOLDS, and a caller that set two option objects to the same values must be told they are equal. It is
// implemented, and the equality is the port's own state and nothing else - a comparison against the
// release's stack would be a comparison of nothing, because there is no such stack.
bool sec_protocol_options_are_equal(sec_protocol_options_t optionsA, sec_protocol_options_t optionsB)
{
    if (optionsA == optionsB)
        return true;                        // the same object is trivially equal to itself
    if (!optionsA || !optionsB)
        return false;
    if (![optionsA conformsToProtocol:@protocol(OS_sec_protocol_options)]
        || ![optionsB conformsToProtocol:@protocol(OS_sec_protocol_options)])
        return false;
    CharonSecProtocolOptions *a = (CharonSecProtocolOptions *)optionsA;
    CharonSecProtocolOptions *b = (CharonSecProtocolOptions *)optionsB;
    if (a.charonHasVersionSettings != b.charonHasVersionSettings)
        return false;                       // one has a range and the other does not
    if (!a.charonHasVersionSettings)
        return true;                        // neither has been given a range: nothing to disagree about
    return a.charonMinTLS == b.charonMinTLS && a.charonMaxTLS == b.charonMaxTLS;
}

// --- the six setters, which HOLD what they are given ---
//
// Every one of these is INERT in the registry's sense: callable, the value held on the port's own
// object, and the effect stated as "the handshake ignores it". The reason is one sentence and it is the
// same for all six: 6.1.3 has no stack that takes a sec_protocol_options_t, so nothing ever reads what
// is held. A port that returned an error here would break a caller that sets options before it connects;
// a port that pretended the setting took effect would be a lie about a handshake it cannot perform.

@interface CharonSecProtocolOptionsHeld : CharonSecProtocolOptions
{
    // the ciphersuites are HELD, not aliased: a caller that appends twice gets both, and a caller that
    // frees its own array afterwards does not empty the object's copy
    tls_ciphersuite_t *_ciphersuites;
    size_t _ciphersuiteCount, _ciphersuiteCapacity;
    tls_ciphersuite_group_t *_groups;
    size_t _groupCount, _groupCapacity;
    __strong dispatch_data_t _pskIdentityHint;   // ARC-managed: libdispatch objects ARE ObjC here
    __strong sec_protocol_pre_shared_key_selection_t _pskSelection;   // ARC COPIES a block into a strong ivar
    __strong dispatch_queue_t _pskQueue;
}
- (void)charonAppendCiphersuite:(tls_ciphersuite_t)ciphersuite;
- (void)charonAppendCiphersuiteGroup:(tls_ciphersuite_group_t)group;
- (size_t)charonCiphersuiteCount;
- (size_t)charonGroupCount;
- (void)charonSetPSKIdentityHint:(dispatch_data_t)hint;
- (void)charonSetPSKSelection:(sec_protocol_pre_shared_key_selection_t)block
                             queue:(dispatch_queue_t)queue;
- (sec_protocol_pre_shared_key_selection_t)charonPSKSelection;
@end

@implementation CharonSecProtocolOptionsHeld
- (void)charonAppendCiphersuite:(tls_ciphersuite_t)ciphersuite
{
    if (_ciphersuiteCount == _ciphersuiteCapacity) {
        size_t room = _ciphersuiteCapacity ? _ciphersuiteCapacity * 2 : 4;
        tls_ciphersuite_t *bigger = realloc(_ciphersuites, room * sizeof(tls_ciphersuite_t));
        if (!bigger)
            return;   // a failed allocation holds nothing rather than a half-written list
        _ciphersuites = bigger;
        _ciphersuiteCapacity = room;
    }
    _ciphersuites[_ciphersuiteCount++] = ciphersuite;
}
- (void)charonAppendCiphersuiteGroup:(tls_ciphersuite_group_t)group
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
- (size_t)charonCiphersuiteCount { return _ciphersuiteCount; }
- (size_t)charonGroupCount { return _groupCount; }
- (void)charonSetPSKIdentityHint:(dispatch_data_t)hint
{
    // The hint is HELD across the setter's return, which is the whole point, and a __strong ivar does
    // that: dispatch_data_t is an ObjC object, so assigning it retains. dispatch_retain/dispatch_release
    // are ARC-FORBIDDEN on it - the same rule that forbids CFRelease and -release on an ObjC pointer.
    _pskIdentityHint = hint;
}
- (void)charonSetPSKSelection:(sec_protocol_pre_shared_key_selection_t)block
                        queue:(dispatch_queue_t)queue
{
    // A BLOCK IS COPIED, not held by pointer: a stack block would be dead when the setter returned and
    // the port would later call into a frame that no longer exists. Block_copy is the C form. The QUEUE
    // goes with it and is dispatch_retained, because a block held without the queue it was given for
    // would be held for a queue nobody owns any more.
    // A BLOCK IS COPIED, not held by pointer: a stack block would be dead when the setter returned and
    // the port would later call into a frame that no longer exists. Assigning a block to a __strong ivar
    // COPIES it, which is what makes the held block safe to call later - and the QUEUE goes with it and
    // is retained the same way, because a block held without the queue it was given for would be held
    // for a queue nobody owns any more.
    _pskSelection = block;
    _pskQueue = queue;
}
- (sec_protocol_pre_shared_key_selection_t)charonPSKSelection { return _pskSelection; }
- (void)dealloc
{
    free(_ciphersuites);
    free(_groups);
    // The C buffers are freed by hand because ARC does not manage them, and the strong ivars are
    // released by ARC itself - which is why there is no dispatch_release, no Block_release and no
    // [super dealloc] here, all three of which are forbidden or redundant under ARC.
}
@end

//   118  void sec_protocol_options_append_tls_ciphersuite(sec_protocol_options_t, tls_ciphersuite_t)
void sec_protocol_options_append_tls_ciphersuite(sec_protocol_options_t options,
                                                tls_ciphersuite_t ciphersuite)
{
    if (![options isKindOfClass:CharonSecProtocolOptionsHeld.class])
        return;
    [(CharonSecProtocolOptionsHeld *)options charonAppendCiphersuite:ciphersuite];
}

//   150  void sec_protocol_options_append_tls_ciphersuite_group(sec_protocol_options_t,
//                                                               tls_ciphersuite_group_t)
void sec_protocol_options_append_tls_ciphersuite_group(sec_protocol_options_t options,
                                                      tls_ciphersuite_group_t group)
{
    if (![options isKindOfClass:CharonSecProtocolOptionsHeld.class])
        return;
    [(CharonSecProtocolOptionsHeld *)options charonAppendCiphersuiteGroup:group];
}

//   199  void sec_protocol_options_set_min_tls_protocol_version(sec_protocol_options_t,
//                                                              tls_protocol_version_t)
void sec_protocol_options_set_min_tls_protocol_version(sec_protocol_options_t options,
                                                       tls_protocol_version_t version)
{
    if (![options isKindOfClass:CharonSecProtocolOptions.class])
        return;
    [(CharonSecProtocolOptions *)options charonSetMinTLS:version];
}

//   256  void sec_protocol_options_set_max_tls_protocol_version(sec_protocol_options_t,
//                                                              tls_protocol_version_t)
void sec_protocol_options_set_max_tls_protocol_version(sec_protocol_options_t options,
                                                       tls_protocol_version_t version)
{
    if (![options isKindOfClass:CharonSecProtocolOptions.class])
        return;
    [(CharonSecProtocolOptions *)options charonSetMaxTLS:version];
}

//   390  void sec_protocol_options_set_tls_pre_shared_key_identity_hint(sec_protocol_options_t,
//                                                                       dispatch_data_t)
void sec_protocol_options_set_tls_pre_shared_key_identity_hint(sec_protocol_options_t options,
                                                               dispatch_data_t hint)
{
    if (![options isKindOfClass:CharonSecProtocolOptionsHeld.class])
        return;
    [(CharonSecProtocolOptionsHeld *)options charonSetPSKIdentityHint:hint];
}

//   439  void sec_protocol_options_set_pre_shared_key_selection_block(sec_protocol_options_t,
//                                                                     sec_protocol_pre_shared_key_selection_block)
void sec_protocol_options_set_pre_shared_key_selection_block(
    sec_protocol_options_t options, sec_protocol_pre_shared_key_selection_t block,
    dispatch_queue_t queue)
{
    if (![options isKindOfClass:CharonSecProtocolOptionsHeld.class])
        return;
    [(CharonSecProtocolOptionsHeld *)options charonSetPSKSelection:block queue:queue];
}
