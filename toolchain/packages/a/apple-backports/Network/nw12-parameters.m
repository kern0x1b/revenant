#import "RevenantNW.h"
#import "RevenantNWSupport.h"

#include <string.h>

const nw_parameters_configure_protocol_block_t _nw_parameters_configure_protocol_default_configuration =
    ^(nw_protocol_options_t options) {
        (void)options;
    };
const nw_parameters_configure_protocol_block_t _nw_parameters_configure_protocol_disable = ^(nw_protocol_options_t options) {
    (void)options;
};

static RevenantNWParameters *revenant_parameters(RevenantNWProtocolStack *stack)
{
    RevenantNWParameters *parameters = [[RevenantNWParameters alloc] init];
    parameters->_stack = stack;
    parameters->_prohibitedInterfaces = [NSMutableArray array];
    parameters->_prohibitedInterfaceTypes = [NSMutableArray array];
    parameters->_serviceClass = nw_service_class_best_effort;
    parameters->_multipathService = nw_multipath_service_disabled;
    parameters->_expiredDNSBehavior = nw_parameters_expired_dns_behavior_default;
    parameters->_requiredInterfaceType = nw_interface_type_other;
    parameters->_attribution = nw_parameters_attribution_developer;
    return parameters;
}

static RevenantNWProtocolStack *revenant_stack(nw_protocol_definition_t transport, nw_protocol_definition_t internet)
{
    RevenantNWProtocolStack *stack = [[RevenantNWProtocolStack alloc] init];
    stack->_application = [NSMutableArray array];
    stack->_transport = nil;
    stack->_internet = nil;
    if (internet) {
        RevenantNWProtocolOptions *options = [[RevenantNWProtocolOptions alloc] init];
        options->_definition = (RevenantNWProtocolDefinition *)internet;
        options->_values = [NSMutableDictionary dictionary];
        options->_objects = [NSMutableDictionary dictionary];
        stack->_internet = options;
    }
    if (transport) {
        RevenantNWProtocolOptions *options = [[RevenantNWProtocolOptions alloc] init];
        options->_definition = (RevenantNWProtocolDefinition *)transport;
        options->_values = [NSMutableDictionary dictionary];
        options->_objects = [NSMutableDictionary dictionary];
        stack->_transport = options;
    }
    return stack;
}

static bool revenant_disabled(nw_parameters_configure_protocol_block_t configure)
{
    return configure == (nw_parameters_configure_protocol_block_t)_nw_parameters_configure_protocol_disable;
}

static bool revenant_defaulted(nw_parameters_configure_protocol_block_t configure)
{
    return !configure ||
           configure == (nw_parameters_configure_protocol_block_t)_nw_parameters_configure_protocol_default_configuration;
}

nw_parameters_t nw_parameters_create(void)
{
    return revenant_parameters(revenant_stack(NULL, nw_protocol_copy_ip_definition()));
}

nw_parameters_t nw_parameters_create_secure_tcp(nw_parameters_configure_protocol_block_t configure_tls,
                                                nw_parameters_configure_protocol_block_t configure_tcp)
{
    RevenantNWProtocolStack *stack = revenant_stack(nw_protocol_copy_tcp_definition(), nw_protocol_copy_ip_definition());
    if (!revenant_disabled(configure_tls)) {
        RevenantNWProtocolOptions *tls = (RevenantNWProtocolOptions *)nw_tls_create_options();
        if (!revenant_defaulted(configure_tls))
            configure_tls(tls);
        [stack->_application insertObject:(RevenantNWProtocolOptions *)tls atIndex:0];
    }
    if (!revenant_defaulted(configure_tcp))
        configure_tcp(stack->_transport);
    return revenant_parameters(stack);
}

nw_parameters_t nw_parameters_create_secure_udp(nw_parameters_configure_protocol_block_t configure_dtls,
                                                nw_parameters_configure_protocol_block_t configure_udp)
{
    RevenantNWProtocolStack *stack = revenant_stack(nw_protocol_copy_udp_definition(), nw_protocol_copy_ip_definition());
    if (!revenant_disabled(configure_dtls)) {
        RevenantNWProtocolOptions *tls = (RevenantNWProtocolOptions *)nw_tls_create_options();
        if (!revenant_defaulted(configure_dtls))
            configure_dtls(tls);
        [stack->_application insertObject:(RevenantNWProtocolOptions *)tls atIndex:0];
    }
    if (!revenant_defaulted(configure_udp))
        configure_udp(stack->_transport);
    return revenant_parameters(stack);
}

