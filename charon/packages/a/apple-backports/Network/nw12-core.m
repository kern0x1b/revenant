/*
 * The objects of Network's C API that arrived with the framework itself, iOS 12: the retain and
 * release of an nw_object, an error, an endpoint, a content context, the identity of a protocol and
 * the settings of the four protocols that had one that day - IP, TCP, TLS and UDP.
 *
 * Everything here is the port's own object graph over data the program gave it, except the socket
 * address of an endpoint, which is the address itself. What a connection does with a stack it is
 * given is nw12-connection.m's business; what the program can ask of the objects themselves is
 * answered here, and every getter's default is the default the SDK documents for it.
 */

#import "CharonNW.h"
#import "CharonNWSupport.h"

#include <arpa/inet.h>
#include <netinet/in.h>
#include <string.h>

#pragma mark - nw_object

/* The header makes these two Objective-C macros whenever the file is Objective-C, so a program's
   nw_retain is a message and needs no symbol; these are the C functions of the same name, for a C
   translation unit and for the two of them to be found where the SDK declares them. The macros are
   taken back first, or the definitions below would be macros too. */
#undef nw_retain
#undef nw_release

void *nw_retain(void *object)
{
    return (void *)CFBridgingRetain((__bridge id)object);
}

void nw_release(void *object)
{
    CFBridgingRelease((void *)object);
}

#pragma mark - nw_error

nw_error_domain_t nw_error_get_error_domain(nw_error_t error)
{
    return error ? ((CharonNWError *)error)->_domain : nw_error_domain_invalid;
}

int nw_error_get_error_code(nw_error_t error)
{
    return error ? ((CharonNWError *)error)->_code : 0;
}

CFErrorRef nw_error_copy_cf_error(nw_error_t error)
{
    if (!error)
        return NULL;
    CharonNWError *value = (CharonNWError *)error;
    CFStringRef domain = NULL;
    switch (value->_domain) {
    case nw_error_domain_posix:
        domain = kCFErrorDomainPOSIX;
        break;
    case nw_error_domain_dns:
        domain = kNWErrorDomainDNS;
        break;
    case nw_error_domain_tls:
        domain = kNWErrorDomainTLS;
        break;
    default:
        domain = kCFErrorDomainPOSIX;
        break;
    }
    CFErrorRef result = CFErrorCreate(kCFAllocatorDefault, domain, value->_code, NULL);
    return result;
}

#pragma mark - nw_endpoint

nw_endpoint_t nw_endpoint_create_host(const char *hostname, const char *port)
{
    if (!hostname)
        return NULL;
    CharonNWEndpoint *endpoint = [[CharonNWEndpoint alloc] init];
    /* The port is what makes a host endpoint one: a host with no port, or with a port that names
       neither a number nor a service, is the invalid endpoint, which is what the host's own Network
       makes of it (tests/backports/host/network-objects). */
    uint16_t number = 0;
    if (!charon_nw_resolve_port(port, &number))
        return NULL;
    endpoint->_port = [NSString stringWithFormat:@"%u", number];
    /* A host that is already an address is not looked up: it is the address, and the endpoint says
       so, which is what lets a connection open it without a resolver. The host is kept either way,
       because an address endpoint answers the host it was made from as its own text. */
    CFDataRef address = NULL;
    if (charon_nw_host_is_address(hostname, number, &address)) {
        endpoint->_type = nw_endpoint_type_address;
        endpoint->_address = (__bridge_transfer NSData *)address;
    } else {
        endpoint->_type = nw_endpoint_type_host;
    }
    endpoint->_hostname = @(hostname);
    return endpoint;
}

nw_endpoint_t nw_endpoint_create_address(const struct sockaddr *address)
{
    if (!address)
        return NULL;
    socklen_t length = charon_nw_sockaddr_length(address);
    if (!length)
        return NULL;
    CharonNWEndpoint *endpoint = [[CharonNWEndpoint alloc] init];
    endpoint->_type = nw_endpoint_type_address;
    endpoint->_address = (__bridge_transfer NSData *)charon_nw_sockaddr_data(address, length);
    char text[INET6_ADDRSTRLEN + 4] = {0};
    if (charon_nw_sockaddr_text(address, text, sizeof text)) {
        endpoint->_hostname = @(text);
        endpoint->_port = [NSString stringWithFormat:@"%u", charon_nw_sockaddr_port(address)];
    }
    return endpoint;
}

