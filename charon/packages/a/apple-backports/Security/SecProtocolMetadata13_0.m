#import <Foundation/Foundation.h>
#import <Security/SecProtocolTypes.h>
#import <Security/SecProtocolMetadata.h>
#import <CoreFoundation/CoreFoundation.h>
#import <dispatch/dispatch.h>

// The sec_protocol_metadata family, from Security/SecProtocolMetadata.h.
//
// THE OBJECT IS THE PORT'S OWN, exactly as the preprocessor emits the type:
//
//     @protocol OS_sec_protocol_metadata <NSObject> @end
//     typedef NSObject<OS_sec_protocol_metadata> * __attribute__((objc_independent_class))
//         sec_protocol_metadata_t;
//
// NOTHING IN 6.1.3 EVER PRODUCES ONE, and that is the whole of this family. A sec_protocol_metadata_t is
// handed to a TLS callback by the handshake that negotiated it, and 6.1.3 has no TLS stack that calls
// one: the release's networking is not this API. So the object exists because the rows are callable, and
// every getter answers the header's absence.
//
// THE CLASS IS DELIBERATELY EMPTY OF NEGOTIATED VALUES, and there is nothing to put in it: there is no
// setter anywhere in this header, so a held ciphersuite or version would be a value the port invented
// with no caller able to have set it. An empty object and a getter that says so is the honest shape; a
// held value here would be a number that looks negotiated and is not.

@interface CharonSecProtocolMetadata : NSObject <OS_sec_protocol_metadata>
@end
@implementation CharonSecProtocolMetadata
@end

//    109  tls_protocol_version_t sec_protocol_metadata_get_negotiated_tls_protocol_version(
//             sec_protocol_metadata_t metadata)
//         API_AVAILABLE(macos(10.15), ios(13.0), watchos(6.0), tvos(13.0));
//
// WHAT THE HEADER PROMISES IS "A tls_protocol_version_t value" and NOTHING ELSE - there is no documented
// absence for this getter, and the enum has no member that means one:
//
//    58  typedef CF_ENUM(uint16_t, tls_protocol_version_t) {
//           tls_protocol_version_TLSv10 = 0x0301   (deprecated alias)
//           tls_protocol_version_TLSv12 = 0x0303
//           tls_protocol_version_TLSv13 = 0x0304
//           tls_protocol_version_DTLSv12 = 0xfefd
//        };
//
// Every one of those is a REAL version, so 0 is not a member and returning it is the port inventing an
// absence the header does not define. It is the only value left that is not a lie about a negotiation,
// and the row says what a caller can and cannot do with it.
tls_protocol_version_t sec_protocol_metadata_get_negotiated_tls_protocol_version(
    sec_protocol_metadata_t metadata)
{
    (void)metadata;
    return 0;   // NOT a member of tls_protocol_version_t, and stated as such in the row
}

//    140  tls_ciphersuite_t sec_protocol_metadata_get_negotiated_tls_ciphersuite(
//             sec_protocol_metadata_t metadata)
//         API_AVAILABLE(macos(10.15), ios(13.0), watchos(6.0), tvos(13.0));
//
//    101  typedef CF_ENUM(uint16_t, tls_ciphersuite_t) { ... }   - every member is a real ciphersuite
//
// The same shape as the version getter: the header promises "A tls_ciphersuite_t" and names no absence,
// and the enum has no invalid member, so 0 is again a value the header does not define.
tls_ciphersuite_t sec_protocol_metadata_get_negotiated_tls_ciphersuite(sec_protocol_metadata_t metadata)
{
    (void)metadata;
    return 0;   // NOT a member of tls_ciphersuite_t, and stated as such in the row
}

//    267  bool sec_protocol_metadata_access_pre_shared_keys(sec_protocol_metadata_t metadata,
//                                                            void (^handler)(dispatch_data_t psk,
//                                                                            dispatch_data_t psk_identity))
//         API_AVAILABLE(macos(10.15), ios(13.0), watchos(6.0), tvos(13.0))
//
// THIS ONE HAS A DOCUMENTED ABSENCE, so it is the one that can be answered properly:
//
//    the declared return is a bool: the answer to whether the PSKs can be reached.
//
// so it returns false, and - the part worth the assertion - IT DOES NOT RUN THE HANDLER. A block that ran
// for a caller with no metadata would hand it an identity, a ciphersuite and a PSK that were never
// negotiated, and the caller would act on a secret that does not exist.
bool sec_protocol_metadata_access_pre_shared_keys(sec_protocol_metadata_t metadata,
                                                  void (^handler)(dispatch_data_t psk,
                                                                  dispatch_data_t psk_identity))
{
    (void)metadata;
    (void)handler;   // the block PARAMETERS are not in scope in the body - they are in scope inside the
                     // block literal - so there is nothing of theirs to silence here
    return false;   // the header's own "false otherwise", and the handler is not run
}
