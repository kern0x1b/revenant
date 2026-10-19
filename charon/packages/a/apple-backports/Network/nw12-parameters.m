/*
 * nw_parameters_t, the calls that arrived with it in iOS 12: the factories that build a stack, and
 * everything a program can say about the path a connection of these parameters takes and about the
 * interface it will not take.
 *
 * A stack here is the three layers a connection is built from - the internet protocol, the transport
 * protocol, and the application protocols above them - held as the options of each. The factories
 * differ in what they put in the stack and in what they hand the caller's configure block: the
 * block of a protocol is run with that protocol's own options, once, before the stack is given
 * back, and the two sentinels the header names are compared by pointer, so each is defined here as
 * the empty block it is documented to behave as.
 *
 * The settings that reach the socket are read back by the connection that is given these
 * parameters: the TCP ones become setsockopt calls and the path ones are what the path monitor is
 * asked, so a program that sets them changes what its connection does rather than a field nobody
 * reads.
 */

#import "CharonNW.h"
#import "CharonNWSupport.h"

#include <string.h>

/* The SDK's two sentinels, which on a release with no Network bind as the null: a caller passes
   NW_PARAMETERS_DEFAULT_CONFIGURATION to mean "the defaults" and NW_PARAMETERS_DISABLE_PROTOCOL to
   mean "this protocol is not part of the stack", and every factory that takes them compares them by
   pointer. Each is given here as the empty block it is documented to behave as, so the pointer the
   caller passes is a real one and the comparison means what it says. */
const nw_parameters_configure_protocol_block_t _nw_parameters_configure_protocol_default_configuration =
    ^(nw_protocol_options_t options) {
        (void)options;
    };
const nw_parameters_configure_protocol_block_t _nw_parameters_configure_protocol_disable = ^(nw_protocol_options_t options) {
    (void)options;
};