nw_endpoint_t nw_endpoint_create_bonjour_service(const char *name, const char *type, const char *domain)
{
    /* A service needs all three of what it is: without a name there is nothing to publish, without a
       type there is nothing to look for, and without a domain there is nowhere to publish it. Each
       of those is refused, as the host's own Network refuses it (tests/backports/host/network-objects). */
    if (!name || !*name || !type || !*type || !domain || !*domain)
        return NULL;
    CharonNWEndpoint *endpoint = [[CharonNWEndpoint alloc] init];
    endpoint->_type = nw_endpoint_type_bonjour_service;
    endpoint->_bonjourName = @(name);
    endpoint->_bonjourType = @(type);
    endpoint->_bonjourDomain = @(domain);
    /* The port of a service is not in its name: it comes from the record the service publishes, and
       until that is resolved the port is zero - which is what the port string says as well. */
    endpoint->_port = @"0";
    return endpoint;
}

nw_endpoint_type_t nw_endpoint_get_type(nw_endpoint_t endpoint)
{
    return endpoint ? ((CharonNWEndpoint *)endpoint)->_type : nw_endpoint_type_invalid;
}

const char *nw_endpoint_get_hostname(nw_endpoint_t endpoint)
{
    CharonNWEndpoint *value = (CharonNWEndpoint *)endpoint;
    if (!value || (value->_type != nw_endpoint_type_host && value->_type != nw_endpoint_type_address &&
                   value->_type != nw_endpoint_type_url))
        return NULL;
    return value->_hostname.UTF8String;
}

uint16_t nw_endpoint_get_port(nw_endpoint_t endpoint)
{
    /* Host byte order, as the header says, and 0 for an endpoint with no port. The port is kept as the
       number it names, so this is that number. */
    CharonNWEndpoint *value = (CharonNWEndpoint *)endpoint;
    if (!value || !value->_port.length)
        return 0;
    long number = strtol(value->_port.UTF8String, NULL, 10);
    if (number <= 0 || number > UINT16_MAX)
        return 0;
    return (uint16_t)number;
}

const struct sockaddr *nw_endpoint_get_address(nw_endpoint_t endpoint)
{
    CharonNWEndpoint *value = (CharonNWEndpoint *)endpoint;
    if (!value || !value->_address)
        return NULL;
    return (const struct sockaddr *)value->_address.bytes;
}

const char *nw_endpoint_get_bonjour_service_name(nw_endpoint_t endpoint)
{
    CharonNWEndpoint *value = (CharonNWEndpoint *)endpoint;
    if (!value || value->_type != nw_endpoint_type_bonjour_service)
        return NULL;
    return value->_bonjourName.UTF8String;
}

const char *nw_endpoint_get_bonjour_service_type(nw_endpoint_t endpoint)
{
    CharonNWEndpoint *value = (CharonNWEndpoint *)endpoint;
    if (!value || value->_type != nw_endpoint_type_bonjour_service)
        return NULL;
    return value->_bonjourType.UTF8String;
}

const char *nw_endpoint_get_bonjour_service_domain(nw_endpoint_t endpoint)
{
    CharonNWEndpoint *value = (CharonNWEndpoint *)endpoint;
    if (!value || value->_type != nw_endpoint_type_bonjour_service)
        return NULL;
    return value->_bonjourDomain.UTF8String;
}

char *nw_endpoint_copy_address_string(nw_endpoint_t endpoint)
{
    CharonNWEndpoint *value = (CharonNWEndpoint *)endpoint;
    if (!value)
        return NULL;
    const struct sockaddr *address = (const struct sockaddr *)value->_address.bytes;
    if (value->_address.length && address) {
        char text[INET6_ADDRSTRLEN + 4] = {0};
        if (charon_nw_sockaddr_text(address, text, sizeof text))
            return charon_nw_copy_cstring(text);
    }
    return NULL;
}

char *nw_endpoint_copy_port_string(nw_endpoint_t endpoint)
{
    CharonNWEndpoint *value = (CharonNWEndpoint *)endpoint;
    if (!value || !value->_port.length)
        return NULL;
    return charon_nw_copy_cstring(value->_port.UTF8String);
}

#pragma mark - nw_protocol_definition, nw_protocol_options, nw_protocol_metadata

