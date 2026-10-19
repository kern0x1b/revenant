#import <Foundation/Foundation.h>
#import <Security/SecProtocolTypes.h>
#import <Security/SecProtocolMetadata.h>

// sec_protocol_metadata_get_server_name, split out of SecProtocolMetadataAccessors13_0.m because the release
// ladder first exports it at iOS 16.0 while its siblings there are exported from 12.0 (the gate's release
// split: an object carries API that arrived in one release). The registry row stays in ios13.json: that is
// the header's availability; this file is where the release's first rung places the symbol.
// The answer is the accessors' shared one: nothing in 6.1.3 ever produces a metadata object, and the return
// type is _Nullable, so NULL is the header's own spelling of absence.

//   287   const char * _Nullable sec_protocol_metadata_get_server_name(sec_protocol_metadata_t)
const char * _Nullable sec_protocol_metadata_get_server_name(sec_protocol_metadata_t metadata)
{
    (void)metadata;
    return NULL;
}
