#import "RevenantSecProtocolOptions.h"
#import "RevenantSecProtocolMetadata.h"

static RevenantSecProtocolOptions *RevenantOptions(sec_protocol_options_t options)
{
    return [options isKindOfClass:RevenantSecProtocolOptions.class] ? (RevenantSecProtocolOptions *)options : nil;
}

static BOOL RevenantTLSVersionForSSLProtocol(SSLProtocol protocol, tls_protocol_version_t *version)
{
    switch (protocol) {
    case kTLSProtocol1:
        *version = tls_protocol_version_TLSv10;
        return YES;
    case kTLSProtocol11:
        *version = tls_protocol_version_TLSv11;
        return YES;
    case kTLSProtocol12:
        *version = tls_protocol_version_TLSv12;
        return YES;
    case kTLSProtocol13:
        *version = tls_protocol_version_TLSv13;
        return YES;
    default:
        return NO;
    }
}

@implementation RevenantSecProtocolOptions

@synthesize minTLSVersion = _minTLSVersion, maxTLSVersion = _maxTLSVersion;
@synthesize serverName = _serverName, applicationProtocols = _applicationProtocols;
@synthesize peerAuthenticationRequired = _peerAuthenticationRequired, localIdentity = _localIdentity;
@synthesize ticketsEnabled = _ticketsEnabled, fallbackAttempt = _fallbackAttempt;
@synthesize resumptionEnabled = _resumptionEnabled, falseStartEnabled = _falseStartEnabled;
@synthesize ocspEnabled = _ocspEnabled, sctEnabled = _sctEnabled, renegotiationEnabled = _renegotiationEnabled;
@synthesize ciphersuites = _ciphersuites, ciphersuiteGroup = _ciphersuiteGroup, ciphersuiteGroups = _ciphersuiteGroups;
@synthesize diffieHellmanParameters = _diffieHellmanParameters;
@synthesize preSharedKeys = _preSharedKeys, preSharedKeyIdentities = _preSharedKeyIdentities;
@synthesize preSharedKeyIdentityHint = _preSharedKeyIdentityHint;
@synthesize preSharedKeySelection = _preSharedKeySelection, preSharedKeySelectionQueue = _preSharedKeySelectionQueue;
@synthesize keyUpdateBlock = _keyUpdateBlock, keyUpdateQueue = _keyUpdateQueue;
@synthesize challengeBlock = _challengeBlock, challengeQueue = _challengeQueue;
@synthesize verifyBlock = _verifyBlock, verifyQueue = _verifyQueue;

- (SecIdentityRef)revenantCopyIdentityRef
{
    return self.localIdentity ? sec_identity_copy_ref(self.localIdentity) : NULL;
}

- (NSArray<NSNumber *> *)revenantCiphersuiteGroups
{
    NSMutableArray<NSNumber *> *groups = [NSMutableArray array];
    if (self.ciphersuiteGroup)
        [groups addObject:self.ciphersuiteGroup];
    [groups addObjectsFromArray:self.ciphersuiteGroups];
    return groups;
}

- (const char *)revenantUnsupportedSettingForServer:(BOOL)server
{
    if (self.diffieHellmanParameters)
        return "DHE parameters are unsupported: BoringSSL removed finite-field Diffie-Hellman";
    if (self.preSharedKeySelection)
        return "pre-shared-key selection blocks are unsupported: BoringSSL has no PSK selection callback";
    if (self.preSharedKeys.count > 0 && self.maxTLSVersion >= tls_protocol_version_TLSv13)
        return "pre-shared keys need TLS 1.2 as the maximum: BoringSSL has no TLS 1.3 external PSK callback";
    if (server && self.challengeBlock)
        return "challenge blocks are unsupported on a server: they answer client certificate requests";
    if (server && (self.ocspEnabled || self.sctEnabled))
        return "OCSP and SCT are unsupported on a server: they are client-side requests";
    return NULL;
}

static NSData *RevenantDispatchDataBytes(dispatch_data_t data)
{
    NSMutableData *bytes = [NSMutableData data];
    dispatch_data_apply(data, ^bool(dispatch_data_t region, size_t offset, const void *buffer, size_t size) {
        (void)region;
        (void)offset;
        [bytes appendBytes:buffer length:size];
        return true;
    });
    return bytes;
}

- (NSUInteger)revenantCopyData:(NSInteger)kind index:(NSUInteger)index into:(void *)buffer capacity:(NSUInteger)capacity
{
    dispatch_data_t data = nil;
    if (kind == 0) {
        if (index < self.preSharedKeys.count)
            data = self.preSharedKeys[index];
    } else if (kind == 1) {
        if (index < self.preSharedKeyIdentities.count)
            data = self.preSharedKeyIdentities[index];
    } else {
        data = self.preSharedKeyIdentityHint;
    }
    if (!data)
        return 0;
    NSData *bytes = RevenantDispatchDataBytes(data);
    if (buffer && capacity >= bytes.length)
        memcpy(buffer, bytes.bytes, bytes.length);
    return bytes.length;
}

