#import "RevenantNW.h"

nw_advertise_descriptor_t nw_advertise_descriptor_create_application_service(const char *application_service_name)
{
    if (!application_service_name || !*application_service_name)
        return NULL;
    RevenantNWAdvertiseDescriptor *descriptor = [[RevenantNWAdvertiseDescriptor alloc] init];
    descriptor->_applicationService = @(application_service_name);
    return descriptor;
}

const char *nw_advertise_descriptor_get_application_service_name(nw_advertise_descriptor_t advertise_descriptor)
{
    RevenantNWAdvertiseDescriptor *value = (RevenantNWAdvertiseDescriptor *)advertise_descriptor;
    return value ? value->_applicationService.UTF8String : NULL;
}
