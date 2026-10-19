#import "CharonNW.h"

nw_browse_descriptor_t nw_browse_descriptor_create_bonjour_service(const char *type, const char *domain)
{
    if (!type || !*type || !domain || !*domain)
        return NULL;
    CharonNWBrowseDescriptor *descriptor = [[CharonNWBrowseDescriptor alloc] init];
    descriptor->_bonjourType = @(type);
    descriptor->_bonjourDomain = @(domain);
    return descriptor;
}
