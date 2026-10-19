#import "CharonNW.h"

bool nw_parameters_get_prohibit_constrained(nw_parameters_t parameters)
{
    CharonNWParameters *value = (CharonNWParameters *)parameters;
    return value ? value->_prohibitConstrained : false;
}

void nw_parameters_set_prohibit_constrained(nw_parameters_t parameters, bool prohibit_constrained)
{
    CharonNWParameters *value = (CharonNWParameters *)parameters;
    if (value)
        value->_prohibitConstrained = prohibit_constrained;
}
