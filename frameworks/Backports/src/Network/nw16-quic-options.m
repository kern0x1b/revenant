#import "RevenantNW.h"
#import "RevenantNWSupport.h"

#include <string.h>

static bool revenant_quic_metadata(nw_protocol_metadata_t metadata, RevenantNWProtocolMetadata **out)
{
    if (!nw_protocol_metadata_is_quic(metadata))
        return false;
    *out = (RevenantNWProtocolMetadata *)metadata;
    return true;
}

nw_protocol_definition_t nw_protocol_copy_quic_definition(void)
{
    static RevenantNWProtocolDefinition *definition;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        definition = [[RevenantNWProtocolDefinition alloc] init];
        definition->_family = @"nw_quic";
        definition->_identifier = @"nw_quic";
    });
    return definition;
}

bool nw_protocol_metadata_is_quic(nw_protocol_metadata_t metadata)
{
    RevenantNWProtocolMetadata *value = (RevenantNWProtocolMetadata *)metadata;
    if (![value isKindOfClass:[RevenantNWProtocolMetadata class]])
        return false;
    return [value->_definition->_family isEqualToString:@"nw_quic"];
}

nw_protocol_options_t nw_quic_create_options(void)
{
    RevenantNWProtocolOptions *options = [[RevenantNWProtocolOptions alloc] init];
    options->_definition = (RevenantNWProtocolDefinition *)nw_protocol_copy_quic_definition();
    options->_values = [NSMutableDictionary dictionary];
    options->_objects = [NSMutableDictionary dictionary];
    return options;
}

nw_parameters_t nw_parameters_create_quic(nw_parameters_configure_protocol_block_t configure_quic)
{
    RevenantNWProtocolStack *stack = [[RevenantNWProtocolStack alloc] init];
    stack->_application = [NSMutableArray array];
    if (configure_quic && configure_quic != (nw_parameters_configure_protocol_block_t)_nw_parameters_configure_protocol_default_configuration &&
        configure_quic != (nw_parameters_configure_protocol_block_t)_nw_parameters_configure_protocol_disable) {
        RevenantNWProtocolOptions *quic = (RevenantNWProtocolOptions *)nw_quic_create_options();
        configure_quic(quic);
        [stack->_application insertObject:(RevenantNWProtocolOptions *)quic atIndex:0];
    }
    RevenantNWParameters *parameters = [[RevenantNWParameters alloc] init];
    parameters->_stack = stack;
    parameters->_prohibitedInterfaces = [NSMutableArray array];
    parameters->_prohibitedInterfaceTypes = [NSMutableArray array];
    parameters->_serviceClass = nw_service_class_best_effort;
    parameters->_multipathService = nw_multipath_service_disabled;
    parameters->_expiredDNSBehavior = nw_parameters_expired_dns_behavior_allow;
    parameters->_requiredInterfaceType = nw_interface_type_other;
    parameters->_attribution = nw_parameters_attribution_developer;
    return parameters;
}

#define REVENANT_QUIC_OPTION(name) ((RevenantNWProtocolOptions *)options)->_values
#define REVENANT_QUIC_METADATA(name) ((RevenantNWProtocolMetadata *)metadata)->_values

void nw_quic_set_idle_timeout(nw_protocol_options_t options, uint32_t idle_timeout)
{
    revenant_nw_set_integer((__bridge CFMutableDictionaryRef)REVENANT_QUIC_OPTION(0), "idle_timeout", idle_timeout);
}

uint32_t nw_quic_get_idle_timeout(nw_protocol_options_t options)
{
    return (uint32_t)revenant_nw_integer((__bridge CFDictionaryRef)REVENANT_QUIC_OPTION(0), "idle_timeout", 30000);
}

void nw_quic_set_max_udp_payload_size(nw_protocol_options_t options, uint16_t max_udp_payload_size)
{
    revenant_nw_set_integer((__bridge CFMutableDictionaryRef)REVENANT_QUIC_OPTION(0), "max_udp_payload_size", max_udp_payload_size);
}

