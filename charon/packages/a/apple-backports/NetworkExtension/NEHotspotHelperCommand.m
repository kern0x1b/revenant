#import "CharonNEHotspot.h"

/* The command the helper is handed. The port never registers the helper (NEHotspotHelper.m), so it never builds a
   command, and a command made with alloc and init answers what the host answers for a fresh one: type None, no
   network, no list, and no response, connection or session for any endpoint (measured in
   tests/backports/host/netext-hotspot/). The endpoint answers hold for a nil endpoint on the host; a real endpoint
   is not measured (facts/NetworkExtension/Hotspot.md). */
@implementation NEHotspotHelperCommand

- (NEHotspotHelperCommandType)commandType
{
    return kNEHotspotHelperCommandTypeNone;
}

- (nullable NEHotspotNetwork *)network
{
    return nil;
}

- (nullable NSArray<NEHotspotNetwork *> *)networkList
{
    return nil;
}

- (nullable NEHotspotHelperResponse *)createResponse:(NEHotspotHelperResult)result
{
    return nil;
}

- (nullable NWTCPConnection *)createTCPConnection:(NWEndpoint *)endpoint
{
    return nil;
}

- (nullable NWUDPSession *)createUDPSession:(NWEndpoint *)endpoint
{
    return nil;
}

@end
