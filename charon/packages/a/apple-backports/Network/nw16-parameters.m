/*
 * The calls of iOS 16 on a parameters: an application service, and whether its names must be
 * resolved with DNSSEC.
 *
 * An application service is a name that stands for a service, so the stack of such a parameters is
 * the internet protocol and a transport and nothing above them, which is what the host answers for
 * its default protocol stack, measured. DNSSEC is a demand the release's resolver does not meet - it
 * resolves with the resolver the system gives it - so the demand is kept and read back, and the
 * connection resolves the way this release resolves.
 */

#import "CharonNW.h"

nw_parameters_t nw_parameters_create_application_service(void)
{
    CharonNWParameters *parameters = [[CharonNWParameters alloc] init];
    CharonNWProtocolStack *stack = [[CharonNWProtocolStack alloc] init];
    stack->_application = [NSMutableArray array];
    CharonNWProtocolOptions *internet = [[CharonNWProtocolOptions alloc] init];
    internet->_definition = (CharonNWProtocolDefinition *)nw_protocol_copy_ip_definition();
    internet->_values = [NSMutableDictionary dictionary];
    internet->_objects = [NSMutableDictionary dictionary];
    stack->_internet = internet;
    CharonNWProtocolOptions *transport = [[CharonNWProtocolOptions alloc] init];
    transport->_definition = (CharonNWProtocolDefinition *)nw_protocol_copy_tcp_definition();
    transport->_values = [NSMutableDictionary dictionary];
    transport->_objects = [NSMutableDictionary dictionary];
    stack->_transport = transport;
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

bool nw_parameters_requires_dnssec_validation(nw_parameters_t parameters)
{
    CharonNWParameters *value = (CharonNWParameters *)parameters;
    return value ? value->_requiresDNSSEC : false;
}

void nw_parameters_set_requires_dnssec_validation(nw_parameters_t parameters, bool requires_dnssec_validation)
{
    CharonNWParameters *value = (CharonNWParameters *)parameters;
    if (value)
        value->_requiresDNSSEC = requires_dnssec_validation;
}