uint16_t nw_quic_get_max_udp_payload_size(nw_protocol_options_t options)
{
    return (uint16_t)revenant_nw_integer((__bridge CFDictionaryRef)REVENANT_QUIC_OPTION(0), "max_udp_payload_size", 65535);
}

void nw_quic_set_initial_max_data(nw_protocol_options_t options, uint64_t initial_max_data)
{
    revenant_nw_set_integer((__bridge CFMutableDictionaryRef)REVENANT_QUIC_OPTION(0), "initial_max_data", (int64_t)initial_max_data);
}

uint64_t nw_quic_get_initial_max_data(nw_protocol_options_t options)
{
    return (uint64_t)revenant_nw_integer((__bridge CFDictionaryRef)REVENANT_QUIC_OPTION(0), "initial_max_data", -1);
}

void nw_quic_set_initial_max_stream_data_bidirectional_local(nw_protocol_options_t options, uint64_t value)
{
    revenant_nw_set_integer((__bridge CFMutableDictionaryRef)REVENANT_QUIC_OPTION(0), "initial_max_stream_data_bidirectional_local", (int64_t)value);
}

uint64_t nw_quic_get_initial_max_stream_data_bidirectional_local(nw_protocol_options_t options)
{
    return (uint64_t)revenant_nw_integer((__bridge CFDictionaryRef)REVENANT_QUIC_OPTION(0), "initial_max_stream_data_bidirectional_local", -1);
}

void nw_quic_set_initial_max_stream_data_bidirectional_remote(nw_protocol_options_t options, uint64_t value)
{
    revenant_nw_set_integer((__bridge CFMutableDictionaryRef)REVENANT_QUIC_OPTION(0), "initial_max_stream_data_bidirectional_remote", (int64_t)value);
}

uint64_t nw_quic_get_initial_max_stream_data_bidirectional_remote(nw_protocol_options_t options)
{
    return (uint64_t)revenant_nw_integer((__bridge CFDictionaryRef)REVENANT_QUIC_OPTION(0), "initial_max_stream_data_bidirectional_remote", -1);
}

void nw_quic_set_initial_max_stream_data_unidirectional(nw_protocol_options_t options, uint64_t value)
{
    revenant_nw_set_integer((__bridge CFMutableDictionaryRef)REVENANT_QUIC_OPTION(0), "initial_max_stream_data_unidirectional", (int64_t)value);
}

uint64_t nw_quic_get_initial_max_stream_data_unidirectional(nw_protocol_options_t options)
{
    return (uint64_t)revenant_nw_integer((__bridge CFDictionaryRef)REVENANT_QUIC_OPTION(0), "initial_max_stream_data_unidirectional", -1);
}

void nw_quic_set_initial_max_streams_bidirectional(nw_protocol_options_t options, uint64_t value)
{
    revenant_nw_set_integer((__bridge CFMutableDictionaryRef)REVENANT_QUIC_OPTION(0), "initial_max_streams_bidirectional", (int64_t)value);
}

uint64_t nw_quic_get_initial_max_streams_bidirectional(nw_protocol_options_t options)
{
    return (uint64_t)revenant_nw_integer((__bridge CFDictionaryRef)REVENANT_QUIC_OPTION(0), "initial_max_streams_bidirectional", -1);
}

void nw_quic_set_initial_max_streams_unidirectional(nw_protocol_options_t options, uint64_t value)
{
    revenant_nw_set_integer((__bridge CFMutableDictionaryRef)REVENANT_QUIC_OPTION(0), "initial_max_streams_unidirectional", (int64_t)value);
}

uint64_t nw_quic_get_initial_max_streams_unidirectional(nw_protocol_options_t options)
{
    return (uint64_t)revenant_nw_integer((__bridge CFDictionaryRef)REVENANT_QUIC_OPTION(0), "initial_max_streams_unidirectional", -1);
}

void nw_quic_set_stream_is_unidirectional(nw_protocol_options_t options, bool is_unidirectional)
{
    revenant_nw_set_flag((__bridge CFMutableDictionaryRef)REVENANT_QUIC_OPTION(0), "stream_is_unidirectional", is_unidirectional);
}

