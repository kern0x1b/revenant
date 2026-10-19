/*
 * The objects Network's C API hands back, declared once for every file of the library.
 *
 * Each nw_* type of the SDK is a protocol (OS_OBJECT_DECL makes it `NSObject<OS_nw_thing>`), so
 * every object here is an NSObject that adopts the protocol of the type it is. The SDK's own types
 * are therefore the ivars' home: a port that hands its own object to a release that has Network
 * would find the release's calls reach an object that is not its class, and a release below iOS 9
 * has no calls of its own to reach anything with.
 *
 * One object per file, one file per release: `modules/apple/backports.lua` splits an object that
 * exports symbols of two introductions, so a file here carries the calls of one release only, named
 * for it (nw12, nw13, nw14, nw142, nw15, nw154, nw16, nw17, nw26). The two exceptions are the
 * headers, which declare nothing the linker sees.
 */

#import <Foundation/Foundation.h>
#import <Network/Network.h>
#import <Security/Security.h>
#import <Security/SecureTransport.h>


/* The SDK's headers wrap Network in an assume-nonnull region and so mark every factory's result
   non-null, while documenting several of those factories as returning NULL for an argument they
   refuse - nw_endpoint_create_host with no host, nw_parameters_create with nothing to build, a
   getter asked of an object of the wrong type. The port answers as the documentation says, so the
   note is taken back for the files that include this one. */
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"

NS_ASSUME_NONNULL_BEGIN

/* The two types of iOS 17, declared as the SDK's own OS_OBJECT_DECL would declare them: a release
   that has Network defines both of them as a protocol and a typedef. The SDK this port compiles
   against is 16.4, which predates them and has no proxy_config.h at all, so the port declares them
   itself; an SDK new enough to have that header declares them itself and must not be declared twice,
   which is what the test is for. */
/* The base every object of this library has, chosen the way the SDK chooses it.
 *
 * Above iOS 6.0 the SDK's own spelling (nw_object.h:28) is OS_OBJECT_DECL: an NSObject adopting the
 * protocol of the type, which is what these classes are and what every call of the API takes. Below
 * 6.0 the SDK's spelling (nw_object.h:32) is a plain C struct pointer with no protocol at all, and
 * `OS_nw_endpoint` and the rest of them are not declared by any header - so naming one here would be
 * inventing API Apple's own header deliberately does not have. The classes therefore take NSObject as
 * their base on that side, and the macro's argument is never expanded, so the undeclared protocol is
 * never named: which is the SDK's own answer, and the only one that is not an invention.
 *
 * The calls keep the types the SDK declares for that target, so a function defined here and a caller
 * of it agree on `struct nw_connection *` below 6.0 and on `NSObject<OS_nw_connection> *` above it,
 * and the casts between a port object and an nw_* one are the same explicit cast either way. */
#if OS_OBJECT_USE_OBJC
#define CHARON_NW_OBJECT(protocol) NSObject <protocol>
#else
#define CHARON_NW_OBJECT(protocol) NSObject
#endif

#if !__has_include(<Network/proxy_config.h>)
@protocol OS_nw_proxy_config <NSObject>
@end
@protocol OS_nw_relay_hop <NSObject>
@end
typedef CHARON_NW_OBJECT(OS_nw_proxy_config) *nw_proxy_config_t;
typedef CHARON_NW_OBJECT(OS_nw_relay_hop) *nw_relay_hop_t;
#endif



@class CharonNWEndpoint;
@class CharonNWParameters;
@class CharonNWProtocolDefinition;
@class CharonNWProtocolOptions;
@class CharonNWProtocolStack;
@class CharonNWTxtRecord;
@class CharonNWPrivacyContext;
@class CharonNWProxyConfig;
@class CharonNWRelayHop;
@class CharonNWResolverConfig;
@class CharonNWBrowseDescriptor;
@class CharonNWAdvertiseDescriptor;
@class CharonNWBrowser;
@class CharonNWBrowseResult;
@class CharonNWListener;
@class CharonNWConnection;
@class CharonNWConnectionGroup;
@class CharonNWGroupDescriptor;
@class CharonNWFramer;
@class CharonNWSecProtocol;
@class CharonNWWebSocketRequest;
@class CharonNWWebSocketResponse;
@class CharonNWEthernetChannel;

/* An endpoint. The release keeps a host, a port, a URL, a Bonjour service and a socket address in
   one object, and answers only the accessors of the type it holds: a host endpoint has no address,
   an address endpoint no host name. */
