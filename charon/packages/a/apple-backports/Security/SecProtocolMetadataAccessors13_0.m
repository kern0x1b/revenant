#import <Foundation/Foundation.h>
#import <Security/SecProtocolTypes.h>
#import <Security/SecProtocolMetadata.h>
#import <CoreFoundation/CoreFoundation.h>
#import <dispatch/dispatch.h>

// The remaining sec_protocol_metadata accessors. The class is the port's own, exactly as
// SecProtocolMetadata13_0.m declares it: as clang -E emits the type, sec_protocol_metadata_t is
// `NSObject<OS_sec_protocol_metadata> *`, so the port supplies the object under its own name.
//
// NOTHING IN 6.1.3 EVER PRODUCES A METADATA OBJECT. One is handed to a TLS callback by the handshake
// that negotiated it, and the release has no stack that calls one, and this header has no setter. So
// every accessor here answers an absence, and the shapes are only three:
//
//   1. A _Nullable POINTER RETURN is NULL. That is the header's own spelling of absence - the return
//      type is _Nullable, so NULL is a documented answer and not an invention.
//   2. A bool accessor is false.
//   3. A block-taking accessor is false AND DOES NOT RUN THE HANDLER, which is the part worth
//      asserting: a handler that ran would hand the caller values that were never negotiated.
//
// TWO OF THEM ARE DIFFERENT IN KIND, because their enums HAVE a member that means "none":
//
//    156  kSSLProtocolUnknown                    = 0    (SecProtocolTypes.h:156)
//     48  SSL_NULL_WITH_NULL_NULL               = 0x0000 (CipherSuite.h:48)
//
// so 0 is a DOCUMENTED value in both and is returned as itself, not as a port-invented sentinel. This is
// the opposite of the two tls_protocol_version_t getters in the other file, where the enum has no such
// member and the row has to state that a caller cannot tell 0 from an undefined value.
//
// THE TWO COMPARATORS READ THE PORT'S OWN HELD STATE and are implemented for the same reason
// sec_protocol_options_are_equal is: a comparison against the release's stack would compare nothing,
// because there is no such stack, while a comparison of two metadata objects the caller made is a
// question the port can answer.

//    79   const char * _Nullable sec_protocol_metadata_get_negotiated_protocol(sec_protocol_metadata_t)
const char * _Nullable sec_protocol_metadata_get_negotiated_protocol(sec_protocol_metadata_t metadata)
{
    (void)metadata;
    return NULL;   // the return type is _Nullable, so NULL is the header's own answer
}

//    94   SEC_RETURNS_RETAINED _Nullable dispatch_data_t sec_protocol_metadata_copy_peer_public_key(...)
dispatch_data_t sec_protocol_metadata_copy_peer_public_key(sec_protocol_metadata_t metadata)
{
    (void)metadata;
    return NULL;   // no peer, because nothing connected
}

//   352   SEC_RETURNS_RETAINED _Nullable dispatch_data_t sec_protocol_metadata_create_secret(...)
dispatch_data_t sec_protocol_metadata_create_secret(sec_protocol_metadata_t metadata,
                                                   size_t label_len, const char *label,
                                                   size_t exporter_length)
{
    (void)metadata; (void)label_len; (void)label; (void)exporter_length;
    return NULL;   // a secret over a handshake that did not happen
}

//   383   SEC_RETURNS_RETAINED _Nullable dispatch_data_t sec_protocol_metadata_create_secret_with_context(...)
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

//   125   SSLProtocol sec_protocol_metadata_get_negotiated_protocol_version(sec_protocol_metadata_t)
//
// 0 IS kSSLProtocolUnknown (SecProtocolTypes.h:156) - a documented member, not a port-invented 0.
SSLProtocol sec_protocol_metadata_get_negotiated_protocol_version(sec_protocol_metadata_t metadata)
{
    (void)metadata;
    return kSSLProtocolUnknown;
}

//   156   SSLCipherSuite sec_protocol_metadata_get_negotiated_ciphersuite(sec_protocol_metadata_t)
//
// 0x0000 IS SSL_NULL_WITH_NULL_NULL (CipherSuite.h:48) - the null ciphersuite, a real member.
SSLCipherSuite sec_protocol_metadata_get_negotiated_ciphersuite(sec_protocol_metadata_t metadata)
{
    (void)metadata;
    return SSL_NULL_WITH_NULL_NULL;
}

//   171   bool sec_protocol_metadata_get_early_data_accepted(sec_protocol_metadata_t)
bool sec_protocol_metadata_get_early_data_accepted(sec_protocol_metadata_t metadata)
{
    (void)metadata;
    return false;   // 0-RTT did not exist in 2011, and nothing here negotiated it
}

//   190   bool sec_protocol_metadata_access_peer_certificate_chain(metadata, handler)
bool sec_protocol_metadata_access_peer_certificate_chain(sec_protocol_metadata_t metadata,
                                                         void (^handler)(sec_certificate_t certificate))
{
    (void)metadata;
    (void)handler;
    return false;   // the handler is NOT run: a chain that was never received
}

//   209   bool sec_protocol_metadata_access_ocsp_response(metadata, handler)
bool sec_protocol_metadata_access_ocsp_response(sec_protocol_metadata_t metadata,
                                                void (^handler)(dispatch_data_t response))
{
    (void)metadata;
    (void)handler;
    return false;   // and a response that was never stapled
}

//   229   bool sec_protocol_metadata_access_supported_signature_algorithms(metadata, handler)
bool sec_protocol_metadata_access_supported_signature_algorithms(sec_protocol_metadata_t metadata,
                                                                void (^handler)(uint16_t signature_algorithm))
{
    (void)metadata;
    (void)handler;
    return false;
}

//   248   bool sec_protocol_metadata_access_distinguished_names(metadata, handler)
bool sec_protocol_metadata_access_distinguished_names(sec_protocol_metadata_t metadata,
                                                      void (^handler)(dispatch_data_t distinguished_name))
{
    (void)metadata;
    (void)handler;
    return false;
}

//   306   bool sec_protocol_metadata_peers_are_equal(sec_protocol_metadata_t A, sec_protocol_metadata_t B)
//
// A REAL ANSWER: two metadata objects the caller made, with nothing negotiated on either, are equal -
// and so is the same object, and two NULLs. It is false for one NULL, because one is a peer and the
// other is not.
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
    return true;   // neither carries a peer, so neither disagrees with the other
}

//   328   bool sec_protocol_metadata_challenge_parameters_are_equal(A, B)
//
// The same shape, and the same reason: no challenge parameters were ever exchanged, so there is nothing
// for one to differ from the other on.
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