static CharonNWProtocolDefinition *charon_definition(NSString *family, uint32_t flags)
{
    CharonNWProtocolDefinition *definition = [[CharonNWProtocolDefinition alloc] init];
    definition->_family = family;
    definition->_identifier = family;
    definition->_flags = flags;
    return definition;
}

/* The built-in protocols each have one definition for the whole process, as the SDK's own do: a
   stack built twice compares equal to itself. */
static nw_protocol_definition_t charon_builtin_definition(NSString *family)
{
    static NSMutableDictionary *cache;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        cache = [NSMutableDictionary dictionary];
    });
    @synchronized(cache) {
        nw_protocol_definition_t held = cache[family];
        if (!held) {
            held = charon_definition(family, 0);
            cache[family] = held;
        }
        return held;
    }
}

bool nw_protocol_definition_is_equal(nw_protocol_definition_t first, nw_protocol_definition_t second)
{
    if (first == second)
        return true;
    if (!first || !second)
        return false;
    CharonNWProtocolDefinition *a = (CharonNWProtocolDefinition *)first, *b = (CharonNWProtocolDefinition *)second;
    /* A framer's definition is made afresh every time and belongs to the program that made it, so two
       of them are not the same protocol even under one name: they carry different start handlers. The
       built-in protocols each have one definition for the whole process, so those compare by what
       they are. Both are what the host's own Network answers (tests/backports/host/network-objects). */
    if (a->_payload || b->_payload)
        return false;
    return a->_flags == b->_flags && [a->_family isEqualToString:b->_family] &&
           [a->_identifier isEqualToString:b->_identifier];
}

nw_protocol_definition_t nw_protocol_options_copy_definition(nw_protocol_options_t options)
{
    return options ? ((CharonNWProtocolOptions *)options)->_definition : NULL;
}

nw_protocol_definition_t nw_protocol_metadata_copy_definition(nw_protocol_metadata_t metadata)
{
    return metadata ? ((CharonNWProtocolMetadata *)metadata)->_definition : NULL;
}

nw_protocol_definition_t nw_protocol_copy_tcp_definition(void)
{
    return charon_builtin_definition(@"nw_tcp");
}

nw_protocol_definition_t nw_protocol_copy_udp_definition(void)
{
    return charon_builtin_definition(@"nw_udp");
}

nw_protocol_definition_t nw_protocol_copy_ip_definition(void)
{
    return charon_builtin_definition(@"nw_ip");
}

nw_protocol_definition_t nw_protocol_copy_tls_definition(void)
{
    return charon_builtin_definition(@"nw_tls");
}

static CharonNWProtocolOptions *charon_options(nw_protocol_definition_t definition)
{
    CharonNWProtocolOptions *options = [[CharonNWProtocolOptions alloc] init];
    options->_definition = (CharonNWProtocolDefinition *)definition;
    options->_values = [NSMutableDictionary dictionary];
    options->_objects = [NSMutableDictionary dictionary];
    return options;
}

nw_protocol_options_t nw_tcp_create_options(void)
{
    return charon_options(charon_builtin_definition(@"nw_tcp"));
}

nw_protocol_options_t nw_udp_create_options(void)
{
    return charon_options(charon_builtin_definition(@"nw_udp"));
}

nw_protocol_options_t nw_tls_create_options(void)
{
    return charon_options(charon_builtin_definition(@"nw_tls"));
}

static bool charon_metadata_is(nw_protocol_metadata_t metadata, NSString *family)
{
    /* The options of a protocol and the metadata of one are different objects, and a predicate about
       a message is false for the options: only metadata carries a message's own values. */
    CharonNWProtocolMetadata *value = (CharonNWProtocolMetadata *)metadata;
    if (![value isKindOfClass:[CharonNWProtocolMetadata class]])
        return false;
    return [value->_definition->_family isEqualToString:family];
}

bool nw_protocol_metadata_is_tcp(nw_protocol_metadata_t metadata)
{
    return charon_metadata_is(metadata, @"nw_tcp");
}

bool nw_protocol_metadata_is_udp(nw_protocol_metadata_t metadata)
{
    return charon_metadata_is(metadata, @"nw_udp");
}

bool nw_protocol_metadata_is_ip(nw_protocol_metadata_t metadata)
{
    return charon_metadata_is(metadata, @"nw_ip");
}

