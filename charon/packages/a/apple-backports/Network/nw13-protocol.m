/*
 * The WebSocket definition and the one predicate of iOS 13 that answers for it.
 */

#import "CharonNW.h"

nw_protocol_definition_t nw_protocol_copy_ws_definition(void)
{
    static CharonNWProtocolDefinition *definition;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        definition = [[CharonNWProtocolDefinition alloc] init];
        definition->_family = @"nw_ws";
        definition->_identifier = @"nw_ws";
    });
    return definition;
}

bool nw_protocol_metadata_is_ws(nw_protocol_metadata_t metadata)
{
    CharonNWProtocolMetadata *value = (CharonNWProtocolMetadata *)metadata;
    return value && [value->_definition->_family isEqualToString:@"nw_ws"];
}
