#import "RevenantNW.h"
#include <Availability.h>

#define REVENANT_IOS_26 API_AVAILABLE(ios(26.0))

REVENANT_IOS_26 bool nw_parameters_get_allow_ultra_constrained(nw_parameters_t parameters)
{
    RevenantNWParameters *value = (RevenantNWParameters *)parameters;
    return value ? value->_allowUltraConstrained : false;
}

REVENANT_IOS_26 void nw_parameters_set_allow_ultra_constrained(nw_parameters_t parameters, bool allow_ultra_constrained)
{
    RevenantNWParameters *value = (RevenantNWParameters *)parameters;
    if (value)
        value->_allowUltraConstrained = allow_ultra_constrained;
}
