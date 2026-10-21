#import <Foundation/Foundation.h>
#import <Network/Network.h>
#import <Security/Security.h>
#import <Security/SecureTransport.h>


#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"

NS_ASSUME_NONNULL_BEGIN

#if OS_OBJECT_USE_OBJC
#define REVENANT_NW_OBJECT(protocol) NSObject <protocol>
#else
#define REVENANT_NW_OBJECT(protocol) NSObject
#endif

#if !__has_include(<Network/proxy_config.h>)
@protocol OS_nw_proxy_config <NSObject>
@end
@protocol OS_nw_relay_hop <NSObject>
@end
typedef REVENANT_NW_OBJECT(OS_nw_proxy_config) *nw_proxy_config_t;
typedef REVENANT_NW_OBJECT(OS_nw_relay_hop) *nw_relay_hop_t;
#endif



@class RevenantNWEndpoint;
@class RevenantNWParameters;
@class RevenantNWProtocolDefinition;
@class RevenantNWProtocolOptions;
@class RevenantNWProtocolStack;
@class RevenantNWTxtRecord;
@class RevenantNWPrivacyContext;
@class RevenantNWProxyConfig;
@class RevenantNWRelayHop;
@class RevenantNWResolverConfig;
@class RevenantNWBrowseDescriptor;
@class RevenantNWAdvertiseDescriptor;
@class RevenantNWBrowser;
@class RevenantNWBrowseResult;
@class RevenantNWListener;
@class RevenantNWConnection;
@class RevenantNWConnectionGroup;
@class RevenantNWGroupDescriptor;
@class RevenantNWFramer;
@class RevenantNWSecProtocol;
@class RevenantNWWebSocketRequest;
@class RevenantNWWebSocketResponse;
@class RevenantNWEthernetChannel;

@interface RevenantNWEndpoint : REVENANT_NW_OBJECT(OS_nw_endpoint) {
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
    RevenantNWTxtRecord *_txtRecord;
}
@end

@interface RevenantNWProtocolDefinition : REVENANT_NW_OBJECT(OS_nw_protocol_definition) {
@public
    NSString *_family;
    NSString *_identifier;
    uint32_t _flags;
    id _payload;
}
@end

@interface RevenantNWProtocolOptions : REVENANT_NW_OBJECT(OS_nw_protocol_options) {
@public
    RevenantNWProtocolDefinition *_definition;
    NSMutableDictionary *_values;
    NSMutableDictionary *_objects;
}
@end

@interface RevenantNWProtocolMetadata : REVENANT_NW_OBJECT(OS_nw_protocol_metadata) {
@public
    RevenantNWProtocolDefinition *_definition;
    NSMutableDictionary *_values;
    NSMutableDictionary *_objects;
}
@end

@interface RevenantNWError : REVENANT_NW_OBJECT(OS_nw_error) {
@public
    nw_error_domain_t _domain;
    int _code;
}
@end

@interface RevenantNWContentContext : REVENANT_NW_OBJECT(OS_nw_content_context) {
@public
    NSString *_identifier;
    double _relativePriority;
    uint64_t _expirationMilliseconds;
    bool _isFinal;
    RevenantNWContentContext *_antecedent;
    NSMutableDictionary *_metadata;
}
@end

@interface RevenantNWProtocolStack : REVENANT_NW_OBJECT(OS_nw_protocol_stack) {
@public
    RevenantNWProtocolOptions *_internet;
    RevenantNWProtocolOptions *_transport;
    NSMutableArray *_application;
}
@end

@interface RevenantNWParameters : REVENANT_NW_OBJECT(OS_nw_parameters) {
@public
    RevenantNWProtocolStack *_stack;
    RevenantNWEndpoint *_localEndpoint;
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
    RevenantNWPrivacyContext *_privacyContext;
    NSString *_applicationService;
}
@end

@interface RevenantNWTxtRecord : REVENANT_NW_OBJECT(OS_nw_txt_record) {
@public
    NSMutableArray *_keys;
    NSMutableArray *_values;
    BOOL _dictionary;
}
@end

@interface RevenantNWRelayHop : REVENANT_NW_OBJECT(OS_nw_relay_hop) {
@public
    RevenantNWEndpoint *_http3;
    RevenantNWEndpoint *_http2;
    RevenantNWProtocolOptions *_tls;
    NSMutableArray *_headerNames;
    NSMutableArray *_headerValues;
}
@end

@interface RevenantNWProxyConfig : REVENANT_NW_OBJECT(OS_nw_proxy_config) {
@public
    NSString *_kind;
    RevenantNWEndpoint *_endpoint;
    RevenantNWProtocolOptions *_tls;
    RevenantNWRelayHop *_firstHop;
    RevenantNWRelayHop *_secondHop;
    NSString *_relayResourcePath;
    NSData *_gatewayKeyConfig;
    NSString *_username;
    NSString *_password;
    BOOL _failoverAllowed;
    NSMutableArray *_matchDomains;
    NSMutableArray *_excludedDomains;
}
@end

