/*
 * The host differential for the objects of Network: every family the port carries, asked the same
 * questions of the host's own Network.framework and of the port's implementation compiled beside it
 * with its names changed, and the two answers compared.
 *
 * The port's files are compiled into this program by run.sh with every symbol they define renamed -
 * every nw_* call to charonhost_nw_*, every Charon class to CharonHostCharon* - so one table of
 * function pointers reaches either side and a scenario runs through both unchanged. What is compared
 * is what a program can observe: a getter's default, a set and a get, a refused argument, the shape
 * of an endpoint, the bytes of a record, and the predicate that says which protocol an object is.
 *
 * Where a call has no getter, the setter is called on both sides and the two are compared by the fact
 * that nothing crashed: there is nothing else of a setting-only call to see.
 */

#import <Foundation/Foundation.h>
#import <Network/Network.h>
#import <arpa/inet.h>
#import <ctype.h>
#include <ifaddrs.h>
#include <net/if.h>
#include <net/if_dl.h>
#include <sys/socket.h>
#import <netinet/in.h>
#import <stdlib.h>
#import <string.h>
#import "check.h"

/* ---------------------------------------------------------------- the port's side, renamed */

#define P(name) charonhost_##name

/* The port's own types of iOS 17, which the 16.4 SDK does not carry: the port declares them itself
   (CharonNW.h), so the test names them the way the port does. */
typedef id P(nw_proxy_config_t);
typedef id P(nw_relay_hop_t);
typedef enum { P(nw_link_quality_t) } P(nw_link_quality_e);
extern id charonhost_nw_relay_hop_create(nw_endpoint_t, nw_endpoint_t, nw_protocol_options_t);
extern void charonhost_nw_relay_hop_add_additional_http_header_field(id, const char *, const char *);
extern id charonhost_nw_proxy_config_create_http_connect(nw_endpoint_t, nw_protocol_options_t);
extern id charonhost_nw_proxy_config_create_socksv5(nw_endpoint_t);
extern id charonhost_nw_proxy_config_create_relay(id, id);
extern id charonhost_nw_proxy_config_create_oblivious_http(id, const char *, const uint8_t *, size_t);
extern void charonhost_nw_proxy_config_set_username_and_password(id, const char *, const char *);
extern void charonhost_nw_proxy_config_set_failover_allowed(id, bool);
extern bool charonhost_nw_proxy_config_get_failover_allowed(id);
extern void charonhost_nw_proxy_config_add_match_domain(id, const char *);
extern void charonhost_nw_proxy_config_add_excluded_domain(id, const char *);
extern void charonhost_nw_proxy_config_clear_match_domains(id);
extern void charonhost_nw_proxy_config_clear_excluded_domains(id);
extern void charonhost_nw_proxy_config_enumerate_match_domains(id, void (^)(const char *));
extern void charonhost_nw_proxy_config_enumerate_excluded_domains(id, void (^)(const char *));
extern void charonhost_nw_privacy_context_add_proxy(nw_privacy_context_t, id);
extern void charonhost_nw_privacy_context_clear_proxies(nw_privacy_context_t);
extern void charonhost_nw_parameters_prohibit_interface(nw_parameters_t, nw_interface_t);
extern void charonhost_nw_parameters_clear_prohibited_interfaces(nw_parameters_t);
extern void charonhost_nw_parameters_iterate_prohibited_interfaces(nw_parameters_t, nw_parameters_iterate_interfaces_block_t);
extern nw_path_monitor_t charonhost_nw_path_monitor_create(void);
extern void charonhost_nw_path_monitor_set_queue(nw_path_monitor_t, dispatch_queue_t);
extern void charonhost_nw_path_monitor_set_update_handler(nw_path_monitor_t, nw_path_monitor_update_handler_t);
extern void charonhost_nw_path_monitor_start(nw_path_monitor_t);
extern void charonhost_nw_path_monitor_cancel(nw_path_monitor_t);
extern bool charonhost_nw_path_is_constrained(nw_path_t);
extern void charonhost_nw_path_enumerate_gateways(nw_path_t, void (^)(nw_endpoint_t));
extern nw_path_unsatisfied_reason_t charonhost_nw_path_get_unsatisfied_reason(nw_path_t);
/* The path's own decision about an interface, asked with synthetic types: what the release's
   path does with a tunnel and a bridge is measured on the host and is the same. */
extern bool charon_path_wants_interface(nw_interface_type_t required, nw_interface_type_t type, bool reachable,
                                        bool cellular, bool hasAddress);
extern int charonhost_nw_path_get_link_quality(nw_path_t);
/* The port's own interface classifier, over the AF_LINK entry of an interface. */
extern nw_interface_type_t charon_path_interface_type(const struct ifaddrs *item);
extern int charonhost_nw_path_get_link_quality(nw_path_t);
extern bool charonhost_nw_path_is_ultra_constrained(nw_path_t);
extern void *P(nw_retain)(void *);
extern void P(nw_release)(void *);
extern nw_error_domain_t P(nw_error_get_error_domain)(nw_error_t);
extern int P(nw_error_get_error_code)(nw_error_t);
extern CFErrorRef P(nw_error_copy_cf_error)(nw_error_t);
extern nw_endpoint_t P(nw_endpoint_create_host)(const char *, const char *);
extern nw_endpoint_t P(nw_endpoint_create_address)(const struct sockaddr *);
extern nw_endpoint_t P(nw_endpoint_create_bonjour_service)(const char *, const char *, const char *);
extern nw_endpoint_t P(nw_endpoint_create_url)(const char *);
extern nw_endpoint_type_t P(nw_endpoint_get_type)(nw_endpoint_t);
extern const char *P(nw_endpoint_get_hostname)(nw_endpoint_t);
extern uint16_t P(nw_endpoint_get_port)(nw_endpoint_t);
extern const struct sockaddr *P(nw_endpoint_get_address)(nw_endpoint_t);
extern const char *P(nw_endpoint_get_bonjour_service_name)(nw_endpoint_t);
extern const char *P(nw_endpoint_get_bonjour_service_type)(nw_endpoint_t);
extern const char *P(nw_endpoint_get_bonjour_service_domain)(nw_endpoint_t);
extern const char *P(nw_endpoint_get_url)(nw_endpoint_t);
extern char *P(nw_endpoint_copy_address_string)(nw_endpoint_t);
extern char *P(nw_endpoint_copy_port_string)(nw_endpoint_t);
extern nw_txt_record_t P(nw_endpoint_copy_txt_record)(nw_endpoint_t);
extern const uint8_t *P(nw_endpoint_get_signature)(nw_endpoint_t, size_t *);
extern nw_parameters_t P(nw_parameters_create)(void);
extern nw_parameters_t P(nw_parameters_create_secure_tcp)(nw_parameters_configure_protocol_block_t, nw_parameters_configure_protocol_block_t);
extern nw_parameters_t P(nw_parameters_create_secure_udp)(nw_parameters_configure_protocol_block_t, nw_parameters_configure_protocol_block_t);
extern nw_parameters_t P(nw_parameters_create_quic)(nw_parameters_configure_protocol_block_t);
extern nw_parameters_t P(nw_parameters_create_application_service)(void);
extern nw_parameters_t P(nw_parameters_copy)(nw_parameters_t);
extern nw_protocol_stack_t P(nw_parameters_copy_default_protocol_stack)(nw_parameters_t);
extern nw_endpoint_t P(nw_parameters_copy_local_endpoint)(nw_parameters_t);
extern void P(nw_parameters_set_local_endpoint)(nw_parameters_t, nw_endpoint_t);
extern bool P(nw_parameters_get_prohibit_expensive)(nw_parameters_t);
extern void P(nw_parameters_set_prohibit_expensive)(nw_parameters_t, bool);
extern bool P(nw_parameters_get_prohibit_constrained)(nw_parameters_t);
extern void P(nw_parameters_set_prohibit_constrained)(nw_parameters_t, bool);
extern bool P(nw_parameters_get_local_only)(nw_parameters_t);
extern void P(nw_parameters_set_local_only)(nw_parameters_t, bool);
extern bool P(nw_parameters_get_fast_open_enabled)(nw_parameters_t);
extern void P(nw_parameters_set_fast_open_enabled)(nw_parameters_t, bool);
extern bool P(nw_parameters_get_include_peer_to_peer)(nw_parameters_t);
extern void P(nw_parameters_set_include_peer_to_peer)(nw_parameters_t, bool);
extern bool P(nw_parameters_get_reuse_local_address)(nw_parameters_t);
extern void P(nw_parameters_set_reuse_local_address)(nw_parameters_t, bool);
extern bool P(nw_parameters_get_prefer_no_proxy)(nw_parameters_t);
extern void P(nw_parameters_set_prefer_no_proxy)(nw_parameters_t, bool);
extern bool P(nw_parameters_get_allow_ultra_constrained)(nw_parameters_t);
extern void P(nw_parameters_set_allow_ultra_constrained)(nw_parameters_t, bool);
extern bool P(nw_parameters_requires_dnssec_validation)(nw_parameters_t);
extern void P(nw_parameters_set_requires_dnssec_validation)(nw_parameters_t, bool);
extern nw_service_class_t P(nw_parameters_get_service_class)(nw_parameters_t);
extern void P(nw_parameters_set_service_class)(nw_parameters_t, nw_service_class_t);
extern nw_multipath_service_t P(nw_parameters_get_multipath_service)(nw_parameters_t);
extern void P(nw_parameters_set_multipath_service)(nw_parameters_t, nw_multipath_service_t);
extern nw_parameters_expired_dns_behavior_t P(nw_parameters_get_expired_dns_behavior)(nw_parameters_t);
extern void P(nw_parameters_set_expired_dns_behavior)(nw_parameters_t, nw_parameters_expired_dns_behavior_t);
extern nw_parameters_attribution_t P(nw_parameters_get_attribution)(nw_parameters_t);
extern void P(nw_parameters_set_attribution)(nw_parameters_t, nw_parameters_attribution_t);
extern nw_interface_type_t P(nw_parameters_get_required_interface_type)(nw_parameters_t);
extern void P(nw_parameters_set_required_interface_type)(nw_parameters_t, nw_interface_type_t);
extern nw_interface_t P(nw_parameters_copy_required_interface)(nw_parameters_t);
extern void P(nw_parameters_require_interface)(nw_parameters_t, nw_interface_t);
extern void P(nw_parameters_prohibit_interface_type)(nw_parameters_t, nw_interface_type_t);
extern void P(nw_parameters_clear_prohibited_interface_types)(nw_parameters_t);
extern void P(nw_parameters_iterate_prohibited_interface_types)(nw_parameters_t, nw_parameters_iterate_interface_types_block_t);
extern void P(nw_parameters_set_privacy_context)(nw_parameters_t, nw_privacy_context_t);
extern nw_protocol_options_t P(nw_protocol_stack_copy_internet_protocol)(nw_protocol_stack_t);
extern nw_protocol_options_t P(nw_protocol_stack_copy_transport_protocol)(nw_protocol_stack_t);
extern void P(nw_protocol_stack_set_transport_protocol)(nw_protocol_stack_t, nw_protocol_options_t);
extern void P(nw_protocol_stack_prepend_application_protocol)(nw_protocol_stack_t, nw_protocol_options_t);
extern void P(nw_protocol_stack_clear_application_protocols)(nw_protocol_stack_t);
extern void P(nw_protocol_stack_iterate_application_protocols)(nw_protocol_stack_t, nw_protocol_stack_iterate_protocols_block_t);
extern bool P(nw_protocol_definition_is_equal)(nw_protocol_definition_t, nw_protocol_definition_t);
extern nw_protocol_definition_t P(nw_protocol_options_copy_definition)(nw_protocol_options_t);
extern nw_protocol_definition_t P(nw_protocol_metadata_copy_definition)(nw_protocol_metadata_t);
extern nw_protocol_definition_t P(nw_protocol_copy_tcp_definition)(void);
extern nw_protocol_definition_t P(nw_protocol_copy_udp_definition)(void);
extern nw_protocol_definition_t P(nw_protocol_copy_ip_definition)(void);
extern nw_protocol_definition_t P(nw_protocol_copy_tls_definition)(void);
extern nw_protocol_definition_t P(nw_protocol_copy_ws_definition)(void);
extern nw_protocol_definition_t P(nw_protocol_copy_quic_definition)(void);
extern bool P(nw_protocol_metadata_is_tcp)(nw_protocol_metadata_t);
extern bool P(nw_protocol_metadata_is_udp)(nw_protocol_metadata_t);
extern bool P(nw_protocol_metadata_is_ip)(nw_protocol_metadata_t);
extern bool P(nw_protocol_metadata_is_tls)(nw_protocol_metadata_t);
extern bool P(nw_protocol_metadata_is_ws)(nw_protocol_metadata_t);
extern bool P(nw_protocol_metadata_is_quic)(nw_protocol_metadata_t);
extern bool P(nw_protocol_options_is_quic)(nw_protocol_options_t);
extern nw_protocol_options_t P(nw_tcp_create_options)(void);
extern nw_protocol_options_t P(nw_udp_create_options)(void);
extern nw_protocol_options_t P(nw_tls_create_options)(void);
extern nw_protocol_options_t P(nw_quic_create_options)(void);
extern nw_protocol_options_t P(nw_ws_create_options)(nw_ws_version_t);
extern nw_protocol_metadata_t P(nw_ip_create_metadata)(void);
extern nw_protocol_metadata_t P(nw_udp_create_metadata)(void);
extern nw_protocol_metadata_t P(nw_ws_create_metadata)(nw_ws_opcode_t);
extern void P(nw_tcp_options_set_no_delay)(nw_protocol_options_t, bool);
extern void P(nw_tcp_options_set_no_options)(nw_protocol_options_t, bool);
extern void P(nw_tcp_options_set_no_push)(nw_protocol_options_t, bool);
extern void P(nw_tcp_options_set_disable_ecn)(nw_protocol_options_t, bool);
extern void P(nw_tcp_options_set_disable_ack_stretching)(nw_protocol_options_t, bool);
extern void P(nw_tcp_options_set_retransmit_fin_drop)(nw_protocol_options_t, bool);
extern void P(nw_tcp_options_set_enable_fast_open)(nw_protocol_options_t, bool);
extern void P(nw_tcp_options_set_enable_keepalive)(nw_protocol_options_t, bool);
extern void P(nw_tcp_options_set_connection_timeout)(nw_protocol_options_t, uint32_t);
extern void P(nw_tcp_options_set_keepalive_count)(nw_protocol_options_t, uint32_t);
extern void P(nw_tcp_options_set_keepalive_idle_time)(nw_protocol_options_t, uint32_t);
extern void P(nw_tcp_options_set_keepalive_interval)(nw_protocol_options_t, uint32_t);
extern void P(nw_tcp_options_set_maximum_segment_size)(nw_protocol_options_t, uint32_t);
extern void P(nw_tcp_options_set_persist_timeout)(nw_protocol_options_t, uint32_t);
extern void P(nw_tcp_options_set_retransmit_connection_drop_time)(nw_protocol_options_t, uint32_t);
extern void P(nw_tcp_options_set_multipath_force_version)(nw_protocol_options_t, nw_multipath_version_t);
extern void P(nw_udp_options_set_prefer_no_checksum)(nw_protocol_options_t, bool);
extern void P(nw_ip_options_set_version)(nw_protocol_options_t, nw_ip_version_t);
extern void P(nw_ip_options_set_hop_limit)(nw_protocol_options_t, uint8_t);
extern void P(nw_ip_options_set_calculate_receive_time)(nw_protocol_options_t, bool);
extern void P(nw_ip_options_set_disable_fragmentation)(nw_protocol_options_t, bool);
extern void P(nw_ip_options_set_use_minimum_mtu)(nw_protocol_options_t, bool);
extern void P(nw_ip_options_set_local_address_preference)(nw_protocol_options_t, nw_ip_local_address_preference_t);
extern void P(nw_ip_options_set_disable_multicast_loopback)(nw_protocol_options_t, bool);
extern nw_service_class_t P(nw_ip_metadata_get_service_class)(nw_protocol_metadata_t);
extern void P(nw_ip_metadata_set_service_class)(nw_protocol_metadata_t, nw_service_class_t);
extern nw_ip_ecn_flag_t P(nw_ip_metadata_get_ecn_flag)(nw_protocol_metadata_t);
extern void P(nw_ip_metadata_set_ecn_flag)(nw_protocol_metadata_t, nw_ip_ecn_flag_t);
extern uint64_t P(nw_ip_metadata_get_receive_time)(nw_protocol_metadata_t);
extern uint32_t P(nw_tcp_get_available_send_buffer)(nw_protocol_metadata_t);
extern uint32_t P(nw_tcp_get_available_receive_buffer)(nw_protocol_metadata_t);
extern sec_protocol_options_t P(nw_tls_copy_sec_protocol_options)(nw_protocol_options_t);
extern sec_protocol_metadata_t P(nw_tls_copy_sec_protocol_metadata)(nw_protocol_metadata_t);
extern sec_protocol_options_t P(nw_quic_copy_sec_protocol_options)(nw_protocol_options_t);
extern sec_protocol_metadata_t P(nw_quic_copy_sec_protocol_metadata)(nw_protocol_metadata_t);
extern nw_content_context_t P(nw_content_context_create)(const char *);
extern const char *P(nw_content_context_get_identifier)(nw_content_context_t);
extern double P(nw_content_context_get_relative_priority)(nw_content_context_t);
extern void P(nw_content_context_set_relative_priority)(nw_content_context_t, double);
extern uint64_t P(nw_content_context_get_expiration_milliseconds)(nw_content_context_t);
extern void P(nw_content_context_set_expiration_milliseconds)(nw_content_context_t, uint64_t);
extern bool P(nw_content_context_get_is_final)(nw_content_context_t);
extern void P(nw_content_context_set_is_final)(nw_content_context_t, bool);
extern nw_content_context_t P(nw_content_context_copy_antecedent)(nw_content_context_t);
extern void P(nw_content_context_set_antecedent)(nw_content_context_t, nw_content_context_t);
extern nw_protocol_metadata_t P(nw_content_context_copy_protocol_metadata)(nw_content_context_t, nw_protocol_definition_t);
extern void P(nw_content_context_set_metadata_for_protocol)(nw_content_context_t, nw_protocol_metadata_t);
extern void P(nw_content_context_foreach_protocol_metadata)(nw_content_context_t, void (^)(nw_protocol_definition_t, nw_protocol_metadata_t));
extern nw_txt_record_t P(nw_txt_record_create_dictionary)(void);
extern nw_txt_record_t P(nw_txt_record_create_with_bytes)(const uint8_t *, size_t);
extern nw_txt_record_t P(nw_txt_record_copy)(nw_txt_record_t);
extern size_t P(nw_txt_record_get_key_count)(nw_txt_record_t);
extern bool P(nw_txt_record_is_dictionary)(nw_txt_record_t);
extern bool P(nw_txt_record_is_equal)(nw_txt_record_t, nw_txt_record_t);
extern nw_txt_record_find_key_t P(nw_txt_record_find_key)(nw_txt_record_t, const char *);
extern bool P(nw_txt_record_set_key)(nw_txt_record_t, const char *, const uint8_t *, size_t);
extern bool P(nw_txt_record_remove_key)(nw_txt_record_t, const char *);
extern bool P(nw_txt_record_access_key)(nw_txt_record_t, const char *, nw_txt_record_access_key_t);
extern bool P(nw_txt_record_apply)(nw_txt_record_t, nw_txt_record_applier_t);
extern bool P(nw_txt_record_access_bytes)(nw_txt_record_t, nw_txt_record_access_bytes_t);
extern nw_ws_opcode_t P(nw_ws_metadata_get_opcode)(nw_protocol_metadata_t);
extern nw_ws_close_code_t P(nw_ws_metadata_get_close_code)(nw_protocol_metadata_t);
extern void P(nw_ws_metadata_set_close_code)(nw_protocol_metadata_t, nw_ws_close_code_t);
extern nw_ws_response_t P(nw_ws_metadata_copy_server_response)(nw_protocol_metadata_t);
extern void P(nw_ws_metadata_set_pong_handler)(nw_protocol_metadata_t, dispatch_queue_t, nw_ws_pong_handler_t);
extern void P(nw_ws_options_add_subprotocol)(nw_protocol_options_t, const char *);
extern void P(nw_ws_options_add_additional_header)(nw_protocol_options_t, const char *, const char *);
extern void P(nw_ws_options_set_auto_reply_ping)(nw_protocol_options_t, bool);
extern void P(nw_ws_options_set_maximum_message_size)(nw_protocol_options_t, size_t);
extern void P(nw_ws_options_set_skip_handshake)(nw_protocol_options_t, bool);
extern void P(nw_ws_options_set_client_request_handler)(nw_protocol_options_t, dispatch_queue_t, nw_ws_client_request_handler_t);
extern nw_ws_response_t P(nw_ws_response_create)(nw_ws_response_status_t, const char *);
extern nw_ws_response_status_t P(nw_ws_response_get_status)(nw_ws_response_t);
extern const char *P(nw_ws_response_get_selected_subprotocol)(nw_ws_response_t);
extern void P(nw_ws_response_add_additional_header)(nw_ws_response_t, const char *, const char *);
extern bool P(nw_ws_response_enumerate_additional_headers)(nw_ws_response_t, nw_ws_additional_header_enumerator_t);
extern bool P(nw_ws_request_enumerate_subprotocols)(nw_ws_request_t, nw_ws_subprotocol_enumerator_t);
extern bool P(nw_ws_request_enumerate_additional_headers)(nw_ws_request_t, nw_ws_additional_header_enumerator_t);
extern nw_protocol_definition_t P(nw_framer_create_definition)(const char *, uint32_t, nw_framer_start_handler_t);
extern nw_protocol_options_t P(nw_framer_create_options)(nw_protocol_definition_t);
extern void P(nw_framer_options_set_object_value)(nw_protocol_options_t, const char *, id);
extern id P(nw_framer_options_copy_object_value)(nw_protocol_options_t, const char *);
extern nw_framer_message_t P(nw_framer_protocol_create_message)(nw_protocol_definition_t);
extern void P(nw_framer_message_set_value)(nw_framer_message_t, const char *, void *, nw_framer_message_dispose_value_t);
extern bool P(nw_framer_message_access_value)(nw_framer_message_t, const char *, bool (^)(const void *));
extern void P(nw_framer_message_set_object_value)(nw_framer_message_t, const char *, id);
extern id P(nw_framer_message_copy_object_value)(nw_framer_message_t, const char *);
extern bool P(nw_protocol_metadata_is_framer_message)(nw_protocol_metadata_t);
extern void P(nw_quic_set_idle_timeout)(nw_protocol_options_t, uint32_t);
extern uint32_t P(nw_quic_get_idle_timeout)(nw_protocol_options_t);
extern void P(nw_quic_set_max_udp_payload_size)(nw_protocol_options_t, uint16_t);
extern uint16_t P(nw_quic_get_max_udp_payload_size)(nw_protocol_options_t);
extern void P(nw_quic_set_initial_max_data)(nw_protocol_options_t, uint64_t);
extern uint64_t P(nw_quic_get_initial_max_data)(nw_protocol_options_t);
extern void P(nw_quic_set_initial_max_stream_data_bidirectional_local)(nw_protocol_options_t, uint64_t);
extern uint64_t P(nw_quic_get_initial_max_stream_data_bidirectional_local)(nw_protocol_options_t);
extern void P(nw_quic_set_initial_max_stream_data_bidirectional_remote)(nw_protocol_options_t, uint64_t);
extern uint64_t P(nw_quic_get_initial_max_stream_data_bidirectional_remote)(nw_protocol_options_t);
extern void P(nw_quic_set_initial_max_stream_data_unidirectional)(nw_protocol_options_t, uint64_t);
extern uint64_t P(nw_quic_get_initial_max_stream_data_unidirectional)(nw_protocol_options_t);
extern void P(nw_quic_set_initial_max_streams_bidirectional)(nw_protocol_options_t, uint64_t);
extern uint64_t P(nw_quic_get_initial_max_streams_bidirectional)(nw_protocol_options_t);
extern void P(nw_quic_set_initial_max_streams_unidirectional)(nw_protocol_options_t, uint64_t);
extern uint64_t P(nw_quic_get_initial_max_streams_unidirectional)(nw_protocol_options_t);
extern void P(nw_quic_set_stream_is_unidirectional)(nw_protocol_options_t, bool);
extern bool P(nw_quic_get_stream_is_unidirectional)(nw_protocol_options_t);
extern void P(nw_quic_set_stream_is_datagram)(nw_protocol_options_t, bool);
extern bool P(nw_quic_get_stream_is_datagram)(nw_protocol_options_t);
extern void P(nw_quic_set_max_datagram_frame_size)(nw_protocol_options_t, uint16_t);
extern uint16_t P(nw_quic_get_max_datagram_frame_size)(nw_protocol_options_t);
extern void P(nw_quic_add_tls_application_protocol)(nw_protocol_options_t, const char *);
extern void P(nw_quic_set_keepalive_interval)(nw_protocol_metadata_t, uint16_t);
extern uint16_t P(nw_quic_get_keepalive_interval)(nw_protocol_metadata_t);
extern void P(nw_quic_set_local_max_streams_bidirectional)(nw_protocol_metadata_t, uint64_t);
extern uint64_t P(nw_quic_get_local_max_streams_bidirectional)(nw_protocol_metadata_t);
extern void P(nw_quic_set_local_max_streams_unidirectional)(nw_protocol_metadata_t, uint64_t);
extern uint64_t P(nw_quic_get_local_max_streams_unidirectional)(nw_protocol_metadata_t);
extern uint64_t P(nw_quic_get_remote_idle_timeout)(nw_protocol_metadata_t);
extern uint64_t P(nw_quic_get_remote_max_streams_bidirectional)(nw_protocol_metadata_t);
extern uint64_t P(nw_quic_get_remote_max_streams_unidirectional)(nw_protocol_metadata_t);
extern void P(nw_quic_set_application_error)(nw_protocol_metadata_t, uint64_t, const char *);
extern uint64_t P(nw_quic_get_application_error)(nw_protocol_metadata_t);
extern const char *P(nw_quic_get_application_error_reason)(nw_protocol_metadata_t);
extern void P(nw_quic_set_stream_application_error)(nw_protocol_metadata_t, uint64_t);
extern uint64_t P(nw_quic_get_stream_application_error)(nw_protocol_metadata_t);
extern uint64_t P(nw_quic_get_stream_id)(nw_protocol_metadata_t);
extern uint8_t P(nw_quic_get_stream_type)(nw_protocol_metadata_t);
extern uint16_t P(nw_quic_get_stream_usable_datagram_frame_size)(nw_protocol_metadata_t);
extern nw_browse_descriptor_t P(nw_browse_descriptor_create_bonjour_service)(const char *, const char *);
extern const char *P(nw_browse_descriptor_get_bonjour_service_type)(nw_browse_descriptor_t);
extern const char *P(nw_browse_descriptor_get_bonjour_service_domain)(nw_browse_descriptor_t);
extern bool P(nw_browse_descriptor_get_include_txt_record)(nw_browse_descriptor_t);
extern void P(nw_browse_descriptor_set_include_txt_record)(nw_browse_descriptor_t, bool);
extern nw_browse_descriptor_t P(nw_browse_descriptor_create_application_service)(const char *);
extern const char *P(nw_browse_descriptor_get_application_service_name)(nw_browse_descriptor_t);
extern nw_advertise_descriptor_t P(nw_advertise_descriptor_create_bonjour_service)(const char *, const char *, const char *);
extern bool P(nw_advertise_descriptor_get_no_auto_rename)(nw_advertise_descriptor_t);
extern void P(nw_advertise_descriptor_set_no_auto_rename)(nw_advertise_descriptor_t, bool);
extern void P(nw_advertise_descriptor_set_txt_record)(nw_advertise_descriptor_t, const void *, size_t);
extern void P(nw_advertise_descriptor_set_txt_record_object)(nw_advertise_descriptor_t, nw_txt_record_t);
extern nw_txt_record_t P(nw_advertise_descriptor_copy_txt_record_object)(nw_advertise_descriptor_t);
extern nw_advertise_descriptor_t P(nw_advertise_descriptor_create_application_service)(const char *);
extern const char *P(nw_advertise_descriptor_get_application_service_name)(nw_advertise_descriptor_t);
extern nw_group_descriptor_t P(nw_group_descriptor_create_multicast)(nw_endpoint_t);
extern bool P(nw_group_descriptor_add_endpoint)(nw_group_descriptor_t, nw_endpoint_t);
extern void P(nw_group_descriptor_enumerate_endpoints)(nw_group_descriptor_t, nw_group_descriptor_enumerate_endpoints_block_t);
extern void P(nw_multicast_group_descriptor_set_specific_source)(nw_group_descriptor_t, nw_endpoint_t);
extern void P(nw_multicast_group_descriptor_set_disable_unicast_traffic)(nw_group_descriptor_t, bool);
extern bool P(nw_multicast_group_descriptor_get_disable_unicast_traffic)(nw_group_descriptor_t);
extern nw_group_descriptor_t P(nw_group_descriptor_create_multiplex)(nw_endpoint_t);
extern nw_privacy_context_t P(nw_privacy_context_create)(const char *);
extern void P(nw_privacy_context_disable_logging)(nw_privacy_context_t);
extern void P(nw_privacy_context_require_encrypted_name_resolution)(nw_privacy_context_t, bool, nw_resolver_config_t);
extern void P(nw_privacy_context_flush_cache)(nw_privacy_context_t);
extern nw_resolver_config_t P(nw_resolver_config_create_tls)(nw_endpoint_t);
extern nw_resolver_config_t P(nw_resolver_config_create_https)(nw_endpoint_t);
extern void P(nw_resolver_config_add_server_address)(nw_resolver_config_t, nw_endpoint_t);
extern nw_data_transfer_report_state_t P(nw_data_transfer_report_get_state)(nw_data_transfer_report_t);
extern void P(nw_data_transfer_report_collect)(nw_data_transfer_report_t, dispatch_queue_t, nw_data_transfer_report_collect_block_t);
extern uint64_t P(nw_data_transfer_report_get_duration_milliseconds)(nw_data_transfer_report_t);
extern uint32_t P(nw_data_transfer_report_get_path_count)(nw_data_transfer_report_t);
extern uint64_t P(nw_data_transfer_report_get_sent_application_byte_count)(nw_data_transfer_report_t, uint32_t);
extern uint64_t P(nw_data_transfer_report_get_received_application_byte_count)(nw_data_transfer_report_t, uint32_t);
extern uint64_t P(nw_data_transfer_report_get_sent_transport_byte_count)(nw_data_transfer_report_t, uint32_t);
extern uint64_t P(nw_data_transfer_report_get_received_transport_byte_count)(nw_data_transfer_report_t, uint32_t);
extern uint64_t P(nw_data_transfer_report_get_sent_transport_retransmitted_byte_count)(nw_data_transfer_report_t, uint32_t);
extern uint64_t P(nw_data_transfer_report_get_received_transport_duplicate_byte_count)(nw_data_transfer_report_t, uint32_t);
extern uint64_t P(nw_data_transfer_report_get_received_transport_out_of_order_byte_count)(nw_data_transfer_report_t, uint32_t);
extern uint64_t P(nw_data_transfer_report_get_sent_ip_packet_count)(nw_data_transfer_report_t, uint32_t);
extern uint64_t P(nw_data_transfer_report_get_received_ip_packet_count)(nw_data_transfer_report_t, uint32_t);
extern uint64_t P(nw_data_transfer_report_get_transport_smoothed_rtt_milliseconds)(nw_data_transfer_report_t, uint32_t);
extern uint64_t P(nw_data_transfer_report_get_transport_minimum_rtt_milliseconds)(nw_data_transfer_report_t, uint32_t);
extern uint64_t P(nw_data_transfer_report_get_transport_rtt_variance)(nw_data_transfer_report_t, uint32_t);
extern nw_interface_t P(nw_data_transfer_report_copy_path_interface)(nw_data_transfer_report_t, uint32_t);
extern nw_interface_radio_type_t P(nw_data_transfer_report_get_path_radio_type)(nw_data_transfer_report_t, uint32_t);