@interface CharonNWEndpoint : CHARON_NW_OBJECT(OS_nw_endpoint) {
@public
    nw_endpoint_type_t _type;
    NSString *_hostname;
    NSString *_port;
    NSString *_url;
    NSString *_bonjourName;
    NSString *_bonjourType;
    NSString *_bonjourDomain;
    NSData *_address;
    NSData *_signature;
    CharonNWTxtRecord *_txtRecord;
}
@end

/* The identity of a protocol: which protocol it is, and for a framer the name the program gave it
   and the flags it was created with. The built-in protocols each have one definition for the whole
   process, and `nw_protocol_definition_is_equal` says two are the same when they name the same
   protocol the same way. */
@interface CharonNWProtocolDefinition : CHARON_NW_OBJECT(OS_nw_protocol_definition) {
@public
    NSString *_family;
    NSString *_identifier;
    uint32_t _flags;
    id _payload;
}
@end

/* What a connection is told about one protocol of its stack. The settings are kept by the name the
   SDK's own setter for each of them uses, so the connection reads back exactly what the program
   set, and a setting nobody set reads as the default its getter documents. */
@interface CharonNWProtocolOptions : CHARON_NW_OBJECT(OS_nw_protocol_options) {
@public
    CharonNWProtocolDefinition *_definition;
    NSMutableDictionary *_values;
    NSMutableDictionary *_objects;
}
@end

/* What is known about a protocol on a connection that is up: which protocol it is, and what that
   protocol has to say about the message - the service class and the ECN flag of an IP packet, the
   opcode and the close code of a WebSocket frame, the stream a QUIC message belongs to. A framer's
   message is one of these too, which is what nw_framer_message_t is a typedef of. */
@interface CharonNWProtocolMetadata : CHARON_NW_OBJECT(OS_nw_protocol_metadata) {
@public
    CharonNWProtocolDefinition *_definition;
    NSMutableDictionary *_values;
    NSMutableDictionary *_objects;
}
@end

/* An error, as the state handler and the failed-handler of a framer are given it: the domain of
   Network's own errors and the code inside it. */
@interface CharonNWError : CHARON_NW_OBJECT(OS_nw_error) {
@public
    nw_error_domain_t _domain;
    int _code;
}
@end

/* What a piece of content is: the name a program gave it, how soon it matters, when it stops
   mattering, whether it is the last of a message, and what each protocol of the stack is told
   about it. */
@interface CharonNWContentContext : CHARON_NW_OBJECT(OS_nw_content_context) {
@public
    NSString *_identifier;
    double _relativePriority;
    uint64_t _expirationMilliseconds;
    bool _isFinal;
    CharonNWContentContext *_antecedent;
    NSMutableDictionary *_metadata;
}
@end

/* The stack: the internet protocol, the transport protocol, and the application protocols above
   them, outermost first - the order `nw_protocol_stack_iterate_application_protocols` walks. */
@interface CharonNWProtocolStack : CHARON_NW_OBJECT(OS_nw_protocol_stack) {
@public
    CharonNWProtocolOptions *_internet;
    CharonNWProtocolOptions *_transport;
    NSMutableArray *_application;
}
@end

@interface CharonNWParameters : CHARON_NW_OBJECT(OS_nw_parameters) {
@public
    CharonNWProtocolStack *_stack;
    CharonNWEndpoint *_localEndpoint;
    id _requiredInterface;
    nw_interface_type_t _requiredInterfaceType;
    NSMutableArray *_prohibitedInterfaces;
    NSMutableArray *_prohibitedInterfaceTypes;
    BOOL _localOnly;
    BOOL _prohibitExpensive;
    BOOL _prohibitConstrained;
    BOOL _fastOpenEnabled;
    BOOL _includePeerToPeer;
    BOOL _reuseLocalAddress;
    BOOL _preferNoProxy;
    BOOL _allowUltraConstrained;
    BOOL _requiresDNSSEC;
    nw_service_class_t _serviceClass;
    nw_multipath_service_t _multipathService;
    nw_parameters_expired_dns_behavior_t _expiredDNSBehavior;
    nw_parameters_attribution_t _attribution;
    CharonNWPrivacyContext *_privacyContext;
    NSString *_applicationService;
}
@end

/* A DNS-SD TXT record: the key-value pairs of a Bonjour service, kept in the order they arrived. */
@interface CharonNWTxtRecord : CHARON_NW_OBJECT(OS_nw_txt_record) {
@public
    NSMutableArray *_keys;
    NSMutableArray *_values;
    BOOL _dictionary;
}
@end

