#import "RevenantNW.h"
#import "RevenantNWSupport.h"

#include <string.h>

nw_privacy_context_t nw_privacy_context_create(const char *description)
{
    if (!description)
        return NULL;
    RevenantNWPrivacyContext *context = [[RevenantNWPrivacyContext alloc] init];
    context->_description = @(description);
    context->_proxies = [NSMutableArray array];
    return context;
}

void nw_privacy_context_disable_logging(nw_privacy_context_t privacy_context)
{
    RevenantNWPrivacyContext *value = (RevenantNWPrivacyContext *)privacy_context;
    if (value)
        value->_loggingDisabled = YES;
}

void nw_privacy_context_require_encrypted_name_resolution(nw_privacy_context_t privacy_context, bool require_encrypted_name_resolution, nw_resolver_config_t fallback_resolver_config)
{
    RevenantNWPrivacyContext *value = (RevenantNWPrivacyContext *)privacy_context;
    if (!value)
        return;
    value->_requireEncrypted = require_encrypted_name_resolution;
    value->_fallbackResolver = (RevenantNWResolverConfig *)fallback_resolver_config;
}

void nw_privacy_context_flush_cache(nw_privacy_context_t privacy_context)
{
    RevenantNWPrivacyContext *value = (RevenantNWPrivacyContext *)privacy_context;
    if (!value || !value->_fallbackResolver)
        return;
}

void nw_parameters_set_privacy_context(nw_parameters_t parameters, nw_privacy_context_t privacy_context)
{
    RevenantNWParameters *value = (RevenantNWParameters *)parameters;
    if (value)
        value->_privacyContext = (RevenantNWPrivacyContext *)privacy_context;
}

nw_resolver_config_t nw_resolver_config_create_tls(nw_endpoint_t server_endpoint)
{
    if (!server_endpoint)
        return NULL;
    RevenantNWResolverConfig *config = [[RevenantNWResolverConfig alloc] init];
    config->_kind = @"tls";
    config->_endpoint = (RevenantNWEndpointValue *)server_endpoint;
    config->_servers = [NSMutableArray array];
    return config;
}

nw_resolver_config_t nw_resolver_config_create_https(nw_endpoint_t url_endpoint)
{
    if (!url_endpoint)
        return NULL;
    RevenantNWResolverConfig *config = [[RevenantNWResolverConfig alloc] init];
    config->_kind = @"https";
    config->_endpoint = (RevenantNWEndpointValue *)url_endpoint;
    config->_servers = [NSMutableArray array];
    return config;
}

void nw_resolver_config_add_server_address(nw_resolver_config_t config, nw_endpoint_t server_address)
{
    RevenantNWResolverConfig *value = (RevenantNWResolverConfig *)config;
    if (!value || !server_address)
        return;
    [value->_servers addObject:(RevenantNWEndpointValue *)server_address];
}

void nw_ip_options_set_disable_multicast_loopback(nw_protocol_options_t options, bool disable_multicast_loopback)
{
    revenant_nw_set_flag((__bridge CFMutableDictionaryRef)((RevenantNWProtocolOptions *)options)->_values, "disable_multicast_loopback", disable_multicast_loopback);
}
