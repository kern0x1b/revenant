#import "RevenantNW.h"

nw_protocol_options_t nw_framer_copy_options(nw_framer_t framer)
{
    RevenantNWFramer *value = (RevenantNWFramer *)framer;
    if (!value || !value->_options)
        return NULL;
    RevenantNWProtocolOptions *copy = [[RevenantNWProtocolOptions alloc] init];
    copy->_definition = value->_options->_definition;
    copy->_values = [value->_options->_values mutableCopy];
    copy->_objects = [value->_options->_objects mutableCopy];
    return copy;
}