nw_parameters_t nw_parameters_copy(nw_parameters_t parameters)
{
    RevenantNWParameters *source = (RevenantNWParameters *)parameters;
    if (!source)
        return NULL;
    RevenantNWProtocolStack *stack = revenant_stack(nil, nil);
    stack->_internet = source->_stack->_internet;
    stack->_transport = source->_stack->_transport;
    stack->_application = [source->_stack->_application mutableCopy];
    RevenantNWParameters *copy = revenant_parameters(stack);
    copy->_localEndpoint = source->_localEndpoint;
    copy->_requiredInterface = source->_requiredInterface;
    copy->_requiredInterfaceType = source->_requiredInterfaceType;
    copy->_prohibitedInterfaces = [source->_prohibitedInterfaces mutableCopy];
    copy->_prohibitedInterfaceTypes = [source->_prohibitedInterfaceTypes mutableCopy];
    copy->_localOnly = source->_localOnly;
    copy->_prohibitExpensive = source->_prohibitExpensive;
    copy->_prohibitConstrained = source->_prohibitConstrained;
    copy->_fastOpenEnabled = source->_fastOpenEnabled;
    copy->_includePeerToPeer = source->_includePeerToPeer;
    copy->_reuseLocalAddress = source->_reuseLocalAddress;
    copy->_preferNoProxy = source->_preferNoProxy;
    copy->_allowUltraConstrained = source->_allowUltraConstrained;
    copy->_requiresDNSSEC = source->_requiresDNSSEC;
    copy->_serviceClass = source->_serviceClass;
    copy->_multipathService = source->_multipathService;
    copy->_expiredDNSBehavior = source->_expiredDNSBehavior;
    copy->_attribution = source->_attribution;
    copy->_privacyContext = source->_privacyContext;
    copy->_applicationService = source->_applicationService;
    return copy;
}

nw_protocol_stack_t nw_parameters_copy_default_protocol_stack(nw_parameters_t parameters)
{
    RevenantNWParameters *value = (RevenantNWParameters *)parameters;
    if (!value)
        return NULL;
    RevenantNWProtocolStack *copy = revenant_stack(nil, nil);
    copy->_internet = value->_stack->_internet;
    copy->_transport = value->_stack->_transport;
    copy->_application = [value->_stack->_application mutableCopy];
    return copy;
}

nw_endpoint_t nw_parameters_copy_local_endpoint(nw_parameters_t parameters)
{
    RevenantNWParameters *value = (RevenantNWParameters *)parameters;
    return value ? value->_localEndpoint : NULL;
}

void nw_parameters_set_local_endpoint(nw_parameters_t parameters, nw_endpoint_t local_endpoint)
{
    RevenantNWParameters *value = (RevenantNWParameters *)parameters;
    if (value)
        value->_localEndpoint = (RevenantNWEndpoint *)local_endpoint;
}

bool nw_parameters_get_prohibit_expensive(nw_parameters_t parameters)
{
    RevenantNWParameters *value = (RevenantNWParameters *)parameters;
    return value ? value->_prohibitExpensive : false;
}

void nw_parameters_set_prohibit_expensive(nw_parameters_t parameters, bool prohibit_expensive)
{
    RevenantNWParameters *value = (RevenantNWParameters *)parameters;
    if (value)
        value->_prohibitExpensive = prohibit_expensive;
}

bool nw_parameters_get_local_only(nw_parameters_t parameters)
{
    RevenantNWParameters *value = (RevenantNWParameters *)parameters;
    return value ? value->_localOnly : false;
}

void nw_parameters_set_local_only(nw_parameters_t parameters, bool local_only)
{
    RevenantNWParameters *value = (RevenantNWParameters *)parameters;
    if (value)
        value->_localOnly = local_only;
}

bool nw_parameters_get_fast_open_enabled(nw_parameters_t parameters)
{
    RevenantNWParameters *value = (RevenantNWParameters *)parameters;
    return value ? value->_fastOpenEnabled : false;
}

void nw_parameters_set_fast_open_enabled(nw_parameters_t parameters, bool fast_open_enabled)
{
    RevenantNWParameters *value = (RevenantNWParameters *)parameters;
    if (value)
        value->_fastOpenEnabled = fast_open_enabled;
}

bool nw_parameters_get_include_peer_to_peer(nw_parameters_t parameters)
{
    RevenantNWParameters *value = (RevenantNWParameters *)parameters;
    return value ? value->_includePeerToPeer : false;
}

void nw_parameters_set_include_peer_to_peer(nw_parameters_t parameters, bool include_peer_to_peer)
{
    RevenantNWParameters *value = (RevenantNWParameters *)parameters;
    if (value)
        value->_includePeerToPeer = include_peer_to_peer;
}

bool nw_parameters_get_reuse_local_address(nw_parameters_t parameters)
{
    RevenantNWParameters *value = (RevenantNWParameters *)parameters;
    return value ? value->_reuseLocalAddress : false;
}

void nw_parameters_set_reuse_local_address(nw_parameters_t parameters, bool reuse_local_address)
{
    RevenantNWParameters *value = (RevenantNWParameters *)parameters;
    if (value)
        value->_reuseLocalAddress = reuse_local_address;
}

bool nw_parameters_get_prefer_no_proxy(nw_parameters_t parameters)
{
    RevenantNWParameters *value = (RevenantNWParameters *)parameters;
    return value ? value->_preferNoProxy : false;
}

