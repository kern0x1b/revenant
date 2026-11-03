#ifndef REVENANT_NETWORK_C_H
#define REVENANT_NETWORK_C_H

#include <CoreFoundation/CFError.h>
#include <Security/SecProtocolOptions.h>
#include <dispatch/dispatch.h>
#include <os/availability.h>
#include <os/object.h>
#include <stdbool.h>
#include <stdint.h>

#define REVENANT_NW_API API_AVAILABLE(macos(10.14), ios(12.0), watchos(5.0), tvos(12.0))
#define REVENANT_NW_RETURNS_RETAINED __attribute__((ns_returns_retained))

_Pragma("clang assume_nonnull begin")

OS_OBJECT_DECL(nw_connection);
OS_OBJECT_DECL(nw_content_context);
OS_OBJECT_DECL(nw_endpoint);
OS_OBJECT_DECL(nw_error);
OS_OBJECT_DECL(nw_parameters);
OS_OBJECT_DECL(nw_protocol_options);
OS_OBJECT_DECL(nw_protocol_stack);

typedef enum {
    nw_connection_state_invalid = 0,
    nw_connection_state_waiting = 1,
    nw_connection_state_preparing = 2,
    nw_connection_state_ready = 3,
    nw_connection_state_failed = 4,
    nw_connection_state_cancelled = 5,
} nw_connection_state_t;

typedef enum {
    nw_error_domain_invalid = 0,
    nw_error_domain_posix = 1,
    nw_error_domain_dns = 2,
    nw_error_domain_tls = 3,
    nw_error_domain_wifi_aware = 4,
} nw_error_domain_t;

typedef void (^nw_parameters_configure_protocol_block_t)(nw_protocol_options_t options);
typedef void (^nw_connection_state_changed_handler_t)(nw_connection_state_t state, _Nullable nw_error_t error);
typedef void (^nw_connection_receive_completion_t)(_Nullable dispatch_data_t content, _Nullable nw_content_context_t context, bool is_complete, _Nullable nw_error_t error);
typedef void (^nw_connection_send_completion_t)(_Nullable nw_error_t error);

REVENANT_NW_API REVENANT_NW_RETURNS_RETAINED nw_connection_t nw_connection_create(nw_endpoint_t endpoint, nw_parameters_t parameters);
REVENANT_NW_API void nw_connection_set_queue(nw_connection_t connection, dispatch_queue_t queue);
REVENANT_NW_API void nw_connection_set_state_changed_handler(nw_connection_t connection, _Nullable nw_connection_state_changed_handler_t handler);
REVENANT_NW_API void nw_connection_start(nw_connection_t connection);
REVENANT_NW_API void nw_connection_cancel(nw_connection_t connection);
REVENANT_NW_API void nw_connection_send(nw_connection_t connection, _Nullable dispatch_data_t content, nw_content_context_t context, bool is_complete, nw_connection_send_completion_t completion);
REVENANT_NW_API void nw_connection_receive(nw_connection_t connection, uint32_t minimum_incomplete_length, uint32_t maximum_length, nw_connection_receive_completion_t completion);

REVENANT_NW_API extern const nw_content_context_t _nw_content_context_default_message;

REVENANT_NW_API REVENANT_NW_RETURNS_RETAINED nw_parameters_t nw_parameters_create(void);
REVENANT_NW_API REVENANT_NW_RETURNS_RETAINED nw_parameters_t nw_parameters_create_secure_tcp(nw_parameters_configure_protocol_block_t configure_tls, nw_parameters_configure_protocol_block_t configure_tcp);
REVENANT_NW_API REVENANT_NW_RETURNS_RETAINED nw_protocol_stack_t nw_parameters_copy_default_protocol_stack(nw_parameters_t parameters);
REVENANT_NW_API void nw_protocol_stack_set_transport_protocol(nw_protocol_stack_t stack, nw_protocol_options_t protocol);

REVENANT_NW_API REVENANT_NW_RETURNS_RETAINED nw_protocol_options_t nw_tcp_create_options(void);
REVENANT_NW_API void nw_tcp_options_set_no_delay(nw_protocol_options_t options, bool no_delay);
REVENANT_NW_API void nw_tcp_options_set_connection_timeout(nw_protocol_options_t options, uint32_t connection_timeout);

REVENANT_NW_API REVENANT_NW_RETURNS_RETAINED sec_protocol_options_t nw_tls_copy_sec_protocol_options(nw_protocol_options_t options);

REVENANT_NW_API REVENANT_NW_RETURNS_RETAINED nw_endpoint_t nw_endpoint_create_host(const char *hostname, const char *port);

REVENANT_NW_API CFErrorRef nw_error_copy_cf_error(nw_error_t error);
REVENANT_NW_API nw_error_domain_t nw_error_get_error_domain(nw_error_t error);
REVENANT_NW_API int nw_error_get_error_code(nw_error_t error);

_Pragma("clang assume_nonnull end")

#undef REVENANT_NW_API
#undef REVENANT_NW_RETURNS_RETAINED

#endif
