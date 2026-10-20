#import <Foundation/Foundation.h>
#import <Security/SecIdentity.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, NEHotspotNetworkSecurityType) {
    NEHotspotNetworkSecurityTypeOpen = 0,
    NEHotspotNetworkSecurityTypeWEP = 1,
    NEHotspotNetworkSecurityTypePersonal = 2,
    NEHotspotNetworkSecurityTypeEnterprise = 3,
    NEHotspotNetworkSecurityTypeUnknown = 4
};

typedef NS_ENUM(NSInteger, NEHotspotHelperConfidence) {
    kNEHotspotHelperConfidenceNone = 0,
    kNEHotspotHelperConfidenceLow = 1,
    kNEHotspotHelperConfidenceHigh = 2,
};

@interface NEHotspotNetwork : NSObject
@property (readonly, nullable) NSString *SSID;
@property (readonly, nullable) NSString *BSSID;
@property (readonly) NEHotspotNetworkSecurityType securityType;
+ (void)fetchCurrentWithCompletionHandler:(void (^)(NEHotspotNetwork * __nullable currentNetwork))completionHandler;
@end

@interface NEHotspotNetwork (HotspotHelper)
@property (readonly) double signalStrength;
@property (readonly, getter=isSecure) BOOL secure;
@property (readonly, getter=didAutoJoin) BOOL autoJoined;
@property (readonly, getter=didJustJoin) BOOL justJoined;
@property (readonly, getter=isChosenHelper) BOOL chosenHelper;
- (void)setConfidence:(NEHotspotHelperConfidence)confidence;
- (void)setPassword:(NSString *)password;
@end

typedef NS_ENUM(NSInteger, NEHotspotConfigurationEAPType) {
    NEHotspotConfigurationEAPTypeEAPTLS = 13,
    NEHotspotConfigurationEAPTypeEAPTTLS = 21,
    NEHotspotConfigurationEAPTypeEAPPEAP = 25,
    NEHotspotConfigurationEAPTypeEAPFAST = 43
};

typedef NS_ENUM(NSInteger, NEHotspotConfigurationTTLSInnerAuthenticationType) {
    NEHotspotConfigurationEAPTTLSInnerAuthenticationPAP = 0,
    NEHotspotConfigurationEAPTTLSInnerAuthenticationCHAP = 1,
    NEHotspotConfigurationEAPTTLSInnerAuthenticationMSCHAP = 2,
    NEHotspotConfigurationEAPTTLSInnerAuthenticationMSCHAPv2 = 3,
    NEHotspotConfigurationEAPTTLSInnerAuthenticationEAP = 4
};

typedef NS_ENUM(NSInteger, NEHotspotConfigurationEAPTLSVersion) {
    NEHotspotConfigurationEAPTLSVersion_1_0 = 0,
    NEHotspotConfigurationEAPTLSVersion_1_1 = 1,
    NEHotspotConfigurationEAPTLSVersion_1_2 = 2,
};

@interface NEHotspotHS20Settings : NSObject <NSCopying, NSSecureCoding>
@property (readonly) NSString *domainName;
@property (getter=isRoamingEnabled) BOOL roamingEnabled;
@property (copy, nullable) NSArray<NSString *> *roamingConsortiumOIs;
@property (copy, nullable) NSArray<NSString *> *naiRealmNames;
@property (copy, nullable) NSArray<NSString *> *MCCAndMNCs;
- (instancetype)initWithDomainName:(NSString *)domainName roamingEnabled:(BOOL)roamingEnabled;
@end

@interface NEHotspotEAPSettings : NSObject <NSCopying, NSSecureCoding>
@property (copy, nullable) NSArray<NSNumber *> *supportedEAPTypes;
@property (copy, nullable) NSString *username;
@property (copy, nullable) NSString *outerIdentity;
@property NEHotspotConfigurationTTLSInnerAuthenticationType ttlsInnerAuthenticationType;
@property (copy, nullable) NSString *password;
@property (copy, nullable) NSArray<NSString *> *trustedServerNames;
@property (getter=isTLSClientCertificateRequired) BOOL tlsClientCertificateRequired;
@property NEHotspotConfigurationEAPTLSVersion preferredTLSVersion;
- (BOOL)setIdentity:(SecIdentityRef)identity;
- (BOOL)setTrustedServerCertificates:(NSArray *)certificates;
@end

@interface NEHotspotConfiguration : NSObject <NSCopying, NSSecureCoding>
@property (readonly, nullable) NSString *SSID;
@property (readonly, nullable) NSString *SSIDPrefix;
@property BOOL joinOnce;
@property (copy, nullable) NSNumber *lifeTimeInDays;
@property BOOL hidden;
- (instancetype)initWithSSID:(NSString *)SSID;
- (instancetype)initWithSSID:(NSString *)SSID passphrase:(NSString *)passphrase isWEP:(BOOL)isWEP;
- (instancetype)initWithSSIDPrefix:(NSString *)SSIDPrefix;
- (instancetype)initWithSSIDPrefix:(NSString *)SSIDPrefix passphrase:(NSString *)passphrase isWEP:(BOOL)isWEP;
- (instancetype)initWithSSID:(NSString *)SSID eapSettings:(NEHotspotEAPSettings *)eapSettings;
- (instancetype)initWithHS20Settings:(NEHotspotHS20Settings *)hs20Settings eapSettings:(NEHotspotEAPSettings *)eapSettings;
@end