void nw_parameters_set_prefer_no_proxy(nw_parameters_t parameters, bool prefer_no_proxy)
{
    RevenantNWParameters *value = (RevenantNWParameters *)parameters;
    if (value)
        value->_preferNoProxy = prefer_no_proxy;
}

nw_service_class_t nw_parameters_get_service_class(nw_parameters_t parameters)
{
    RevenantNWParameters *value = (RevenantNWParameters *)parameters;
    return value ? value->_serviceClass : nw_service_class_best_effort;
}

void nw_parameters_set_service_class(nw_parameters_t parameters, nw_service_class_t service_class)
{
    RevenantNWParameters *value = (RevenantNWParameters *)parameters;
    if (value)
        value->_serviceClass = service_class;
}

nw_multipath_service_t nw_parameters_get_multipath_service(nw_parameters_t parameters)
{
    RevenantNWParameters *value = (RevenantNWParameters *)parameters;
    return value ? value->_multipathService : nw_multipath_service_disabled;
}

void nw_parameters_set_multipath_service(nw_parameters_t parameters, nw_multipath_service_t multipath_service)
{
    RevenantNWParameters *value = (RevenantNWParameters *)parameters;
    if (value)
        value->_multipathService = multipath_service;
}

nw_parameters_expired_dns_behavior_t nw_parameters_get_expired_dns_behavior(nw_parameters_t parameters)
{
    RevenantNWParameters *value = (RevenantNWParameters *)parameters;
    return value ? value->_expiredDNSBehavior : nw_parameters_expired_dns_behavior_default;
}

void nw_parameters_set_expired_dns_behavior(nw_parameters_t parameters, nw_parameters_expired_dns_behavior_t expired_dns_behavior)
{
    RevenantNWParameters *value = (RevenantNWParameters *)parameters;
    if (value)
        value->_expiredDNSBehavior = expired_dns_behavior;
}

nw_interface_type_t nw_parameters_get_required_interface_type(nw_parameters_t parameters)
{
    RevenantNWParameters *value = (RevenantNWParameters *)parameters;
    return value ? value->_requiredInterfaceType : nw_interface_type_other;
}

void nw_parameters_set_required_interface_type(nw_parameters_t parameters, nw_interface_type_t interface_type)
{
    RevenantNWParameters *value = (RevenantNWParameters *)parameters;
    if (value)
        value->_requiredInterfaceType = interface_type;
}

nw_interface_t nw_parameters_copy_required_interface(nw_parameters_t parameters)
{
    RevenantNWParameters *value = (RevenantNWParameters *)parameters;
    if (!value || !value->_requiredInterface)
        return NULL;
    return (nw_interface_t)value->_requiredInterface;
}

void nw_parameters_require_interface(nw_parameters_t parameters, nw_interface_t interface)
{
    RevenantNWParameters *value = (RevenantNWParameters *)parameters;
    if (value)
        value->_requiredInterface = (id)interface;
}

void nw_parameters_prohibit_interface(nw_parameters_t parameters, nw_interface_t interface)
{
    RevenantNWParameters *value = (RevenantNWParameters *)parameters;
    if (!value || !interface)
        return;
    [value->_prohibitedInterfaces addObject:(id)interface];
}

void nw_parameters_prohibit_interface_type(nw_parameters_t parameters, nw_interface_type_t interface_type)
{
    RevenantNWParameters *value = (RevenantNWParameters *)parameters;
    if (!value)
        return;
    [value->_prohibitedInterfaceTypes addObject:@(interface_type)];
}

void nw_parameters_clear_prohibited_interfaces(nw_parameters_t parameters)
{
    RevenantNWParameters *value = (RevenantNWParameters *)parameters;
    [value->_prohibitedInterfaces removeAllObjects];
}

void nw_parameters_clear_prohibited_interface_types(nw_parameters_t parameters)
{
    RevenantNWParameters *value = (RevenantNWParameters *)parameters;
    [value->_prohibitedInterfaceTypes removeAllObjects];
}

void nw_parameters_iterate_prohibited_interfaces(nw_parameters_t parameters, nw_parameters_iterate_interfaces_block_t iterate_block)
{
    RevenantNWParameters *value = (RevenantNWParameters *)parameters;
    if (!value || !iterate_block)
        return;
    for (id interface in [value->_prohibitedInterfaces copy]) {
        if (!iterate_block((nw_interface_t)interface))
            break;
    }
}

void nw_parameters_iterate_prohibited_interface_types(nw_parameters_t parameters, nw_parameters_iterate_interface_types_block_t iterate_block)
{
    RevenantNWParameters *value = (RevenantNWParameters *)parameters;
    if (!value || !iterate_block)
        return;
    for (NSNumber *type in [value->_prohibitedInterfaceTypes copy]) {
        if (!iterate_block((nw_interface_type_t)type.unsignedIntegerValue))
            break;
    }
}