/* The two sentinel blocks are compared by pointer, so each side is given its own: a factory that was
   given the other's sentinel sees a block of one's own, which is what a program passing nothing sees. */
extern const nw_parameters_configure_protocol_block_t charonhost__nw_parameters_configure_protocol_default_configuration;
extern const nw_parameters_configure_protocol_block_t charonhost__nw_parameters_configure_protocol_disable;
#define SYSTEM_DEFAULT NW_PARAMETERS_DEFAULT_CONFIGURATION
#define SYSTEM_DISABLE NW_PARAMETERS_DISABLE_PROTOCOL
#define PORT_DEFAULT ((nw_parameters_configure_protocol_block_t)charonhost__nw_parameters_configure_protocol_default_configuration)
#define PORT_DISABLE ((nw_parameters_configure_protocol_block_t)charonhost__nw_parameters_configure_protocol_disable)

/* ---------------------------------------------------------------- the one table both sides answer through */

typedef struct {
    nw_endpoint_t (*endpoint_host)(const char *, const char *);
    nw_endpoint_t (*endpoint_address)(const struct sockaddr *);
    nw_endpoint_t (*endpoint_bonjour)(const char *, const char *, const char *);
    nw_endpoint_t (*endpoint_url)(const char *);
    nw_endpoint_type_t (*endpoint_type)(nw_endpoint_t);
    const char *(*endpoint_hostname)(nw_endpoint_t);
    uint16_t (*endpoint_port)(nw_endpoint_t);
    const struct sockaddr *(*endpoint_address_of)(nw_endpoint_t);
    const char *(*bonjour_name)(nw_endpoint_t);
    const char *(*bonjour_type)(nw_endpoint_t);
    const char *(*bonjour_domain)(nw_endpoint_t);
    const char *(*endpoint_url_text)(nw_endpoint_t);
    char *(*endpoint_address_string)(nw_endpoint_t);
    char *(*endpoint_port_string)(nw_endpoint_t);
    nw_txt_record_t (*endpoint_txt_record)(nw_endpoint_t);
    const uint8_t *(*endpoint_signature)(nw_endpoint_t, size_t *);

    nw_parameters_t (*parameters_create)(void);
    nw_parameters_t (*parameters_secure_tcp)(nw_parameters_configure_protocol_block_t, nw_parameters_configure_protocol_block_t);
    nw_parameters_t (*parameters_secure_udp)(nw_parameters_configure_protocol_block_t, nw_parameters_configure_protocol_block_t);
    nw_parameters_t (*parameters_quic)(nw_parameters_configure_protocol_block_t);
    nw_parameters_t (*parameters_application_service)(void);
    nw_parameters_t (*parameters_copy)(nw_parameters_t);
    nw_protocol_stack_t (*parameters_stack)(nw_parameters_t);
    nw_endpoint_t (*parameters_local_endpoint)(nw_parameters_t);
    void (*parameters_set_local_endpoint)(nw_parameters_t, nw_endpoint_t);
    bool (*prohibit_expensive)(nw_parameters_t);
    void (*set_prohibit_expensive)(nw_parameters_t, bool);
    bool (*prohibit_constrained)(nw_parameters_t);
    void (*set_prohibit_constrained)(nw_parameters_t, bool);
    bool (*local_only)(nw_parameters_t);
    void (*set_local_only)(nw_parameters_t, bool);
    bool (*fast_open)(nw_parameters_t);
    void (*set_fast_open)(nw_parameters_t, bool);
    bool (*peer_to_peer)(nw_parameters_t);
    void (*set_peer_to_peer)(nw_parameters_t, bool);
    bool (*reuse_local_address)(nw_parameters_t);
    void (*set_reuse_local_address)(nw_parameters_t, bool);
    bool (*prefer_no_proxy)(nw_parameters_t);
    void (*set_prefer_no_proxy)(nw_parameters_t, bool);
    bool (*allow_ultra_constrained)(nw_parameters_t);
    void (*set_allow_ultra_constrained)(nw_parameters_t, bool);
    bool (*dnssec)(nw_parameters_t);
    void (*set_dnssec)(nw_parameters_t, bool);
    nw_service_class_t (*service_class)(nw_parameters_t);
    void (*set_service_class)(nw_parameters_t, nw_service_class_t);
    nw_multipath_service_t (*multipath)(nw_parameters_t);
    void (*set_multipath)(nw_parameters_t, nw_multipath_service_t);
    nw_parameters_expired_dns_behavior_t (*expired_dns)(nw_parameters_t);
    void (*set_expired_dns)(nw_parameters_t, nw_parameters_expired_dns_behavior_t);
    nw_parameters_attribution_t (*attribution)(nw_parameters_t);
    void (*set_attribution)(nw_parameters_t, nw_parameters_attribution_t);
    nw_interface_type_t (*required_type)(nw_parameters_t);
    void (*set_required_type)(nw_parameters_t, nw_interface_type_t);
    nw_interface_t (*required_interface)(nw_parameters_t);
    void (*require_interface)(nw_parameters_t, nw_interface_t);
    void (*prohibit_type)(nw_parameters_t, nw_interface_type_t);
    void (*clear_prohibited_types)(nw_parameters_t);
    void (*iterate_prohibited_types)(nw_parameters_t, nw_parameters_iterate_interface_types_block_t);
    void (*set_privacy)(nw_parameters_t, nw_privacy_context_t);

    nw_protocol_options_t (*stack_internet)(nw_protocol_stack_t);
    nw_protocol_options_t (*stack_transport)(nw_protocol_stack_t);
    void (*stack_set_transport)(nw_protocol_stack_t, nw_protocol_options_t);
    void (*stack_prepend)(nw_protocol_stack_t, nw_protocol_options_t);
    void (*stack_clear)(nw_protocol_stack_t);
    void (*stack_iterate)(nw_protocol_stack_t, nw_protocol_stack_iterate_protocols_block_t);

    bool (*definition_equal)(nw_protocol_definition_t, nw_protocol_definition_t);
    nw_protocol_definition_t (*options_definition)(nw_protocol_options_t);
    nw_protocol_definition_t (*metadata_definition)(nw_protocol_metadata_t);
    nw_protocol_definition_t (*definition_tcp)(void);
    nw_protocol_definition_t (*definition_udp)(void);
    nw_protocol_definition_t (*definition_ip)(void);
    nw_protocol_definition_t (*definition_tls)(void);
    nw_protocol_definition_t (*definition_ws)(void);
    nw_protocol_definition_t (*definition_quic)(void);
    bool (*is_tcp)(nw_protocol_metadata_t);
    bool (*is_udp)(nw_protocol_metadata_t);
    bool (*is_ip)(nw_protocol_metadata_t);
    bool (*is_tls)(nw_protocol_metadata_t);
    bool (*is_ws)(nw_protocol_metadata_t);
    bool (*is_quic)(nw_protocol_metadata_t);
    bool (*options_is_quic)(nw_protocol_options_t);
    nw_protocol_options_t (*tcp_options)(void);
    nw_protocol_options_t (*udp_options)(void);
    nw_protocol_options_t (*tls_options)(void);
    nw_protocol_options_t (*quic_options)(void);
    nw_protocol_options_t (*ws_options)(nw_ws_version_t);
    nw_protocol_metadata_t (*ip_metadata)(void);
    nw_protocol_metadata_t (*udp_metadata)(void);
    nw_protocol_metadata_t (*ws_metadata)(nw_ws_opcode_t);
    void (*tcp_no_delay)(nw_protocol_options_t, bool);
    void (*tcp_no_options)(nw_protocol_options_t, bool);
    void (*tcp_no_push)(nw_protocol_options_t, bool);
    void (*tcp_disable_ecn)(nw_protocol_options_t, bool);
    void (*tcp_disable_ack)(nw_protocol_options_t, bool);
    void (*tcp_retransmit_fin)(nw_protocol_options_t, bool);
    void (*tcp_fast_open)(nw_protocol_options_t, bool);
    void (*tcp_keepalive)(nw_protocol_options_t, bool);
    void (*tcp_connection_timeout)(nw_protocol_options_t, uint32_t);
    void (*tcp_keepalive_count)(nw_protocol_options_t, uint32_t);
    void (*tcp_keepalive_idle)(nw_protocol_options_t, uint32_t);
    void (*tcp_keepalive_interval)(nw_protocol_options_t, uint32_t);
    void (*tcp_mss)(nw_protocol_options_t, uint32_t);
    void (*tcp_persist)(nw_protocol_options_t, uint32_t);
    void (*tcp_drop_time)(nw_protocol_options_t, uint32_t);
    void (*tcp_multipath_version)(nw_protocol_options_t, nw_multipath_version_t);
    void (*udp_no_checksum)(nw_protocol_options_t, bool);
    void (*ip_version)(nw_protocol_options_t, nw_ip_version_t);
    void (*ip_hop_limit)(nw_protocol_options_t, uint8_t);
    void (*ip_receive_time)(nw_protocol_options_t, bool);
    void (*ip_no_fragmentation)(nw_protocol_options_t, bool);
    void (*ip_minimum_mtu)(nw_protocol_options_t, bool);
    void (*ip_address_preference)(nw_protocol_options_t, nw_ip_local_address_preference_t);
    void (*ip_no_loopback)(nw_protocol_options_t, bool);
    nw_service_class_t (*ip_service_class)(nw_protocol_metadata_t);
    void (*ip_set_service_class)(nw_protocol_metadata_t, nw_service_class_t);
    nw_ip_ecn_flag_t (*ip_ecn)(nw_protocol_metadata_t);
    void (*ip_set_ecn)(nw_protocol_metadata_t, nw_ip_ecn_flag_t);
    uint64_t (*ip_receive_time_value)(nw_protocol_metadata_t);
    uint32_t (*tcp_send_buffer)(nw_protocol_metadata_t);
    uint32_t (*tcp_receive_buffer)(nw_protocol_metadata_t);
    sec_protocol_options_t (*tls_sec_options)(nw_protocol_options_t);
    sec_protocol_metadata_t (*tls_sec_metadata)(nw_protocol_metadata_t);
    sec_protocol_options_t (*quic_sec_options)(nw_protocol_options_t);
    sec_protocol_metadata_t (*quic_sec_metadata)(nw_protocol_metadata_t);

    nw_content_context_t (*context_create)(const char *);
    const char *(*context_identifier)(nw_content_context_t);
    double (*context_priority)(nw_content_context_t);
    void (*context_set_priority)(nw_content_context_t, double);
    uint64_t (*context_expiration)(nw_content_context_t);
    void (*context_set_expiration)(nw_content_context_t, uint64_t);
    bool (*context_is_final)(nw_content_context_t);
    void (*context_set_final)(nw_content_context_t, bool);
    nw_content_context_t (*context_antecedent)(nw_content_context_t);
    void (*context_set_antecedent)(nw_content_context_t, nw_content_context_t);
    nw_protocol_metadata_t (*context_metadata)(nw_content_context_t, nw_protocol_definition_t);
    void (*context_set_metadata)(nw_content_context_t, nw_protocol_metadata_t);
    void (*context_foreach)(nw_content_context_t, void (^)(nw_protocol_definition_t, nw_protocol_metadata_t));

    nw_txt_record_t (*txt_dictionary)(void);
    nw_txt_record_t (*txt_bytes)(const uint8_t *, size_t);
    nw_txt_record_t (*txt_copy)(nw_txt_record_t);
    size_t (*txt_count)(nw_txt_record_t);
    bool (*txt_is_dictionary)(nw_txt_record_t);
    bool (*txt_equal)(nw_txt_record_t, nw_txt_record_t);
    nw_txt_record_find_key_t (*txt_find)(nw_txt_record_t, const char *);
    bool (*txt_set)(nw_txt_record_t, const char *, const uint8_t *, size_t);
    bool (*txt_remove)(nw_txt_record_t, const char *);
    bool (*txt_access_key)(nw_txt_record_t, const char *, nw_txt_record_access_key_t);
    bool (*txt_apply)(nw_txt_record_t, nw_txt_record_applier_t);
    bool (*txt_access_bytes)(nw_txt_record_t, nw_txt_record_access_bytes_t);

    nw_ws_opcode_t (*ws_opcode)(nw_protocol_metadata_t);
    nw_ws_close_code_t (*ws_close_code)(nw_protocol_metadata_t);
    void (*ws_set_close_code)(nw_protocol_metadata_t, nw_ws_close_code_t);
    nw_ws_response_t (*ws_server_response)(nw_protocol_metadata_t);
    void (*ws_pong_handler)(nw_protocol_metadata_t, dispatch_queue_t, nw_ws_pong_handler_t);
    void (*ws_add_subprotocol)(nw_protocol_options_t, const char *);
    void (*ws_add_header)(nw_protocol_options_t, const char *, const char *);
    void (*ws_auto_ping)(nw_protocol_options_t, bool);
    void (*ws_maximum_message)(nw_protocol_options_t, size_t);
    void (*ws_skip_handshake)(nw_protocol_options_t, bool);
    void (*ws_client_request_handler)(nw_protocol_options_t, dispatch_queue_t, nw_ws_client_request_handler_t);
    nw_ws_response_t (*ws_response_create)(nw_ws_response_status_t, const char *);
    nw_ws_response_status_t (*ws_response_status)(nw_ws_response_t);
    const char *(*ws_response_subprotocol)(nw_ws_response_t);
    void (*ws_response_add_header)(nw_ws_response_t, const char *, const char *);
    bool (*ws_response_headers)(nw_ws_response_t, nw_ws_additional_header_enumerator_t);
    bool (*ws_request_subprotocols)(nw_ws_request_t, nw_ws_subprotocol_enumerator_t);
    bool (*ws_request_headers)(nw_ws_request_t, nw_ws_additional_header_enumerator_t);

    nw_protocol_definition_t (*framer_definition)(const char *, uint32_t, nw_framer_start_handler_t);
    nw_protocol_options_t (*framer_options)(nw_protocol_definition_t);
    void (*framer_set_object)(nw_protocol_options_t, const char *, id);
    id (*framer_copy_object)(nw_protocol_options_t, const char *);
    nw_framer_message_t (*framer_message)(nw_protocol_definition_t);
    void (*message_set_value)(nw_framer_message_t, const char *, void *, nw_framer_message_dispose_value_t);
    bool (*message_access_value)(nw_framer_message_t, const char *, bool (^)(const void *));
    void (*message_set_object)(nw_framer_message_t, const char *, id);
    id (*message_copy_object)(nw_framer_message_t, const char *);
    bool (*metadata_is_framer_message)(nw_protocol_metadata_t);

    void (*quic_idle)(nw_protocol_options_t, uint32_t);
    uint32_t (*quic_idle_value)(nw_protocol_options_t);
    void (*quic_max_udp)(nw_protocol_options_t, uint16_t);
    uint16_t (*quic_max_udp_value)(nw_protocol_options_t);
    void (*quic_max_data)(nw_protocol_options_t, uint64_t);
    uint64_t (*quic_max_data_value)(nw_protocol_options_t);
    void (*quic_data_local)(nw_protocol_options_t, uint64_t);
    uint64_t (*quic_data_local_value)(nw_protocol_options_t);
    void (*quic_data_remote)(nw_protocol_options_t, uint64_t);
    uint64_t (*quic_data_remote_value)(nw_protocol_options_t);
    void (*quic_data_uni)(nw_protocol_options_t, uint64_t);
    uint64_t (*quic_data_uni_value)(nw_protocol_options_t);
    void (*quic_streams_bidi)(nw_protocol_options_t, uint64_t);
    uint64_t (*quic_streams_bidi_value)(nw_protocol_options_t);
    void (*quic_streams_uni)(nw_protocol_options_t, uint64_t);
    uint64_t (*quic_streams_uni_value)(nw_protocol_options_t);
    void (*quic_stream_unidirectional)(nw_protocol_options_t, bool);
    bool (*quic_stream_unidirectional_value)(nw_protocol_options_t);
    void (*quic_stream_datagram)(nw_protocol_options_t, bool);
    bool (*quic_stream_datagram_value)(nw_protocol_options_t);
    void (*quic_datagram_frame)(nw_protocol_options_t, uint16_t);
    uint16_t (*quic_datagram_frame_value)(nw_protocol_options_t);
    void (*quic_add_application_protocol)(nw_protocol_options_t, const char *);
    void (*quic_keepalive)(nw_protocol_metadata_t, uint16_t);
    uint16_t (*quic_keepalive_value)(nw_protocol_metadata_t);
    void (*quic_local_bidi)(nw_protocol_metadata_t, uint64_t);
    uint64_t (*quic_local_bidi_value)(nw_protocol_metadata_t);
    void (*quic_local_uni)(nw_protocol_metadata_t, uint64_t);
    uint64_t (*quic_local_uni_value)(nw_protocol_metadata_t);
    uint64_t (*quic_remote_idle)(nw_protocol_metadata_t);
    uint64_t (*quic_remote_bidi)(nw_protocol_metadata_t);
    uint64_t (*quic_remote_uni)(nw_protocol_metadata_t);
    void (*quic_application_error)(nw_protocol_metadata_t, uint64_t, const char *);
    uint64_t (*quic_application_error_value)(nw_protocol_metadata_t);
    const char *(*quic_application_error_reason)(nw_protocol_metadata_t);
    void (*quic_stream_error)(nw_protocol_metadata_t, uint64_t);
    uint64_t (*quic_stream_error_value)(nw_protocol_metadata_t);
    uint64_t (*quic_stream_id)(nw_protocol_metadata_t);
    uint8_t (*quic_stream_type)(nw_protocol_metadata_t);
    uint16_t (*quic_usable_datagram)(nw_protocol_metadata_t);

    nw_browse_descriptor_t (*browse_bonjour)(const char *, const char *);
    const char *(*browse_type)(nw_browse_descriptor_t);
    const char *(*browse_domain)(nw_browse_descriptor_t);
    bool (*browse_include_txt)(nw_browse_descriptor_t);
    void (*browse_set_include_txt)(nw_browse_descriptor_t, bool);
    nw_browse_descriptor_t (*browse_application)(const char *);
    const char *(*browse_application_name)(nw_browse_descriptor_t);

    nw_advertise_descriptor_t (*advertise_bonjour)(const char *, const char *, const char *);
    bool (*advertise_no_auto_rename)(nw_advertise_descriptor_t);
    void (*advertise_set_no_auto_rename)(nw_advertise_descriptor_t, bool);
    void (*advertise_txt_bytes)(nw_advertise_descriptor_t, const void *, size_t);
    void (*advertise_txt_object)(nw_advertise_descriptor_t, nw_txt_record_t);
    nw_txt_record_t (*advertise_copy_txt_object)(nw_advertise_descriptor_t);
    nw_advertise_descriptor_t (*advertise_application)(const char *);
    const char *(*advertise_application_name)(nw_advertise_descriptor_t);

    nw_group_descriptor_t (*group_multicast)(nw_endpoint_t);
    bool (*group_add)(nw_group_descriptor_t, nw_endpoint_t);
    void (*group_endpoints)(nw_group_descriptor_t, nw_group_descriptor_enumerate_endpoints_block_t);
    void (*group_specific_source)(nw_group_descriptor_t, nw_endpoint_t);
    void (*group_disable_unicast)(nw_group_descriptor_t, bool);
    bool (*group_disable_unicast_value)(nw_group_descriptor_t);
    nw_group_descriptor_t (*group_multiplex)(nw_endpoint_t);

    nw_privacy_context_t (*privacy_create)(const char *);
    void (*privacy_disable_logging)(nw_privacy_context_t);
    void (*privacy_require_encrypted)(nw_privacy_context_t, bool, nw_resolver_config_t);
    void (*privacy_flush)(nw_privacy_context_t);
    nw_resolver_config_t (*resolver_tls)(nw_endpoint_t);
    nw_resolver_config_t (*resolver_https)(nw_endpoint_t);
    void (*resolver_add_server)(nw_resolver_config_t, nw_endpoint_t);

    nw_data_transfer_report_state_t (*report_state)(nw_data_transfer_report_t);
    void (*report_collect)(nw_data_transfer_report_t, dispatch_queue_t, nw_data_transfer_report_collect_block_t);
    uint64_t (*report_duration)(nw_data_transfer_report_t);
    uint32_t (*report_path_count)(nw_data_transfer_report_t);
    uint64_t (*report_sent_application)(nw_data_transfer_report_t, uint32_t);
    uint64_t (*report_received_application)(nw_data_transfer_report_t, uint32_t);
    uint64_t (*report_sent_transport)(nw_data_transfer_report_t, uint32_t);
    uint64_t (*report_received_transport)(nw_data_transfer_report_t, uint32_t);
    uint64_t (*report_sent_retransmitted)(nw_data_transfer_report_t, uint32_t);
    uint64_t (*report_received_duplicate)(nw_data_transfer_report_t, uint32_t);
    uint64_t (*report_received_out_of_order)(nw_data_transfer_report_t, uint32_t);
    uint64_t (*report_sent_packets)(nw_data_transfer_report_t, uint32_t);
    uint64_t (*report_received_packets)(nw_data_transfer_report_t, uint32_t);
    uint64_t (*report_smoothed)(nw_data_transfer_report_t, uint32_t);
    uint64_t (*report_minimum)(nw_data_transfer_report_t, uint32_t);
    uint64_t (*report_variance)(nw_data_transfer_report_t, uint32_t);
    nw_interface_t (*report_interface)(nw_data_transfer_report_t, uint32_t);
    nw_interface_radio_type_t (*report_radio)(nw_data_transfer_report_t, uint32_t);

    id (*relay_hop_create)(nw_endpoint_t, nw_endpoint_t, nw_protocol_options_t);
    void (*relay_hop_add_header)(id, const char *, const char *);
    id (*proxy_http_connect)(nw_endpoint_t, nw_protocol_options_t);
    id (*proxy_socksv5)(nw_endpoint_t);
    id (*proxy_relay)(id, id);
    id (*proxy_oblivious_http)(id, const char *, const uint8_t *, size_t);
    void (*proxy_credentials)(id, const char *, const char *);
    void (*proxy_failover)(id, bool);
    bool (*proxy_failover_value)(id);
    void (*proxy_add_match)(id, const char *);
    void (*proxy_add_excluded)(id, const char *);
    void (*proxy_clear_match)(id);
    void (*proxy_clear_excluded)(id);
    void (*proxy_enumerate_match)(id, void (^)(const char *));
    void (*proxy_enumerate_excluded)(id, void (^)(const char *));
    void (*privacy_add_proxy)(nw_privacy_context_t, id);
    void (*privacy_clear_proxies)(nw_privacy_context_t);
    void (*parameters_prohibit_interface)(nw_parameters_t, nw_interface_t);
    void (*parameters_clear_prohibited_interfaces)(nw_parameters_t);
    void (*parameters_iterate_prohibited_interfaces)(nw_parameters_t, nw_parameters_iterate_interfaces_block_t);
    nw_path_monitor_t (*monitor_path)(void);
    void (*monitor_set_queue)(nw_path_monitor_t, dispatch_queue_t);
    void (*monitor_set_update)(nw_path_monitor_t, nw_path_monitor_update_handler_t);
    void (*monitor_start)(nw_path_monitor_t);
    void (*monitor_cancel)(nw_path_monitor_t);
    bool (*path_is_constrained)(nw_path_t);
    void (*path_enumerate_gateways)(nw_path_t, void (^)(nw_endpoint_t));
    nw_path_unsatisfied_reason_t (*path_unsatisfied_reason)(nw_path_t);
    nw_link_quality_t (*path_link_quality)(nw_path_t);
    bool (*path_is_ultra_constrained)(nw_path_t);

    nw_error_domain_t (*error_domain)(nw_error_t);
    int (*error_code)(nw_error_t);
    CFErrorRef (*error_cf)(nw_error_t);
} API;

