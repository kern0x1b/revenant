#include "../revenant_impl.h"
#import "RevenantNW.h"

bool BACKPORT_IMPL(nw_protocol_options_is_quic)(nw_protocol_options_t options)
{
    RevenantNWProtocolOptions *value = (RevenantNWProtocolOptions *)options;
    if (![value isKindOfClass:[RevenantNWProtocolOptions class]])
        return false;
    return [value->_definition->_family isEqualToString:@"nw_quic"];
}
