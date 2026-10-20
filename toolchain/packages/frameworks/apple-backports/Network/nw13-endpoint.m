#import "RevenantNW.h"
#import "RevenantNWSupport.h"

#include <string.h>

nw_endpoint_t nw_endpoint_create_url(const char *url)
{
    if (!url || !*url)
        return NULL;
    if (!strchr(url, ':'))
        return NULL;
    const char *separator = strstr(url, "://");
    CFStringRef host = separator ? revenant_nw_url_host(url) : revenant_nw_cfstring("");
    if (!host)
        host = revenant_nw_cfstring("");
    uint16_t port = separator ? revenant_nw_url_port(url) : 0;
    if (!port)
        port = revenant_nw_default_port_for_scheme(url);
    RevenantNWEndpoint *endpoint = [[RevenantNWEndpoint alloc] init];
    endpoint->_type = nw_endpoint_type_url;
    endpoint->_url = @(url);
    endpoint->_hostname = (__bridge_transfer NSString *)host;
    endpoint->_port = [NSString stringWithFormat:@"%u", port];
    return endpoint;
}

const char *nw_endpoint_get_url(nw_endpoint_t endpoint)
{
    RevenantNWEndpoint *value = (RevenantNWEndpoint *)endpoint;
    if (!value || value->_type != nw_endpoint_type_url)
        return NULL;
    return value->_url.UTF8String;
}