bool nw_protocol_metadata_is_tls(nw_protocol_metadata_t metadata)
{
    return charon_metadata_is(metadata, @"nw_tls");
}

nw_protocol_metadata_t nw_ip_create_metadata(void)
{
    CharonNWProtocolMetadata *metadata = [[CharonNWProtocolMetadata alloc] init];
    metadata->_definition = (CharonNWProtocolDefinition *)charon_builtin_definition(@"nw_ip");
    metadata->_values = [NSMutableDictionary dictionary];
    metadata->_objects = [NSMutableDictionary dictionary];
    return metadata;
}

nw_protocol_metadata_t nw_udp_create_metadata(void)
{
    CharonNWProtocolMetadata *metadata = [[CharonNWProtocolMetadata alloc] init];
    metadata->_definition = (CharonNWProtocolDefinition *)charon_builtin_definition(@"nw_udp");
    metadata->_values = [NSMutableDictionary dictionary];
    metadata->_objects = [NSMutableDictionary dictionary];
    return metadata;
}

sec_protocol_options_t nw_tls_copy_sec_protocol_options(nw_protocol_options_t options)
{
    if (![options isKindOfClass:[CharonNWProtocolOptions class]])
        return NULL;
    CharonNWProtocolOptions *value = (CharonNWProtocolOptions *)options;
    CharonNWSecProtocol *sec = value->_objects[@"sec_protocol_options"];
    if (!sec) {
        sec = [[CharonNWSecProtocol alloc] init];
        sec->_values = [NSMutableDictionary dictionary];
        sec->_applicationProtocols = [NSMutableArray array];
        value->_objects[@"sec_protocol_options"] = sec;
    }
    return (sec_protocol_options_t)sec;
}

sec_protocol_metadata_t nw_tls_copy_sec_protocol_metadata(nw_protocol_metadata_t metadata)
{
    if (![metadata isKindOfClass:[CharonNWProtocolMetadata class]])
        return NULL;
    CharonNWProtocolMetadata *value = (CharonNWProtocolMetadata *)metadata;
    CharonNWSecProtocol *sec = value->_objects[@"sec_protocol_metadata"];
    if (!sec) {
        sec = [[CharonNWSecProtocol alloc] init];
        sec->_values = [NSMutableDictionary dictionary];
        sec->_applicationProtocols = [NSMutableArray array];
        value->_objects[@"sec_protocol_metadata"] = sec;
    }
    return (sec_protocol_metadata_t)sec;
}

#pragma mark - nw_protocol_stack

nw_protocol_options_t nw_protocol_stack_copy_internet_protocol(nw_protocol_stack_t stack)
{
    return stack ? ((CharonNWProtocolStack *)stack)->_internet : NULL;
}

nw_protocol_options_t nw_protocol_stack_copy_transport_protocol(nw_protocol_stack_t stack)
{
    return stack ? ((CharonNWProtocolStack *)stack)->_transport : NULL;
}

void nw_protocol_stack_set_transport_protocol(nw_protocol_stack_t stack, nw_protocol_options_t protocol)
{
    if (!stack)
        return;
    ((CharonNWProtocolStack *)stack)->_transport = (CharonNWProtocolOptions *)protocol;
}

void nw_protocol_stack_prepend_application_protocol(nw_protocol_stack_t stack, nw_protocol_options_t protocol)
{
    CharonNWProtocolStack *value = (CharonNWProtocolStack *)stack;
    if (!value || !protocol)
        return;
    [value->_application insertObject:(CharonNWProtocolOptions *)protocol atIndex:0];
}

void nw_protocol_stack_clear_application_protocols(nw_protocol_stack_t stack)
{
    CharonNWProtocolStack *value = (CharonNWProtocolStack *)stack;
    if (!value)
        return;
    [value->_application removeAllObjects];
}

void nw_protocol_stack_iterate_application_protocols(nw_protocol_stack_t stack, nw_protocol_stack_iterate_protocols_block_t iterate_block)
{
    CharonNWProtocolStack *value = (CharonNWProtocolStack *)stack;
    if (!value || !iterate_block)
        return;
    for (CharonNWProtocolOptions *options in [value->_application copy])
        iterate_block(options);
}

#pragma mark - nw_content_context

