#import <Foundation/Foundation.h>
#import <Security/SecProtocolTypes.h>
#import <Security/SecProtocolOptions.h>
#import <CoreFoundation/CoreFoundation.h>
#include <stdlib.h>
#include <string.h>

@interface CharonSecProtocolStrings : NSObject <OS_sec_protocol_options>
{
    char *_serverName;
    char *_applicationProtocols[8];
    size_t _applicationProtocolCount;
}
- (void)charonSetServerName:(const char *)name;
- (const char *)charonServerName;
- (void)charonAddApplicationProtocol:(const char *)protocol;
- (const char *)charonApplicationProtocolAt:(size_t)index;
- (size_t)charonApplicationProtocolCount;
@end

@implementation CharonSecProtocolStrings
- (void)charonSetServerName:(const char *)name
{
    if (_serverName) {
        free(_serverName);
        _serverName = NULL;
    }
    if (name)
        _serverName = strdup(name);
}
- (const char *)charonServerName { return _serverName; }
- (void)charonAddApplicationProtocol:(const char *)protocol
{
    if (!protocol || _applicationProtocolCount >= 8)
        return;
    char *copy = strdup(protocol);
    if (!copy)
        return;
    _applicationProtocols[_applicationProtocolCount++] = copy;
}
- (const char *)charonApplicationProtocolAt:(size_t)index
{
    return index < _applicationProtocolCount ? _applicationProtocols[index] : NULL;
}
- (size_t)charonApplicationProtocolCount { return _applicationProtocolCount; }
- (void)dealloc
{
    if (_serverName)
        free(_serverName);
    for (size_t i = 0; i < _applicationProtocolCount; i++)
        free(_applicationProtocols[i]);
}
@end

void sec_protocol_options_add_tls_application_protocol(sec_protocol_options_t options,
                                                       const char *application_protocol)
{
    if (![options isKindOfClass:CharonSecProtocolStrings.class])
        return;
    [(CharonSecProtocolStrings *)options charonAddApplicationProtocol:application_protocol];
}

void sec_protocol_options_set_tls_server_name(sec_protocol_options_t options, const char *server_name)
{
    if (![options isKindOfClass:CharonSecProtocolStrings.class])
        return;
    [(CharonSecProtocolStrings *)options charonSetServerName:server_name];
}
