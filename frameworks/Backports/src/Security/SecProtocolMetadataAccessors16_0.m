#include "../revenant_impl.h"
#import <Foundation/Foundation.h>
#import <Security/SecProtocolTypes.h>
#import <Security/SecProtocolMetadata.h>

const char * _Nullable BACKPORT_IMPL(sec_protocol_metadata_get_server_name)(sec_protocol_metadata_t metadata)
{
    (void)metadata;
    return NULL;
}