nw_content_context_t nw_content_context_create(const char *context_identifier)
{
    if (!context_identifier)
        return NULL;
    CharonNWContentContext *context = [[CharonNWContentContext alloc] init];
    context->_identifier = @(context_identifier);
    context->_metadata = [NSMutableDictionary dictionary];
    /* A context is a relative priority of "normal" and no expiration until it is told otherwise. */
    context->_relativePriority = 0.5;
    context->_expirationMilliseconds = 0;
    context->_isFinal = false;
    return context;
}

const char *nw_content_context_get_identifier(nw_content_context_t context)
{
    return context ? ((CharonNWContentContext *)context)->_identifier.UTF8String : NULL;
}

double nw_content_context_get_relative_priority(nw_content_context_t context)
{
    /* A context that has been declared final reports the defaults, whatever it was told before: the
       end of its message is already decided, and the host's own Network answers it that way
       (tests/backports/host/network-objects). */
    CharonNWContentContext *value = (CharonNWContentContext *)context;
    if (!value)
        return 0.0;
    return value->_isFinal ? 0.5 : value->_relativePriority;
}

void nw_content_context_set_relative_priority(nw_content_context_t context, double relative_priority)
{
    /* A context that has been declared final is the end of its message: what it carries is already
       decided, so a later change of its priority or its expiration is not taken. That is what the
       host's own Network does, measured (tests/backports/host/network-objects). */
    CharonNWContentContext *value = (CharonNWContentContext *)context;
    if (value && !value->_isFinal)
        value->_relativePriority = relative_priority;
}

uint64_t nw_content_context_get_expiration_milliseconds(nw_content_context_t context)
{
    CharonNWContentContext *value = (CharonNWContentContext *)context;
    if (!value)
        return 0;
    return value->_isFinal ? 0 : value->_expirationMilliseconds;
}

void nw_content_context_set_expiration_milliseconds(nw_content_context_t context, uint64_t expiration_milliseconds)
{
    CharonNWContentContext *value = (CharonNWContentContext *)context;
    if (value && !value->_isFinal)
        value->_expirationMilliseconds = expiration_milliseconds;
}

bool nw_content_context_get_is_final(nw_content_context_t context)
{
    return context ? ((CharonNWContentContext *)context)->_isFinal : false;
}

void nw_content_context_set_is_final(nw_content_context_t context, bool is_final)
{
    if (context)
        ((CharonNWContentContext *)context)->_isFinal = is_final;
}

nw_content_context_t nw_content_context_copy_antecedent(nw_content_context_t context)
{
    /* The antecedent itself, held: the context a message is an answer to is the one that was set,
       which is what the host's own Network answers, measured (tests/backports/host/network-objects). */
    CharonNWContentContext *value = (CharonNWContentContext *)context;
    return value ? value->_antecedent : NULL;
}

void nw_content_context_set_antecedent(nw_content_context_t context, nw_content_context_t antecedent_context)
{
    /* A context that is final takes no antecedent either: what it carries is already decided. */
    CharonNWContentContext *value = (CharonNWContentContext *)context;
    if (value && !value->_isFinal)
        value->_antecedent = (CharonNWContentContext *)antecedent_context;
}

void nw_content_context_set_metadata_for_protocol(nw_content_context_t context, nw_protocol_metadata_t protocol_metadata)
{
    CharonNWProtocolMetadata *metadata = (CharonNWProtocolMetadata *)protocol_metadata;
    CharonNWContentContext *value = (CharonNWContentContext *)context;
    if (!value || !metadata || !metadata->_definition)
        return;
    value->_metadata[metadata->_definition->_family] = metadata;
}

nw_protocol_metadata_t nw_content_context_copy_protocol_metadata(nw_content_context_t context, nw_protocol_definition_t protocol)
{
    CharonNWContentContext *value = (CharonNWContentContext *)context;
    CharonNWProtocolDefinition *definition = (CharonNWProtocolDefinition *)protocol;
    if (!value || !definition)
        return NULL;
    return value->_metadata[definition->_family];
}

