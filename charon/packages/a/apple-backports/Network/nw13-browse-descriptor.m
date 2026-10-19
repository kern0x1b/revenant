/*
 * What a browse answers about itself: the calls of browse_descriptor.h that arrived after the browse
 * itself - the type and the domain it is for, and whether the records a browser finds come with their
 * TXT record.
 */

#import "CharonNW.h"

const char *nw_browse_descriptor_get_bonjour_service_type(nw_browse_descriptor_t descriptor)
{
    CharonNWBrowseDescriptor *value = (CharonNWBrowseDescriptor *)descriptor;
    return value ? value->_bonjourType.UTF8String : NULL;
}

const char *nw_browse_descriptor_get_bonjour_service_domain(nw_browse_descriptor_t descriptor)
{
    CharonNWBrowseDescriptor *value = (CharonNWBrowseDescriptor *)descriptor;
    return value ? value->_bonjourDomain.UTF8String : NULL;
}

bool nw_browse_descriptor_get_include_txt_record(nw_browse_descriptor_t descriptor)
{
    CharonNWBrowseDescriptor *value = (CharonNWBrowseDescriptor *)descriptor;
    return value ? value->_includeTxtRecord : false;
}

void nw_browse_descriptor_set_include_txt_record(nw_browse_descriptor_t descriptor, bool include_txt_record)
{
    CharonNWBrowseDescriptor *value = (CharonNWBrowseDescriptor *)descriptor;
    if (value)
        value->_includeTxtRecord = include_txt_record;
}
