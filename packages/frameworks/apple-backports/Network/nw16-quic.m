#import "RevenantNW.h"
#import "RevenantNWSupport.h"

static BOOL revenant_quic_options(nw_protocol_options_t options, RevenantNWProtocolOptions **out)
{
    if (!nw_protocol_options_is_quic(options))
        return NO;
    *out = (RevenantNWProtocolOptions *)options;
    return YES;
}

void nw_quic_set_max_datagram_frame_size(nw_protocol_options_t options, uint16_t max_datagram_frame_size)
{
    RevenantNWProtocolOptions *value;
    if (revenant_quic_options(options, &value))
        revenant_nw_set_integer((__bridge CFMutableDictionaryRef)value->_values, "max_datagram_frame_size", max_datagram_frame_size);
}

uint16_t nw_quic_get_max_datagram_frame_size(nw_protocol_options_t options)
{
    RevenantNWProtocolOptions *value;
    if (!revenant_quic_options(options, &value))
        return 0;
    return (uint16_t)revenant_nw_integer((__bridge CFDictionaryRef)value->_values, "max_datagram_frame_size", 0);
}

void nw_quic_set_stream_is_datagram(nw_protocol_options_t options, bool is_datagram)
{
    RevenantNWProtocolOptions *value;
    if (revenant_quic_options(options, &value))
        revenant_nw_set_flag((__bridge CFMutableDictionaryRef)value->_values, "stream_is_datagram", is_datagram);
}

bool nw_quic_get_stream_is_datagram(nw_protocol_options_t options)
{
    RevenantNWProtocolOptions *value;
    if (!revenant_quic_options(options, &value))
        return false;
    return revenant_nw_flag((__bridge CFDictionaryRef)value->_values, "stream_is_datagram", false);
}

uint16_t nw_quic_get_stream_usable_datagram_frame_size(nw_protocol_metadata_t metadata)
{
    RevenantNWProtocolMetadata *value = (RevenantNWProtocolMetadata *)metadata;
    if (![value isKindOfClass:[RevenantNWProtocolMetadata class]] ||
        ![value->_definition->_family isEqualToString:@"nw_quic"])
        return 0;
    return (uint16_t)revenant_nw_integer((__bridge CFDictionaryRef)value->_values, "usable_datagram_frame_size", 0);
}