void nw_content_context_foreach_protocol_metadata(nw_content_context_t context, void (^foreach_block)(nw_protocol_definition_t definition, nw_protocol_metadata_t metadata))
{
    CharonNWContentContext *value = (CharonNWContentContext *)context;
    if (!value || !foreach_block)
        return;
    for (NSString *family in [value->_metadata.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
        CharonNWProtocolMetadata *metadata = value->_metadata[family];
        foreach_block(metadata->_definition, metadata);
    }
}

#pragma mark - nw_tcp_options

void nw_tcp_options_set_no_delay(nw_protocol_options_t options, bool no_delay)
{
    charon_nw_set_flag((__bridge CFMutableDictionaryRef)((CharonNWProtocolOptions *)options)->_values, "no_delay", no_delay);
}

void nw_tcp_options_set_no_options(nw_protocol_options_t options, bool no_options)
{
    charon_nw_set_flag((__bridge CFMutableDictionaryRef)((CharonNWProtocolOptions *)options)->_values, "no_options", no_options);
}

void nw_tcp_options_set_no_push(nw_protocol_options_t options, bool no_push)
{
    charon_nw_set_flag((__bridge CFMutableDictionaryRef)((CharonNWProtocolOptions *)options)->_values, "no_push", no_push);
}

void nw_tcp_options_set_retransmit_fin_drop(nw_protocol_options_t options, bool retransmit_fin_drop)
{
    charon_nw_set_flag((__bridge CFMutableDictionaryRef)((CharonNWProtocolOptions *)options)->_values, "retransmit_fin_drop", retransmit_fin_drop);
}

void nw_tcp_options_set_disable_ack_stretching(nw_protocol_options_t options, bool disable_ack_stretching)
{
    charon_nw_set_flag((__bridge CFMutableDictionaryRef)((CharonNWProtocolOptions *)options)->_values, "disable_ack_stretching", disable_ack_stretching);
}

void nw_tcp_options_set_disable_ecn(nw_protocol_options_t options, bool disable_ecn)
{
    charon_nw_set_flag((__bridge CFMutableDictionaryRef)((CharonNWProtocolOptions *)options)->_values, "disable_ecn", disable_ecn);
}

void nw_tcp_options_set_enable_fast_open(nw_protocol_options_t options, bool enable_fast_open)
{
    charon_nw_set_flag((__bridge CFMutableDictionaryRef)((CharonNWProtocolOptions *)options)->_values, "enable_fast_open", enable_fast_open);
}

void nw_tcp_options_set_enable_keepalive(nw_protocol_options_t options, bool enable_keepalive)
{
    charon_nw_set_flag((__bridge CFMutableDictionaryRef)((CharonNWProtocolOptions *)options)->_values, "enable_keepalive", enable_keepalive);
}

void nw_tcp_options_set_connection_timeout(nw_protocol_options_t options, uint32_t connection_timeout)
{
    charon_nw_set_integer((__bridge CFMutableDictionaryRef)((CharonNWProtocolOptions *)options)->_values, "connection_timeout", connection_timeout);
}

void nw_tcp_options_set_keepalive_count(nw_protocol_options_t options, uint32_t keepalive_count)
{
    charon_nw_set_integer((__bridge CFMutableDictionaryRef)((CharonNWProtocolOptions *)options)->_values, "keepalive_count", keepalive_count);
}

void nw_tcp_options_set_keepalive_idle_time(nw_protocol_options_t options, uint32_t keepalive_idle_time)
{
    charon_nw_set_integer((__bridge CFMutableDictionaryRef)((CharonNWProtocolOptions *)options)->_values, "keepalive_idle_time", keepalive_idle_time);
}

void nw_tcp_options_set_keepalive_interval(nw_protocol_options_t options, uint32_t keepalive_interval)
{
    charon_nw_set_integer((__bridge CFMutableDictionaryRef)((CharonNWProtocolOptions *)options)->_values, "keepalive_interval", keepalive_interval);
}

void nw_tcp_options_set_maximum_segment_size(nw_protocol_options_t options, uint32_t maximum_segment_size)
{
    charon_nw_set_integer((__bridge CFMutableDictionaryRef)((CharonNWProtocolOptions *)options)->_values, "maximum_segment_size", maximum_segment_size);
}

void nw_tcp_options_set_persist_timeout(nw_protocol_options_t options, uint32_t persist_timeout)
{
    charon_nw_set_integer((__bridge CFMutableDictionaryRef)((CharonNWProtocolOptions *)options)->_values, "persist_timeout", persist_timeout);
}

void nw_tcp_options_set_retransmit_connection_drop_time(nw_protocol_options_t options, uint32_t retransmit_connection_drop_time)
{
    charon_nw_set_integer((__bridge CFMutableDictionaryRef)((CharonNWProtocolOptions *)options)->_values, "retransmit_connection_drop_time", retransmit_connection_drop_time);
}

uint32_t nw_tcp_get_available_send_buffer(nw_protocol_metadata_t metadata)
{
    CharonNWProtocolMetadata *value = (CharonNWProtocolMetadata *)metadata;
    return (uint32_t)charon_nw_integer((__bridge CFDictionaryRef)value->_values, "available_send_buffer", 0);
}

uint32_t nw_tcp_get_available_receive_buffer(nw_protocol_metadata_t metadata)
{
    CharonNWProtocolMetadata *value = (CharonNWProtocolMetadata *)metadata;
    return (uint32_t)charon_nw_integer((__bridge CFDictionaryRef)value->_values, "available_receive_buffer", 0);
}

#pragma mark - nw_udp_options

void nw_udp_options_set_prefer_no_checksum(nw_protocol_options_t options, bool prefer_no_checksum)
{
    charon_nw_set_flag((__bridge CFMutableDictionaryRef)((CharonNWProtocolOptions *)options)->_values, "prefer_no_checksum", prefer_no_checksum);
}

#pragma mark - nw_ip_options

void nw_ip_options_set_version(nw_protocol_options_t options, nw_ip_version_t version)
{
    charon_nw_set_integer((__bridge CFMutableDictionaryRef)((CharonNWProtocolOptions *)options)->_values, "version", version);
}

void nw_ip_options_set_hop_limit(nw_protocol_options_t options, uint8_t hop_limit)
{
    charon_nw_set_integer((__bridge CFMutableDictionaryRef)((CharonNWProtocolOptions *)options)->_values, "hop_limit", hop_limit);
}

void nw_ip_options_set_calculate_receive_time(nw_protocol_options_t options, bool calculate_receive_time)
{
    charon_nw_set_flag((__bridge CFMutableDictionaryRef)((CharonNWProtocolOptions *)options)->_values, "calculate_receive_time", calculate_receive_time);
}

void nw_ip_options_set_disable_fragmentation(nw_protocol_options_t options, bool disable_fragmentation)
{
    charon_nw_set_flag((__bridge CFMutableDictionaryRef)((CharonNWProtocolOptions *)options)->_values, "disable_fragmentation", disable_fragmentation);
}

void nw_ip_options_set_use_minimum_mtu(nw_protocol_options_t options, bool use_minimum_mtu)
{
    charon_nw_set_flag((__bridge CFMutableDictionaryRef)((CharonNWProtocolOptions *)options)->_values, "use_minimum_mtu", use_minimum_mtu);
}

nw_service_class_t nw_ip_metadata_get_service_class(nw_protocol_metadata_t metadata)
{
    CharonNWProtocolMetadata *value = (CharonNWProtocolMetadata *)metadata;
    return (nw_service_class_t)charon_nw_integer((__bridge CFDictionaryRef)value->_values, "service_class", nw_service_class_best_effort);
}

void nw_ip_metadata_set_service_class(nw_protocol_metadata_t metadata, nw_service_class_t service_class)
{
    charon_nw_set_integer((__bridge CFMutableDictionaryRef)((CharonNWProtocolMetadata *)metadata)->_values, "service_class", service_class);
}

nw_ip_ecn_flag_t nw_ip_metadata_get_ecn_flag(nw_protocol_metadata_t metadata)
{
    CharonNWProtocolMetadata *value = (CharonNWProtocolMetadata *)metadata;
    return (nw_ip_ecn_flag_t)charon_nw_integer((__bridge CFDictionaryRef)value->_values, "ecn_flag", nw_ip_ecn_flag_non_ect);
}

void nw_ip_metadata_set_ecn_flag(nw_protocol_metadata_t metadata, nw_ip_ecn_flag_t ecn_flag)
{
    charon_nw_set_integer((__bridge CFMutableDictionaryRef)((CharonNWProtocolMetadata *)metadata)->_values, "ecn_flag", ecn_flag);
}

uint64_t nw_ip_metadata_get_receive_time(nw_protocol_metadata_t metadata)
{
    CharonNWProtocolMetadata *value = (CharonNWProtocolMetadata *)metadata;
    return (uint64_t)charon_nw_integer((__bridge CFDictionaryRef)value->_values, "receive_time", 0);
}
