#import "RevenantNW.h"

void nw_framer_options_set_object_value(nw_protocol_options_t options, const char *key, id value)
{
    RevenantNWProtocolOptions *held = (RevenantNWProtocolOptions *)options;
    if (!held || !key)
        return;
    if (value)
        held->_objects[@(key)] = value;
    else
        [held->_objects removeObjectForKey:@(key)];
}

id nw_framer_options_copy_object_value(nw_protocol_options_t options, const char *key)
{
    RevenantNWProtocolOptions *held = (RevenantNWProtocolOptions *)options;
    if (!held || !key)
        return nil;
    return held->_objects[@(key)];
}