typedef NS_ENUM(NSInteger, NEHotspotConfigurationError) {
    NEHotspotConfigurationErrorInvalid = 0,
    NEHotspotConfigurationErrorInvalidSSID = 1,
    NEHotspotConfigurationErrorInvalidWPAPassphrase = 2,
    NEHotspotConfigurationErrorInvalidWEPPassphrase = 3,
    NEHotspotConfigurationErrorInvalidEAPSettings = 4,
    NEHotspotConfigurationErrorInvalidHS20Settings = 5,
    NEHotspotConfigurationErrorInvalidHS20DomainName = 6,
    NEHotspotConfigurationErrorUserDenied = 7,
    NEHotspotConfigurationErrorInternal = 8,
    NEHotspotConfigurationErrorPending = 9,
    NEHotspotConfigurationErrorSystemConfiguration = 10,
    NEHotspotConfigurationErrorUnknown = 11,
    NEHotspotConfigurationErrorJoinOnceNotSupported = 12,
    NEHotspotConfigurationErrorAlreadyAssociated = 13,
    NEHotspotConfigurationErrorApplicationIsNotInForeground = 14,
    NEHotspotConfigurationErrorInvalidSSIDPrefix = 15,
    NEHotspotConfigurationErrorUserUnauthorized = 16,
    NEHotspotConfigurationErrorSystemDenied = 17,
};

extern NSString *const NEHotspotConfigurationErrorDomain;

@interface NEHotspotConfigurationManager : NSObject
@property (class, readonly, strong) NEHotspotConfigurationManager *sharedManager;
- (void)applyConfiguration:(NEHotspotConfiguration *)configuration completionHandler:(void (^)(NSError * __nullable error))completionHandler;
- (void)removeConfigurationForSSID:(NSString *)SSID;
- (void)removeConfigurationForHS20DomainName:(NSString *)domainName;
- (void)getConfiguredSSIDsWithCompletionHandler:(void (^)(NSArray<NSString *> * __nullable ssids))completionHandler;
@end

typedef NS_ENUM(NSInteger, NEHotspotHelperCommandType) {
    kNEHotspotHelperCommandTypeNone = 0,
    kNEHotspotHelperCommandTypeFilterScanList = 1,
    kNEHotspotHelperCommandTypeEvaluate = 2,
    kNEHotspotHelperCommandTypeAuthenticate = 3,
    kNEHotspotHelperCommandTypePresentUI = 4,
    kNEHotspotHelperCommandTypeMaintain = 5,
    kNEHotspotHelperCommandTypeLogoff = 6,
};

typedef NS_ENUM(NSInteger, NEHotspotHelperResult) {
    kNEHotspotHelperResultSuccess = 0,
    kNEHotspotHelperResultFailure = 1,
    kNEHotspotHelperResultUIRequired = 2,
    kNEHotspotHelperResultCommandNotRecognized = 3,
    kNEHotspotHelperResultAuthenticationRequired = 4,
    kNEHotspotHelperResultUnsupportedNetwork = 5,
    kNEHotspotHelperResultTemporaryFailure = 6,
};

@class NEHotspotHelperCommand;
@class NEHotspotHelperResponse;
@class NWEndpoint;
@class NWTCPConnection;
@class NWUDPSession;

typedef void (^NEHotspotHelperHandler)(NEHotspotHelperCommand *command);

@interface NEHotspotHelper : NSObject
+ (BOOL)registerWithOptions:(NSDictionary<NSString *, NSObject *> * __nullable)options queue:(dispatch_queue_t)queue handler:(NEHotspotHelperHandler)handler;
+ (BOOL)logoff:(NEHotspotNetwork *)network;
+ (nullable NSArray *)supportedNetworkInterfaces;
@end

@interface NEHotspotHelperCommand : NSObject
@property (readonly) NEHotspotHelperCommandType commandType;
@property (readonly, nullable) NEHotspotNetwork *network;
@property (readonly, nullable) NSArray<NEHotspotNetwork *> *networkList;
- (nullable NEHotspotHelperResponse *)createResponse:(NEHotspotHelperResult)result;
- (nullable NWTCPConnection *)createTCPConnection:(NWEndpoint *)endpoint;
- (nullable NWUDPSession *)createUDPSession:(NWEndpoint *)endpoint;
@end

@interface NEHotspotHelperResponse : NSObject
- (void)setNetwork:(NEHotspotNetwork *)network;
- (void)setNetworkList:(NSArray<NEHotspotNetwork *> *)networkList;
- (void)deliver;
@end

@interface NSMutableURLRequest (HotspotHelper)
- (void)bindToHotspotHelperCommand:(NEHotspotHelperCommand *)command;
@end

NS_ASSUME_NONNULL_END
