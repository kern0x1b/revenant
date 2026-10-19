/*
 * What a browser looks for: the browse of a Bonjour service type and domain, the call of iOS 12 that
 * every later one of browse_descriptor.h is a variation of.
 *
 * A descriptor is the service type and domain a browser is asked to browse. Nothing here reaches the
 * network: a browser takes the descriptor and starts looking, which is the browser's own business.
 */

#import "CharonNW.h"

nw_browse_descriptor_t nw_browse_descriptor_create_bonjour_service(const char *type, const char *domain)
{
    /* A type and a domain are what a browse is: without either there is nothing to look for and
       nowhere to look, and the host's own Network refuses it (tests/backports/host/network-objects). */
    if (!type || !*type || !domain || !*domain)
        return NULL;
    CharonNWBrowseDescriptor *descriptor = [[CharonNWBrowseDescriptor alloc] init];
    descriptor->_bonjourType = @(type);
    descriptor->_bonjourDomain = @(domain);
    return descriptor;
}
