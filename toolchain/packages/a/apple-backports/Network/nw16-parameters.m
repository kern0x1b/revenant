#import "RevenantNW.h"

nw_parameters_t nw_parameters_create_application_service(void)
{
    RevenantNWParameters *parameters = [[RevenantNWParameters alloc] init];
    RevenantNWProtocolStack *stack = [[RevenantNWProtocolStack alloc] init];
    stack->_application = [NSMutableArray array];
    RevenantNWProtocolOptions *internet = [[RevenantNWProtocolOptions alloc] init];
    internet->_definition = (RevenantNWProtocolDefinition *)nw_protocol_copy_ip_definition();
    internet->_values = [NSMutableDictionary dictionary];
    internet->_objects = [NSMutableDictionary dictionary];
    stack->_internet = internet;
    RevenantNWProtocolOptions *transport = [[RevenantNWProtocolOptions alloc] init];
    transport->_definition = (RevenantNWProtocolDefinition *)nw_protocol_copy_tcp_definition();
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
    RevenantNWParameters *value = (RevenantNWParameters *)parameters;
    return value ? value->_requiresDNSSEC : false;
}

void nw_parameters_set_requires_dnssec_validation(nw_parameters_t parameters, bool requires_dnssec_validation)
{
    RevenantNWParameters *value = (RevenantNWParameters *)parameters;
    if (value)
        value->_requiresDNSSEC = requires_dnssec_validation;
}
