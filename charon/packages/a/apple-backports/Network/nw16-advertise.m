/*
 * The application service a listener advertises, as iOS 16 names it: one name that stands for the
 * whole service, with no type and no domain of its own.
 */

#import "CharonNW.h"

nw_advertise_descriptor_t nw_advertise_descriptor_create_application_service(const char *application_service_name)
{
    if (!application_service_name || !*application_service_name)
        return NULL;
    CharonNWAdvertiseDescriptor *descriptor = [[CharonNWAdvertiseDescriptor alloc] init];
    descriptor->_applicationService = @(application_service_name);
    return descriptor;
}

const char *nw_advertise_descriptor_get_application_service_name(nw_advertise_descriptor_t advertise_descriptor)
{
    CharonNWAdvertiseDescriptor *value = (CharonNWAdvertiseDescriptor *)advertise_descriptor;
    return value ? value->_applicationService.UTF8String : NULL;
}
