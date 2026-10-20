#import <Foundation/Foundation.h>
#import <Security/SecProtocolTypes.h>
#import <Security/SecProtocolMetadata.h>
#import <CoreFoundation/CoreFoundation.h>
#import <dispatch/dispatch.h>

const char * _Nullable sec_protocol_metadata_get_negotiated_protocol(sec_protocol_metadata_t metadata)
{
    (void)metadata;
    return NULL;
}

dispatch_data_t sec_protocol_metadata_copy_peer_public_key(sec_protocol_metadata_t metadata)
{
    (void)metadata;
    return NULL;
}

dispatch_data_t sec_protocol_metadata_create_secret(sec_protocol_metadata_t metadata,
                                                   size_t label_len, const char *label,
                                                   size_t exporter_length)
{
    (void)metadata; (void)label_len; (void)label; (void)exporter_length;
    return NULL;
}

dispatch_data_t sec_protocol_metadata_create_secret_with_context(sec_protocol_metadata_t metadata,
                                                                 size_t label_len, const char *label,
                                                                 size_t context_len,
                                                                 const uint8_t *context,
                                                                 size_t exporter_length)
{
    (void)metadata; (void)label_len; (void)label; (void)context_len; (void)context;
    (void)exporter_length;
    return NULL;
}

SSLProtocol sec_protocol_metadata_get_negotiated_protocol_version(sec_protocol_metadata_t metadata)
{
    (void)metadata;
    return kSSLProtocolUnknown;
}

SSLCipherSuite sec_protocol_metadata_get_negotiated_ciphersuite(sec_protocol_metadata_t metadata)
{
    (void)metadata;
    return SSL_NULL_WITH_NULL_NULL;
}

bool sec_protocol_metadata_get_early_data_accepted(sec_protocol_metadata_t metadata)
{
    (void)metadata;
    return false;
}

bool sec_protocol_metadata_access_peer_certificate_chain(sec_protocol_metadata_t metadata,
                                                         void (^handler)(sec_certificate_t certificate))
{
    (void)metadata;
    (void)handler;
    return false;
}

bool sec_protocol_metadata_access_ocsp_response(sec_protocol_metadata_t metadata,
                                                void (^handler)(dispatch_data_t response))
{
    (void)metadata;
    (void)handler;
    return false;
}

bool sec_protocol_metadata_access_supported_signature_algorithms(sec_protocol_metadata_t metadata,
                                                                void (^handler)(uint16_t signature_algorithm))
{
    (void)metadata;
    (void)handler;
    return false;
}

bool sec_protocol_metadata_access_distinguished_names(sec_protocol_metadata_t metadata,
                                                      void (^handler)(dispatch_data_t distinguished_name))
{
    (void)metadata;
    (void)handler;
    return false;
}

bool sec_protocol_metadata_peers_are_equal(sec_protocol_metadata_t metadataA,
                                           sec_protocol_metadata_t metadataB)
{
    if (metadataA == metadataB)
        return true;
    if (!metadataA || !metadataB)
        return false;
    if (![metadataA conformsToProtocol:@protocol(OS_sec_protocol_metadata)]
        || ![metadataB conformsToProtocol:@protocol(OS_sec_protocol_metadata)])
        return false;
    return true;
}

bool sec_protocol_metadata_challenge_parameters_are_equal(sec_protocol_metadata_t metadataA,
                                                         sec_protocol_metadata_t metadataB)
{
    if (metadataA == metadataB)
        return true;
    if (!metadataA || !metadataB)
        return false;
    if (![metadataA conformsToProtocol:@protocol(OS_sec_protocol_metadata)]
        || ![metadataB conformsToProtocol:@protocol(OS_sec_protocol_metadata)])
        return false;
    return true;
}
