#import <Foundation/Foundation.h>
#import <Security/SecProtocolTypes.h>
#import <Security/SecProtocolOptions.h>
#import <Security/CipherSuite.h>
#import <CoreFoundation/CoreFoundation.h>
#include <stdlib.h>

// The two SSLCipherSuite setters, from Security/SecProtocolOptions.h:
//
//   134  void sec_protocol_options_add_tls_ciphersuite(sec_protocol_options_t, SSLCipherSuite)
//   166  void sec_protocol_options_add_tls_ciphersuite_group(sec_protocol_options_t, SSLCiphersuiteGroup)
//
// NEITHER VALUE IS TRANSLATED, for the same reason as the SSLProtocol pair beside it, and here the two
// numberings are further apart still: SSLCipherSuite is a uint16 of wire values
//
//     270  typedef CF_ENUM(int, SSLCiphersuiteGroup) { kSSLCiphersuiteGroupDefault,
//                                                       kSSLCiphersuiteGroupCompatibility };
//      48  { SSL_NULL_WITH_NULL_NULL = 0x0000, SSL_RSA_WITH_NULL_MD5 = 0x0001, ...
//
// and tls_ciphersuite_t is a CF_ENUM(uint16_t) whose members are the IANA names of the same suites. So
// the port holds the caller's number as given, and the row says the held value is a wire value in the
// caller's own enum and that no handshake reads it. Translating would be the port inventing a
// correspondence between two enums that no header relates.
//
// THE GROUP ENUM IS A THIRD NUMBERING and is not a subset of anything: it has two members and they are
// ORDINAL, not wire values - kSSLCiphersuiteGroupDefault is 0 and kSSLCiphersuiteGroupCompatibility is
// 1, which is a position in a list, not a ciphersuite. So it is held as given for a different reason
// again: there is nothing it could be translated INTO.

@interface CharonSecProtocolCiphersuite : NSObject <OS_sec_protocol_options>
{
    SSLCipherSuite *_ciphersuites;
    size_t _count, _capacity;
    SSLCiphersuiteGroup _group;
    BOOL _hasGroup;
}
- (void)charonAddCiphersuite:(SSLCipherSuite)ciphersuite;
- (SSLCipherSuite)charonCiphersuiteAt:(size_t)index;
- (size_t)charonCiphersuiteCount;
- (void)charonSetGroup:(SSLCiphersuiteGroup)group;
- (SSLCiphersuiteGroup)charonGroup;
@end

@implementation CharonSecProtocolCiphersuite
- (void)charonAddCiphersuite:(SSLCipherSuite)ciphersuite
{
    if (_count == _capacity) {
        size_t room = _capacity ? _capacity * 2 : 4;
        SSLCipherSuite *bigger = realloc(_ciphersuites, room * sizeof(SSLCipherSuite));
        if (!bigger)
            return;   // a failed allocation holds nothing rather than a half-written list
        _ciphersuites = bigger;
        _capacity = room;
    }
    _ciphersuites[_count++] = ciphersuite;
}
- (SSLCipherSuite)charonCiphersuiteAt:(size_t)index
{
    return index < _count ? _ciphersuites[index] : 0;
}
- (size_t)charonCiphersuiteCount { return _count; }
- (void)charonSetGroup:(SSLCiphersuiteGroup)group { _group = group; _hasGroup = YES; }
- (SSLCiphersuiteGroup)charonGroup { return _group; }
- (void)dealloc { free(_ciphersuites); }
@end

//   134
void sec_protocol_options_add_tls_ciphersuite(sec_protocol_options_t options, SSLCipherSuite ciphersuite)
{
    if (![options isKindOfClass:CharonSecProtocolCiphersuite.class])
        return;
    [(CharonSecProtocolCiphersuite *)options charonAddCiphersuite:ciphersuite];
}

//   166
void sec_protocol_options_add_tls_ciphersuite_group(sec_protocol_options_t options,
                                                    SSLCiphersuiteGroup group)
{
    if (![options isKindOfClass:CharonSecProtocolCiphersuite.class])
        return;
    [(CharonSecProtocolCiphersuite *)options charonSetGroup:group];
}
