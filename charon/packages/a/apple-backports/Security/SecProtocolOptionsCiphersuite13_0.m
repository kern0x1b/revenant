#import <Foundation/Foundation.h>
#import <Security/SecProtocolTypes.h>
#import <Security/SecProtocolOptions.h>
#import <Security/CipherSuite.h>
#import <CoreFoundation/CoreFoundation.h>
#include <stdlib.h>

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
            return;
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

void sec_protocol_options_add_tls_ciphersuite(sec_protocol_options_t options, SSLCipherSuite ciphersuite)
{
    if (![options isKindOfClass:CharonSecProtocolCiphersuite.class])
        return;
    [(CharonSecProtocolCiphersuite *)options charonAddCiphersuite:ciphersuite];
}

void sec_protocol_options_add_tls_ciphersuite_group(sec_protocol_options_t options,
                                                    SSLCiphersuiteGroup group)
{
    if (![options isKindOfClass:CharonSecProtocolCiphersuite.class])
        return;
    [(CharonSecProtocolCiphersuite *)options charonSetGroup:group];
}
