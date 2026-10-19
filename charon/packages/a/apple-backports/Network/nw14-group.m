#import "CharonNW.h"

nw_group_descriptor_t nw_group_descriptor_create_multicast(nw_endpoint_t multicast_group)
{
    CharonNWEndpoint *group = (CharonNWEndpoint *)multicast_group;
    if (!group)
        return NULL;
    CharonNWGroupDescriptor *descriptor = [[CharonNWGroupDescriptor alloc] init];
    descriptor->_kind = @"multicast";
    descriptor->_multicastGroup = group;
    descriptor->_endpoints = [NSMutableArray array];
    return descriptor;
}

bool nw_group_descriptor_add_endpoint(nw_group_descriptor_t descriptor, nw_endpoint_t endpoint)
{
    CharonNWGroupDescriptor *value = (CharonNWGroupDescriptor *)descriptor;
    if (!value || !endpoint)
        return false;
    nw_endpoint_type_t type = ((CharonNWEndpoint *)endpoint)->_type;
    if (type != nw_endpoint_type_host && type != nw_endpoint_type_address)
        return false;
    [value->_endpoints addObject:(CharonNWEndpoint *)endpoint];
    return true;
}

void nw_group_descriptor_enumerate_endpoints(nw_group_descriptor_t descriptor, nw_group_descriptor_enumerate_endpoints_block_t enumerate_block)
{
    CharonNWGroupDescriptor *value = (CharonNWGroupDescriptor *)descriptor;
    if (!value || !enumerate_block)
        return;
    for (CharonNWEndpoint *endpoint in [value->_endpoints copy]) {
        if (!enumerate_block(endpoint))
            break;
    }
}

void nw_multicast_group_descriptor_set_specific_source(nw_group_descriptor_t multicast_descriptor, nw_endpoint_t source)
{
    CharonNWGroupDescriptor *value = (CharonNWGroupDescriptor *)multicast_descriptor;
    if (value)
        value->_specificSource = (CharonNWEndpoint *)source;
}

void nw_multicast_group_descriptor_set_disable_unicast_traffic(nw_group_descriptor_t multicast_descriptor, bool disable_unicast_traffic)
{
    CharonNWGroupDescriptor *value = (CharonNWGroupDescriptor *)multicast_descriptor;
    if (value)
        value->_disableUnicastTraffic = disable_unicast_traffic;
}

bool nw_multicast_group_descriptor_get_disable_unicast_traffic(nw_group_descriptor_t multicast_descriptor)
{
    CharonNWGroupDescriptor *value = (CharonNWGroupDescriptor *)multicast_descriptor;
    return value ? value->_disableUnicastTraffic : false;
}
