#import "CharonNW.h"

nw_group_descriptor_t nw_group_descriptor_create_multiplex(nw_endpoint_t remote_endpoint)
{
    CharonNWEndpoint *remote = (CharonNWEndpoint *)remote_endpoint;
    if (!remote)
        return NULL;
    CharonNWGroupDescriptor *descriptor = [[CharonNWGroupDescriptor alloc] init];
    descriptor->_kind = @"multiplex";
    descriptor->_remoteEndpoint = remote;
    descriptor->_endpoints = [NSMutableArray array];
    return descriptor;
}