/* The two tables name the same fields in the same order: the host's own calls on one side, the port's
   on the other. A call Apple's headers mark as returning a retained object is a different
   function-pointer type from the same call without that mark, so both are written through a void *. */
static API system_api(void)
{
    API api;
    memset(&api, 0, sizeof api);
    void **fields = (void **)&api;
    void *values[] = {
        (void *)nw_endpoint_create_host,
        (void *)nw_endpoint_create_address,
        (void *)nw_endpoint_create_bonjour_service,
        (void *)nw_endpoint_create_url,
        (void *)nw_endpoint_get_type,
        (void *)nw_endpoint_get_hostname,
        (void *)nw_endpoint_get_port,
        (void *)nw_endpoint_get_address,
        (void *)nw_endpoint_get_bonjour_service_name,
        (void *)nw_endpoint_get_bonjour_service_type,
        (void *)nw_endpoint_get_bonjour_service_domain,
        (void *)nw_endpoint_get_url,
        (void *)nw_endpoint_copy_address_string,
        (void *)nw_endpoint_copy_port_string,
        (void *)nw_endpoint_copy_txt_record,
        (void *)nw_endpoint_get_signature,
        (void *)nw_parameters_create,
        (void *)nw_parameters_create_secure_tcp,
        (void *)nw_parameters_create_secure_udp,
        (void *)nw_parameters_create_quic,
        (void *)nw_parameters_create_application_service,
        (void *)nw_parameters_copy,
        (void *)nw_parameters_copy_default_protocol_stack,
        (void *)nw_parameters_copy_local_endpoint,
        (void *)nw_parameters_set_local_endpoint,
        (void *)nw_parameters_get_prohibit_expensive,
        (void *)nw_parameters_set_prohibit_expensive,
        (void *)nw_parameters_get_prohibit_constrained,
        (void *)nw_parameters_set_prohibit_constrained,
        (void *)nw_parameters_get_local_only,
        (void *)nw_parameters_set_local_only,
        (void *)nw_parameters_get_fast_open_enabled,
        (void *)nw_parameters_set_fast_open_enabled,
        (void *)nw_parameters_get_include_peer_to_peer,
        (void *)nw_parameters_set_include_peer_to_peer,
        (void *)nw_parameters_get_reuse_local_address,
        (void *)nw_parameters_set_reuse_local_address,
        (void *)nw_parameters_get_prefer_no_proxy,
        (void *)nw_parameters_set_prefer_no_proxy,
        (void *)nw_parameters_get_allow_ultra_constrained,
        (void *)nw_parameters_set_allow_ultra_constrained,
        (void *)nw_parameters_requires_dnssec_validation,
        (void *)nw_parameters_set_requires_dnssec_validation,
        (void *)nw_parameters_get_service_class,
        (void *)nw_parameters_set_service_class,
        (void *)nw_parameters_get_multipath_service,
        (void *)nw_parameters_set_multipath_service,
        (void *)nw_parameters_get_expired_dns_behavior,
        (void *)nw_parameters_set_expired_dns_behavior,
        (void *)nw_parameters_get_attribution,
        (void *)nw_parameters_set_attribution,
        (void *)nw_parameters_get_required_interface_type,
        (void *)nw_parameters_set_required_interface_type,
        (void *)nw_parameters_copy_required_interface,
        (void *)nw_parameters_require_interface,
        (void *)nw_parameters_prohibit_interface_type,
        (void *)nw_parameters_clear_prohibited_interface_types,
        (void *)nw_parameters_iterate_prohibited_interface_types,
        (void *)nw_parameters_set_privacy_context,
        (void *)nw_protocol_stack_copy_internet_protocol,
        (void *)nw_protocol_stack_copy_transport_protocol,
        (void *)nw_protocol_stack_set_transport_protocol,
        (void *)nw_protocol_stack_prepend_application_protocol,
        (void *)nw_protocol_stack_clear_application_protocols,
        (void *)nw_protocol_stack_iterate_application_protocols,
        (void *)nw_protocol_definition_is_equal,
        (void *)nw_protocol_options_copy_definition,
        (void *)nw_protocol_metadata_copy_definition,
        (void *)nw_protocol_copy_tcp_definition,
        (void *)nw_protocol_copy_udp_definition,
        (void *)nw_protocol_copy_ip_definition,
        (void *)nw_protocol_copy_tls_definition,
        (void *)nw_protocol_copy_ws_definition,
        (void *)nw_protocol_copy_quic_definition,
        (void *)nw_protocol_metadata_is_tcp,
        (void *)nw_protocol_metadata_is_udp,
        (void *)nw_protocol_metadata_is_ip,
        (void *)nw_protocol_metadata_is_tls,
        (void *)nw_protocol_metadata_is_ws,
        (void *)nw_protocol_metadata_is_quic,
        (void *)nw_protocol_options_is_quic,
        (void *)nw_tcp_create_options,
        (void *)nw_udp_create_options,
        (void *)nw_tls_create_options,
        (void *)nw_quic_create_options,
        (void *)nw_ws_create_options,
        (void *)nw_ip_create_metadata,
        (void *)nw_udp_create_metadata,
        (void *)nw_ws_create_metadata,
        (void *)nw_tcp_options_set_no_delay,
        (void *)nw_tcp_options_set_no_options,
        (void *)nw_tcp_options_set_no_push,
        (void *)nw_tcp_options_set_disable_ecn,
        (void *)nw_tcp_options_set_disable_ack_stretching,
        (void *)nw_tcp_options_set_retransmit_fin_drop,
        (void *)nw_tcp_options_set_enable_fast_open,
        (void *)nw_tcp_options_set_enable_keepalive,
        (void *)nw_tcp_options_set_connection_timeout,
        (void *)nw_tcp_options_set_keepalive_count,
        (void *)nw_tcp_options_set_keepalive_idle_time,
        (void *)nw_tcp_options_set_keepalive_interval,
        (void *)nw_tcp_options_set_maximum_segment_size,
        (void *)nw_tcp_options_set_persist_timeout,
        (void *)nw_tcp_options_set_retransmit_connection_drop_time,
        (void *)nw_tcp_options_set_multipath_force_version,
        (void *)nw_udp_options_set_prefer_no_checksum,
        (void *)nw_ip_options_set_version,
        (void *)nw_ip_options_set_hop_limit,
        (void *)nw_ip_options_set_calculate_receive_time,
        (void *)nw_ip_options_set_disable_fragmentation,
        (void *)nw_ip_options_set_use_minimum_mtu,
        (void *)nw_ip_options_set_local_address_preference,
        (void *)nw_ip_options_set_disable_multicast_loopback,
        (void *)nw_ip_metadata_get_service_class,
        (void *)nw_ip_metadata_set_service_class,
        (void *)nw_ip_metadata_get_ecn_flag,
        (void *)nw_ip_metadata_set_ecn_flag,
        (void *)nw_ip_metadata_get_receive_time,
        (void *)nw_tcp_get_available_send_buffer,
        (void *)nw_tcp_get_available_receive_buffer,
        (void *)nw_tls_copy_sec_protocol_options,
        (void *)nw_tls_copy_sec_protocol_metadata,
        (void *)nw_quic_copy_sec_protocol_options,
        (void *)nw_quic_copy_sec_protocol_metadata,
        (void *)nw_content_context_create,
        (void *)nw_content_context_get_identifier,
        (void *)nw_content_context_get_relative_priority,
        (void *)nw_content_context_set_relative_priority,
        (void *)nw_content_context_get_expiration_milliseconds,
        (void *)nw_content_context_set_expiration_milliseconds,
        (void *)nw_content_context_get_is_final,
        (void *)nw_content_context_set_is_final,
        (void *)nw_content_context_copy_antecedent,
        (void *)nw_content_context_set_antecedent,
        (void *)nw_content_context_copy_protocol_metadata,
        (void *)nw_content_context_set_metadata_for_protocol,
        (void *)nw_content_context_foreach_protocol_metadata,
        (void *)nw_txt_record_create_dictionary,
        (void *)nw_txt_record_create_with_bytes,
        (void *)nw_txt_record_copy,
        (void *)nw_txt_record_get_key_count,
        (void *)nw_txt_record_is_dictionary,
        (void *)nw_txt_record_is_equal,
        (void *)nw_txt_record_find_key,
        (void *)nw_txt_record_set_key,
        (void *)nw_txt_record_remove_key,
        (void *)nw_txt_record_access_key,
        (void *)nw_txt_record_apply,
        (void *)nw_txt_record_access_bytes,
        (void *)nw_ws_metadata_get_opcode,
        (void *)nw_ws_metadata_get_close_code,
        (void *)nw_ws_metadata_set_close_code,
        (void *)nw_ws_metadata_copy_server_response,
        (void *)nw_ws_metadata_set_pong_handler,
        (void *)nw_ws_options_add_subprotocol,
        (void *)nw_ws_options_add_additional_header,
        (void *)nw_ws_options_set_auto_reply_ping,
        (void *)nw_ws_options_set_maximum_message_size,
        (void *)nw_ws_options_set_skip_handshake,
        (void *)nw_ws_options_set_client_request_handler,
        (void *)nw_ws_response_create,
        (void *)nw_ws_response_get_status,
        (void *)nw_ws_response_get_selected_subprotocol,
        (void *)nw_ws_response_add_additional_header,
        (void *)nw_ws_response_enumerate_additional_headers,
        (void *)nw_ws_request_enumerate_subprotocols,
        (void *)nw_ws_request_enumerate_additional_headers,
        (void *)nw_framer_create_definition,
        (void *)nw_framer_create_options,
        (void *)nw_framer_options_set_object_value,
        (void *)nw_framer_options_copy_object_value,
        (void *)nw_framer_protocol_create_message,
        (void *)nw_framer_message_set_value,
        (void *)nw_framer_message_access_value,
        (void *)nw_framer_message_set_object_value,
        (void *)nw_framer_message_copy_object_value,
        (void *)nw_protocol_metadata_is_framer_message,
        (void *)nw_quic_set_idle_timeout,
        (void *)nw_quic_get_idle_timeout,
        (void *)nw_quic_set_max_udp_payload_size,
        (void *)nw_quic_get_max_udp_payload_size,
        (void *)nw_quic_set_initial_max_data,
        (void *)nw_quic_get_initial_max_data,
        (void *)nw_quic_set_initial_max_stream_data_bidirectional_local,
        (void *)nw_quic_get_initial_max_stream_data_bidirectional_local,
        (void *)nw_quic_set_initial_max_stream_data_bidirectional_remote,
        (void *)nw_quic_get_initial_max_stream_data_bidirectional_remote,
        (void *)nw_quic_set_initial_max_stream_data_unidirectional,
        (void *)nw_quic_get_initial_max_stream_data_unidirectional,
        (void *)nw_quic_set_initial_max_streams_bidirectional,
        (void *)nw_quic_get_initial_max_streams_bidirectional,
        (void *)nw_quic_set_initial_max_streams_unidirectional,
        (void *)nw_quic_get_initial_max_streams_unidirectional,
        (void *)nw_quic_set_stream_is_unidirectional,
        (void *)nw_quic_get_stream_is_unidirectional,
        (void *)nw_quic_set_stream_is_datagram,
        (void *)nw_quic_get_stream_is_datagram,
        (void *)nw_quic_set_max_datagram_frame_size,
        (void *)nw_quic_get_max_datagram_frame_size,
        (void *)nw_quic_add_tls_application_protocol,
        (void *)nw_quic_set_keepalive_interval,
        (void *)nw_quic_get_keepalive_interval,
        (void *)nw_quic_set_local_max_streams_bidirectional,
        (void *)nw_quic_get_local_max_streams_bidirectional,
        (void *)nw_quic_set_local_max_streams_unidirectional,
        (void *)nw_quic_get_local_max_streams_unidirectional,
        (void *)nw_quic_get_remote_idle_timeout,
        (void *)nw_quic_get_remote_max_streams_bidirectional,
        (void *)nw_quic_get_remote_max_streams_unidirectional,
        (void *)nw_quic_set_application_error,
        (void *)nw_quic_get_application_error,
        (void *)nw_quic_get_application_error_reason,
        (void *)nw_quic_set_stream_application_error,
        (void *)nw_quic_get_stream_application_error,
        (void *)nw_quic_get_stream_id,
        (void *)nw_quic_get_stream_type,
        (void *)nw_quic_get_stream_usable_datagram_frame_size,
        (void *)nw_browse_descriptor_create_bonjour_service,
        (void *)nw_browse_descriptor_get_bonjour_service_type,
        (void *)nw_browse_descriptor_get_bonjour_service_domain,
        (void *)nw_browse_descriptor_get_include_txt_record,
        (void *)nw_browse_descriptor_set_include_txt_record,
        (void *)nw_browse_descriptor_create_application_service,
        (void *)nw_browse_descriptor_get_application_service_name,
        (void *)nw_advertise_descriptor_create_bonjour_service,
        (void *)nw_advertise_descriptor_get_no_auto_rename,
        (void *)nw_advertise_descriptor_set_no_auto_rename,
        (void *)nw_advertise_descriptor_set_txt_record,
        (void *)nw_advertise_descriptor_set_txt_record_object,
        (void *)nw_advertise_descriptor_copy_txt_record_object,
        (void *)nw_advertise_descriptor_create_application_service,
        (void *)nw_advertise_descriptor_get_application_service_name,
        (void *)nw_group_descriptor_create_multicast,
        (void *)nw_group_descriptor_add_endpoint,
        (void *)nw_group_descriptor_enumerate_endpoints,
        (void *)nw_multicast_group_descriptor_set_specific_source,
        (void *)nw_multicast_group_descriptor_set_disable_unicast_traffic,
        (void *)nw_multicast_group_descriptor_get_disable_unicast_traffic,
        (void *)nw_group_descriptor_create_multiplex,
        (void *)nw_privacy_context_create,
        (void *)nw_privacy_context_disable_logging,
        (void *)nw_privacy_context_require_encrypted_name_resolution,
        (void *)nw_privacy_context_flush_cache,
        (void *)nw_resolver_config_create_tls,
        (void *)nw_resolver_config_create_https,
        (void *)nw_resolver_config_add_server_address,
        (void *)nw_data_transfer_report_get_state,
        (void *)nw_data_transfer_report_collect,
        (void *)nw_data_transfer_report_get_duration_milliseconds,
        (void *)nw_data_transfer_report_get_path_count,
        (void *)nw_data_transfer_report_get_sent_application_byte_count,
        (void *)nw_data_transfer_report_get_received_application_byte_count,
        (void *)nw_data_transfer_report_get_sent_transport_byte_count,
        (void *)nw_data_transfer_report_get_received_transport_byte_count,
        (void *)nw_data_transfer_report_get_sent_transport_retransmitted_byte_count,
        (void *)nw_data_transfer_report_get_received_transport_duplicate_byte_count,
        (void *)nw_data_transfer_report_get_received_transport_out_of_order_byte_count,
        (void *)nw_data_transfer_report_get_sent_ip_packet_count,
        (void *)nw_data_transfer_report_get_received_ip_packet_count,
        (void *)nw_data_transfer_report_get_transport_smoothed_rtt_milliseconds,
        (void *)nw_data_transfer_report_get_transport_minimum_rtt_milliseconds,
        (void *)nw_data_transfer_report_get_transport_rtt_variance,
        (void *)nw_data_transfer_report_copy_path_interface,
        (void *)nw_data_transfer_report_get_path_radio_type,
        (void *)nw_relay_hop_create,
        (void *)nw_relay_hop_add_additional_http_header_field,
        (void *)nw_proxy_config_create_http_connect,
        (void *)nw_proxy_config_create_socksv5,
        (void *)nw_proxy_config_create_relay,
        (void *)nw_proxy_config_create_oblivious_http,
        (void *)nw_proxy_config_set_username_and_password,
        (void *)nw_proxy_config_set_failover_allowed,
        (void *)nw_proxy_config_get_failover_allowed,
        (void *)nw_proxy_config_add_match_domain,
        (void *)nw_proxy_config_add_excluded_domain,
        (void *)nw_proxy_config_clear_match_domains,
        (void *)nw_proxy_config_clear_excluded_domains,
        (void *)nw_proxy_config_enumerate_match_domains,
        (void *)nw_proxy_config_enumerate_excluded_domains,
        (void *)nw_privacy_context_add_proxy,
        (void *)nw_privacy_context_clear_proxies,
        (void *)nw_parameters_prohibit_interface,
        (void *)nw_parameters_clear_prohibited_interfaces,
        (void *)nw_parameters_iterate_prohibited_interfaces,
        (void *)nw_path_monitor_create,
        (void *)nw_path_monitor_set_queue,
        (void *)nw_path_monitor_set_update_handler,
        (void *)nw_path_monitor_start,
        (void *)nw_path_monitor_cancel,
        (void *)nw_path_is_constrained,
        (void *)nw_path_enumerate_gateways,
        (void *)nw_path_get_unsatisfied_reason,
        (void *)nw_path_get_link_quality,
        (void *)nw_path_is_ultra_constrained,
        (void *)nw_error_get_error_domain,
        (void *)nw_error_get_error_code,
        (void *)nw_error_copy_cf_error,
    };
    for (size_t index = 0; index < sizeof values / sizeof values[0]; index++)
        fields[index] = values[index];
    return api;
}

