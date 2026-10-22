#import "RevenantNW.h"

nw_group_descriptor_t nw_group_descriptor_create_multicast(nw_endpoint_t multicast_group)
{
    RevenantNWEndpointValue *group = (RevenantNWEndpointValue *)multicast_group;
    if (!group)
        return NULL;
    RevenantNWGroupDescriptor *descriptor = [[RevenantNWGroupDescriptor alloc] init];
    descriptor->_kind = @"multicast";
    descriptor->_multicastGroup = group;
    descriptor->_endpoints = [NSMutableArray array];
    return descriptor;
}

bool nw_group_descriptor_add_endpoint(nw_group_descriptor_t descriptor, nw_endpoint_t endpoint)
{
    RevenantNWGroupDescriptor *value = (RevenantNWGroupDescriptor *)descriptor;
    if (!value || !endpoint)
        return false;
    nw_endpoint_type_t type = ((RevenantNWEndpointValue *)endpoint)->_type;
    if (type != nw_endpoint_type_host && type != nw_endpoint_type_address)
        return false;
    [value->_endpoints addObject:(RevenantNWEndpointValue *)endpoint];
    return true;
}

void nw_group_descriptor_enumerate_endpoints(nw_group_descriptor_t descriptor, nw_group_descriptor_enumerate_endpoints_block_t enumerate_block)
{
    RevenantNWGroupDescriptor *value = (RevenantNWGroupDescriptor *)descriptor;
    if (!value || !enumerate_block)
        return;
    for (RevenantNWEndpointValue *endpoint in [value->_endpoints copy]) {
        if (!enumerate_block(endpoint))
            break;
    }
}

void nw_multicast_group_descriptor_set_specific_source(nw_group_descriptor_t multicast_descriptor, nw_endpoint_t source)
{
    RevenantNWGroupDescriptor *value = (RevenantNWGroupDescriptor *)multicast_descriptor;
    if (value)
        value->_specificSource = (RevenantNWEndpointValue *)source;
}

void nw_multicast_group_descriptor_set_disable_unicast_traffic(nw_group_descriptor_t multicast_descriptor, bool disable_unicast_traffic)
{
    RevenantNWGroupDescriptor *value = (RevenantNWGroupDescriptor *)multicast_descriptor;
    if (value)
        value->_disableUnicastTraffic = disable_unicast_traffic;
}

bool nw_multicast_group_descriptor_get_disable_unicast_traffic(nw_group_descriptor_t multicast_descriptor)
{
    RevenantNWGroupDescriptor *value = (RevenantNWGroupDescriptor *)multicast_descriptor;
    return value ? value->_disableUnicastTraffic : false;
}
