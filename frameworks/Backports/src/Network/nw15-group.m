#include "../revenant_impl.h"
#import "RevenantNW.h"

nw_group_descriptor_t BACKPORT_IMPL(nw_group_descriptor_create_multiplex)(nw_endpoint_t remote_endpoint)
{
    RevenantNWEndpointValue *remote = (RevenantNWEndpointValue *)remote_endpoint;
    if (!remote)
        return NULL;
    RevenantNWGroupDescriptor *descriptor = [[RevenantNWGroupDescriptor alloc] init];
    descriptor->_kind = @"multiplex";
    descriptor->_remoteEndpoint = remote;
    descriptor->_endpoints = [NSMutableArray array];
    return descriptor;
}
