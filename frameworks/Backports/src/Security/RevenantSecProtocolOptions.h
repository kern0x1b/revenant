#import <Foundation/Foundation.h>
#import <Security/CipherSuite.h>
#import <Security/SecIdentity.h>
#import <Security/SecProtocolOptions.h>
#import <Security/SecProtocolTypes.h>
#import <Security/SecureTransport.h>
#import <dispatch/dispatch.h>

NS_ASSUME_NONNULL_BEGIN

__attribute__((visibility("default")))
@interface RevenantSecProtocolOptions : NSObject <OS_sec_protocol_options>

@property (nonatomic) uint16_t minTLSVersion;
@property (nonatomic) uint16_t maxTLSVersion;
@property (nonatomic, nullable) NSString *serverName;
@property (nonatomic) NSMutableArray<NSString *> *applicationProtocols;
@property (nonatomic) BOOL peerAuthenticationRequired;
@property (nonatomic, nullable) sec_identity_t localIdentity;
- (nullable SecIdentityRef)revenantCopyIdentityRef CF_RETURNS_RETAINED;
- (NSArray<NSNumber *> *)revenantCiphersuiteGroups;
- (nullable const char *)revenantUnsupportedSettingForServer:(BOOL)server;
- (NSUInteger)revenantCopyData:(NSInteger)kind index:(NSUInteger)index into:(nullable void *)buffer capacity:(NSUInteger)capacity;
- (BOOL)revenantVerifyTrust:(SecTrustRef)trust;
- (nullable SecIdentityRef)revenantChallengeIdentity CF_RETURNS_RETAINED;

@property (nonatomic) BOOL ticketsEnabled;
@property (nonatomic) BOOL fallbackAttempt;
@property (nonatomic) BOOL resumptionEnabled;
@property (nonatomic) BOOL falseStartEnabled;
@property (nonatomic) BOOL ocspEnabled;
@property (nonatomic) BOOL sctEnabled;
@property (nonatomic) BOOL renegotiationEnabled;

@property (nonatomic) NSMutableArray<NSNumber *> *ciphersuites;
@property (nonatomic, nullable) NSNumber *ciphersuiteGroup;
@property (nonatomic) NSMutableArray<NSNumber *> *ciphersuiteGroups;

@property (nonatomic, nullable) dispatch_data_t diffieHellmanParameters;
@property (nonatomic) NSMutableArray *preSharedKeys;
@property (nonatomic) NSMutableArray *preSharedKeyIdentities;
@property (nonatomic, nullable) dispatch_data_t preSharedKeyIdentityHint;
@property (nonatomic, nullable) sec_protocol_pre_shared_key_selection_t preSharedKeySelection;
@property (nonatomic, nullable) dispatch_queue_t preSharedKeySelectionQueue;

@property (nonatomic, nullable) sec_protocol_key_update_t keyUpdateBlock;
@property (nonatomic, nullable) dispatch_queue_t keyUpdateQueue;
@property (nonatomic, nullable) sec_protocol_challenge_t challengeBlock;
@property (nonatomic, nullable) dispatch_queue_t challengeQueue;
@property (nonatomic, nullable) sec_protocol_verify_t verifyBlock;
@property (nonatomic, nullable) dispatch_queue_t verifyQueue;

@end

NS_ASSUME_NONNULL_END
