#import <Foundation/Foundation.h>
#import <Security/SecProtocolTypes.h>
#import <Security/SecProtocolMetadata.h>
#import <CoreFoundation/CoreFoundation.h>
#import <dispatch/dispatch.h>

@interface RevenantSecProtocolMetadata : NSObject <OS_sec_protocol_metadata>
@end
@implementation RevenantSecProtocolMetadata
@end

tls_protocol_version_t sec_protocol_metadata_get_negotiated_tls_protocol_version(
    sec_protocol_metadata_t metadata)
{
    (void)metadata;
    return 0;
}

tls_ciphersuite_t sec_protocol_metadata_get_negotiated_tls_ciphersuite(sec_protocol_metadata_t metadata)
{
    (void)metadata;
    return 0;
}

bool sec_protocol_metadata_access_pre_shared_keys(sec_protocol_metadata_t metadata,
                                                  void (^handler)(dispatch_data_t psk,
                                                                  dispatch_data_t psk_identity))
{
    (void)metadata;
    (void)handler;
    return false;
}
