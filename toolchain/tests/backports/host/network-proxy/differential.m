#import <Foundation/Foundation.h>
#import <Network/Network.h>
#import <string.h>
#import "check.h"

#define P(name) charonhost_##name
extern nw_endpoint_t P(nw_endpoint_create_host)(const char *, const char *);
extern nw_endpoint_t P(nw_endpoint_create_url)(const char *);
extern id P(nw_relay_hop_create)(nw_endpoint_t, nw_endpoint_t, nw_protocol_options_t);
extern void P(nw_relay_hop_add_additional_http_header_field)(id, const char *, const char *);
extern id P(nw_proxy_config_create_http_connect)(nw_endpoint_t, nw_protocol_options_t);
extern id P(nw_proxy_config_create_socksv5)(nw_endpoint_t);
extern id P(nw_proxy_config_create_relay)(id, id);
extern id P(nw_proxy_config_create_oblivious_http)(id, const char *, const uint8_t *, size_t);
extern void P(nw_proxy_config_set_username_and_password)(id, const char *, const char *);
extern void P(nw_proxy_config_set_failover_allowed)(id, bool);
extern bool P(nw_proxy_config_get_failover_allowed)(id);
extern void P(nw_proxy_config_add_match_domain)(id, const char *);
extern void P(nw_proxy_config_add_excluded_domain)(id, const char *);
extern void P(nw_proxy_config_clear_match_domains)(id);
extern void P(nw_proxy_config_clear_excluded_domains)(id);
extern nw_privacy_context_t P(nw_privacy_context_create)(const char *);
extern void P(nw_privacy_context_add_proxy)(nw_privacy_context_t, id);
extern void P(nw_privacy_context_clear_proxies)(nw_privacy_context_t);

int main(void)
{
    @autoreleasepool {
        nw_endpoint_t proxy = P(nw_endpoint_create_host)("192.0.2.10", "8080");
        nw_endpoint_t http3 = P(nw_endpoint_create_url)("https://relay.example/h3");
        nw_endpoint_t http2 = P(nw_endpoint_create_url)("https://relay.example/h2");
        const uint8_t key[] = {1, 2, 3};

        id hop_both = P(nw_relay_hop_create)(http3, http2, NULL);
        CHECK(hop_both != NULL, "a relay hop with both of its endpoints");
        CHECK(P(nw_relay_hop_create)(http3, NULL, NULL) != NULL, "a relay hop with one");
        CHECK(P(nw_relay_hop_create)(NULL, NULL, NULL) == NULL, "a relay hop with neither is no hop");
        P(nw_relay_hop_add_additional_http_header_field)(hop_both, "X-Hop", "1");
        P(nw_relay_hop_add_additional_http_header_field)(hop_both, "", "2");
        CHECK(hop_both != NULL, "a hop takes the header fields a program adds to it");

        id config = P(nw_proxy_config_create_http_connect)(proxy, NULL);
        CHECK(config != NULL, "an HTTP CONNECT proxy of an endpoint");
        CHECK(P(nw_proxy_config_create_http_connect)(NULL, NULL) == NULL, "an HTTP CONNECT proxy of nothing is no proxy");
        CHECK(P(nw_proxy_config_create_socksv5)(proxy) != NULL, "a SOCKSv5 proxy of an endpoint");
        CHECK(P(nw_proxy_config_create_socksv5)(NULL) == NULL, "a SOCKSv5 proxy of nothing is no proxy");
        CHECK(P(nw_proxy_config_create_relay)(hop_both, NULL) != NULL, "a relay proxy of a hop");
        CHECK(P(nw_proxy_config_create_relay)(NULL, NULL) == NULL, "a relay proxy of no hop is no proxy");
        CHECK(P(nw_proxy_config_create_oblivious_http)(hop_both, "/path", key, sizeof key) != NULL,
              "an oblivious HTTP proxy with a key configuration");
        CHECK(P(nw_proxy_config_create_oblivious_http)(hop_both, "/path", NULL, 0) != NULL,
              "and one with none");
        CHECK(P(nw_proxy_config_create_oblivious_http)(NULL, "/path", key, sizeof key) == NULL,
              "an oblivious HTTP proxy of no relay is no proxy");

        P(nw_proxy_config_set_username_and_password)(config, "user", "secret");
        P(nw_proxy_config_set_failover_allowed)(config, true);
        CHECK(P(nw_proxy_config_get_failover_allowed)(config), "a failover that was allowed");
        P(nw_proxy_config_set_failover_allowed)(config, false);
        CHECK(!P(nw_proxy_config_get_failover_allowed)(config), "and one that was not");
        CHECK(!P(nw_proxy_config_get_failover_allowed)(P(nw_proxy_config_create_socksv5)(proxy)),
              "a proxy nobody allowed a failover on does not allow one");

        P(nw_proxy_config_add_match_domain)(config, "one.example");
        P(nw_proxy_config_add_excluded_domain)(config, "no.example");
        CHECK(config != NULL, "a proxy takes the domains a program adds to it");
        P(nw_proxy_config_clear_match_domains)(config);
        P(nw_proxy_config_clear_excluded_domains)(config);
        CHECK(config != NULL, "and lets them be cleared again");

        nw_privacy_context_t privacy = P(nw_privacy_context_create)("proxy test");
        CHECK(privacy != NULL, "a privacy context with a description");
        P(nw_privacy_context_add_proxy)(privacy, config);
        P(nw_privacy_context_add_proxy)(privacy, P(nw_proxy_config_create_socksv5)(proxy));
        P(nw_privacy_context_clear_proxies)(privacy);
        CHECK(privacy != NULL, "and its proxies can be put on it and taken off it");

        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
    }
    return charon_failures ? 1 : 0;
}