static CharonNWParameters *charon_parameters(CharonNWProtocolStack *stack)
{
    CharonNWParameters *parameters = [[CharonNWParameters alloc] init];
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

static CharonNWProtocolStack *charon_stack(nw_protocol_definition_t transport, nw_protocol_definition_t internet)
{
    CharonNWProtocolStack *stack = [[CharonNWProtocolStack alloc] init];
    stack->_application = [NSMutableArray array];
    stack->_transport = nil;
    stack->_internet = nil;
    if (internet) {
        CharonNWProtocolOptions *options = [[CharonNWProtocolOptions alloc] init];
        options->_definition = (CharonNWProtocolDefinition *)internet;
        options->_values = [NSMutableDictionary dictionary];
        options->_objects = [NSMutableDictionary dictionary];
        stack->_internet = options;
    }
    if (transport) {
        CharonNWProtocolOptions *options = [[CharonNWProtocolOptions alloc] init];
        options->_definition = (CharonNWProtocolDefinition *)transport;
        options->_values = [NSMutableDictionary dictionary];
        options->_objects = [NSMutableDictionary dictionary];
        stack->_transport = options;
    }
    return stack;
}

/* Whether the block a factory was given is the sentinel that leaves a protocol out. */
static bool charon_disabled(nw_parameters_configure_protocol_block_t configure)
{
    return configure == (nw_parameters_configure_protocol_block_t)_nw_parameters_configure_protocol_disable;
}

/* Whether the block is the one that means "the defaults", which is the same as a block of one's own
   that changes nothing - so a program's own block that sets nothing leaves the protocol as it is. */
static bool charon_defaulted(nw_parameters_configure_protocol_block_t configure)
{
    return !configure ||
           configure == (nw_parameters_configure_protocol_block_t)_nw_parameters_configure_protocol_default_configuration;
}

nw_parameters_t nw_parameters_create(void)
{
    /* No transport protocol is in the stack yet: the default stack of a plain parameters holds the
       internet protocol, and the transport is decided when a connection is made of it - which is a
       TCP connection, because that is the transport a connection with no transport is. Measured on
       the host (tests/backports/host/network-objects), which answers NULL for the transport here
       and a transport for every other factory. */
    return charon_parameters(charon_stack(NULL, nw_protocol_copy_ip_definition()));
}

nw_parameters_t nw_parameters_create_secure_tcp(nw_parameters_configure_protocol_block_t configure_tls,
                                                nw_parameters_configure_protocol_block_t configure_tcp)
{
    CharonNWProtocolStack *stack = charon_stack(nw_protocol_copy_tcp_definition(), nw_protocol_copy_ip_definition());
    if (!charon_disabled(configure_tls)) {
        CharonNWProtocolOptions *tls = (CharonNWProtocolOptions *)nw_tls_create_options();
        if (!charon_defaulted(configure_tls))
            configure_tls(tls);
        [stack->_application insertObject:(CharonNWProtocolOptions *)tls atIndex:0];
    }
    if (!charon_defaulted(configure_tcp))
        configure_tcp(stack->_transport);
    return charon_parameters(stack);
}

nw_parameters_t nw_parameters_create_secure_udp(nw_parameters_configure_protocol_block_t configure_dtls,
                                                nw_parameters_configure_protocol_block_t configure_udp)
{
    /* The two protocol stacks are built in that order, the secure one above the plain one, so the
       DTLS block runs first. */
    CharonNWProtocolStack *stack = charon_stack(nw_protocol_copy_udp_definition(), nw_protocol_copy_ip_definition());
    if (!charon_disabled(configure_dtls)) {
        CharonNWProtocolOptions *tls = (CharonNWProtocolOptions *)nw_tls_create_options();
        if (!charon_defaulted(configure_dtls))
            configure_dtls(tls);
        [stack->_application insertObject:(CharonNWProtocolOptions *)tls atIndex:0];
    }
    if (!charon_defaulted(configure_udp))
        configure_udp(stack->_transport);
    return charon_parameters(stack);
}

nw_parameters_t nw_parameters_copy(nw_parameters_t parameters)
{
    CharonNWParameters *source = (CharonNWParameters *)parameters;
    if (!source)
        return NULL;
    CharonNWProtocolStack *stack = charon_stack(nil, nil);
    stack->_internet = source->_stack->_internet;
    stack->_transport = source->_stack->_transport;
    stack->_application = [source->_stack->_application mutableCopy];
    CharonNWParameters *copy = charon_parameters(stack);
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
    CharonNWParameters *value = (CharonNWParameters *)parameters;
    if (!value)
        return NULL;
    CharonNWProtocolStack *copy = charon_stack(nil, nil);
    copy->_internet = value->_stack->_internet;
    copy->_transport = value->_stack->_transport;
    copy->_application = [value->_stack->_application mutableCopy];
    return copy;
}

nw_endpoint_t nw_parameters_copy_local_endpoint(nw_parameters_t parameters)
{
    CharonNWParameters *value = (CharonNWParameters *)parameters;
    return value ? value->_localEndpoint : NULL;
}

void nw_parameters_set_local_endpoint(nw_parameters_t parameters, nw_endpoint_t local_endpoint)
{
    CharonNWParameters *value = (CharonNWParameters *)parameters;
    if (value)
        value->_localEndpoint = (CharonNWEndpoint *)local_endpoint;
}

bool nw_parameters_get_prohibit_expensive(nw_parameters_t parameters)
{
    CharonNWParameters *value = (CharonNWParameters *)parameters;
    return value ? value->_prohibitExpensive : false;
}

void nw_parameters_set_prohibit_expensive(nw_parameters_t parameters, bool prohibit_expensive)
{
    CharonNWParameters *value = (CharonNWParameters *)parameters;
    if (value)
        value->_prohibitExpensive = prohibit_expensive;
}

bool nw_parameters_get_local_only(nw_parameters_t parameters)
{
    CharonNWParameters *value = (CharonNWParameters *)parameters;
    return value ? value->_localOnly : false;
}

void nw_parameters_set_local_only(nw_parameters_t parameters, bool local_only)
{
    CharonNWParameters *value = (CharonNWParameters *)parameters;
    if (value)
        value->_localOnly = local_only;
}

bool nw_parameters_get_fast_open_enabled(nw_parameters_t parameters)
{
    CharonNWParameters *value = (CharonNWParameters *)parameters;
    return value ? value->_fastOpenEnabled : false;
}

void nw_parameters_set_fast_open_enabled(nw_parameters_t parameters, bool fast_open_enabled)
{
    CharonNWParameters *value = (CharonNWParameters *)parameters;
    if (value)
        value->_fastOpenEnabled = fast_open_enabled;
}

bool nw_parameters_get_include_peer_to_peer(nw_parameters_t parameters)
{
    CharonNWParameters *value = (CharonNWParameters *)parameters;
    return value ? value->_includePeerToPeer : false;
}

void nw_parameters_set_include_peer_to_peer(nw_parameters_t parameters, bool include_peer_to_peer)
{
    CharonNWParameters *value = (CharonNWParameters *)parameters;
    if (value)
        value->_includePeerToPeer = include_peer_to_peer;
}

bool nw_parameters_get_reuse_local_address(nw_parameters_t parameters)
{
    CharonNWParameters *value = (CharonNWParameters *)parameters;
    return value ? value->_reuseLocalAddress : false;
}

void nw_parameters_set_reuse_local_address(nw_parameters_t parameters, bool reuse_local_address)
{
    CharonNWParameters *value = (CharonNWParameters *)parameters;
    if (value)
        value->_reuseLocalAddress = reuse_local_address;
}

bool nw_parameters_get_prefer_no_proxy(nw_parameters_t parameters)
{
    CharonNWParameters *value = (CharonNWParameters *)parameters;
    return value ? value->_preferNoProxy : false;
}

void nw_parameters_set_prefer_no_proxy(nw_parameters_t parameters, bool prefer_no_proxy)
{
    CharonNWParameters *value = (CharonNWParameters *)parameters;
    if (value)
        value->_preferNoProxy = prefer_no_proxy;
}

nw_service_class_t nw_parameters_get_service_class(nw_parameters_t parameters)
{
    CharonNWParameters *value = (CharonNWParameters *)parameters;
    return value ? value->_serviceClass : nw_service_class_best_effort;
}

void nw_parameters_set_service_class(nw_parameters_t parameters, nw_service_class_t service_class)
{
    CharonNWParameters *value = (CharonNWParameters *)parameters;
    if (value)
        value->_serviceClass = service_class;
}

nw_multipath_service_t nw_parameters_get_multipath_service(nw_parameters_t parameters)
{
    CharonNWParameters *value = (CharonNWParameters *)parameters;
    return value ? value->_multipathService : nw_multipath_service_disabled;
}

void nw_parameters_set_multipath_service(nw_parameters_t parameters, nw_multipath_service_t multipath_service)
{
    CharonNWParameters *value = (CharonNWParameters *)parameters;
    if (value)
        value->_multipathService = multipath_service;
}

nw_parameters_expired_dns_behavior_t nw_parameters_get_expired_dns_behavior(nw_parameters_t parameters)
{
    CharonNWParameters *value = (CharonNWParameters *)parameters;
    return value ? value->_expiredDNSBehavior : nw_parameters_expired_dns_behavior_default;
}

void nw_parameters_set_expired_dns_behavior(nw_parameters_t parameters, nw_parameters_expired_dns_behavior_t expired_dns_behavior)
{
    CharonNWParameters *value = (CharonNWParameters *)parameters;
    if (value)
        value->_expiredDNSBehavior = expired_dns_behavior;
}

nw_interface_type_t nw_parameters_get_required_interface_type(nw_parameters_t parameters)
{
    CharonNWParameters *value = (CharonNWParameters *)parameters;
    return value ? value->_requiredInterfaceType : nw_interface_type_other;
}

void nw_parameters_set_required_interface_type(nw_parameters_t parameters, nw_interface_type_t interface_type)
{
    CharonNWParameters *value = (CharonNWParameters *)parameters;
    if (value)
        value->_requiredInterfaceType = interface_type;
}

nw_interface_t nw_parameters_copy_required_interface(nw_parameters_t parameters)
{
    CharonNWParameters *value = (CharonNWParameters *)parameters;
    if (!value || !value->_requiredInterface)
        return NULL;
    return (nw_interface_t)value->_requiredInterface;
}

void nw_parameters_require_interface(nw_parameters_t parameters, nw_interface_t interface)
{
    CharonNWParameters *value = (CharonNWParameters *)parameters;
    if (value)
        value->_requiredInterface = (id)interface;
}

void nw_parameters_prohibit_interface(nw_parameters_t parameters, nw_interface_t interface)
{
    CharonNWParameters *value = (CharonNWParameters *)parameters;
    if (!value || !interface)
        return;
    [value->_prohibitedInterfaces addObject:(id)interface];
}

void nw_parameters_prohibit_interface_type(nw_parameters_t parameters, nw_interface_type_t interface_type)
{
    CharonNWParameters *value = (CharonNWParameters *)parameters;
    if (!value)
        return;
    [value->_prohibitedInterfaceTypes addObject:@(interface_type)];
}

void nw_parameters_clear_prohibited_interfaces(nw_parameters_t parameters)
{
    CharonNWParameters *value = (CharonNWParameters *)parameters;
    [value->_prohibitedInterfaces removeAllObjects];
}

void nw_parameters_clear_prohibited_interface_types(nw_parameters_t parameters)
{
    CharonNWParameters *value = (CharonNWParameters *)parameters;
    [value->_prohibitedInterfaceTypes removeAllObjects];
}

void nw_parameters_iterate_prohibited_interfaces(nw_parameters_t parameters, nw_parameters_iterate_interfaces_block_t iterate_block)
{
    CharonNWParameters *value = (CharonNWParameters *)parameters;
    if (!value || !iterate_block)
        return;
    for (id interface in [value->_prohibitedInterfaces copy]) {
        if (!iterate_block((nw_interface_t)interface))
            break;
    }
}

void nw_parameters_iterate_prohibited_interface_types(nw_parameters_t parameters, nw_parameters_iterate_interface_types_block_t iterate_block)
{
    CharonNWParameters *value = (CharonNWParameters *)parameters;
    if (!value || !iterate_block)
        return;
    for (NSNumber *type in [value->_prohibitedInterfaceTypes copy]) {
        if (!iterate_block((nw_interface_type_t)type.unsignedIntegerValue))
            break;
    }
}