- (BOOL)revenantVerifyTrust:(SecTrustRef)trust
{
    sec_protocol_verify_t block = self.verifyBlock;
    if (!block)
        return NO;
    dispatch_queue_t queue = self.verifyQueue ?: dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    id metadata = [[RevenantSecProtocolMetadata alloc] init];
    sec_trust_t wrapped = sec_trust_create(trust);
    __block BOOL accepted = NO;
    dispatch_semaphore_t finished = dispatch_semaphore_create(0);
    dispatch_async(queue, ^{
        block((sec_protocol_metadata_t)metadata, wrapped, ^(bool result) {
            accepted = result;
            dispatch_semaphore_signal(finished);
        });
    });
    if (dispatch_semaphore_wait(finished, dispatch_time(DISPATCH_TIME_NOW, 30 * NSEC_PER_SEC)) != 0)
        return NO;
    return accepted;
}

- (SecIdentityRef)revenantChallengeIdentity
{
    sec_protocol_challenge_t block = self.challengeBlock;
    if (!block)
        return NULL;
    dispatch_queue_t queue = self.challengeQueue ?: dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    id metadata = [[RevenantSecProtocolMetadata alloc] init];
    __block SecIdentityRef identity = NULL;
    dispatch_semaphore_t finished = dispatch_semaphore_create(0);
    dispatch_async(queue, ^{
        block((sec_protocol_metadata_t)metadata, ^(sec_identity_t chosen) {
            if (chosen)
                identity = sec_identity_copy_ref(chosen);
            dispatch_semaphore_signal(finished);
        });
    });
    if (dispatch_semaphore_wait(finished, dispatch_time(DISPATCH_TIME_NOW, 30 * NSEC_PER_SEC)) != 0)
        return NULL;
    return identity;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _minTLSVersion = tls_protocol_version_TLSv12;
        _maxTLSVersion = tls_protocol_version_TLSv13;
        _applicationProtocols = [NSMutableArray array];
        _peerAuthenticationRequired = YES;
        _ciphersuites = [NSMutableArray array];
        _ciphersuiteGroups = [NSMutableArray array];
        _preSharedKeys = [NSMutableArray array];
        _preSharedKeyIdentities = [NSMutableArray array];
    }
    return self;
}

@end

tls_protocol_version_t sec_protocol_options_get_default_min_tls_protocol_version(void)
{
    return tls_protocol_version_TLSv12;
}

tls_protocol_version_t sec_protocol_options_get_default_min_dtls_protocol_version(void)
{
    return tls_protocol_version_DTLSv10;
}

tls_protocol_version_t sec_protocol_options_get_default_max_tls_protocol_version(void)
{
    return tls_protocol_version_TLSv13;
}

tls_protocol_version_t sec_protocol_options_get_default_max_dtls_protocol_version(void)
{
    return tls_protocol_version_DTLSv10;
}

bool sec_protocol_options_are_equal(sec_protocol_options_t optionsA, sec_protocol_options_t optionsB)
{
    RevenantSecProtocolOptions *a = RevenantOptions(optionsA);
    RevenantSecProtocolOptions *b = RevenantOptions(optionsB);
    if (!a || !b)
        return optionsA == optionsB;
    return a.minTLSVersion == b.minTLSVersion
        && a.maxTLSVersion == b.maxTLSVersion
        && a.peerAuthenticationRequired == b.peerAuthenticationRequired
        && (a.serverName == b.serverName || [a.serverName isEqualToString:b.serverName])
        && [a.applicationProtocols isEqualToArray:b.applicationProtocols];
}

void sec_protocol_options_set_min_tls_protocol_version(sec_protocol_options_t options,
                                                       tls_protocol_version_t version)
{
    RevenantOptions(options).minTLSVersion = version;
}

void sec_protocol_options_set_max_tls_protocol_version(sec_protocol_options_t options,
                                                       tls_protocol_version_t version)
{
    RevenantOptions(options).maxTLSVersion = version;
}

void sec_protocol_options_set_tls_min_version(sec_protocol_options_t options, SSLProtocol version)
{
    tls_protocol_version_t mapped;
    if (RevenantTLSVersionForSSLProtocol(version, &mapped))
        RevenantOptions(options).minTLSVersion = mapped;
}

void sec_protocol_options_set_tls_max_version(sec_protocol_options_t options, SSLProtocol version)
{
    tls_protocol_version_t mapped;
    if (RevenantTLSVersionForSSLProtocol(version, &mapped))
        RevenantOptions(options).maxTLSVersion = mapped;
}

void sec_protocol_options_set_tls_server_name(sec_protocol_options_t options, const char *server_name)
{
    RevenantOptions(options).serverName = server_name ? [NSString stringWithUTF8String:server_name] : nil;
}

void sec_protocol_options_add_tls_application_protocol(sec_protocol_options_t options,
                                                       const char *application_protocol)
{
    if (!application_protocol)
        return;
    [RevenantOptions(options).applicationProtocols addObject:[NSString stringWithUTF8String:application_protocol]];
}