@interface CharonNWRelayHop : CHARON_NW_OBJECT(OS_nw_relay_hop) {
@public
    CharonNWEndpoint *_http3;
    CharonNWEndpoint *_http2;
    CharonNWProtocolOptions *_tls;
    NSMutableArray *_headerNames;
    NSMutableArray *_headerValues;
}
@end

@interface CharonNWProxyConfig : CHARON_NW_OBJECT(OS_nw_proxy_config) {
@public
    NSString *_kind;
    CharonNWEndpoint *_endpoint;
    CharonNWProtocolOptions *_tls;
    CharonNWRelayHop *_firstHop;
    CharonNWRelayHop *_secondHop;
    NSString *_relayResourcePath;
    NSData *_gatewayKeyConfig;
    NSString *_username;
    NSString *_password;
    BOOL _failoverAllowed;
    NSMutableArray *_matchDomains;
    NSMutableArray *_excludedDomains;
}
@end

@interface CharonNWPrivacyContext : CHARON_NW_OBJECT(OS_nw_privacy_context) {
@public
    NSString *_description;
    BOOL _loggingDisabled;
    BOOL _requireEncrypted;
    CharonNWResolverConfig *_fallbackResolver;
    NSMutableArray *_proxies;
}
@end

@interface CharonNWResolverConfig : CHARON_NW_OBJECT(OS_nw_resolver_config) {
@public
    NSString *_kind;
    CharonNWEndpoint *_endpoint;
    NSMutableArray *_servers;
}
@end

@interface CharonNWBrowseDescriptor : CHARON_NW_OBJECT(OS_nw_browse_descriptor) {
@public
    NSString *_bonjourType;
    NSString *_bonjourDomain;
    NSString *_applicationService;
    BOOL _includeTxtRecord;
}
@end

@interface CharonNWAdvertiseDescriptor : CHARON_NW_OBJECT(OS_nw_advertise_descriptor) {
@public
    NSString *_bonjourName;
    NSString *_bonjourType;
    NSString *_bonjourDomain;
    NSString *_applicationService;
    BOOL _noAutoRename;
    NSData *_txtRecord;
    CharonNWTxtRecord *_txtRecordObject;
}
@end

@interface CharonNWBrowseResult : CHARON_NW_OBJECT(OS_nw_browse_result) {
@public
    NSString *_name;
    NSString *_type;
    NSString *_domain;
    CharonNWEndpoint *_endpoint;
    CharonNWTxtRecord *_txtRecord;
    NSMutableArray *_interfaces;
}
@end

@interface CharonNWGroupDescriptor : CHARON_NW_OBJECT(OS_nw_group_descriptor) {
@public
    NSString *_kind;
    CharonNWEndpoint *_multicastGroup;
    CharonNWEndpoint *_remoteEndpoint;
    CharonNWEndpoint *_specificSource;
    NSMutableArray *_endpoints;
    BOOL _disableUnicastTraffic;
}
@end

/* The framer's own state. A framer is a program's protocol: it is handed bytes and hands bytes
   back, and everything it needs between the two calls is here. */
@interface CharonNWFramer : CHARON_NW_OBJECT(OS_nw_framer) {
@public
    CharonNWProtocolDefinition *_definition;
    CharonNWProtocolOptions *_options;
    CharonNWParameters *_parameters;
    CharonNWEndpoint *_localEndpoint;
    CharonNWEndpoint *_remoteEndpoint;
    nw_framer_start_handler_t _startHandler;
    nw_framer_input_handler_t _inputHandler;
    nw_framer_output_handler_t _outputHandler;
    nw_framer_stop_handler_t _stopHandler;
    nw_framer_cleanup_handler_t _cleanupHandler;
    nw_framer_wakeup_handler_t _wakeupHandler;
    dispatch_queue_t _queue;
    BOOL _ready;
    BOOL _failed;
    int _errorCode;
    BOOL _inputPassThrough;
    BOOL _outputPassThrough;
    BOOL _outputPassThroughPending;
    NSMutableData *_input;
    NSMutableData *_output;
    NSMutableArray *_delivered;
    NSMutableArray *_pendingWakeups;
    uint64_t _wakeupGeneration;
}
@end

/* The WebSocket handshake's request and response: the headers and the subprotocols of each side. */
@interface CharonNWWebSocketRequest : CHARON_NW_OBJECT(OS_nw_ws_request) {
@public
    NSMutableArray *_subprotocols;
    NSMutableArray *_headerNames;
    NSMutableArray *_headerValues;
}
@end

