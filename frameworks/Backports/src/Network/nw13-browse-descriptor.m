#include "../revenant_impl.h"
#import "RevenantNW.h"

const char *BACKPORT_IMPL(nw_browse_descriptor_get_bonjour_service_type)(nw_browse_descriptor_t descriptor)
{
    RevenantNWBrowseDescriptor *value = (RevenantNWBrowseDescriptor *)descriptor;
    return value ? value->_bonjourType.UTF8String : NULL;
}

const char *BACKPORT_IMPL(nw_browse_descriptor_get_bonjour_service_domain)(nw_browse_descriptor_t descriptor)
{
    RevenantNWBrowseDescriptor *value = (RevenantNWBrowseDescriptor *)descriptor;
    return value ? value->_bonjourDomain.UTF8String : NULL;
}

bool BACKPORT_IMPL(nw_browse_descriptor_get_include_txt_record)(nw_browse_descriptor_t descriptor)
{
    RevenantNWBrowseDescriptor *value = (RevenantNWBrowseDescriptor *)descriptor;
    return value ? value->_includeTxtRecord : false;
}

void BACKPORT_IMPL(nw_browse_descriptor_set_include_txt_record)(nw_browse_descriptor_t descriptor, bool include_txt_record)
{
    RevenantNWBrowseDescriptor *value = (RevenantNWBrowseDescriptor *)descriptor;
    if (value)
        value->_includeTxtRecord = include_txt_record;
}
