/*
 * The QUIC predicate of iOS 13.4: whether a protocol options object is the options of QUIC. The held
 * iOS 13.4 cache is the first to export it. The metadata predicate and the QUIC calls of iOS 16.0 are in
 * nw16-quic-options.m and nw16-quic.m.
 */

#import "CharonNW.h"

bool nw_protocol_options_is_quic(nw_protocol_options_t options)
{
    CharonNWProtocolOptions *value = (CharonNWProtocolOptions *)options;
    if (![value isKindOfClass:[CharonNWProtocolOptions class]])
        return false;
    return [value->_definition->_family isEqualToString:@"nw_quic"];
}
