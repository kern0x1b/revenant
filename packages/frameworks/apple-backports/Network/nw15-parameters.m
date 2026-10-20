#import "RevenantNW.h"

nw_parameters_attribution_t nw_parameters_get_attribution(nw_parameters_t parameters)
{
    RevenantNWParameters *value = (RevenantNWParameters *)parameters;
    return value ? value->_attribution : nw_parameters_attribution_developer;
}

void nw_parameters_set_attribution(nw_parameters_t parameters, nw_parameters_attribution_t attribution)
{
    RevenantNWParameters *value = (RevenantNWParameters *)parameters;
    if (value)
        value->_attribution = attribution;
}
