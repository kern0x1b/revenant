#import "CharonNW.h"

bool nw_protocol_options_is_quic(nw_protocol_options_t options)
{
    CharonNWProtocolOptions *value = (CharonNWProtocolOptions *)options;
    if (![value isKindOfClass:[CharonNWProtocolOptions class]])
        return false;
    return [value->_definition->_family isEqualToString:@"nw_quic"];
}