static API port_api(void)
{
    API api;
    memset(&api, 0, sizeof api);
    void **fields = (void **)&api;
    void *values[] = {
        (void *)charonhost_nw_endpoint_create_host,
        (void *)charonhost_nw_endpoint_create_address,
        (void *)charonhost_nw_endpoint_create_bonjour_service,
        (void *)charonhost_nw_endpoint_create_url,
        (void *)charonhost_nw_endpoint_get_type,
        (void *)charonhost_nw_endpoint_get_hostname,
        (void *)charonhost_nw_endpoint_get_port,
        (void *)charonhost_nw_endpoint_get_address,
        (void *)charonhost_nw_endpoint_get_bonjour_service_name,
        (void *)charonhost_nw_endpoint_get_bonjour_service_type,
        (void *)charonhost_nw_endpoint_get_bonjour_service_domain,
        (void *)charonhost_nw_endpoint_get_url,
        (void *)charonhost_nw_endpoint_copy_address_string,
        (void *)charonhost_nw_endpoint_copy_port_string,
        (void *)charonhost_nw_endpoint_copy_txt_record,
        (void *)charonhost_nw_endpoint_get_signature,
        (void *)charonhost_nw_parameters_create,
        (void *)charonhost_nw_parameters_create_secure_tcp,
        (void *)charonhost_nw_parameters_create_secure_udp,
        (void *)charonhost_nw_parameters_create_quic,
        (void *)charonhost_nw_parameters_create_application_service,
        (void *)charonhost_nw_parameters_copy,
        (void *)charonhost_nw_parameters_copy_default_protocol_stack,
        (void *)charonhost_nw_parameters_copy_local_endpoint,
        (void *)charonhost_nw_parameters_set_local_endpoint,
        (void *)charonhost_nw_parameters_get_prohibit_expensive,
        (void *)charonhost_nw_parameters_set_prohibit_expensive,
        (void *)charonhost_nw_parameters_get_prohibit_constrained,
        (void *)charonhost_nw_parameters_set_prohibit_constrained,
        (void *)charonhost_nw_parameters_get_local_only,
        (void *)charonhost_nw_parameters_set_local_only,
        (void *)charonhost_nw_parameters_get_fast_open_enabled,
        (void *)charonhost_nw_parameters_set_fast_open_enabled,
        (void *)charonhost_nw_parameters_get_include_peer_to_peer,
        (void *)charonhost_nw_parameters_set_include_peer_to_peer,
        (void *)charonhost_nw_parameters_get_reuse_local_address,
        (void *)charonhost_nw_parameters_set_reuse_local_address,
        (void *)charonhost_nw_parameters_get_prefer_no_proxy,
        (void *)charonhost_nw_parameters_set_prefer_no_proxy,
        (void *)charonhost_nw_parameters_get_allow_ultra_constrained,
        (void *)charonhost_nw_parameters_set_allow_ultra_constrained,
        (void *)charonhost_nw_parameters_requires_dnssec_validation,
        (void *)charonhost_nw_parameters_set_requires_dnssec_validation,
        (void *)charonhost_nw_parameters_get_service_class,
        (void *)charonhost_nw_parameters_set_service_class,
        (void *)charonhost_nw_parameters_get_multipath_service,
        (void *)charonhost_nw_parameters_set_multipath_service,
        (void *)charonhost_nw_parameters_get_expired_dns_behavior,
        (void *)charonhost_nw_parameters_set_expired_dns_behavior,
        (void *)charonhost_nw_parameters_get_attribution,
        (void *)charonhost_nw_parameters_set_attribution,
        (void *)charonhost_nw_parameters_get_required_interface_type,
        (void *)charonhost_nw_parameters_set_required_interface_type,
        (void *)charonhost_nw_parameters_copy_required_interface,
        (void *)charonhost_nw_parameters_require_interface,
        (void *)charonhost_nw_parameters_prohibit_interface_type,
        (void *)charonhost_nw_parameters_clear_prohibited_interface_types,
        (void *)charonhost_nw_parameters_iterate_prohibited_interface_types,
        (void *)charonhost_nw_parameters_set_privacy_context,
        (void *)charonhost_nw_protocol_stack_copy_internet_protocol,
        (void *)charonhost_nw_protocol_stack_copy_transport_protocol,
        (void *)charonhost_nw_protocol_stack_set_transport_protocol,
        (void *)charonhost_nw_protocol_stack_prepend_application_protocol,
        (void *)charonhost_nw_protocol_stack_clear_application_protocols,
        (void *)charonhost_nw_protocol_stack_iterate_application_protocols,
        (void *)charonhost_nw_protocol_definition_is_equal,
        (void *)charonhost_nw_protocol_options_copy_definition,
        (void *)charonhost_nw_protocol_metadata_copy_definition,
        (void *)charonhost_nw_protocol_copy_tcp_definition,
        (void *)charonhost_nw_protocol_copy_udp_definition,
        (void *)charonhost_nw_protocol_copy_ip_definition,
        (void *)charonhost_nw_protocol_copy_tls_definition,
        (void *)charonhost_nw_protocol_copy_ws_definition,
        (void *)charonhost_nw_protocol_copy_quic_definition,
        (void *)charonhost_nw_protocol_metadata_is_tcp,
        (void *)charonhost_nw_protocol_metadata_is_udp,
        (void *)charonhost_nw_protocol_metadata_is_ip,
        (void *)charonhost_nw_protocol_metadata_is_tls,
        (void *)charonhost_nw_protocol_metadata_is_ws,
        (void *)charonhost_nw_protocol_metadata_is_quic,
        (void *)charonhost_nw_protocol_options_is_quic,
        (void *)charonhost_nw_tcp_create_options,
        (void *)charonhost_nw_udp_create_options,
        (void *)charonhost_nw_tls_create_options,
        (void *)charonhost_nw_quic_create_options,
        (void *)charonhost_nw_ws_create_options,
        (void *)charonhost_nw_ip_create_metadata,
        (void *)charonhost_nw_udp_create_metadata,
        (void *)charonhost_nw_ws_create_metadata,
        (void *)charonhost_nw_tcp_options_set_no_delay,
        (void *)charonhost_nw_tcp_options_set_no_options,
        (void *)charonhost_nw_tcp_options_set_no_push,
        (void *)charonhost_nw_tcp_options_set_disable_ecn,
        (void *)charonhost_nw_tcp_options_set_disable_ack_stretching,
        (void *)charonhost_nw_tcp_options_set_retransmit_fin_drop,
        (void *)charonhost_nw_tcp_options_set_enable_fast_open,
        (void *)charonhost_nw_tcp_options_set_enable_keepalive,
        (void *)charonhost_nw_tcp_options_set_connection_timeout,
        (void *)charonhost_nw_tcp_options_set_keepalive_count,
        (void *)charonhost_nw_tcp_options_set_keepalive_idle_time,
        (void *)charonhost_nw_tcp_options_set_keepalive_interval,
        (void *)charonhost_nw_tcp_options_set_maximum_segment_size,
        (void *)charonhost_nw_tcp_options_set_persist_timeout,
        (void *)charonhost_nw_tcp_options_set_retransmit_connection_drop_time,
        (void *)charonhost_nw_tcp_options_set_multipath_force_version,
        (void *)charonhost_nw_udp_options_set_prefer_no_checksum,
        (void *)charonhost_nw_ip_options_set_version,
        (void *)charonhost_nw_ip_options_set_hop_limit,
        (void *)charonhost_nw_ip_options_set_calculate_receive_time,
        (void *)charonhost_nw_ip_options_set_disable_fragmentation,
        (void *)charonhost_nw_ip_options_set_use_minimum_mtu,
        (void *)charonhost_nw_ip_options_set_local_address_preference,
        (void *)charonhost_nw_ip_options_set_disable_multicast_loopback,
        (void *)charonhost_nw_ip_metadata_get_service_class,
        (void *)charonhost_nw_ip_metadata_set_service_class,
        (void *)charonhost_nw_ip_metadata_get_ecn_flag,
        (void *)charonhost_nw_ip_metadata_set_ecn_flag,
        (void *)charonhost_nw_ip_metadata_get_receive_time,
        (void *)charonhost_nw_tcp_get_available_send_buffer,
        (void *)charonhost_nw_tcp_get_available_receive_buffer,
        (void *)charonhost_nw_tls_copy_sec_protocol_options,
        (void *)charonhost_nw_tls_copy_sec_protocol_metadata,
        (void *)charonhost_nw_quic_copy_sec_protocol_options,
        (void *)charonhost_nw_quic_copy_sec_protocol_metadata,
        (void *)charonhost_nw_content_context_create,
        (void *)charonhost_nw_content_context_get_identifier,
        (void *)charonhost_nw_content_context_get_relative_priority,
        (void *)charonhost_nw_content_context_set_relative_priority,
        (void *)charonhost_nw_content_context_get_expiration_milliseconds,
        (void *)charonhost_nw_content_context_set_expiration_milliseconds,
        (void *)charonhost_nw_content_context_get_is_final,
        (void *)charonhost_nw_content_context_set_is_final,
        (void *)charonhost_nw_content_context_copy_antecedent,
        (void *)charonhost_nw_content_context_set_antecedent,
        (void *)charonhost_nw_content_context_copy_protocol_metadata,
        (void *)charonhost_nw_content_context_set_metadata_for_protocol,
        (void *)charonhost_nw_content_context_foreach_protocol_metadata,
        (void *)charonhost_nw_txt_record_create_dictionary,
        (void *)charonhost_nw_txt_record_create_with_bytes,
        (void *)charonhost_nw_txt_record_copy,
        (void *)charonhost_nw_txt_record_get_key_count,
        (void *)charonhost_nw_txt_record_is_dictionary,
        (void *)charonhost_nw_txt_record_is_equal,
        (void *)charonhost_nw_txt_record_find_key,
        (void *)charonhost_nw_txt_record_set_key,
        (void *)charonhost_nw_txt_record_remove_key,
        (void *)charonhost_nw_txt_record_access_key,
        (void *)charonhost_nw_txt_record_apply,
        (void *)charonhost_nw_txt_record_access_bytes,
        (void *)charonhost_nw_ws_metadata_get_opcode,
        (void *)charonhost_nw_ws_metadata_get_close_code,
        (void *)charonhost_nw_ws_metadata_set_close_code,
        (void *)charonhost_nw_ws_metadata_copy_server_response,
        (void *)charonhost_nw_ws_metadata_set_pong_handler,
        (void *)charonhost_nw_ws_options_add_subprotocol,
        (void *)charonhost_nw_ws_options_add_additional_header,
        (void *)charonhost_nw_ws_options_set_auto_reply_ping,
        (void *)charonhost_nw_ws_options_set_maximum_message_size,
        (void *)charonhost_nw_ws_options_set_skip_handshake,
        (void *)charonhost_nw_ws_options_set_client_request_handler,
        (void *)charonhost_nw_ws_response_create,
        (void *)charonhost_nw_ws_response_get_status,
        (void *)charonhost_nw_ws_response_get_selected_subprotocol,
        (void *)charonhost_nw_ws_response_add_additional_header,
        (void *)charonhost_nw_ws_response_enumerate_additional_headers,
        (void *)charonhost_nw_ws_request_enumerate_subprotocols,
        (void *)charonhost_nw_ws_request_enumerate_additional_headers,
        (void *)charonhost_nw_framer_create_definition,
        (void *)charonhost_nw_framer_create_options,
        (void *)charonhost_nw_framer_options_set_object_value,
        (void *)charonhost_nw_framer_options_copy_object_value,
        (void *)charonhost_nw_framer_protocol_create_message,
        (void *)charonhost_nw_framer_message_set_value,
        (void *)charonhost_nw_framer_message_access_value,
        (void *)charonhost_nw_framer_message_set_object_value,
        (void *)charonhost_nw_framer_message_copy_object_value,
        (void *)charonhost_nw_protocol_metadata_is_framer_message,
        (void *)charonhost_nw_quic_set_idle_timeout,
        (void *)charonhost_nw_quic_get_idle_timeout,
        (void *)charonhost_nw_quic_set_max_udp_payload_size,
        (void *)charonhost_nw_quic_get_max_udp_payload_size,
        (void *)charonhost_nw_quic_set_initial_max_data,
        (void *)charonhost_nw_quic_get_initial_max_data,
        (void *)charonhost_nw_quic_set_initial_max_stream_data_bidirectional_local,
        (void *)charonhost_nw_quic_get_initial_max_stream_data_bidirectional_local,
        (void *)charonhost_nw_quic_set_initial_max_stream_data_bidirectional_remote,
        (void *)charonhost_nw_quic_get_initial_max_stream_data_bidirectional_remote,
        (void *)charonhost_nw_quic_set_initial_max_stream_data_unidirectional,
        (void *)charonhost_nw_quic_get_initial_max_stream_data_unidirectional,
        (void *)charonhost_nw_quic_set_initial_max_streams_bidirectional,
        (void *)charonhost_nw_quic_get_initial_max_streams_bidirectional,
        (void *)charonhost_nw_quic_set_initial_max_streams_unidirectional,
        (void *)charonhost_nw_quic_get_initial_max_streams_unidirectional,
        (void *)charonhost_nw_quic_set_stream_is_unidirectional,
        (void *)charonhost_nw_quic_get_stream_is_unidirectional,
        (void *)charonhost_nw_quic_set_stream_is_datagram,
        (void *)charonhost_nw_quic_get_stream_is_datagram,
        (void *)charonhost_nw_quic_set_max_datagram_frame_size,
        (void *)charonhost_nw_quic_get_max_datagram_frame_size,
        (void *)charonhost_nw_quic_add_tls_application_protocol,
        (void *)charonhost_nw_quic_set_keepalive_interval,
        (void *)charonhost_nw_quic_get_keepalive_interval,
        (void *)charonhost_nw_quic_set_local_max_streams_bidirectional,
        (void *)charonhost_nw_quic_get_local_max_streams_bidirectional,
        (void *)charonhost_nw_quic_set_local_max_streams_unidirectional,
        (void *)charonhost_nw_quic_get_local_max_streams_unidirectional,
        (void *)charonhost_nw_quic_get_remote_idle_timeout,
        (void *)charonhost_nw_quic_get_remote_max_streams_bidirectional,
        (void *)charonhost_nw_quic_get_remote_max_streams_unidirectional,
        (void *)charonhost_nw_quic_set_application_error,
        (void *)charonhost_nw_quic_get_application_error,
        (void *)charonhost_nw_quic_get_application_error_reason,
        (void *)charonhost_nw_quic_set_stream_application_error,
        (void *)charonhost_nw_quic_get_stream_application_error,
        (void *)charonhost_nw_quic_get_stream_id,
        (void *)charonhost_nw_quic_get_stream_type,
        (void *)charonhost_nw_quic_get_stream_usable_datagram_frame_size,
        (void *)charonhost_nw_browse_descriptor_create_bonjour_service,
        (void *)charonhost_nw_browse_descriptor_get_bonjour_service_type,
        (void *)charonhost_nw_browse_descriptor_get_bonjour_service_domain,
        (void *)charonhost_nw_browse_descriptor_get_include_txt_record,
        (void *)charonhost_nw_browse_descriptor_set_include_txt_record,
        (void *)charonhost_nw_browse_descriptor_create_application_service,
        (void *)charonhost_nw_browse_descriptor_get_application_service_name,
        (void *)charonhost_nw_advertise_descriptor_create_bonjour_service,
        (void *)charonhost_nw_advertise_descriptor_get_no_auto_rename,
        (void *)charonhost_nw_advertise_descriptor_set_no_auto_rename,
        (void *)charonhost_nw_advertise_descriptor_set_txt_record,
        (void *)charonhost_nw_advertise_descriptor_set_txt_record_object,
        (void *)charonhost_nw_advertise_descriptor_copy_txt_record_object,
        (void *)charonhost_nw_advertise_descriptor_create_application_service,
        (void *)charonhost_nw_advertise_descriptor_get_application_service_name,
        (void *)charonhost_nw_group_descriptor_create_multicast,
        (void *)charonhost_nw_group_descriptor_add_endpoint,
        (void *)charonhost_nw_group_descriptor_enumerate_endpoints,
        (void *)charonhost_nw_multicast_group_descriptor_set_specific_source,
        (void *)charonhost_nw_multicast_group_descriptor_set_disable_unicast_traffic,
        (void *)charonhost_nw_multicast_group_descriptor_get_disable_unicast_traffic,
        (void *)charonhost_nw_group_descriptor_create_multiplex,
        (void *)charonhost_nw_privacy_context_create,
        (void *)charonhost_nw_privacy_context_disable_logging,
        (void *)charonhost_nw_privacy_context_require_encrypted_name_resolution,
        (void *)charonhost_nw_privacy_context_flush_cache,
        (void *)charonhost_nw_resolver_config_create_tls,
        (void *)charonhost_nw_resolver_config_create_https,
        (void *)charonhost_nw_resolver_config_add_server_address,
        (void *)charonhost_nw_data_transfer_report_get_state,
        (void *)charonhost_nw_data_transfer_report_collect,
        (void *)charonhost_nw_data_transfer_report_get_duration_milliseconds,
        (void *)charonhost_nw_data_transfer_report_get_path_count,
        (void *)charonhost_nw_data_transfer_report_get_sent_application_byte_count,
        (void *)charonhost_nw_data_transfer_report_get_received_application_byte_count,
        (void *)charonhost_nw_data_transfer_report_get_sent_transport_byte_count,
        (void *)charonhost_nw_data_transfer_report_get_received_transport_byte_count,
        (void *)charonhost_nw_data_transfer_report_get_sent_transport_retransmitted_byte_count,
        (void *)charonhost_nw_data_transfer_report_get_received_transport_duplicate_byte_count,
        (void *)charonhost_nw_data_transfer_report_get_received_transport_out_of_order_byte_count,
        (void *)charonhost_nw_data_transfer_report_get_sent_ip_packet_count,
        (void *)charonhost_nw_data_transfer_report_get_received_ip_packet_count,
        (void *)charonhost_nw_data_transfer_report_get_transport_smoothed_rtt_milliseconds,
        (void *)charonhost_nw_data_transfer_report_get_transport_minimum_rtt_milliseconds,
        (void *)charonhost_nw_data_transfer_report_get_transport_rtt_variance,
        (void *)charonhost_nw_data_transfer_report_copy_path_interface,
        (void *)charonhost_nw_data_transfer_report_get_path_radio_type,
        (void *)charonhost_nw_relay_hop_create,
        (void *)charonhost_nw_relay_hop_add_additional_http_header_field,
        (void *)charonhost_nw_proxy_config_create_http_connect,
        (void *)charonhost_nw_proxy_config_create_socksv5,
        (void *)charonhost_nw_proxy_config_create_relay,
        (void *)charonhost_nw_proxy_config_create_oblivious_http,
        (void *)charonhost_nw_proxy_config_set_username_and_password,
        (void *)charonhost_nw_proxy_config_set_failover_allowed,
        (void *)charonhost_nw_proxy_config_get_failover_allowed,
        (void *)charonhost_nw_proxy_config_add_match_domain,
        (void *)charonhost_nw_proxy_config_add_excluded_domain,
        (void *)charonhost_nw_proxy_config_clear_match_domains,
        (void *)charonhost_nw_proxy_config_clear_excluded_domains,
        (void *)charonhost_nw_proxy_config_enumerate_match_domains,
        (void *)charonhost_nw_proxy_config_enumerate_excluded_domains,
        (void *)charonhost_nw_privacy_context_add_proxy,
        (void *)charonhost_nw_privacy_context_clear_proxies,
        (void *)charonhost_nw_parameters_prohibit_interface,
        (void *)charonhost_nw_parameters_clear_prohibited_interfaces,
        (void *)charonhost_nw_parameters_iterate_prohibited_interfaces,
        (void *)charonhost_nw_path_monitor_create,
        (void *)charonhost_nw_path_monitor_set_queue,
        (void *)charonhost_nw_path_monitor_set_update_handler,
        (void *)charonhost_nw_path_monitor_start,
        (void *)charonhost_nw_path_monitor_cancel,
        (void *)charonhost_nw_path_is_constrained,
        (void *)charonhost_nw_path_enumerate_gateways,
        (void *)charonhost_nw_path_get_unsatisfied_reason,
        (void *)charonhost_nw_path_get_link_quality,
        (void *)charonhost_nw_path_is_ultra_constrained,
        (void *)charonhost_nw_error_get_error_domain,
        (void *)charonhost_nw_error_get_error_code,
        (void *)charonhost_nw_error_copy_cf_error,
    };
    for (size_t index = 0; index < sizeof values / sizeof values[0]; index++)
        fields[index] = values[index];
    return api;
}