bool nw_quic_get_stream_is_unidirectional(nw_protocol_options_t options)
{
    return revenant_nw_flag((__bridge CFDictionaryRef)REVENANT_QUIC_OPTION(0), "stream_is_unidirectional", false);
}

void nw_quic_add_tls_application_protocol(nw_protocol_options_t options, const char *application_protocol)
{
    if (!application_protocol || !*application_protocol)
        return;
    RevenantNWProtocolOptions *value = (RevenantNWProtocolOptions *)options;
    NSMutableArray *held = value->_objects[@"application_protocols"];
    if (!held) {
        held = [NSMutableArray array];
        value->_objects[@"application_protocols"] = held;
    }
    [held addObject:@(application_protocol)];
}

sec_protocol_options_t nw_quic_copy_sec_protocol_options(nw_protocol_options_t options)
{
    if (!nw_protocol_options_is_quic(options))
        return NULL;
    RevenantNWProtocolOptions *value = (RevenantNWProtocolOptions *)options;
    RevenantSecProtocolOptions *sec = value->_objects[@"sec_protocol_options"];
    if (!sec) {
        sec = [[RevenantSecProtocolOptions alloc] init];
        value->_objects[@"sec_protocol_options"] = sec;
    }
    return (sec_protocol_options_t)sec;
}

void nw_quic_set_keepalive_interval(nw_protocol_metadata_t metadata, uint16_t keepalive_interval)
{
    RevenantNWProtocolMetadata *value;
    if (revenant_quic_metadata(metadata, &value))
        revenant_nw_set_integer((__bridge CFMutableDictionaryRef)value->_values, "keepalive_interval", keepalive_interval);
}

uint16_t nw_quic_get_keepalive_interval(nw_protocol_metadata_t metadata)
{
    RevenantNWProtocolMetadata *value;
    if (!revenant_quic_metadata(metadata, &value))
        return 0;
    return (uint16_t)revenant_nw_integer((__bridge CFDictionaryRef)value->_values, "keepalive_interval", 0);
}

void nw_quic_set_local_max_streams_bidirectional(nw_protocol_metadata_t metadata, uint64_t max_streams_bidirectional)
{
    RevenantNWProtocolMetadata *value;
    if (revenant_quic_metadata(metadata, &value))
        revenant_nw_set_integer((__bridge CFMutableDictionaryRef)value->_values, "local_max_streams_bidirectional", (int64_t)max_streams_bidirectional);
}

uint64_t nw_quic_get_local_max_streams_bidirectional(nw_protocol_metadata_t metadata)
{
    RevenantNWProtocolMetadata *value;
    if (!revenant_quic_metadata(metadata, &value))
        return 0;
    return (uint64_t)revenant_nw_integer((__bridge CFDictionaryRef)value->_values, "local_max_streams_bidirectional", 0);
}

void nw_quic_set_local_max_streams_unidirectional(nw_protocol_metadata_t metadata, uint64_t max_streams_unidirectional)
{
    RevenantNWProtocolMetadata *value;
    if (revenant_quic_metadata(metadata, &value))
        revenant_nw_set_integer((__bridge CFMutableDictionaryRef)value->_values, "local_max_streams_unidirectional", (int64_t)max_streams_unidirectional);
}

uint64_t nw_quic_get_local_max_streams_unidirectional(nw_protocol_metadata_t metadata)
{
    RevenantNWProtocolMetadata *value;
    if (!revenant_quic_metadata(metadata, &value))
        return 0;
    return (uint64_t)revenant_nw_integer((__bridge CFDictionaryRef)value->_values, "local_max_streams_unidirectional", 0);
}

uint64_t nw_quic_get_remote_idle_timeout(nw_protocol_metadata_t metadata)
{
    RevenantNWProtocolMetadata *value;
    if (!revenant_quic_metadata(metadata, &value))
        return 0;
    return (uint64_t)revenant_nw_integer((__bridge CFDictionaryRef)value->_values, "remote_idle_timeout", 0);
}

