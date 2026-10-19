#import "CharonNEHotspot.h"

/* The response a helper answers a command with. The host has no getter for the network or the list, and a response
   is never delivered by the port, since no command reaches it (NEHotspotHelper.m). The setters keep the values, and
   deliver sends nothing (tests/backports/host/netext-hotspot/). */
@implementation NEHotspotHelperResponse {
    NEHotspotNetwork *_network;
    NSArray<NEHotspotNetwork *> *_networkList;
}

- (void)setNetwork:(NEHotspotNetwork *)network
{
    _network = network;
}

- (void)setNetworkList:(NSArray<NEHotspotNetwork *> *)networkList
{
    _networkList = [networkList copy];
}

- (void)deliver
{
}

@end
