#import "RevenantNW.h"
#import "RevenantNWSupport.h"

#include <string.h>

#if !__has_feature(objc_arc)
#error "the proxy configuration is written for ARC"
#endif

typedef void (^nw_proxy_domain_enumerator_t)(const char *domain);

nw_relay_hop_t nw_relay_hop_create(nw_endpoint_t http3_relay_endpoint, nw_endpoint_t http2_relay_endpoint, nw_protocol_options_t relay_tls_options)
{
    if (!http3_relay_endpoint && !http2_relay_endpoint)
        return NULL;
    RevenantNWRelayHop *hop = [[RevenantNWRelayHop alloc] init];
    hop->_http3 = (RevenantNWEndpoint *)http3_relay_endpoint;
    hop->_http2 = (RevenantNWEndpoint *)http2_relay_endpoint;
    hop->_tls = (RevenantNWProtocolOptions *)relay_tls_options;
    hop->_headerNames = [NSMutableArray array];
    hop->_headerValues = [NSMutableArray array];
    return hop;
}

void nw_relay_hop_add_additional_http_header_field(nw_relay_hop_t relay_hop, const char *field_name, const char *field_value)
{
    RevenantNWRelayHop *value = (RevenantNWRelayHop *)relay_hop;
    if (!value || !field_name || !*field_name)
        return;
    [value->_headerNames addObject:@(field_name)];
    [value->_headerValues addObject:field_value ? @(field_value) : @""];
}

static RevenantNWProxyConfig *revenant_proxy_config(NSString *kind)
{
    RevenantNWProxyConfig *config = [[RevenantNWProxyConfig alloc] init];
    config->_kind = kind;
    config->_matchDomains = [NSMutableArray array];
    config->_excludedDomains = [NSMutableArray array];
    return config;
}

nw_proxy_config_t nw_proxy_config_create_http_connect(nw_endpoint_t proxy_endpoint, nw_protocol_options_t proxy_tls_options)
{
    if (!proxy_endpoint)
        return NULL;
    RevenantNWProxyConfig *config = revenant_proxy_config(@"http_connect");
    config->_endpoint = (RevenantNWEndpoint *)proxy_endpoint;
    config->_tls = (RevenantNWProtocolOptions *)proxy_tls_options;
    return config;
}

nw_proxy_config_t nw_proxy_config_create_socksv5(nw_endpoint_t proxy_endpoint)
{
    if (!proxy_endpoint)
        return NULL;
    RevenantNWProxyConfig *config = revenant_proxy_config(@"socksv5");
    config->_endpoint = (RevenantNWEndpoint *)proxy_endpoint;
    return config;
}

nw_proxy_config_t nw_proxy_config_create_relay(nw_relay_hop_t first_hop, nw_relay_hop_t second_hop)
{
    if (!first_hop)
        return NULL;
    RevenantNWProxyConfig *config = revenant_proxy_config(@"relay");
    config->_firstHop = (RevenantNWRelayHop *)first_hop;
    config->_secondHop = (RevenantNWRelayHop *)second_hop;
    return config;
}

nw_proxy_config_t nw_proxy_config_create_oblivious_http(nw_relay_hop_t relay, const char *relay_resource_path, const uint8_t *gateway_key_config, size_t gateway_key_config_length)
{
    if (!relay)
        return NULL;
    RevenantNWProxyConfig *config = revenant_proxy_config(@"oblivious_http");
    config->_firstHop = (RevenantNWRelayHop *)relay;
    config->_relayResourcePath = relay_resource_path ? @(relay_resource_path) : nil;
    config->_gatewayKeyConfig = gateway_key_config ? [NSData dataWithBytes:gateway_key_config length:gateway_key_config_length] : nil;
    return config;
}

void nw_proxy_config_set_failover_allowed(nw_proxy_config_t proxy_config, bool failover_allowed)
{
    RevenantNWProxyConfig *value = (RevenantNWProxyConfig *)proxy_config;
    if (value)
        value->_failoverAllowed = failover_allowed;
}

bool nw_proxy_config_get_failover_allowed(nw_proxy_config_t proxy_config)
{
    RevenantNWProxyConfig *value = (RevenantNWProxyConfig *)proxy_config;
    return value ? value->_failoverAllowed : false;
}

void nw_proxy_config_add_match_domain(nw_proxy_config_t config, const char *match_domain)
{
    RevenantNWProxyConfig *value = (RevenantNWProxyConfig *)config;
    if (value && match_domain && *match_domain)
        [value->_matchDomains addObject:@(match_domain)];
}

void nw_proxy_config_add_excluded_domain(nw_proxy_config_t config, const char *excluded_domain)
{
    RevenantNWProxyConfig *value = (RevenantNWProxyConfig *)config;
    if (value && excluded_domain && *excluded_domain)
        [value->_excludedDomains addObject:@(excluded_domain)];
}

void nw_proxy_config_clear_match_domains(nw_proxy_config_t config)
{
    RevenantNWProxyConfig *value = (RevenantNWProxyConfig *)config;
    [value->_matchDomains removeAllObjects];
}

void nw_proxy_config_clear_excluded_domains(nw_proxy_config_t config)
{
    RevenantNWProxyConfig *value = (RevenantNWProxyConfig *)config;
    [value->_excludedDomains removeAllObjects];
}

void nw_proxy_config_enumerate_match_domains(nw_proxy_config_t config, nw_proxy_domain_enumerator_t enumerator)
{
    RevenantNWProxyConfig *value = (RevenantNWProxyConfig *)config;
    if (!value || !enumerator)
        return;
    for (NSString *domain in [value->_matchDomains copy])
        enumerator(domain.UTF8String);
}

void nw_proxy_config_enumerate_excluded_domains(nw_proxy_config_t config, nw_proxy_domain_enumerator_t enumerator)
{
    RevenantNWProxyConfig *value = (RevenantNWProxyConfig *)config;
    if (!value || !enumerator)
        return;
    for (NSString *domain in [value->_excludedDomains copy])
        enumerator(domain.UTF8String);
}

void nw_privacy_context_add_proxy(nw_privacy_context_t privacy_context, nw_proxy_config_t proxy_config)
{
    RevenantNWPrivacyContext *value = (RevenantNWPrivacyContext *)privacy_context;
    if (value && proxy_config)
        [value->_proxies addObject:(RevenantNWProxyConfig *)proxy_config];
}

void nw_privacy_context_clear_proxies(nw_privacy_context_t privacy_context)
{
    RevenantNWPrivacyContext *value = (RevenantNWPrivacyContext *)privacy_context;
    [value->_proxies removeAllObjects];
}
