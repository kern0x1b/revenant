#import "CharonNEHotspot.h"

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
