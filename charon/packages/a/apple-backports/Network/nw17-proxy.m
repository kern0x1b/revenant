/*
 * The proxy configuration of iOS 17: a proxy a connection may be sent through, the relay hops of a
 * MASQUE-style relay, and the domains that do and do not go through it.
 *
 * The release this port builds for has no per-connection proxy: a connection is made to the peer its
 * endpoint names, and the system proxy settings are not consulted for it. So what is carried here is
 * the configuration itself - which kind of proxy, which endpoint, which credentials, which domains,
 * whether a failover to a direct connection is allowed - kept and answered as the SDK documents. A
 * connection that is given a privacy context holding one of these reads it and says so in the
 * establishment report rather than pretending to have gone through it; see facts/Network/NWProxy.md.
 *
 * The declarations of the two types here are the port's own: the SDK it compiles against is 16.4,
 * which predates them, and what they are is what the header of a release that has them says.
 */

#import "CharonNW.h"
#import "CharonNWSupport.h"

#include <string.h>

#if !__has_feature(objc_arc)
#error "the proxy configuration is written for ARC"
#endif

typedef void (^nw_proxy_domain_enumerator_t)(const char *domain);

nw_relay_hop_t nw_relay_hop_create(nw_endpoint_t http3_relay_endpoint, nw_endpoint_t http2_relay_endpoint, nw_protocol_options_t relay_tls_options)
{
    if (!http3_relay_endpoint && !http2_relay_endpoint)
        return NULL;
    CharonNWRelayHop *hop = [[CharonNWRelayHop alloc] init];
    hop->_http3 = (CharonNWEndpoint *)http3_relay_endpoint;
    hop->_http2 = (CharonNWEndpoint *)http2_relay_endpoint;
    hop->_tls = (CharonNWProtocolOptions *)relay_tls_options;
    hop->_headerNames = [NSMutableArray array];
    hop->_headerValues = [NSMutableArray array];
    return hop;
}

void nw_relay_hop_add_additional_http_header_field(nw_relay_hop_t relay_hop, const char *field_name, const char *field_value)
{
    CharonNWRelayHop *value = (CharonNWRelayHop *)relay_hop;
    if (!value || !field_name || !*field_name)
        return;
    [value->_headerNames addObject:@(field_name)];
    [value->_headerValues addObject:field_value ? @(field_value) : @""];
}

static CharonNWProxyConfig *charon_proxy_config(NSString *kind)
{
    CharonNWProxyConfig *config = [[CharonNWProxyConfig alloc] init];
    config->_kind = kind;
    config->_matchDomains = [NSMutableArray array];
    config->_excludedDomains = [NSMutableArray array];
    return config;
}

nw_proxy_config_t nw_proxy_config_create_http_connect(nw_endpoint_t proxy_endpoint, nw_protocol_options_t proxy_tls_options)
{
    if (!proxy_endpoint)
        return NULL;
    CharonNWProxyConfig *config = charon_proxy_config(@"http_connect");
    config->_endpoint = (CharonNWEndpoint *)proxy_endpoint;
    config->_tls = (CharonNWProtocolOptions *)proxy_tls_options;
    return config;
}

nw_proxy_config_t nw_proxy_config_create_socksv5(nw_endpoint_t proxy_endpoint)
{
    if (!proxy_endpoint)
        return NULL;
    CharonNWProxyConfig *config = charon_proxy_config(@"socksv5");
    config->_endpoint = (CharonNWEndpoint *)proxy_endpoint;
    return config;
}

nw_proxy_config_t nw_proxy_config_create_relay(nw_relay_hop_t first_hop, nw_relay_hop_t second_hop)
{
    if (!first_hop)
        return NULL;
    CharonNWProxyConfig *config = charon_proxy_config(@"relay");
    config->_firstHop = (CharonNWRelayHop *)first_hop;
    config->_secondHop = (CharonNWRelayHop *)second_hop;
    return config;
}

nw_proxy_config_t nw_proxy_config_create_oblivious_http(nw_relay_hop_t relay, const char *relay_resource_path, const uint8_t *gateway_key_config, size_t gateway_key_config_length)
{
    if (!relay)
        return NULL;
    CharonNWProxyConfig *config = charon_proxy_config(@"oblivious_http");
    config->_firstHop = (CharonNWRelayHop *)relay;
    config->_relayResourcePath = relay_resource_path ? @(relay_resource_path) : nil;
    config->_gatewayKeyConfig = gateway_key_config ? [NSData dataWithBytes:gateway_key_config length:gateway_key_config_length] : nil;
    return config;
}

void nw_proxy_config_set_failover_allowed(nw_proxy_config_t proxy_config, bool failover_allowed)
{
    CharonNWProxyConfig *value = (CharonNWProxyConfig *)proxy_config;
    if (value)
        value->_failoverAllowed = failover_allowed;
}

bool nw_proxy_config_get_failover_allowed(nw_proxy_config_t proxy_config)
{
    CharonNWProxyConfig *value = (CharonNWProxyConfig *)proxy_config;
    return value ? value->_failoverAllowed : false;
}

void nw_proxy_config_add_match_domain(nw_proxy_config_t config, const char *match_domain)
{
    CharonNWProxyConfig *value = (CharonNWProxyConfig *)config;
    if (value && match_domain && *match_domain)
        [value->_matchDomains addObject:@(match_domain)];
}

void nw_proxy_config_add_excluded_domain(nw_proxy_config_t config, const char *excluded_domain)
{
    CharonNWProxyConfig *value = (CharonNWProxyConfig *)config;
    if (value && excluded_domain && *excluded_domain)
        [value->_excludedDomains addObject:@(excluded_domain)];
}

void nw_proxy_config_clear_match_domains(nw_proxy_config_t config)
{
    CharonNWProxyConfig *value = (CharonNWProxyConfig *)config;
    [value->_matchDomains removeAllObjects];
}

void nw_proxy_config_clear_excluded_domains(nw_proxy_config_t config)
{
    CharonNWProxyConfig *value = (CharonNWProxyConfig *)config;
    [value->_excludedDomains removeAllObjects];
}

void nw_proxy_config_enumerate_match_domains(nw_proxy_config_t config, nw_proxy_domain_enumerator_t enumerator)
{
    CharonNWProxyConfig *value = (CharonNWProxyConfig *)config;
    if (!value || !enumerator)
        return;
    for (NSString *domain in [value->_matchDomains copy])
        enumerator(domain.UTF8String);
}

void nw_proxy_config_enumerate_excluded_domains(nw_proxy_config_t config, nw_proxy_domain_enumerator_t enumerator)
{
    CharonNWProxyConfig *value = (CharonNWProxyConfig *)config;
    if (!value || !enumerator)
        return;
    for (NSString *domain in [value->_excludedDomains copy])
        enumerator(domain.UTF8String);
}

void nw_privacy_context_add_proxy(nw_privacy_context_t privacy_context, nw_proxy_config_t proxy_config)
{
    CharonNWPrivacyContext *value = (CharonNWPrivacyContext *)privacy_context;
    if (value && proxy_config)
        [value->_proxies addObject:(CharonNWProxyConfig *)proxy_config];
}

void nw_privacy_context_clear_proxies(nw_privacy_context_t privacy_context)
{
    CharonNWPrivacyContext *value = (CharonNWPrivacyContext *)privacy_context;
    [value->_proxies removeAllObjects];
}
