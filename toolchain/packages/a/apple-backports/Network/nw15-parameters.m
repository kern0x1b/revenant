#import "CharonNW.h"

nw_parameters_attribution_t nw_parameters_get_attribution(nw_parameters_t parameters)
{
    CharonNWParameters *value = (CharonNWParameters *)parameters;
    return value ? value->_attribution : nw_parameters_attribution_developer;
}

void nw_parameters_set_attribution(nw_parameters_t parameters, nw_parameters_attribution_t attribution)
{
    CharonNWParameters *value = (CharonNWParameters *)parameters;
    if (value)
        value->_attribution = attribution;
}