uint64_t nw_quic_get_remote_max_streams_bidirectional(nw_protocol_metadata_t metadata)
{
    RevenantNWProtocolMetadata *value;
    if (!revenant_quic_metadata(metadata, &value))
        return 0;
    return (uint64_t)revenant_nw_integer((__bridge CFDictionaryRef)value->_values, "remote_max_streams_bidirectional", 0);
}

uint64_t nw_quic_get_remote_max_streams_unidirectional(nw_protocol_metadata_t metadata)
{
    RevenantNWProtocolMetadata *value;
    if (!revenant_quic_metadata(metadata, &value))
        return 0;
    return (uint64_t)revenant_nw_integer((__bridge CFDictionaryRef)value->_values, "remote_max_streams_unidirectional", 0);
}

void nw_quic_set_application_error(nw_protocol_metadata_t metadata, uint64_t application_error, const char *reason)
{
    RevenantNWProtocolMetadata *value;
    if (!revenant_quic_metadata(metadata, &value))
        return;
    revenant_nw_set_integer((__bridge CFMutableDictionaryRef)value->_values, "application_error", (int64_t)application_error);
    value->_objects[@"application_error_reason"] = reason ? @(reason) : nil;
}

uint64_t nw_quic_get_application_error(nw_protocol_metadata_t metadata)
{
    RevenantNWProtocolMetadata *value;
    if (!revenant_quic_metadata(metadata, &value))
        return 0;
    return (uint64_t)revenant_nw_integer((__bridge CFDictionaryRef)value->_values, "application_error", 0);
}

const char *nw_quic_get_application_error_reason(nw_protocol_metadata_t metadata)
{
    RevenantNWProtocolMetadata *value;
    if (!revenant_quic_metadata(metadata, &value))
        return NULL;
    return [value->_objects[@"application_error_reason"] UTF8String];
}

void nw_quic_set_stream_application_error(nw_protocol_metadata_t metadata, uint64_t application_error)
{
    RevenantNWProtocolMetadata *value;
    if (revenant_quic_metadata(metadata, &value))
        revenant_nw_set_integer((__bridge CFMutableDictionaryRef)value->_values, "stream_application_error", (int64_t)application_error);
}

uint64_t nw_quic_get_stream_application_error(nw_protocol_metadata_t metadata)
{
    RevenantNWProtocolMetadata *value;
    if (!revenant_quic_metadata(metadata, &value))
        return 0;
    return (uint64_t)revenant_nw_integer((__bridge CFDictionaryRef)value->_values, "stream_application_error", 0);
}

uint64_t nw_quic_get_stream_id(nw_protocol_metadata_t metadata)
{
    RevenantNWProtocolMetadata *value;
    if (!revenant_quic_metadata(metadata, &value))
        return 0;
    return (uint64_t)revenant_nw_integer((__bridge CFDictionaryRef)value->_values, "stream_id", 0);
}

uint8_t nw_quic_get_stream_type(nw_protocol_metadata_t stream_metadata)
{
    RevenantNWProtocolMetadata *value;
    if (!revenant_quic_metadata(stream_metadata, &value))
        return 0;
    return (uint8_t)revenant_nw_integer((__bridge CFDictionaryRef)value->_values, "stream_type", 0);
}

sec_protocol_metadata_t nw_quic_copy_sec_protocol_metadata(nw_protocol_metadata_t metadata)
{
    if (!nw_protocol_metadata_is_quic(metadata))
        return NULL;
    RevenantNWProtocolMetadata *value = (RevenantNWProtocolMetadata *)metadata;
    RevenantSecProtocolMetadata *sec = value->_objects[@"sec_protocol_metadata"];
    if (!sec) {
        sec = [[RevenantSecProtocolMetadata alloc] init];
        value->_objects[@"sec_protocol_metadata"] = sec;
    }
    return (sec_protocol_metadata_t)sec;
}

void nw_tcp_options_set_multipath_force_version(nw_protocol_options_t options, nw_multipath_version_t multipath_force_version)
{
    revenant_nw_set_integer((__bridge CFMutableDictionaryRef)((RevenantNWProtocolOptions *)options)->_values, "multipath_force_version", multipath_force_version);
}
