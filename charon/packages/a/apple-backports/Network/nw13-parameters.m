/*
 * The two calls of iOS 13 about a path a connection must not take: the constrained network of Low
 * Data Mode.
 *
 * The release this port builds for has no Low Data Mode, so no path is ever constrained and the
 * answer the system gives for a device with that mode switched off is the honest one here - the
 * same `false` a device with the mode off reports. A program that sets it still has it set, and the
 * connection reads it as it does every other path setting, so the flag is kept rather than refused.
 */

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
