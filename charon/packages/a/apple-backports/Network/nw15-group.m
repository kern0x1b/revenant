/*
 * The multiplex group of iOS 15: a group of connections whose members are remote endpoints, one
 * connection each, rather than one multicast group every message goes to.
 */

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