/* ---------------------------------------------------------------- the scenarios */

/* What is compared is what a program sees: both answers are made into text, so a difference in how
   each side made it is not a difference. */
static void compare(NSString *name, id system, id port)
{
    NSString *left = [NSString stringWithFormat:@"%@", system], *right = [NSString stringWithFormat:@"%@", port];
    charon_check([left isEqualToString:right], name.UTF8String,
                 [NSString stringWithFormat:@"system %@ != port %@", left, right]);
}

static NSString *str(const char *value)
{
    return value ? @(value) : @"(nil)";
}

static NSString *describe(API api, nw_endpoint_t endpoint)
{
    if (!endpoint)
        return @"(nil)";
    char *address = api.endpoint_address_string(endpoint), *port = api.endpoint_port_string(endpoint);
    NSString *out = [NSString stringWithFormat:@"type=%d host=%@ port=%u address=%@ port-string=%@ bonjour=%@/%@/%@ url=%@ txt=%d",
                      api.endpoint_type(endpoint), str(api.endpoint_hostname(endpoint)), api.endpoint_port(endpoint),
                      str(address), str(port), str(api.bonjour_name(endpoint)), str(api.bonjour_type(endpoint)),
                      str(api.bonjour_domain(endpoint)), str(api.endpoint_url_text(endpoint)),
                      api.endpoint_txt_record(endpoint) != NULL];
    free(address);
    free(port);
    return out;
}

static NSString *stack_shape(API api, nw_parameters_t parameters)
{
    nw_protocol_stack_t stack = api.parameters_stack(parameters);
    __block int count = 0;
    api.stack_iterate(stack, ^(nw_protocol_options_t options) { count++; });
    return [NSString stringWithFormat:@"internet=%d transport=%d application=%d",
            api.stack_internet(stack) != NULL, api.stack_transport(stack) != NULL, count];
}

/* The options of QUIC, as text, one field per getter and named after it. The datagram frame size is
   asked for separately: the host's own *default* for it is whatever was in the memory (measured, two
   runs two numbers), so it cannot be compared before a program sets it, and after it can. */
static NSString *quic_options_shape(API api, nw_protocol_options_t options)
{
    return [NSString stringWithFormat:@"idle=%u max_udp=%u data=%llu data_local=%llu data_remote=%llu data_uni=%llu "
                                      @"streams_bidi=%llu streams_uni=%llu stream_unidirectional=%d stream_datagram=%d",
            api.quic_idle_value(options), api.quic_max_udp_value(options), api.quic_max_data_value(options),
            api.quic_data_local_value(options), api.quic_data_remote_value(options), api.quic_data_uni_value(options),
            api.quic_streams_bidi_value(options), api.quic_streams_uni_value(options),
            api.quic_stream_unidirectional_value(options), api.quic_stream_datagram_value(options)];
}

static NSString *quic_metadata_shape(API api, nw_protocol_metadata_t metadata)
{
    return [NSString stringWithFormat:@"keepalive=%u local_bidi=%llu local_uni=%llu remote_idle=%llu remote_bidi=%llu remote_uni=%llu error=%llu reason=%@ stream_error=%llu stream_id=%llu type=%u usable=%u",
            api.quic_keepalive_value(metadata), api.quic_local_bidi_value(metadata), api.quic_local_uni_value(metadata),
            api.quic_remote_idle(metadata), api.quic_remote_bidi(metadata), api.quic_remote_uni(metadata),
            api.quic_application_error_value(metadata), str(api.quic_application_error_reason(metadata)),
            api.quic_stream_error_value(metadata), api.quic_stream_id(metadata), api.quic_stream_type(metadata),
            api.quic_usable_datagram(metadata)];
}

static NSString *txt_shape(API api, nw_txt_record_t record)
{
    if (!record)
        return @"(nil)";
    __block NSMutableString *pairs = [NSMutableString string];
    api.txt_apply(record, ^bool(const char *key, nw_txt_record_find_key_t found, const uint8_t *value, size_t length) {
        NSMutableString *bytes = [NSMutableString string];
        for (size_t index = 0; index < length; index++)
            [bytes appendFormat:@"%02x", value[index]];
        [pairs appendFormat:@"%s(%d)=%@ ", key, found, bytes];
        return true;
    });
    __block NSMutableString *raw = [NSMutableString string];
    api.txt_access_bytes(record, ^bool(const uint8_t *bytes, size_t length) {
        for (size_t index = 0; index < length; index++)
            [raw appendFormat:@"%02x", bytes ? bytes[index] : 0];
        return true;
    });
    return [NSString stringWithFormat:@"count=%lu dictionary=%d keys=%@ bytes=%@", (unsigned long)api.txt_count(record),
            api.txt_is_dictionary(record), pairs, raw];
}

