/*
 * The framer calls of iOS 16.0: the object values a program can read and write on the options of a
 * framer. The values are kept by name beside the numbers, so a value a program sets on the options of
 * a framer is the value it reads back. The copy of those options, nw_framer_copy_options, is iOS 13.4
 * and is in nw134-framer.m.
 */

#import "CharonNW.h"

void nw_framer_options_set_object_value(nw_protocol_options_t options, const char *key, id value)
{
    CharonNWProtocolOptions *held = (CharonNWProtocolOptions *)options;
    if (!held || !key)
        return;
    if (value)
        held->_objects[@(key)] = value;
    else
        [held->_objects removeObjectForKey:@(key)];
}

id nw_framer_options_copy_object_value(nw_protocol_options_t options, const char *key)
{
    CharonNWProtocolOptions *held = (CharonNWProtocolOptions *)options;
    if (!held || !key)
        return nil;
    return held->_objects[@(key)];
}