@interface CharonNWWebSocketResponse : CHARON_NW_OBJECT(OS_nw_ws_response) {
@public
    nw_ws_response_status_t _status;
    NSString *_selectedSubprotocol;
    NSMutableArray *_headerNames;
    NSMutableArray *_headerValues;
}
@end

/* What a connection measured while it was being established: how long it took, how many attempts
   came before it, the protocols of the stack, and the addresses that were tried. Filled in by the
   connection from its own state machine, and read back by the block of
   nw_connection_access_establishment_report. */
@interface CharonNWEstablishmentReport : CHARON_NW_OBJECT(OS_nw_establishment_report) {
@public
    uint64_t _durationMilliseconds;
    uint64_t _attemptStartedAfterMilliseconds;
    uint32_t _previousAttemptCount;
    BOOL _proxyConfigured;
    BOOL _usedProxy;
    CharonNWEndpoint *_proxyEndpoint;
    NSMutableArray *_protocols;
    NSMutableArray *_protocolHandshakeMilliseconds;
    NSMutableArray *_protocolHandshakeRTTMilliseconds;
    NSMutableArray *_resolutions;
    NSMutableArray *_resolutionReports;
}
@end

/* One resolution: the address a connection settled on, and the ones it did not, with how long each
   took and where the answer came from. */
@interface CharonNWResolutionReport : CHARON_NW_OBJECT(OS_nw_resolution_report) {
@public
    uint64_t _milliseconds;
    uint32_t _endpointCount;
    nw_report_resolution_protocol_t _protocol;
    nw_report_resolution_source_t _source;
    CharonNWEndpoint *_preferred;
    CharonNWEndpoint *_successful;
    NSMutableArray *_endpoints;
}
@end

/* What a connection moved while it was up. Pending until the block of
   nw_data_transfer_report_collect has been given it, and the byte counts, the RTTs and the state
   are 0 until then, as the header says they are for a report that is not collected. */
@interface CharonNWDataTransferReport : CHARON_NW_OBJECT(OS_nw_data_transfer_report) {
@public
    nw_data_transfer_report_state_t _state;
    uint64_t _durationMilliseconds;
    nw_interface_t _interface;
    nw_interface_radio_type_t _radioType;
    uint64_t _sentApplicationBytes;
    uint64_t _receivedApplicationBytes;
    uint64_t _sentTransportBytes;
    uint64_t _receivedTransportBytes;
    uint64_t _sentRetransmittedBytes;
    uint64_t _receivedDuplicateBytes;
    uint64_t _receivedOutOfOrderBytes;
    uint64_t _sentIPPackets;
    uint64_t _receivedIPPackets;
    uint64_t _smoothedRTTMilliseconds;
    uint64_t _minimumRTTMilliseconds;
    uint64_t _rttVarianceMilliseconds;
}
@end

/* sec_protocol_options_t and sec_protocol_metadata_t are Security.framework's own objects on a
   release that has them and are not declared at all below iOS 12, so the settings they hold are
   kept here and the release's own TLS calls are given a SecIdentity/SecTrust of their own. */
@interface CharonNWSecProtocol : NSObject {
@public
    NSMutableDictionary *_values;
    NSMutableArray *_applicationProtocols;
    NSString *_identityLabel;
    NSString *_label;
    BOOL _server;
    BOOL * _Nullable _verify;
    dispatch_queue_t _verifyQueue;
    BOOL _skipVerify;
    NSString *_peerName;
    NSNumber *_protocolVersion;
}
@end

/* What the files that cannot see a class's ivars ask it for. Each of these is defined in the one
   file that declares the class it belongs to, and the reason they exist is in that file: with the
   fragile ABI a class's ivar offsets are emitted by every file that sees its @interface, so a header
   the library's other files read would make the link see each of them twice. */
extern void CharonNWConnectionAttach(nw_connection_t connection, int handle, BOOL connected);
extern BOOL CharonNWConnectionTakeSocket(nw_connection_t connection, int *out_handle,
                                        void *out_endpoint, void *out_parameters);
extern void CharonNWListenerSetNewConnectionGroup(nw_listener_t listener,
                                                  nw_listener_new_connection_group_handler_t handler);
extern void CharonNWListenerSetNewConnectionLimit(nw_listener_t listener, uint32_t new_connection_limit);
extern uint32_t CharonNWListenerGetNewConnectionLimit(nw_listener_t listener);
extern BOOL CharonNWConnectionHasQueue(nw_connection_t connection);

NS_ASSUME_NONNULL_END