int main(void)
{
    @autoreleasepool {
        API system = system_api(), port = port_api();
        const uint8_t record_bytes[] = {7, 'k', 'e', 'y', '=', 'v', 'a', 'l', 3, 'a', 'b', 'c'};
        struct sockaddr_in v4;
        memset(&v4, 0, sizeof v4);
        v4.sin_len = sizeof v4;
        v4.sin_family = AF_INET;
        v4.sin_port = htons(8080);
        v4.sin_addr.s_addr = htonl(0x7F000001);
        struct sockaddr_in6 v6;
        memset(&v6, 0, sizeof v6);
        v6.sin6_len = sizeof v6;
        v6.sin6_family = AF_INET6;
        v6.sin6_port = htons(443);
        v6.sin6_addr = in6addr_loopback;

        /* the endpoint */
        {
            const char *hosts[] = {"example.test", "192.0.2.7", "", "::1"};
            const char *ports[] = {"80", "443", "0", "http"};
            for (size_t index = 0; index < 4; index++) {
                nw_endpoint_t a = system.endpoint_host(hosts[index], ports[index]);
                nw_endpoint_t b = port.endpoint_host(hosts[index], ports[index]);
                compare([NSString stringWithFormat:@"endpoint: the host %s with the port %s", hosts[index], ports[index]],
                        describe(system, a), describe(port, b));
                compare([NSString stringWithFormat:@"endpoint: the host %s with the port %s has the same address",
                         hosts[index], ports[index]],
                        @(system.endpoint_address_of(a) != NULL), @(port.endpoint_address_of(b) != NULL));
            }
            const char *refused[] = {"example.test", "example.test"};
            const char *with_port[] = {NULL, "nosuchservice"};
            for (size_t index = 0; index < 2; index++)
                compare([NSString stringWithFormat:@"endpoint: the host %s with the port %s is refused",
                         refused[index], with_port[index] ? with_port[index] : "none"],
                        describe(system, system.endpoint_host(refused[index], with_port[index])),
                        describe(port, port.endpoint_host(refused[index], with_port[index])));
            compare(@"endpoint: a host with no name at all", describe(system, system.endpoint_host(NULL, "80")),
                    describe(port, port.endpoint_host(NULL, "80")));
            compare(@"endpoint: an address of IPv4", describe(system, system.endpoint_address((struct sockaddr *)&v4)),
                    describe(port, port.endpoint_address((struct sockaddr *)&v4)));
            compare(@"endpoint: an address of IPv6", describe(system, system.endpoint_address((struct sockaddr *)&v6)),
                    describe(port, port.endpoint_address((struct sockaddr *)&v6)));
            compare(@"endpoint: no address at all", describe(system, system.endpoint_address(NULL)),
                    describe(port, port.endpoint_address(NULL)));
            compare(@"endpoint: a Bonjour service with all three", describe(system, system.endpoint_bonjour("name", "_http._tcp", "local.")),
                    describe(port, port.endpoint_bonjour("name", "_http._tcp", "local.")));
            compare(@"endpoint: a Bonjour service with no name", describe(system, system.endpoint_bonjour(NULL, "_http._tcp", "local.")),
                    describe(port, port.endpoint_bonjour(NULL, "_http._tcp", "local.")));
            compare(@"endpoint: a Bonjour service with no domain", describe(system, system.endpoint_bonjour("n", "_ipp._tcp", NULL)),
                    describe(port, port.endpoint_bonjour("n", "_ipp._tcp", NULL)));
            compare(@"endpoint: a Bonjour service of no type", describe(system, system.endpoint_bonjour("n", NULL, "local.")),
                    describe(port, port.endpoint_bonjour("n", NULL, "local.")));
            const char *urls[] = {"https://user@example.test:8443/path?q=1", "http://example.test/", "example.test:9",
                                  "http://[2001:db8::1]:8080/", "example.test"};
            for (size_t index = 0; index < 5; index++)
                compare([NSString stringWithFormat:@"endpoint: the URL %s", urls[index]],
                        describe(system, system.endpoint_url(urls[index])), describe(port, port.endpoint_url(urls[index])));
            size_t system_length = 0, port_length = 0;
            compare(@"endpoint: the signature of a service",
                    @(system.endpoint_signature(system.endpoint_bonjour("n", "_http._tcp", "local."), &system_length) != NULL),
                    @(port.endpoint_signature(port.endpoint_bonjour("n", "_http._tcp", "local."), &port_length) != NULL));
            compare(@"endpoint: the TXT record of a service",
                    @(system.endpoint_txt_record(system.endpoint_bonjour("n", "_http._tcp", "local.")) != NULL),
                    @(port.endpoint_txt_record(port.endpoint_bonjour("n", "_http._tcp", "local.")) != NULL));
        }

        /* the parameters: every default, then every set and get */
        {
            nw_parameters_t a = system.parameters_create(), b = port.parameters_create();
            compare(@"parameters: the defaults",
                    [NSString stringWithFormat:@"expensive=%d constrained=%d local_only=%d fast_open=%d p2p=%d reuse=%d prefer_no_proxy=%d ultra=%d dnssec=%d class=%d multipath=%d expired=%d attribution=%d required=%d local=%d interface=%d",
                            system.prohibit_expensive(a), system.prohibit_constrained(a), system.local_only(a), system.fast_open(a),
                            system.peer_to_peer(a), system.reuse_local_address(a), system.prefer_no_proxy(a),
                            system.allow_ultra_constrained(a), system.dnssec(a), system.service_class(a), system.multipath(a),
                            system.expired_dns(a), system.attribution(a), system.required_type(a),
                            system.parameters_local_endpoint(a) != NULL, system.required_interface(a) != NULL],
                    [NSString stringWithFormat:@"expensive=%d constrained=%d local_only=%d fast_open=%d p2p=%d reuse=%d prefer_no_proxy=%d ultra=%d dnssec=%d class=%d multipath=%d expired=%d attribution=%d required=%d local=%d interface=%d",
                            port.prohibit_expensive(b), port.prohibit_constrained(b), port.local_only(b), port.fast_open(b),
                            port.peer_to_peer(b), port.reuse_local_address(b), port.prefer_no_proxy(b),
                            port.allow_ultra_constrained(b), port.dnssec(b), port.service_class(b), port.multipath(b),
                            port.expired_dns(b), port.attribution(b), port.required_type(b),
                            port.parameters_local_endpoint(b) != NULL, port.required_interface(b) != NULL]);

#define ROUND_TRIP(setter, getter, value, label)                                     \
    do {                                                                             \
        system.setter(a, (value));                                                    \
        port.setter(b, (value));                                                      \
        compare(@"parameters: " label, @(system.getter(a)), @(port.getter(b)));        \
    } while (0)
            ROUND_TRIP(set_prohibit_expensive, prohibit_expensive, true, "prohibit expensive");
            ROUND_TRIP(set_prohibit_constrained, prohibit_constrained, true, "prohibit constrained");
            ROUND_TRIP(set_local_only, local_only, true, "local only");
            ROUND_TRIP(set_fast_open, fast_open, true, "fast open");
            ROUND_TRIP(set_peer_to_peer, peer_to_peer, true, "peer to peer");
            ROUND_TRIP(set_reuse_local_address, reuse_local_address, true, "reuse local address");
            ROUND_TRIP(set_prefer_no_proxy, prefer_no_proxy, true, "prefer no proxy");
            ROUND_TRIP(set_allow_ultra_constrained, allow_ultra_constrained, true, "allow ultra constrained");
            ROUND_TRIP(set_dnssec, dnssec, true, "DNSSEC");
            ROUND_TRIP(set_service_class, service_class, nw_service_class_signaling, "the service class");
            ROUND_TRIP(set_multipath, multipath, nw_multipath_service_handover, "the multipath service");
            ROUND_TRIP(set_expired_dns, expired_dns, nw_parameters_expired_dns_behavior_prohibit, "the expired DNS behaviour");
            ROUND_TRIP(set_attribution, attribution, nw_parameters_attribution_user, "the attribution");
            ROUND_TRIP(set_required_type, required_type, nw_interface_type_cellular, "the required interface type");
#undef ROUND_TRIP

            nw_endpoint_t local_system = system.endpoint_host("192.0.2.9", "7"), local_port = port.endpoint_host("192.0.2.9", "7");
            system.parameters_set_local_endpoint(a, local_system);
            port.parameters_set_local_endpoint(b, local_port);
            compare(@"parameters: the local endpoint", describe(system, system.parameters_local_endpoint(a)),
                    describe(port, port.parameters_local_endpoint(b)));

            __block int system_types = 0, port_types = 0;
            system.prohibit_type(a, nw_interface_type_cellular);
            system.prohibit_type(a, nw_interface_type_wifi);
            port.prohibit_type(b, nw_interface_type_cellular);
            port.prohibit_type(b, nw_interface_type_wifi);
            system.iterate_prohibited_types(a, ^bool(nw_interface_type_t type) { system_types++; return true; });
            port.iterate_prohibited_types(b, ^bool(nw_interface_type_t type) { port_types++; return true; });
            compare(@"parameters: the prohibited interface types", @(system_types), @(port_types));
            system.clear_prohibited_types(a);
            port.clear_prohibited_types(b);
            __block int system_left = 0, port_left = 0;
            system.iterate_prohibited_types(a, ^bool(nw_interface_type_t type) { system_left++; return true; });
            port.iterate_prohibited_types(b, ^bool(nw_interface_type_t type) { port_left++; return true; });
            compare(@"parameters: and none of them after they are cleared", @(system_left), @(port_left));

            nw_parameters_t system_copy = system.parameters_copy(a), port_copy = port.parameters_copy(b);
            compare(@"parameters: a copy of a configured parameters",
                    [NSString stringWithFormat:@"expensive=%d class=%d attribution=%d", system.prohibit_expensive(system_copy),
                            system.service_class(system_copy), system.attribution(system_copy)],
                    [NSString stringWithFormat:@"expensive=%d class=%d attribution=%d", port.prohibit_expensive(port_copy),
                            port.service_class(port_copy), port.attribution(port_copy)]);
            system.set_prohibit_expensive(system_copy, false);
            port.set_prohibit_expensive(port_copy, false);
            compare(@"parameters: and the original is not changed by it", @(system.prohibit_expensive(a)),
                    @(port.prohibit_expensive(b)));
            compare(@"parameters: the stack of a configured parameters", stack_shape(system, a), stack_shape(port, b));
        }

        /* the factories and the stacks they build */
        {
            compare(@"parameters: the stack of a plain one", stack_shape(system, system.parameters_create()),
                    stack_shape(port, port.parameters_create()));
            compare(@"parameters: the stack of a secure TCP one",
                    stack_shape(system, system.parameters_secure_tcp(SYSTEM_DEFAULT, SYSTEM_DEFAULT)),
                    stack_shape(port, port.parameters_secure_tcp(PORT_DEFAULT, PORT_DEFAULT)));
            compare(@"parameters: the stack of a secure TCP one with no TLS",
                    stack_shape(system, system.parameters_secure_tcp(SYSTEM_DISABLE, SYSTEM_DEFAULT)),
                    stack_shape(port, port.parameters_secure_tcp(PORT_DISABLE, PORT_DEFAULT)));
            compare(@"parameters: the stack of a secure UDP one",
                    stack_shape(system, system.parameters_secure_udp(SYSTEM_DEFAULT, SYSTEM_DEFAULT)),
                    stack_shape(port, port.parameters_secure_udp(PORT_DEFAULT, PORT_DEFAULT)));
            compare(@"parameters: the stack of a secure UDP one with no DTLS",
                    stack_shape(system, system.parameters_secure_udp(SYSTEM_DISABLE, SYSTEM_DEFAULT)),
                    stack_shape(port, port.parameters_secure_udp(PORT_DISABLE, PORT_DEFAULT)));
            compare(@"parameters: the stack of a QUIC one",
                    stack_shape(system, system.parameters_quic(SYSTEM_DEFAULT)),
                    stack_shape(port, port.parameters_quic(PORT_DEFAULT)));
            compare(@"parameters: the stack of an application service",
                    stack_shape(system, system.parameters_application_service()),
                    stack_shape(port, port.parameters_application_service()));
            __block int system_saw_tls = 0, port_saw_tls = 0;
            system.parameters_secure_tcp(SYSTEM_DEFAULT, ^(nw_protocol_options_t options) {
                system_saw_tls = system.definition_equal(system.options_definition(options), system.definition_tls());
            });
            port.parameters_secure_tcp(PORT_DEFAULT, ^(nw_protocol_options_t options) {
                port_saw_tls = port.definition_equal(port.options_definition(options), port.definition_tls());
            });
            compare(@"parameters: the TCP configure block runs with TLS options", @(system_saw_tls), @(port_saw_tls));
            __block int system_quic = 0, port_quic = 0;
            system.parameters_quic(^(nw_protocol_options_t options) { system_quic = system.options_is_quic(options); });
            port.parameters_quic(^(nw_protocol_options_t options) { port_quic = port.options_is_quic(options); });
            compare(@"parameters: the QUIC configure block runs with QUIC options", @(system_quic), @(port_quic));
        }

        /* the protocol stack's own calls */
        {
            nw_protocol_stack_t system_stack = system.parameters_stack(system.parameters_secure_tcp(SYSTEM_DEFAULT, SYSTEM_DEFAULT));
            nw_protocol_stack_t port_stack = port.parameters_stack(port.parameters_secure_tcp(PORT_DEFAULT, PORT_DEFAULT));
            system.stack_prepend(system_stack, system.ws_options(nw_ws_version_13));
            port.stack_prepend(port_stack, port.ws_options(nw_ws_version_13));
            __block int system_apps = 0, port_apps = 0;
            system.stack_iterate(system_stack, ^(nw_protocol_options_t options) { system_apps++; });
            port.stack_iterate(port_stack, ^(nw_protocol_options_t options) { port_apps++; });
            compare(@"stack: a protocol prepended goes first", @(system_apps), @(port_apps));
            system.stack_clear(system_stack);
            port.stack_clear(port_stack);
            __block int system_after = 0, port_after = 0;
            system.stack_iterate(system_stack, ^(nw_protocol_options_t options) { system_after++; });
            port.stack_iterate(port_stack, ^(nw_protocol_options_t options) { port_after++; });
            compare(@"stack: and clearing takes them all", @(system_after), @(port_after));
            system.stack_set_transport(system_stack, system.udp_options());
            port.stack_set_transport(port_stack, port.udp_options());
            compare(@"stack: the transport protocol can be replaced",
                    @(system.definition_equal(system.options_definition(system.stack_transport(system_stack)), system.definition_udp())),
                    @(port.definition_equal(port.options_definition(port.stack_transport(port_stack)), port.definition_udp())));
            compare(@"stack: the internet protocol is the IP one",
                    @(system.definition_equal(system.options_definition(system.stack_internet(system_stack)), system.definition_ip())),
                    @(port.definition_equal(port.options_definition(port.stack_internet(port_stack)), port.definition_ip())));
        }

        /* the identity of a protocol, and which one an object is */
        {
            compare(@"definition: the same TCP twice is equal", @(system.definition_equal(system.definition_tcp(), system.definition_tcp())),
                    @(port.definition_equal(port.definition_tcp(), port.definition_tcp())));
            compare(@"definition: TCP is not UDP", @(system.definition_equal(system.definition_tcp(), system.definition_udp())),
                    @(port.definition_equal(port.definition_tcp(), port.definition_udp())));
            compare(@"definition: nothing is equal to something", @(system.definition_equal(NULL, system.definition_tcp())),
                    @(port.definition_equal(NULL, port.definition_tcp())));
            nw_protocol_options_t system_tcp = system.tcp_options(), port_tcp = port.tcp_options();
            nw_protocol_options_t system_quic = system.quic_options(), port_quic = port.quic_options();
            nw_protocol_metadata_t system_ip = system.ip_metadata(), port_ip = port.ip_metadata();
            nw_protocol_metadata_t system_udp = system.udp_metadata(), port_udp = port.udp_metadata();
            nw_protocol_metadata_t system_wsm = system.ws_metadata(nw_ws_opcode_text), port_wsm = port.ws_metadata(nw_ws_opcode_text);
            compare(@"metadata: an IP packet is IP", @(system.is_ip(system_ip)), @(port.is_ip(port_ip)));
            compare(@"metadata: and is not TCP", @(system.is_tcp(system_ip)), @(port.is_tcp(port_ip)));
            compare(@"metadata: a UDP message is UDP", @(system.is_udp(system_udp)), @(port.is_udp(port_udp)));
            compare(@"metadata: a WebSocket frame is WebSocket", @(system.is_ws(system_wsm)), @(port.is_ws(port_wsm)));
            compare(@"metadata: a WebSocket frame is not UDP", @(system.is_udp(system_wsm)), @(port.is_udp(port_wsm)));
            compare(@"metadata: IP options are not IP metadata", @(system.is_ip(system_tcp)), @(port.is_ip(port_tcp)));
            compare(@"metadata: TCP options are not TCP metadata", @(system.is_tcp(system_tcp)), @(port.is_tcp(port_tcp)));
            compare(@"metadata: QUIC options are QUIC", @(system.options_is_quic(system_quic)), @(port.options_is_quic(port_quic)));
            compare(@"metadata: TCP options are not QUIC", @(system.options_is_quic(system_tcp)), @(port.options_is_quic(port_tcp)));
            compare(@"metadata: an IP packet is not QUIC", @(system.is_quic(system_ip)), @(port.is_quic(port_ip)));
            compare(@"metadata: the definition of options is the protocol's",
                    @(system.definition_equal(system.options_definition(system_tcp), system.definition_tcp())),
                    @(port.definition_equal(port.options_definition(port_tcp), port.definition_tcp())));
            compare(@"metadata: and so is the definition of a message",
                    @(system.definition_equal(system.metadata_definition(system_wsm), system.definition_ws())),
                    @(port.definition_equal(port.metadata_definition(port_wsm), port.definition_ws())));
            compare(@"metadata: a WebSocket frame is a framer's message", @(system.metadata_is_framer_message(system_wsm)),
                    @(port.metadata_is_framer_message(port_wsm)));
            compare(@"metadata: an IP packet is not", @(system.metadata_is_framer_message(system_ip)),
                    @(port.metadata_is_framer_message(port_ip)));
            compare(@"metadata: a UDP message is not", @(system.metadata_is_framer_message(system_udp)),
                    @(port.metadata_is_framer_message(port_udp)));
            nw_protocol_definition_t system_framer = system.framer_definition("_mine._tcp", 0, nil),
                port_framer = port.framer_definition("_mine._tcp", 0, nil);
            compare(@"metadata: a message of a program is a framer's message",
                    @(system.metadata_is_framer_message(system.framer_message(system_framer))),
                    @(port.metadata_is_framer_message(port.framer_message(port_framer))));
        }

        /* the options of IP, TCP, TLS and UDP, and the metadata of a message */
        {
            nw_protocol_options_t system_tcp = system.tcp_options(), port_tcp = port.tcp_options();
            system.tcp_no_delay(system_tcp, true); port.tcp_no_delay(port_tcp, true);
            system.tcp_no_options(system_tcp, true); port.tcp_no_options(port_tcp, true);
            system.tcp_no_push(system_tcp, true); port.tcp_no_push(port_tcp, true);
            system.tcp_disable_ecn(system_tcp, true); port.tcp_disable_ecn(port_tcp, true);
            system.tcp_disable_ack(system_tcp, true); port.tcp_disable_ack(port_tcp, true);
            system.tcp_retransmit_fin(system_tcp, true); port.tcp_retransmit_fin(port_tcp, true);
            system.tcp_fast_open(system_tcp, true); port.tcp_fast_open(port_tcp, true);
            system.tcp_keepalive(system_tcp, true); port.tcp_keepalive(port_tcp, true);
            system.tcp_connection_timeout(system_tcp, 5); port.tcp_connection_timeout(port_tcp, 5);
            system.tcp_keepalive_count(system_tcp, 3); port.tcp_keepalive_count(port_tcp, 3);
            system.tcp_keepalive_idle(system_tcp, 4); port.tcp_keepalive_idle(port_tcp, 4);
            system.tcp_keepalive_interval(system_tcp, 5); port.tcp_keepalive_interval(port_tcp, 5);
            system.tcp_mss(system_tcp, 1200); port.tcp_mss(port_tcp, 1200);
            system.tcp_persist(system_tcp, 6); port.tcp_persist(port_tcp, 6);
            system.tcp_drop_time(system_tcp, 7); port.tcp_drop_time(port_tcp, 7);
            system.tcp_multipath_version(system_tcp, (nw_multipath_version_t)1);
            port.tcp_multipath_version(port_tcp, (nw_multipath_version_t)1);
            nw_protocol_options_t system_udp = system.udp_options(), port_udp = port.udp_options();
            system.udp_no_checksum(system_udp, true); port.udp_no_checksum(port_udp, true);
            nw_protocol_options_t system_ip = system.stack_internet(system.parameters_stack(system.parameters_create())),
                port_ip = port.stack_internet(port.parameters_stack(port.parameters_create()));
            system.ip_version(system_ip, nw_ip_version_4); port.ip_version(port_ip, nw_ip_version_4);
            system.ip_hop_limit(system_ip, 33); port.ip_hop_limit(port_ip, 33);
            system.ip_receive_time(system_ip, true); port.ip_receive_time(port_ip, true);
            system.ip_no_fragmentation(system_ip, true); port.ip_no_fragmentation(port_ip, true);
            system.ip_minimum_mtu(system_ip, true); port.ip_minimum_mtu(port_ip, true);
            system.ip_address_preference(system_ip, (nw_ip_local_address_preference_t)1);
            port.ip_address_preference(port_ip, (nw_ip_local_address_preference_t)1);
            system.ip_no_loopback(system_ip, true); port.ip_no_loopback(port_ip, true);
            nw_protocol_metadata_t system_meta = system.ip_metadata(), port_meta = port.ip_metadata();
            compare(@"metadata: the service class of an IP packet", @(system.ip_service_class(system_meta)),
                    @(port.ip_service_class(port_meta)));
            system.ip_set_service_class(system_meta, nw_service_class_interactive_voice);
            port.ip_set_service_class(port_meta, nw_service_class_interactive_voice);
            compare(@"metadata: and after it is set", @(system.ip_service_class(system_meta)), @(port.ip_service_class(port_meta)));
            compare(@"metadata: the ECN flag of an IP packet", @(system.ip_ecn(system_meta)), @(port.ip_ecn(port_meta)));
            system.ip_set_ecn(system_meta, nw_ip_ecn_flag_ect_0);
            port.ip_set_ecn(port_meta, nw_ip_ecn_flag_ect_0);
            compare(@"metadata: and after it is set", @(system.ip_ecn(system_meta)), @(port.ip_ecn(port_meta)));
            compare(@"metadata: the receive time of an IP packet", @(system.ip_receive_time_value(system_meta)),
                    @(port.ip_receive_time_value(port_meta)));
            compare(@"metadata: the send buffer of a TCP message", @(system.tcp_send_buffer(system_meta)),
                    @(port.tcp_send_buffer(port_meta)));
            compare(@"metadata: the receive buffer of a TCP message", @(system.tcp_receive_buffer(system_meta)),
                    @(port.tcp_receive_buffer(port_meta)));
            compare(@"sec protocol: the options of a TLS one", @(system.tls_sec_options(system.tls_options()) != NULL),
                    @(port.tls_sec_options(port.tls_options()) != NULL));
            compare(@"sec protocol: the options of a TCP one", @(system.tls_sec_options(system_tcp) != NULL),
                    @(port.tls_sec_options(port_tcp) != NULL));
            compare(@"sec protocol: the options of a QUIC one", @(system.quic_sec_options(system.quic_options()) != NULL),
                    @(port.quic_sec_options(port.quic_options()) != NULL));
            compare(@"sec protocol: the options of a TCP one are not QUIC's",
                    @(system.quic_sec_options(system_tcp) != NULL), @(port.quic_sec_options(port_tcp) != NULL));
            compare(@"sec protocol: the metadata of an IP packet", @(system.tls_sec_metadata(system_meta) != NULL),
                    @(port.tls_sec_metadata(port_meta) != NULL));
            compare(@"sec protocol: and the QUIC metadata of an IP packet is none", @(system.quic_sec_metadata(system_meta) != NULL),
                    @(port.quic_sec_metadata(port_meta) != NULL));
        }

        /* the content of a message */
        {
            nw_content_context_t system_context = system.context_create("ctx"), port_context = port.context_create("ctx");
            compare(@"content: the defaults",
                    [NSString stringWithFormat:@"id=%@ priority=%.2f expiration=%llu final=%d antecedent=%d",
                            str(system.context_identifier(system_context)), system.context_priority(system_context),
                            system.context_expiration(system_context), system.context_is_final(system_context),
                            system.context_antecedent(system_context) != NULL],
                    [NSString stringWithFormat:@"id=%@ priority=%.2f expiration=%llu final=%d antecedent=%d",
                            str(port.context_identifier(port_context)), port.context_priority(port_context),
                            port.context_expiration(port_context), port.context_is_final(port_context),
                            port.context_antecedent(port_context) != NULL]);
            system.context_set_priority(system_context, 0.75); port.context_set_priority(port_context, 0.75);
            system.context_set_expiration(system_context, 1500); port.context_set_expiration(port_context, 1500);
            compare(@"content: a priority and an expiration that were set",
                    [NSString stringWithFormat:@"%.2f %llu", system.context_priority(system_context),
                            system.context_expiration(system_context)],
                    [NSString stringWithFormat:@"%.2f %llu", port.context_priority(port_context),
                            port.context_expiration(port_context)]);
            system.context_set_final(system_context, true); port.context_set_final(port_context, true);
            system.context_set_priority(system_context, 0.25); port.context_set_priority(port_context, 0.25);
            system.context_set_expiration(system_context, 99); port.context_set_expiration(port_context, 99);
            compare(@"content: and a final context takes no more of either",
                    [NSString stringWithFormat:@"%.2f %llu %d", system.context_priority(system_context),
                            system.context_expiration(system_context), system.context_is_final(system_context)],
                    [NSString stringWithFormat:@"%.2f %llu %d", port.context_priority(port_context),
                            port.context_expiration(port_context), port.context_is_final(port_context)]);
            nw_content_context_t system_open = system.context_create("open"), port_open = port.context_create("open");
            nw_content_context_t system_antecedent = system.context_create("first"), port_antecedent = port.context_create("first");
            system.context_set_antecedent(system_open, system_antecedent);
            port.context_set_antecedent(port_open, port_antecedent);
            compare(@"content: the antecedent of a context is the context that was set",
                    @(system.context_antecedent(system_open) == system_antecedent),
                    @(port.context_antecedent(port_open) == port_antecedent));
            system.context_set_antecedent(system_context, system_antecedent);
            port.context_set_antecedent(port_context, port_antecedent);
            compare(@"content: and a final context takes no antecedent",
                    @(system.context_antecedent(system_context) != NULL),
                    @(port.context_antecedent(port_context) != NULL));
            compare(@"content: and naming no antecedent leaves none",
                    @(system.context_antecedent(system.context_create("none")) != NULL),
                    @(port.context_antecedent(port.context_create("none")) != NULL));
            nw_protocol_metadata_t system_ip_meta = system.ip_metadata(), port_ip_meta = port.ip_metadata();
            system.context_set_metadata(system_context, system_ip_meta);
            port.context_set_metadata(port_context, port_ip_meta);
            compare(@"content: the metadata of a protocol is there",
                    @(system.context_metadata(system_open, system.definition_ip()) == system_ip_meta),
                    @(port.context_metadata(port_open, port.definition_ip()) == port_ip_meta));
            compare(@"content: and no other protocol has any",
                    @(system.context_metadata(system_open, system.definition_tcp()) != NULL),
                    @(port.context_metadata(port_open, port.definition_tcp()) != NULL));
            __block int system_seen = 0, port_seen = 0;
            system.context_foreach(system_open, ^(nw_protocol_definition_t d, nw_protocol_metadata_t m) { system_seen++; });
            port.context_foreach(port_open, ^(nw_protocol_definition_t d, nw_protocol_metadata_t m) { port_seen++; });
            compare(@"content: and it is enumerated once", @(system_seen), @(port_seen));
            /* A context with no name is not asked of the host: nw_content_context_create(NULL) traps
               there (measured), so there is no answer to compare - the port refuses it instead, which
               is what the header says a factory does when it fails. */
        }

        /* the TXT record of a service */
        {
            nw_txt_record_t system_record = system.txt_bytes(record_bytes, sizeof record_bytes);
            nw_txt_record_t port_record = port.txt_bytes(record_bytes, sizeof record_bytes);
            compare(@"txt: a record made of bytes", txt_shape(system, system_record), txt_shape(port, port_record));
            compare(@"txt: the key with a value", @(system.txt_find(system_record, "key")), @(port.txt_find(port_record, "key")));
            compare(@"txt: the key with no value", @(system.txt_find(system_record, "abc")), @(port.txt_find(port_record, "abc")));
            compare(@"txt: a key that is not there", @(system.txt_find(system_record, "zzz")), @(port.txt_find(port_record, "zzz")));
            compare(@"txt: an empty key", @(system.txt_find(system_record, "")), @(port.txt_find(port_record, "")));
            compare(@"txt: a key that is not ASCII", @(system.txt_find(system_record, "k\xc3" "y")),
                    @(port.txt_find(port_record, "k\xc3" "y")));
            compare(@"txt: a key longer than a character-string", @(system.txt_find(system_record, "0123456789")),
                    @(port.txt_find(port_record, "0123456789")));
            __block NSMutableString *system_seen = [NSMutableString string], *port_seen = [NSMutableString string];
            system.txt_access_key(system_record, "key", ^bool(const char *key, nw_txt_record_find_key_t found, const uint8_t *value, size_t length) {
                [system_seen appendFormat:@"%s/%d/%.*s", key, found, (int)length, value];
                return true;
            });
            port.txt_access_key(port_record, "key", ^bool(const char *key, nw_txt_record_find_key_t found, const uint8_t *value, size_t length) {
                [port_seen appendFormat:@"%s/%d/%.*s", key, found, (int)length, value];
                return true;
            });
            compare(@"txt: a key read through its block", system_seen, port_seen);
            nw_txt_record_t system_dict = system.txt_dictionary(), port_dict = port.txt_dictionary();
            compare(@"txt: a dictionary record is empty", txt_shape(system, system_dict), txt_shape(port, port_dict));
            const uint8_t value[] = {'1'};
            compare(@"txt: a key can be set", @(system.txt_set(system_dict, "a", value, 1)), @(port.txt_set(port_dict, "a", value, 1)));
            compare(@"txt: and a key with no value", @(system.txt_set(system_dict, "b", NULL, 0)),
                    @(port.txt_set(port_dict, "b", NULL, 0)));
            compare(@"txt: but not an invalid key", @(system.txt_set(system_dict, "", value, 1)),
                    @(port.txt_set(port_dict, "", value, 1)));
            compare(@"txt: a dictionary with two keys", txt_shape(system, system_dict), txt_shape(port, port_dict));
            compare(@"txt: a key can be replaced", @(system.txt_set(system_dict, "a", (const uint8_t *)"2", 1)),
                    @(port.txt_set(port_dict, "a", (const uint8_t *)"2", 1)));
            compare(@"txt: a key can be removed", @(system.txt_remove(system_dict, "b")), @(port.txt_remove(port_dict, "b")));
            compare(@"txt: and a key that is not there cannot", @(system.txt_remove(system_dict, "zzz")),
                    @(port.txt_remove(port_dict, "zzz")));
            compare(@"txt: a record with one key", txt_shape(system, system_dict), txt_shape(port, port_dict));
            compare(@"txt: two records with the same keys are equal", @(system.txt_equal(system_dict, system.txt_copy(system_dict))),
                    @(port.txt_equal(port_dict, port.txt_copy(port_dict))));
            compare(@"txt: and two that differ are not", @(system.txt_equal(system_dict, system_record)),
                    @(port.txt_equal(port_dict, port_record)));
            compare(@"txt: nothing is equal to nothing", @(system.txt_equal(NULL, NULL)), @(port.txt_equal(NULL, NULL)));
            compare(@"txt: and nothing is not equal to a record", @(system.txt_equal(NULL, system_dict)),
                    @(port.txt_equal(NULL, port_dict)));
            compare(@"txt: an empty key count", @(system.txt_count(NULL)), @(port.txt_count(NULL)));
            compare(@"txt: a record that is not one", txt_shape(system, system.txt_bytes((const uint8_t *)"\002" "ab", 3)),
                    txt_shape(port, port.txt_bytes((const uint8_t *)"\002" "ab", 3)));
            compare(@"txt: a record of no bytes at all", txt_shape(system, system.txt_bytes((const uint8_t *)"", 0)),
                    txt_shape(port, port.txt_bytes((const uint8_t *)"", 0)));
        }

        /* the WebSocket objects */
        {
            nw_protocol_metadata_t system_meta = system.ws_metadata(nw_ws_opcode_text), port_meta = port.ws_metadata(nw_ws_opcode_text);
            compare(@"ws: the defaults of a frame",
                    [NSString stringWithFormat:@"opcode=%d close=%d", system.ws_opcode(system_meta), system.ws_close_code(system_meta)],
                    [NSString stringWithFormat:@"opcode=%d close=%d", port.ws_opcode(port_meta), port.ws_close_code(port_meta)]);
            system.ws_set_close_code(system_meta, nw_ws_close_code_going_away);
            port.ws_set_close_code(port_meta, nw_ws_close_code_going_away);
            compare(@"ws: a close code that was set", @(system.ws_close_code(system_meta)), @(port.ws_close_code(port_meta)));
            compare(@"ws: the opcode of something that is not a frame", @(system.ws_opcode(system.ip_metadata())),
                    @(port.ws_opcode(port.ip_metadata())));
            compare(@"ws: no server response until there is one", @(system.ws_server_response(system_meta) != NULL),
                    @(port.ws_server_response(port_meta) != NULL));
            nw_ws_response_t system_response = system.ws_response_create(400, "chat"), port_response = port.ws_response_create(400, "chat");
            compare(@"ws: a response keeps its status and its subprotocol",
                    [NSString stringWithFormat:@"%d %@", system.ws_response_status(system_response),
                            str(system.ws_response_subprotocol(system_response))],
                    [NSString stringWithFormat:@"%d %@", port.ws_response_status(port_response),
                            str(port.ws_response_subprotocol(port_response))]);
            system.ws_response_add_header(system_response, "X-A", "1");
            port.ws_response_add_header(port_response, "X-A", "1");
            __block NSMutableString *system_headers = [NSMutableString string], *port_headers = [NSMutableString string];
            system.ws_response_headers(system_response, ^bool(const char *name, const char *value) {
                [system_headers appendFormat:@"%s=%s ", name, value];
                return true;
            });
            port.ws_response_headers(port_response, ^bool(const char *name, const char *value) {
                [port_headers appendFormat:@"%s=%s ", name, value];
                return true;
            });
            compare(@"ws: and its headers are the ones that were added", system_headers, port_headers);
            compare(@"ws: a response with no subprotocol",
                    @(system.ws_response_subprotocol(system.ws_response_create(200, NULL)) != NULL),
                    @(port.ws_response_subprotocol(port.ws_response_create(200, NULL)) != NULL));
            nw_protocol_options_t system_ws = system.ws_options(nw_ws_version_13), port_ws = port.ws_options(nw_ws_version_13);
            system.ws_add_subprotocol(system_ws, "chat"); port.ws_add_subprotocol(port_ws, "chat");
            system.ws_add_header(system_ws, "X-B", "2"); port.ws_add_header(port_ws, "X-B", "2");
            system.ws_auto_ping(system_ws, true); port.ws_auto_ping(port_ws, true);
            system.ws_maximum_message(system_ws, 4096); port.ws_maximum_message(port_ws, 4096);
            system.ws_skip_handshake(system_ws, true); port.ws_skip_handshake(port_ws, true);
            compare(@"ws: the options of a WebSocket carry its definition",
                    @(system.definition_equal(system.options_definition(system_ws), system.definition_ws())),
                    @(port.definition_equal(port.options_definition(port_ws), port.definition_ws())));
            compare(@"ws: options of no version are still options", @(system.ws_options(nw_ws_version_invalid) != NULL),
                    @(port.ws_options(nw_ws_version_invalid) != NULL));
            compare(@"ws: nothing to enumerate in no request",
                    @(system.ws_request_subprotocols(NULL, ^bool(const char *subprotocol) { return true; })),
                    @(port.ws_request_subprotocols(NULL, ^bool(const char *subprotocol) { return true; })));
            compare(@"ws: and no headers either",
                    @(system.ws_request_headers(NULL, ^bool(const char *name, const char *value) { return true; })),
                    @(port.ws_request_headers(NULL, ^bool(const char *name, const char *value) { return true; })));
        }

        /* a framer a program writes */
        {
            nw_protocol_definition_t system_framer = system.framer_definition("_http._tcp", 0, ^(nw_framer_t f) { return nw_framer_start_result_ready; }),
                port_framer = port.framer_definition("_http._tcp", 0, ^(nw_framer_t f) { return nw_framer_start_result_ready; });
            compare(@"framer: two definitions of one name are equal",
                    @(system.definition_equal(system_framer, system.framer_definition("_http._tcp", 0, nil))),
                    @(port.definition_equal(port_framer, port.framer_definition("_http._tcp", 0, nil))));
            compare(@"framer: and two of different names are not",
                    @(system.definition_equal(system_framer, system.framer_definition("_other._tcp", 0, nil))),
                    @(port.definition_equal(port_framer, port.framer_definition("_other._tcp", 0, nil))));
            compare(@"framer: and neither are two of one name and different flags",
                    @(system.definition_equal(system_framer, system.framer_definition("_http._tcp", 1, nil))),
                    @(port.definition_equal(port_framer, port.framer_definition("_http._tcp", 1, nil))));
            compare(@"framer: a definition with no name", @(system.framer_definition(NULL, 0, nil) != NULL),
                    @(port.framer_definition(NULL, 0, nil) != NULL));
            nw_protocol_options_t system_options = system.framer_options(system_framer), port_options = port.framer_options(port_framer);
            compare(@"framer: the options of a framer carry its definition",
                    @(system.definition_equal(system.options_definition(system_options), system_framer)),
                    @(port.definition_equal(port.options_definition(port_options), port_framer)));
            NSString *marker = @"marker";
            system.framer_set_object(system_options, "key", marker); port.framer_set_object(port_options, "key", marker);
            compare(@"framer: an object value on the options is read back",
                    @(system.framer_copy_object(system_options, "key") == marker), @(port.framer_copy_object(port_options, "key") == marker));
            compare(@"framer: and a key nobody set is nothing", @(system.framer_copy_object(system_options, "other") != NULL),
                    @(port.framer_copy_object(port_options, "other") != NULL));
            nw_framer_message_t system_message = system.framer_message(system_framer), port_message = port.framer_message(port_framer);
            compare(@"framer: a message of a framer is its own protocol",
                    @(system.definition_equal(system.metadata_definition(system_message), system_framer)),
                    @(port.definition_equal(port.metadata_definition(port_message), port_framer)));
            int system_value = 7, port_value = 7;
            system.message_set_value(system_message, "raw", &system_value, ^(void *pointer) { });
            port.message_set_value(port_message, "raw", &port_value, ^(void *pointer) { });
            __block int system_seen_value = 0, port_seen_value = 0;
            system.message_access_value(system_message, "raw", ^bool(const void *pointer) { system_seen_value = pointer ? *(const int *)pointer : -1; return true; });
            port.message_access_value(port_message, "raw", ^bool(const void *pointer) { port_seen_value = pointer ? *(const int *)pointer : -1; return true; });
            compare(@"framer: a raw value on a message is read back", @(system_seen_value), @(port_seen_value));
            system.message_set_object(system_message, "object", marker); port.message_set_object(port_message, "object", marker);
            compare(@"framer: an object value on a message is read back",
                    @(system.message_copy_object(system_message, "object") == marker),
                    @(port.message_copy_object(port_message, "object") == marker));
            compare(@"framer: and a value nobody set is nothing", @(system.message_copy_object(system_message, "none") != NULL),
                    @(port.message_copy_object(port_message, "none") != NULL));
            compare(@"framer: options of nothing are nothing", @(system.framer_options(NULL) != NULL),
                    @(port.framer_options(NULL) != NULL));
        }

        /* the QUIC options and metadata */
        {
            nw_protocol_options_t system_quic = system.quic_options(), port_quic = port.quic_options();
            compare(@"quic: the defaults", quic_options_shape(system, system_quic), quic_options_shape(port, port_quic));
            system.quic_idle(system_quic, 1234); port.quic_idle(port_quic, 1234);
            system.quic_max_udp(system_quic, 1400); port.quic_max_udp(port_quic, 1400);
            system.quic_max_data(system_quic, 999); port.quic_max_data(port_quic, 999);
            system.quic_data_local(system_quic, 11); port.quic_data_local(port_quic, 11);
            system.quic_data_remote(system_quic, 12); port.quic_data_remote(port_quic, 12);
            system.quic_data_uni(system_quic, 13); port.quic_data_uni(port_quic, 13);
            system.quic_streams_bidi(system_quic, 7); port.quic_streams_bidi(port_quic, 7);
            system.quic_streams_uni(system_quic, 8); port.quic_streams_uni(port_quic, 8);
            system.quic_stream_unidirectional(system_quic, true); port.quic_stream_unidirectional(port_quic, true);
            system.quic_stream_datagram(system_quic, true); port.quic_stream_datagram(port_quic, true);
            system.quic_datagram_frame(system_quic, 1200); port.quic_datagram_frame(port_quic, 1200);
            system.quic_add_application_protocol(system_quic, "h3"); port.quic_add_application_protocol(port_quic, "h3");
            compare(@"quic: every setting that was made", quic_options_shape(system, system_quic), quic_options_shape(port, port_quic));
            /* Once a program has set the frame size it is a value both sides stand behind. */
            compare(@"quic: the datagram frame size that was set", @(system.quic_datagram_frame_value(system_quic)),
                    @(port.quic_datagram_frame_value(port_quic)));
            nw_protocol_metadata_t system_meta = system.ip_metadata(), port_meta = port.ip_metadata();
            nw_protocol_options_t system_plain = system.tcp_options(), port_plain = port.tcp_options();
            compare(@"quic: the metadata of a message that is not QUIC", quic_metadata_shape(system, system_meta),
                    quic_metadata_shape(port, port_meta));
            compare(@"quic: the datagram frame size asked of options that are not QUIC's",
                    @(system.quic_datagram_frame_value(system_plain)), @(port.quic_datagram_frame_value(port_plain)));
            system.quic_datagram_frame(system_plain, 1200); port.quic_datagram_frame(port_plain, 1200);
            compare(@"quic: and setting it there changes nothing", @(system.quic_datagram_frame_value(system_plain)),
                    @(port.quic_datagram_frame_value(port_plain)));
            compare(@"quic: and neither does a datagram stream", @(system.quic_stream_datagram_value(system_plain)),
                    @(port.quic_stream_datagram_value(port_plain)));
            system.quic_keepalive(system_meta, 42); port.quic_keepalive(port_meta, 42);
            system.quic_local_bidi(system_meta, 5); port.quic_local_bidi(port_meta, 5);
            system.quic_application_error(system_meta, 7, "why"); port.quic_application_error(port_meta, 7, "why");
            system.quic_stream_error(system_meta, 9); port.quic_stream_error(port_meta, 9);
            compare(@"quic: and the setters leave it as it was", quic_metadata_shape(system, system_meta),
                    quic_metadata_shape(port, port_meta));
        }

        /* the descriptors of what to look for and what to publish */
        {
            nw_browse_descriptor_t system_browse = system.browse_bonjour("_http._tcp", "local."),
                port_browse = port.browse_bonjour("_http._tcp", "local.");
            compare(@"browse: a Bonjour browse",
                    [NSString stringWithFormat:@"%@ %@ txt=%d", str(system.browse_type(system_browse)),
                            str(system.browse_domain(system_browse)), system.browse_include_txt(system_browse)],
                    [NSString stringWithFormat:@"%@ %@ txt=%d", str(port.browse_type(port_browse)),
                            str(port.browse_domain(port_browse)), port.browse_include_txt(port_browse)]);
            system.browse_set_include_txt(system_browse, true); port.browse_set_include_txt(port_browse, true);
            compare(@"browse: and whether it takes the records with it", @(system.browse_include_txt(system_browse)),
                    @(port.browse_include_txt(port_browse)));
            compare(@"browse: a browse with no domain", str(system.browse_domain(system.browse_bonjour("_ipp._tcp", NULL))),
                    str(port.browse_domain(port.browse_bonjour("_ipp._tcp", NULL))));
            compare(@"browse: a browse of no type", @(system.browse_bonjour(NULL, "local.") != NULL),
                    @(port.browse_bonjour(NULL, "local.") != NULL));
            compare(@"browse: an application service",
                    str(system.browse_application_name(system.browse_application("com.example.app"))),
                    str(port.browse_application_name(port.browse_application("com.example.app"))));
            nw_advertise_descriptor_t system_advertise = system.advertise_bonjour("name", "_http._tcp", "local."),
                port_advertise = port.advertise_bonjour("name", "_http._tcp", "local.");
            compare(@"advertise: a service is renamed by default", @(system.advertise_no_auto_rename(system_advertise)),
                    @(port.advertise_no_auto_rename(port_advertise)));
            system.advertise_set_no_auto_rename(system_advertise, true); port.advertise_set_no_auto_rename(port_advertise, true);
            compare(@"advertise: and not renamed once that is said", @(system.advertise_no_auto_rename(system_advertise)),
                    @(port.advertise_no_auto_rename(port_advertise)));
            system.advertise_txt_bytes(system_advertise, record_bytes, sizeof record_bytes);
            port.advertise_txt_bytes(port_advertise, record_bytes, sizeof record_bytes);
            compare(@"advertise: bytes and then an object are one record", @(system.advertise_copy_txt_object(system_advertise) != NULL),
                    @(port.advertise_copy_txt_object(port_advertise) != NULL));
            nw_txt_record_t system_object = system.txt_dictionary(), port_object = port.txt_dictionary();
            system.txt_set(system_object, "a", (const uint8_t *)"1", 1);
            port.txt_set(port_object, "a", (const uint8_t *)"1", 1);
            system.advertise_txt_object(system_advertise, system_object);
            port.advertise_txt_object(port_advertise, port_object);
            compare(@"advertise: the record object that was set", txt_shape(system, system.advertise_copy_txt_object(system_advertise)),
                    txt_shape(port, port.advertise_copy_txt_object(port_advertise)));
            compare(@"advertise: an application service",
                    str(system.advertise_application_name(system.advertise_application("com.example.app"))),
                    str(port.advertise_application_name(port.advertise_application("com.example.app"))));
            compare(@"advertise: a service of no type", @(system.advertise_bonjour("n", NULL, "local.") != NULL),
                    @(port.advertise_bonjour("n", NULL, "local.") != NULL));
        }

        /* the group of connections and the privacy of their names */
        {
            nw_endpoint_t system_group = system.endpoint_host("224.0.0.251", "5353"),
                port_group = port.endpoint_host("224.0.0.251", "5353");
            nw_group_descriptor_t system_multicast = system.group_multicast(system_group),
                port_multicast = port.group_multicast(port_group);
            compare(@"group: a multicast group takes unicast traffic by default",
                    @(system.group_disable_unicast_value(system_multicast)), @(port.group_disable_unicast_value(port_multicast)));
            system.group_disable_unicast(system_multicast, true); port.group_disable_unicast(port_multicast, true);
            system.group_specific_source(system_multicast, system.endpoint_host("192.0.2.1", "0"));
            port.group_specific_source(port_multicast, port.endpoint_host("192.0.2.1", "0"));
            compare(@"group: and not once that is prohibited", @(system.group_disable_unicast_value(system_multicast)),
                    @(port.group_disable_unicast_value(port_multicast)));
            /* nw_group_descriptor_add_endpoint is not compared: the host's own Network answers false
               and adds nothing for any endpoint at all - a name, an address, a URL, a Bonjour service,
               on a multicast group and on a multiplex one (measured, and in facts/Network/NWGroup.md) -
               which is not what its own header says. The port follows the header, and these two checks
               are the port's own answer rather than a comparison: a peer is added and enumerated, an
               endpoint that names no peer is refused. */
            nw_group_descriptor_t port_multiplex = port.group_multiplex(port.endpoint_host("192.0.2.3", "9"));
            BOOL port_added = port.group_add(port_multiplex, port.endpoint_host("peer.test", "9"));
            __block int port_members = 0;
            port.group_endpoints(port_multiplex, ^bool(nw_endpoint_t endpoint) { port_members++; return true; });
            compare(@"group: a peer is added to a group and enumerated",
                    [NSString stringWithFormat:@"%d %d", port_added, port_members], @"1 1");
            compare(@"group: an endpoint that names no peer is refused",
                    @(port.group_add(port_multiplex, port.endpoint_url("https://peer.test/x"))),
                    @(port.group_add(port_multiplex, NULL)));
            compare(@"group: a group of no endpoint", @(system.group_multicast(NULL) != NULL), @(port.group_multicast(NULL) != NULL));
            compare(@"group: a multiplex group of no endpoint", @(system.group_multiplex(NULL) != NULL),
                    @(port.group_multiplex(NULL) != NULL));
            nw_privacy_context_t system_privacy = system.privacy_create("app"), port_privacy = port.privacy_create("app");
            compare(@"privacy: a context with no name", @(system.privacy_create(NULL) != NULL), @(port.privacy_create(NULL) != NULL));
            nw_resolver_config_t system_resolver = system.resolver_tls(system.endpoint_host("192.0.2.53", "853")),
                port_resolver = port.resolver_tls(port.endpoint_host("192.0.2.53", "853"));
            compare(@"privacy: a resolver with a server", @(system_resolver != NULL), @(port_resolver != NULL));
            system.resolver_add_server(system_resolver, system.endpoint_host("192.0.2.54", "853"));
            port.resolver_add_server(port_resolver, port.endpoint_host("192.0.2.54", "853"));
            system.privacy_require_encrypted(system_privacy, true, system_resolver);
            port.privacy_require_encrypted(port_privacy, true, port_resolver);
            system.privacy_disable_logging(system_privacy); port.privacy_disable_logging(port_privacy);
            system.privacy_flush(system_privacy); port.privacy_flush(port_privacy);
            nw_parameters_t system_parameters = system.parameters_create(), port_parameters = port.parameters_create();
            system.set_privacy(system_parameters, system_privacy); port.set_privacy(port_parameters, port_privacy);
            compare(@"privacy: a parameters can be given one", @(system_parameters != NULL), @(port_parameters != NULL));
            compare(@"privacy: a resolver of no endpoint", @(system.resolver_tls(NULL) != NULL), @(port.resolver_tls(NULL) != NULL));
            compare(@"privacy: an HTTPS resolver of no endpoint", @(system.resolver_https(NULL) != NULL),
                    @(port.resolver_https(NULL) != NULL));
            compare(@"privacy: an HTTPS resolver of a URL",
                    @(system.resolver_https(system.endpoint_url("https://dns.example/dns-query")) != NULL),
                    @(port.resolver_https(port.endpoint_url("https://dns.example/dns-query")) != NULL));
        }

        /* the prohibited interfaces of a parameters, the two rows the review named */
        {
            nw_parameters_t system_parameters = system.parameters_create(), port_parameters = port.parameters_create();
            __block int system_count = 0, port_count = 0;
            system.parameters_iterate_prohibited_interfaces(system_parameters, ^bool(nw_interface_t interface) {
                system_count++;
                return true;
            });
            port.parameters_iterate_prohibited_interfaces(port_parameters, ^bool(nw_interface_t interface) {
                port_count++;
                return true;
            });
            compare(@"parameters: the prohibited interfaces of a fresh one", @(system_count), @(port_count));
            system.parameters_clear_prohibited_interfaces(system_parameters);
            port.parameters_clear_prohibited_interfaces(port_parameters);
            __block int system_left = 0, port_left = 0;
            system.parameters_iterate_prohibited_interfaces(system_parameters, ^bool(nw_interface_t interface) {
                system_left++;
                return true;
            });
            port.parameters_iterate_prohibited_interfaces(port_parameters, ^bool(nw_interface_t interface) {
                port_left++;
                return true;
            });
            compare(@"parameters: and none of them after they are cleared", @(system_left), @(port_left));
        }

        /* the path: the five rows the review named, asked of a real path from each side's own monitor */
        {
            dispatch_queue_t system_queue = dispatch_queue_create("system.path", DISPATCH_QUEUE_SERIAL);
            dispatch_queue_t port_queue = dispatch_queue_create("port.path", DISPATCH_QUEUE_SERIAL);
            nw_path_monitor_t system_monitor = nw_path_monitor_create(), port_monitor = port.monitor_path();
            __block nw_path_t system_path = nil, port_path = nil;
            dispatch_semaphore_t system_got = dispatch_semaphore_create(0), port_got = dispatch_semaphore_create(0);
            nw_path_monitor_set_update_handler(system_monitor, ^(nw_path_t path) {
                if (!system_path) { system_path = path; dispatch_semaphore_signal(system_got); }
            });
            nw_path_monitor_set_queue(system_monitor, system_queue);
            nw_path_monitor_start(system_monitor);
            port.monitor_set_update(port_monitor, ^(nw_path_t path) {
                if (!port_path) { port_path = path; dispatch_semaphore_signal(port_got); }
            });
            port.monitor_set_queue(port_monitor, port_queue);
            port.monitor_start(port_monitor);
            dispatch_semaphore_wait(system_got, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC));
            dispatch_semaphore_wait(port_got, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC));
            CHECK(system_path != NULL && port_path != NULL, "both sides have a path of their own");
            if (system_path && port_path) {
                compare(@"path: whether it is a constrained network", @(system.path_is_constrained(system_path)),
                        @(port.path_is_constrained(port_path)));
                /* The port's answer, and it is an answer rather than a shape: this device's path is
                   not over a point-to-point interface, and SIOCGIFDSTADDR - the one ioctl that names
                   a router with no privilege - answers for those only, so the port enumerates nothing
                   and says so (facts/Network/NWPath.md). That is what is asserted. The host's own
                   enumeration is not asserted at all: what the host's routers are is not a fact this
                   program can check, and a check that cannot fail is worse than none. */
                __block int port_gateways = 0;
                port.path_enumerate_gateways(port_path, ^(nw_endpoint_t gateway) {
                    port_gateways++;
                });
                CHECK(port_gateways == 0,
                      "the port enumerates no gateway on a path that is not point-to-point");
                compare(@"path: why it is unsatisfied", @(system.path_unsatisfied_reason(system_path)),
                        @(port.path_unsatisfied_reason(port_path)));
                /* The link quality is the port's own check, and the host's answer is not one to
                   compare with: the host measures the quality of its own link and reports 20
                   (moderate) for a wired one, while the release the port builds for has no way to
                   ask its link anything and every path there answers "no measurement available",
                   which is the first of the four values (facts/Network/NWPath.md). Two different
                   machines' links are not one measurement. */
                CHECK(port.path_link_quality(port_path) == 0, "path: the port's link quality is the one it has");
                compare(@"path: whether it is ultra-constrained", @(system.path_is_ultra_constrained(system_path)),
                        @(port.path_is_ultra_constrained(port_path)));
            }
            nw_path_monitor_cancel(system_monitor); port.monitor_cancel(port_monitor);
        }

        /* The interface classifier, over the numbers measured on the host with getifaddrs' AF_LINK
           entries beside ifconfig -v (facts/Network/NWPath.md has the table). Each row is a
           synthetic ifaddrs chain the port's own classifier reads, so flipping a branch of it turns
           its own row red: the loopback number into cellular, the cellular number into loopback, the
           ethernet number into other, or the default into loopback each fail one row here. */
        {
            struct if_data info;
            unsigned char link[128];
            memset(&info, 0, sizeof info);
            memset(link, 0, sizeof link);
            struct sockaddr_dl *dl = (struct sockaddr_dl *)link;
            dl->sdl_len = (unsigned char)sizeof link;
            dl->sdl_family = AF_LINK;
            struct ifaddrs entry;
            memset(&entry, 0, sizeof entry);
            entry.ifa_addr = (struct sockaddr *)link;
            entry.ifa_data = &info;
            entry.ifa_flags = IFF_UP | IFF_RUNNING;

            info.ifi_type = 24;   /* lo0: softwareLoopback */
            entry.ifa_name = "lo0";
            entry.ifa_flags |= IFF_LOOPBACK;
            compare(@"path: the loopback number types the loopback", @(charon_path_interface_type(&entry)),
                    @(nw_interface_type_loopback));
            info.ifi_type = 6;    /* en0: ethernetCsmacd, which on this release is the Wi-Fi radio */
            entry.ifa_name = "en0";
            entry.ifa_flags = IFF_UP | IFF_RUNNING | IFF_BROADCAST;
            compare(@"path: the ethernet number types Wi-Fi", @(charon_path_interface_type(&entry)),
                    @(nw_interface_type_wifi));
            info.ifi_type = 0xff; /* XNU's IFT_CELLULAR: the cellular radio */
            entry.ifa_name = "pdp_ip0";
            entry.ifa_flags = IFF_UP | IFF_RUNNING | IFF_POINTOPOINT;
            compare(@"path: the cellular number types cellular", @(charon_path_interface_type(&entry)),
                    @(nw_interface_type_cellular));
            info.ifi_type = 1;    /* utun0: the kernel says `other`, and not IANA tunnel */
            entry.ifa_name = "utun0";
            entry.ifa_flags = IFF_UP | IFF_RUNNING | IFF_POINTOPOINT;
            compare(@"path: a tunnel keeps its own kind and is other", @(charon_path_interface_type(&entry)),
                    @(nw_interface_type_other));
            info.ifi_type = 209;  /* bridge100: IANA bridge */
            entry.ifa_name = "bridge100";
            entry.ifa_flags = IFF_UP | IFF_RUNNING | IFF_BROADCAST;
            compare(@"path: a bridge is other too", @(charon_path_interface_type(&entry)),
                    @(nw_interface_type_other));
            info.ifi_type = 0;    /* nothing the kernel classified: the point-to-point rule decides */
            entry.ifa_name = "pdp_ip1";
            compare(@"path: an unclassified point-to-point link is other without a gateway",
                    @(charon_path_interface_type(&entry)), @(nw_interface_type_other));
            /* What the path does with an interface the kernel names `other` - a tunnel, a bridge - and
               why the answer is its ADDRESS and not its type. Measured on this machine, reading only,
               three runs, stable: with 44 interfaces up, nw_path_enumerate_interfaces on a live path
               returns en0, en0 and utun21, and utun21 is a tunnel the classifier types `other` (its
               ifi_type is 1, IANA other, not 131, tunnel). So an `other` interface is on the path when
               it carries an address the path can be over; a bridge has none, and is dropped for that
               and not for its type. The mutants: taking the address away from the `other` branch turns
               the tunnel row red; putting the type filter back turns the tunnel row red too. */
            compare(@"path: a tunnel with an address is on the path, as the release puts it",
                    @(charon_path_wants_interface(nw_interface_type_other, nw_interface_type_other, true, false, true)), @YES);
            compare(@"path: a bridge with no address is not on it",
                    @(charon_path_wants_interface(nw_interface_type_other, nw_interface_type_other, true, false, false)), @NO);
            compare(@"path: the loopback is not on the path either",
                    @(charon_path_wants_interface(nw_interface_type_other, nw_interface_type_loopback, true, false, true)), @NO);
            compare(@"path: Wi-Fi is on the path when there is a route",
                    @(charon_path_wants_interface(nw_interface_type_other, nw_interface_type_wifi, true, false, true)), @YES);
            compare(@"path: the cellular radio is on it when the route is cellular",
                    @(charon_path_wants_interface(nw_interface_type_other, nw_interface_type_cellular, true, true, true)), @YES);
            compare(@"path: the cellular radio is not on it when the route is Wi-Fi",
                    @(charon_path_wants_interface(nw_interface_type_other, nw_interface_type_cellular, true, false, true)), @NO);
            compare(@"path: nothing is on a path with no route",
                    @(charon_path_wants_interface(nw_interface_type_other, nw_interface_type_wifi, false, false, true)), @NO);
            compare(@"path: a monitor asked for Wi-Fi takes only Wi-Fi",
                    @(charon_path_wants_interface(nw_interface_type_wifi, nw_interface_type_cellular, true, false, true)), @NO);
            compare(@"path: and a monitor asked for the cellular radio takes that",
                    @(charon_path_wants_interface(nw_interface_type_cellular, nw_interface_type_cellular, true, true, true)), @YES);
        }

        /* the errors and their domains */
        {
            compare(@"error: nothing is no error at all",
                    [NSString stringWithFormat:@"%d %d", system.error_domain(NULL), system.error_code(NULL)],
                    [NSString stringWithFormat:@"%d %d", port.error_domain(NULL), port.error_code(NULL)]);
            CFErrorRef system_error = system.error_cf(NULL), port_error = port.error_cf(NULL);
            compare(@"error: and no CFError either", @(system_error != NULL), @(port_error != NULL));
        }

        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
    }
    return charon_failures ? 1 : 0;
}
