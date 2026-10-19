/*
 * The URL endpoint of iOS 13, and the one call of iOS 12 that answers for it.
 *
 * A URL endpoint keeps the URL as it was given, and answers its host and its port from it: the host
 * is what the URL names without its port, and the port is the URL's own when it has one. A URL the
 * port cannot make an endpoint of is refused, as a host that is not a host is.
 */

#import "CharonNW.h"
#import "CharonNWSupport.h"

#include <string.h>

nw_endpoint_t nw_endpoint_create_url(const char *url)
{
    if (!url || !*url)
        return NULL;
    /* A text with no colon in it names no scheme and no authority, and is not a URL: the host's own
       Network refuses it (tests/backports/host/network-objects). A text with a scheme is one, and its
       host is what its authority names - nothing, where the authority names nothing - and its port is
       its own or, when it has none, the one its scheme answers. */
    if (!strchr(url, ':'))
        return NULL;
    /* Without the "://" there is no authority: the text before the colon is the scheme and nothing
       names a host, so the endpoint's host is empty - which is what the host's own Network answers
       for such a text (tests/backports/host/network-objects). */
    const char *separator = strstr(url, "://");
    CFStringRef host = separator ? charon_nw_url_host(url) : charon_nw_cfstring("");
    if (!host)
        host = charon_nw_cfstring("");
    uint16_t port = separator ? charon_nw_url_port(url) : 0;
    if (!port)
        port = charon_nw_default_port_for_scheme(url);
    CharonNWEndpoint *endpoint = [[CharonNWEndpoint alloc] init];
    endpoint->_type = nw_endpoint_type_url;
    endpoint->_url = @(url);
    endpoint->_hostname = (__bridge_transfer NSString *)host;
    endpoint->_port = [NSString stringWithFormat:@"%u", port];
    return endpoint;
}

const char *nw_endpoint_get_url(nw_endpoint_t endpoint)
{
    CharonNWEndpoint *value = (CharonNWEndpoint *)endpoint;
    if (!value || value->_type != nw_endpoint_type_url)
        return NULL;
    return value->_url.UTF8String;
}
