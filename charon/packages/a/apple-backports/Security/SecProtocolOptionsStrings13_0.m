#import <Foundation/Foundation.h>
#import <Security/SecProtocolTypes.h>
#import <Security/SecProtocolOptions.h>
#import <CoreFoundation/CoreFoundation.h>
#include <stdlib.h>
#include <string.h>

// The two C string setters, from Security/SecProtocolOptions.h:
//
//   321  void sec_protocol_options_add_tls_application_protocol(sec_protocol_options_t, const char *)
//   338  void sec_protocol_options_set_tls_server_name(sec_protocol_options_t, const char *)
//
// A C STRING IS COPIED, and the copy is the whole of the difference from every other setter in this
// family. The caller owns the bytes it passes: a `const char *` on iOS is a UTF-8 pointer with no
// lifetime attached, and a caller that hands over a buffer on its own stack and then returns has left
// the object holding a pointer into a dead frame. That is the same failure the block setter has, and
// the same fix in the C form: strdup, and free at dealloc.
//
// The application protocol is APPENDED rather than replaced, because the header names it "add" and
// because ALPN is a LIST - a client offers several and the server picks one. The server name is a
// single setting, so it replaces.

@interface CharonSecProtocolStrings : NSObject <OS_sec_protocol_options>
{
    // the copies. NOT const-qualified pointers, and not __strong: a C string is not an ObjC object, so
    // ARC manages neither and the port frees them by hand.
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
    // the OLD copy goes first, so setting twice does not leak, and a NULL clears rather than strdup(NULL)
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
        return;   // a full list holds what it has rather than overrunning a fixed array
    char *copy = strdup(protocol);
    if (!copy)
        return;   // a failed allocation adds nothing rather than storing NULL in the middle of the list
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

//   321
void sec_protocol_options_add_tls_application_protocol(sec_protocol_options_t options,
                                                       const char *application_protocol)
{
    if (![options isKindOfClass:CharonSecProtocolStrings.class])
        return;
    [(CharonSecProtocolStrings *)options charonAddApplicationProtocol:application_protocol];
}

//   338
void sec_protocol_options_set_tls_server_name(sec_protocol_options_t options, const char *server_name)
{
    if (![options isKindOfClass:CharonSecProtocolStrings.class])
        return;
    [(CharonSecProtocolStrings *)options charonSetServerName:server_name];
}
