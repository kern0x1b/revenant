#import "CharonNEHotspot.h"

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