void sec_protocol_options_set_local_identity(sec_protocol_options_t options, sec_identity_t identity)
{
    RevenantOptions(options).localIdentity = identity;
}

void sec_protocol_options_set_peer_authentication_required(sec_protocol_options_t options, bool required)
{
    RevenantOptions(options).peerAuthenticationRequired = required;
}

void sec_protocol_options_set_tls_tickets_enabled(sec_protocol_options_t options, bool ticketsEnabled)
{
    RevenantOptions(options).ticketsEnabled = ticketsEnabled;
}

void sec_protocol_options_set_tls_is_fallback_attempt(sec_protocol_options_t options, bool isFallback)
{
    RevenantOptions(options).fallbackAttempt = isFallback;
}

void sec_protocol_options_set_tls_resumption_enabled(sec_protocol_options_t options, bool enabled)
{
    RevenantOptions(options).resumptionEnabled = enabled;
}

void sec_protocol_options_set_tls_false_start_enabled(sec_protocol_options_t options, bool enabled)
{
    RevenantOptions(options).falseStartEnabled = enabled;
}

void sec_protocol_options_set_tls_ocsp_enabled(sec_protocol_options_t options, bool ocspEnabled)
{
    RevenantOptions(options).ocspEnabled = ocspEnabled;
}

void sec_protocol_options_set_tls_sct_enabled(sec_protocol_options_t options, bool sctEnabled)
{
    RevenantOptions(options).sctEnabled = sctEnabled;
}

void sec_protocol_options_set_tls_renegotiation_enabled(sec_protocol_options_t options, bool enabled)
{
    RevenantOptions(options).renegotiationEnabled = enabled;
}

void sec_protocol_options_add_tls_ciphersuite(sec_protocol_options_t options, SSLCipherSuite ciphersuite)
{
    [RevenantOptions(options).ciphersuites addObject:@(ciphersuite)];
}

void sec_protocol_options_append_tls_ciphersuite(sec_protocol_options_t options,
                                                 tls_ciphersuite_t ciphersuite)
{
    [RevenantOptions(options).ciphersuites addObject:@(ciphersuite)];
}

void sec_protocol_options_add_tls_ciphersuite_group(sec_protocol_options_t options,
                                                    SSLCiphersuiteGroup group)
{
    RevenantOptions(options).ciphersuiteGroup = @(group);
}

void sec_protocol_options_append_tls_ciphersuite_group(sec_protocol_options_t options,
                                                       tls_ciphersuite_group_t group)
{
    [RevenantOptions(options).ciphersuiteGroups addObject:@(group)];
}

void sec_protocol_options_set_tls_diffie_hellman_parameters(sec_protocol_options_t options,
                                                            dispatch_data_t dh_params)
{
    RevenantOptions(options).diffieHellmanParameters = dh_params;
}

void sec_protocol_options_add_pre_shared_key(sec_protocol_options_t options, dispatch_data_t psk,
                                             dispatch_data_t psk_identity)
{
    RevenantSecProtocolOptions *value = RevenantOptions(options);
    if (!psk || !psk_identity)
        return;
    [value.preSharedKeys addObject:(id)psk];
    [value.preSharedKeyIdentities addObject:(id)psk_identity];
}

void sec_protocol_options_set_tls_pre_shared_key_identity_hint(sec_protocol_options_t options,
                                                               dispatch_data_t hint)
{
    RevenantOptions(options).preSharedKeyIdentityHint = hint;
}

void sec_protocol_options_set_pre_shared_key_selection_block(
    sec_protocol_options_t options, sec_protocol_pre_shared_key_selection_t block,
    dispatch_queue_t queue)
{
    RevenantSecProtocolOptions *value = RevenantOptions(options);
    value.preSharedKeySelection = block;
    value.preSharedKeySelectionQueue = queue;
}

void sec_protocol_options_set_key_update_block(sec_protocol_options_t options,
                                               sec_protocol_key_update_t key_update_block,
                                               dispatch_queue_t key_update_queue)
{
    RevenantSecProtocolOptions *value = RevenantOptions(options);
    value.keyUpdateBlock = key_update_block;
    value.keyUpdateQueue = key_update_queue;
}

void sec_protocol_options_set_challenge_block(sec_protocol_options_t options,
                                              sec_protocol_challenge_t challenge_block,
                                              dispatch_queue_t challenge_queue)
{
    RevenantSecProtocolOptions *value = RevenantOptions(options);
    value.challengeBlock = challenge_block;
    value.challengeQueue = challenge_queue;
}

void sec_protocol_options_set_verify_block(sec_protocol_options_t options,
                                           sec_protocol_verify_t verify_block,
                                           dispatch_queue_t verify_block_queue)
{
    RevenantSecProtocolOptions *value = RevenantOptions(options);
    value.verifyBlock = verify_block;
    value.verifyQueue = verify_block_queue;
}
