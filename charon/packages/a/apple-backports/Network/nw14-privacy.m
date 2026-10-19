/*
 * The privacy context of iOS 14 and the resolver configuration beside it: what a program says about
 * the names a connection looks up.
 *
 * A privacy context is a name for one program's lookups: it says whether the names must be resolved
 * in an encrypted way, which resolver to fall back on, and whether the system may log them. The
 * release this port builds for resolves names with the resolver the system gives it and has no log
 * of its own to switch off, so what is kept is what a program said - the context is carried, its
 * description is what it was given, and a connection reads the demands from it the way it reads
 * every other setting of its parameters.
 *
 * A resolver configuration is one resolver: over TLS or over HTTPS, with the addresses to ask.
 */

#import "CharonNW.h"
#import "CharonNWSupport.h"

#include <string.h>

nw_privacy_context_t nw_privacy_context_create(const char *description)
{
    if (!description)
        return NULL;
    CharonNWPrivacyContext *context = [[CharonNWPrivacyContext alloc] init];
    context->_description = @(description);
    context->_proxies = [NSMutableArray array];
    return context;
}

void nw_privacy_context_disable_logging(nw_privacy_context_t privacy_context)
{
    CharonNWPrivacyContext *value = (CharonNWPrivacyContext *)privacy_context;
    if (value)
        value->_loggingDisabled = YES;
}

void nw_privacy_context_require_encrypted_name_resolution(nw_privacy_context_t privacy_context, bool require_encrypted_name_resolution, nw_resolver_config_t fallback_resolver_config)
{
    CharonNWPrivacyContext *value = (CharonNWPrivacyContext *)privacy_context;
    if (!value)
        return;
    value->_requireEncrypted = require_encrypted_name_resolution;
    value->_fallbackResolver = (CharonNWResolverConfig *)fallback_resolver_config;
}

void nw_privacy_context_flush_cache(nw_privacy_context_t privacy_context)
{
    CharonNWPrivacyContext *value = (CharonNWPrivacyContext *)privacy_context;
    if (!value || !value->_fallbackResolver)
        return;
    /* The cache of names a context resolved is the system's, and the release has none of its own to
       clear, so asking is answered by doing nothing: a name resolved now is resolved now either
       way, which is the state the call is for. */
}

void nw_parameters_set_privacy_context(nw_parameters_t parameters, nw_privacy_context_t privacy_context)
{
    CharonNWParameters *value = (CharonNWParameters *)parameters;
    if (value)
        value->_privacyContext = (CharonNWPrivacyContext *)privacy_context;
}

nw_resolver_config_t nw_resolver_config_create_tls(nw_endpoint_t server_endpoint)
{
    if (!server_endpoint)
        return NULL;
    CharonNWResolverConfig *config = [[CharonNWResolverConfig alloc] init];
    config->_kind = @"tls";
    config->_endpoint = (CharonNWEndpoint *)server_endpoint;
    config->_servers = [NSMutableArray array];
    return config;
}

nw_resolver_config_t nw_resolver_config_create_https(nw_endpoint_t url_endpoint)
{
    if (!url_endpoint)
        return NULL;
    CharonNWResolverConfig *config = [[CharonNWResolverConfig alloc] init];
    config->_kind = @"https";
    config->_endpoint = (CharonNWEndpoint *)url_endpoint;
    config->_servers = [NSMutableArray array];
    return config;
}

void nw_resolver_config_add_server_address(nw_resolver_config_t config, nw_endpoint_t server_address)
{
    CharonNWResolverConfig *value = (CharonNWResolverConfig *)config;
    if (!value || !server_address)
        return;
    [value->_servers addObject:(CharonNWEndpoint *)server_address];
}

void nw_ip_options_set_disable_multicast_loopback(nw_protocol_options_t options, bool disable_multicast_loopback)
{
    charon_nw_set_flag((__bridge CFMutableDictionaryRef)((CharonNWProtocolOptions *)options)->_values, "disable_multicast_loopback", disable_multicast_loopback);
}
