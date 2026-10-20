#import <Foundation/Foundation.h>
#import <Security/SecProtocolTypes.h>
#import <Security/SecProtocolOptions.h>
#import <Security/CipherSuite.h>
#import <CoreFoundation/CoreFoundation.h>
#include <stdlib.h>

@interface RevenantSecProtocolCiphersuite : NSObject <OS_sec_protocol_options>
{
    SSLCipherSuite *_ciphersuites;
    size_t _count, _capacity;
    SSLCiphersuiteGroup _group;
    BOOL _hasGroup;
}
- (void)revenantAddCiphersuite:(SSLCipherSuite)ciphersuite;
- (SSLCipherSuite)revenantCiphersuiteAt:(size_t)index;
- (size_t)revenantCiphersuiteCount;
- (void)revenantSetGroup:(SSLCiphersuiteGroup)group;
- (SSLCiphersuiteGroup)revenantGroup;
@end

@implementation RevenantSecProtocolCiphersuite
- (void)revenantAddCiphersuite:(SSLCipherSuite)ciphersuite
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
- (SSLCipherSuite)revenantCiphersuiteAt:(size_t)index
{
    return index < _count ? _ciphersuites[index] : 0;
}
- (size_t)revenantCiphersuiteCount { return _count; }
- (void)revenantSetGroup:(SSLCiphersuiteGroup)group { _group = group; _hasGroup = YES; }
- (SSLCiphersuiteGroup)revenantGroup { return _group; }
- (void)dealloc { free(_ciphersuites); }
@end

void sec_protocol_options_add_tls_ciphersuite(sec_protocol_options_t options, SSLCipherSuite ciphersuite)
{
    if (![options isKindOfClass:RevenantSecProtocolCiphersuite.class])
        return;
    [(RevenantSecProtocolCiphersuite *)options revenantAddCiphersuite:ciphersuite];
}

void sec_protocol_options_add_tls_ciphersuite_group(sec_protocol_options_t options,
                                                    SSLCiphersuiteGroup group)
{
    if (![options isKindOfClass:RevenantSecProtocolCiphersuite.class])
        return;
    [(RevenantSecProtocolCiphersuite *)options revenantSetGroup:group];
}
