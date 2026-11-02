#include "../revenant_impl.h"
#import "RevenantNW.h"

bool BACKPORT_IMPL(nw_parameters_get_prohibit_constrained)(nw_parameters_t parameters)
{
    RevenantNWParameters *value = (RevenantNWParameters *)parameters;
    return value ? value->_prohibitConstrained : false;
}

void BACKPORT_IMPL(nw_parameters_set_prohibit_constrained)(nw_parameters_t parameters, bool prohibit_constrained)
{
    RevenantNWParameters *value = (RevenantNWParameters *)parameters;
    if (value)
        value->_prohibitConstrained = prohibit_constrained;
}
