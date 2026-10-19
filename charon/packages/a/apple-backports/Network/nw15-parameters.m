/*
 * The two calls of iOS 15 about where the content of a connection came from: its attribution.
 *
 * A connection's attribution says whether what it carries was chosen by the developer who wrote the
 * program or by the person using it - a video the user picked is theirs, a request the program makes
 * on its own is the developer's - and the system uses it to decide what may be sent over a
 * metered link. The release this port builds for has no such policy and no metered-link policy of its
 * own, so the attribution is kept and read back and the connection reports it in its description,
 * which is where the host's own Network shows it.
 */

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
