/*
 * The application service a browser looks for, as iOS 16 names it: one name that stands for the
 * whole service, with no type and no domain of its own.
 */

#import "CharonNW.h"

nw_browse_descriptor_t nw_browse_descriptor_create_application_service(const char *application_service_name)
{
    if (!application_service_name || !*application_service_name)
        return NULL;
    CharonNWBrowseDescriptor *descriptor = [[CharonNWBrowseDescriptor alloc] init];
    descriptor->_applicationService = @(application_service_name);
    return descriptor;
}

const char *nw_browse_descriptor_get_application_service_name(nw_browse_descriptor_t descriptor)
{
    CharonNWBrowseDescriptor *value = (CharonNWBrowseDescriptor *)descriptor;
    return value ? value->_applicationService.UTF8String : NULL;
}
