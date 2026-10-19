#import "CharonNW.h"
#include <Availability.h>

#define CHARON_IOS_26 API_AVAILABLE(ios(26.0))

CHARON_IOS_26 bool nw_parameters_get_allow_ultra_constrained(nw_parameters_t parameters)
{
    CharonNWParameters *value = (CharonNWParameters *)parameters;
    return value ? value->_allowUltraConstrained : false;
}

CHARON_IOS_26 void nw_parameters_set_allow_ultra_constrained(nw_parameters_t parameters, bool allow_ultra_constrained)
{
    CharonNWParameters *value = (CharonNWParameters *)parameters;
    if (value)
        value->_allowUltraConstrained = allow_ultra_constrained;
}
