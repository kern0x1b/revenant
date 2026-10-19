#import <Foundation/Foundation.h>
#import <Network/Network.h>
#import <Security/Security.h>
#import <Security/SecureTransport.h>


#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"

NS_ASSUME_NONNULL_BEGIN

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

@interface CharonNWProtocolDefinition : CHARON_NW_OBJECT(OS_nw_protocol_definition) {
@public
    NSString *_family;
    NSString *_identifier;
    uint32_t _flags;
    id _payload;
}
@end

@interface CharonNWProtocolOptions : CHARON_NW_OBJECT(OS_nw_protocol_options) {
@public
    CharonNWProtocolDefinition *_definition;
    NSMutableDictionary *_values;
    NSMutableDictionary *_objects;
}
@end

@interface CharonNWProtocolMetadata : CHARON_NW_OBJECT(OS_nw_protocol_metadata) {
@public
    CharonNWProtocolDefinition *_definition;
    NSMutableDictionary *_values;
    NSMutableDictionary *_objects;
}
@end

@interface CharonNWError : CHARON_NW_OBJECT(OS_nw_error) {
@public
    nw_error_domain_t _domain;
    int _code;
}
@end

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

extern void CharonNWConnectionAttach(nw_connection_t connection, int handle, BOOL connected);
extern BOOL CharonNWConnectionTakeSocket(nw_connection_t connection, int *out_handle,
                                        void *out_endpoint, void *out_parameters);
extern void CharonNWListenerSetNewConnectionGroup(nw_listener_t listener,
                                                  nw_listener_new_connection_group_handler_t handler);
extern void CharonNWListenerSetNewConnectionLimit(nw_listener_t listener, uint32_t new_connection_limit);
extern uint32_t CharonNWListenerGetNewConnectionLimit(nw_listener_t listener);
extern BOOL CharonNWConnectionHasQueue(nw_connection_t connection);

NS_ASSUME_NONNULL_END