@interface RevenantNWPrivacyContext : REVENANT_NW_OBJECT(OS_nw_privacy_context) {
@public
    NSString *_description;
    BOOL _loggingDisabled;
    BOOL _requireEncrypted;
    RevenantNWResolverConfig *_fallbackResolver;
    NSMutableArray *_proxies;
}
@end

@interface RevenantNWResolverConfig : REVENANT_NW_OBJECT(OS_nw_resolver_config) {
@public
    NSString *_kind;
    RevenantNWEndpoint *_endpoint;
    NSMutableArray *_servers;
}
@end

@interface RevenantNWBrowseDescriptor : REVENANT_NW_OBJECT(OS_nw_browse_descriptor) {
@public
    NSString *_bonjourType;
    NSString *_bonjourDomain;
    NSString *_applicationService;
    BOOL _includeTxtRecord;
}
@end

@interface RevenantNWAdvertiseDescriptor : REVENANT_NW_OBJECT(OS_nw_advertise_descriptor) {
@public
    NSString *_bonjourName;
    NSString *_bonjourType;
    NSString *_bonjourDomain;
    NSString *_applicationService;
    BOOL _noAutoRename;
    NSData *_txtRecord;
    RevenantNWTxtRecord *_txtRecordObject;
}
@end

@interface RevenantNWBrowseResult : REVENANT_NW_OBJECT(OS_nw_browse_result) {
@public
    NSString *_name;
    NSString *_type;
    NSString *_domain;
    RevenantNWEndpoint *_endpoint;
    RevenantNWTxtRecord *_txtRecord;
    NSMutableArray *_interfaces;
}
@end

@interface RevenantNWGroupDescriptor : REVENANT_NW_OBJECT(OS_nw_group_descriptor) {
@public
    NSString *_kind;
    RevenantNWEndpoint *_multicastGroup;
    RevenantNWEndpoint *_remoteEndpoint;
    RevenantNWEndpoint *_specificSource;
    NSMutableArray *_endpoints;
    BOOL _disableUnicastTraffic;
}
@end

@interface RevenantNWFramer : REVENANT_NW_OBJECT(OS_nw_framer) {
@public
    RevenantNWProtocolDefinition *_definition;
    RevenantNWProtocolOptions *_options;
    RevenantNWParameters *_parameters;
    RevenantNWEndpoint *_localEndpoint;
    RevenantNWEndpoint *_remoteEndpoint;
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

@interface RevenantNWWebSocketRequest : REVENANT_NW_OBJECT(OS_nw_ws_request) {
@public
    NSMutableArray *_subprotocols;
    NSMutableArray *_headerNames;
    NSMutableArray *_headerValues;
}
@end

@interface RevenantNWWebSocketResponse : REVENANT_NW_OBJECT(OS_nw_ws_response) {
@public
    nw_ws_response_status_t _status;
    NSString *_selectedSubprotocol;
    NSMutableArray *_headerNames;
    NSMutableArray *_headerValues;
}
@end

@interface RevenantNWEstablishmentReport : REVENANT_NW_OBJECT(OS_nw_establishment_report) {
@public
    uint64_t _durationMilliseconds;
    uint64_t _attemptStartedAfterMilliseconds;
    uint32_t _previousAttemptCount;
    BOOL _proxyConfigured;
    BOOL _usedProxy;
    RevenantNWEndpoint *_proxyEndpoint;
    NSMutableArray *_protocols;
    NSMutableArray *_protocolHandshakeMilliseconds;
    NSMutableArray *_protocolHandshakeRTTMilliseconds;
    NSMutableArray *_resolutions;
    NSMutableArray *_resolutionReports;
}
@end

@interface RevenantNWResolutionReport : REVENANT_NW_OBJECT(OS_nw_resolution_report) {
@public
    uint64_t _milliseconds;
    uint32_t _endpointCount;
    nw_report_resolution_protocol_t _protocol;
    nw_report_resolution_source_t _source;
    RevenantNWEndpoint *_preferred;
    RevenantNWEndpoint *_successful;
    NSMutableArray *_endpoints;
}
@end

@interface RevenantNWDataTransferReport : REVENANT_NW_OBJECT(OS_nw_data_transfer_report) {
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

@interface RevenantNWSecProtocol : NSObject {
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

extern void RevenantNWConnectionAttach(nw_connection_t connection, int handle, BOOL connected);
extern BOOL RevenantNWConnectionTakeSocket(nw_connection_t connection, int *out_handle,
                                        void *out_endpoint, void *out_parameters);
extern void RevenantNWListenerSetNewConnectionGroup(nw_listener_t listener,
                                                  nw_listener_new_connection_group_handler_t handler);
extern void RevenantNWListenerSetNewConnectionLimit(nw_listener_t listener, uint32_t new_connection_limit);
extern uint32_t RevenantNWListenerGetNewConnectionLimit(nw_listener_t listener);
extern BOOL RevenantNWConnectionHasQueue(nw_connection_t connection);

NS_ASSUME_NONNULL_END
