#import "RevenantNW.h"

nw_group_descriptor_t nw_group_descriptor_create_multiplex(nw_endpoint_t remote_endpoint)
{
    RevenantNWEndpoint *remote = (RevenantNWEndpoint *)remote_endpoint;
    if (!remote)
        return NULL;
    RevenantNWGroupDescriptor *descriptor = [[RevenantNWGroupDescriptor alloc] init];
    descriptor->_kind = @"multiplex";
    descriptor->_remoteEndpoint = remote;
    descriptor->_endpoints = [NSMutableArray array];
    return descriptor;
}
