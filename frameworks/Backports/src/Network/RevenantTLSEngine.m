#import "RevenantTLS/RevenantTLSEngine.h"
#import "../Security/RevenantSecProtocolOptions.h"

#include <CommonCrypto/CommonDigest.h>
#include <TargetConditionals.h>
#include <arpa/inet.h>
#include <dlfcn.h>
#include <limits.h>
#include <netinet/in.h>
#include <openssl/err.h>
#include <openssl/rsa.h>
#include <openssl/ssl.h>
#include <openssl/x509.h>
#include <stdio.h>
#include <string.h>

static const OSStatus kRevenantCertificateChainInvalid = -9807;
static const OSStatus kRevenantPeerHandshakeFailed = -9824;

static const uint16_t kRevenantTLS13Suites[] = {0x1301, 0x1302, 0x1303};
static const uint16_t kRevenantPFSSuites[] = {0xC02C, 0xC02B, 0xCCA9, 0xC030, 0xC02F, 0xCCA8, 0xC00A, 0xC009, 0xC014, 0xC013};
static const uint16_t kRevenantNonPFSSuites[] = {0x009D, 0x009C, 0x0035, 0x002F};
static const uint16_t kRevenantTLS10Suites[] = {0xC009, 0xC00A, 0xC013, 0xC014, 0x0035, 0x002F};
static const uint16_t kRevenantTLS10TripleDESSuites[] = {0xC008, 0xC012, 0x000A};
static const uint16_t kRevenantDHESuites[] = {0x009F, 0x009E, 0x006B, 0x0067, 0x0039, 0x0033, 0x0016};

static NSString *const kRevenantPreSharedKeyCipherNames[] = {@"ECDHE-PSK-AES128-CBC-SHA", @"ECDHE-PSK-AES256-CBC-SHA", @"ECDHE-PSK-CHACHA20-POLY1305"};

static void RevenantAppendSuites(NSMutableArray<NSNumber *> *list, const uint16_t *suites, size_t count)
{
    for (size_t index = 0; index < count; index++)
        [list addObject:@(suites[index])];
}

static NSString *RevenantSuiteText(uint16_t suite)
{
    return [NSString stringWithFormat:@"0x%x", suite];
}

static BOOL RevenantGroupSuites(uint16_t group, NSString **name, NSMutableArray<NSNumber *> *suites)
{
    switch (group) {
    case 0:
        *name = @"default";
        RevenantAppendSuites(suites, kRevenantTLS13Suites, sizeof kRevenantTLS13Suites / sizeof kRevenantTLS13Suites[0]);
        RevenantAppendSuites(suites, kRevenantPFSSuites, sizeof kRevenantPFSSuites / sizeof kRevenantPFSSuites[0]);
        return YES;
    case 1:
        *name = @"compatibility";
        RevenantAppendSuites(suites, kRevenantNonPFSSuites, sizeof kRevenantNonPFSSuites / sizeof kRevenantNonPFSSuites[0]);
        RevenantAppendSuites(suites, kRevenantTLS10Suites, sizeof kRevenantTLS10Suites / sizeof kRevenantTLS10Suites[0]);
        RevenantAppendSuites(suites, kRevenantTLS10TripleDESSuites, sizeof kRevenantTLS10TripleDESSuites / sizeof kRevenantTLS10TripleDESSuites[0]);
        return YES;
    case 2:
        *name = @"legacy";
        RevenantAppendSuites(suites, kRevenantDHESuites, sizeof kRevenantDHESuites / sizeof kRevenantDHESuites[0]);
        return YES;
    case 3:
        *name = @"ats";
        RevenantAppendSuites(suites, kRevenantTLS13Suites, sizeof kRevenantTLS13Suites / sizeof kRevenantTLS13Suites[0]);
        RevenantAppendSuites(suites, kRevenantPFSSuites, sizeof kRevenantPFSSuites / sizeof kRevenantPFSSuites[0]);
        return YES;
    case 4:
        *name = @"ats_compatibility";
        RevenantAppendSuites(suites, kRevenantNonPFSSuites, sizeof kRevenantNonPFSSuites / sizeof kRevenantNonPFSSuites[0]);
        return YES;
    default:
        return NO;
    }
}

static BOOL RevenantCipherNames(NSArray<NSNumber *> *groups, NSArray<NSNumber *> *ciphersuites, uint16_t maximumVersion,
                                NSMutableArray<NSString *> *names, NSString **reason, OSStatus *status)
{
    NSMutableArray<NSNumber *> *requested = [NSMutableArray array];
    for (NSNumber *group in groups) {
        NSString *name = nil;
        NSMutableArray<NSNumber *> *suites = [NSMutableArray array];
        if (!RevenantGroupSuites(group.unsignedShortValue, &name, suites)) {
            *reason = [NSString stringWithFormat:@"ciphersuite group %@ is refused: its suite list is not in the Apple Security source", group];
            *status = errSSLBadCipherSuite;
            return NO;
        }
        NSMutableArray<NSNumber *> *known = [NSMutableArray array];
        NSMutableArray<NSString *> *dropped = [NSMutableArray array];
        for (NSNumber *suite in suites) {
            if (SSL_get_cipher_by_value(suite.unsignedShortValue))
                [known addObject:suite];
            else
                [dropped addObject:RevenantSuiteText(suite.unsignedShortValue)];
        }
        if (known.count == 0) {
            *reason = [NSString stringWithFormat:@"ciphersuite group %@ has no suite BoringSSL supports", name];
            *status = errSSLBadCipherSuite;
            return NO;
        }
        if (dropped.count > 0)
            fprintf(stderr, "Network: ciphersuite group %s drops %s, which BoringSSL lacks\n", name.UTF8String,
                    [dropped componentsJoinedByString:@", "].UTF8String);
        [requested addObjectsFromArray:known];
    }
    [requested addObjectsFromArray:ciphersuites];
    NSMutableSet<NSNumber *> *seen = [NSMutableSet set];
    for (NSNumber *number in requested) {
        if ([seen containsObject:number])
            continue;
        [seen addObject:number];
        uint16_t suite = number.unsignedShortValue;
        const SSL_CIPHER *cipher = SSL_get_cipher_by_value(suite);
        const char *name = cipher ? SSL_CIPHER_get_name(cipher) : NULL;
        if (!name) {
            *reason = [NSString stringWithFormat:@"ciphersuite %@ is unknown to BoringSSL", RevenantSuiteText(suite)];
            *status = errSSLBadCipherSuite;
            return NO;
        }
        if (suite >= 0x1301 && suite <= 0x1305)
            continue;
        [names addObject:[NSString stringWithUTF8String:name]];
    }
    if (names.count == 0 && requested.count > 0 && maximumVersion < 0x0304) {
        *reason = @"only TLS 1.3 ciphersuites are listed, but the maximum is TLS 1.2: list a TLS 1.2 ciphersuite too";
        *status = errSSLBadCipherSuite;
        return NO;
    }
    return YES;
}

static NSData *RevenantCopyData(RevenantSecProtocolOptions *options, NSInteger kind, NSUInteger index)
{
    NSUInteger length = [options revenantCopyData:kind index:index into:NULL capacity:0];
    NSMutableData *data = [NSMutableData dataWithLength:length];
    [options revenantCopyData:kind index:index into:data.mutableBytes capacity:length];
    return data;
}

static NSArray<NSNumber *> *RevenantSuiteList(NSArray<NSNumber *> *list)
{
    return list ?: @[];
}

static size_t RevenantMinimum(size_t left, size_t right)
{
    return left < right ? left : right;
}

static BOOL RevenantIsIPAddress(NSString *name)
{
    struct in6_addr address;
    struct in_addr version4;
    return inet_pton(AF_INET, name.UTF8String, &version4) == 1 || inet_pton(AF_INET6, name.UTF8String, &address) == 1;
}

static int RevenantSessionIndex(void)
{
    static int index = -1;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        index = SSL_get_ex_new_index(0, NULL, NULL, NULL, NULL);
    });
    return index;
}

static OSStatus RevenantPeerFailure(void)
{
    int reason = ERR_GET_REASON(ERR_peek_error());
    ERR_clear_error();
    switch (reason) {
    case SSL_R_NO_SHARED_CIPHER:
        return errSSLNegotiation;
    case SSL_R_NO_CIPHER_MATCH:
    case SSL_R_NO_CIPHERS_AVAILABLE:
        return errSSLBadCipherSuite;
    case SSL_R_SSLV3_ALERT_BAD_CERTIFICATE:
        return errSSLPeerBadCert;
    case SSL_R_SSLV3_ALERT_CERTIFICATE_UNKNOWN:
        return errSSLPeerCertUnknown;
    case SSL_R_TLSV1_ALERT_UNKNOWN_CA:
        return errSSLPeerUnknownCA;
    case SSL_R_SSLV3_ALERT_ILLEGAL_PARAMETER:
        return errSSLIllegalParam;
    case SSL_R_SSLV3_ALERT_BAD_RECORD_MAC:
        return errSSLBadRecordMac;
    case SSL_R_TLSV1_ALERT_PROTOCOL_VERSION:
        return errSSLPeerProtocolVersion;
    default:
        return kRevenantPeerHandshakeFailed;
    }
}

static const uint16_t kRevenantSignaturePreferences[] = {
#if TARGET_OS_OSX
    0x0804, 0x0805, 0x0806,
#endif
    0x0401, 0x0501, 0x0601, 0x0201,
};

static size_t RevenantDigestInfo(uint16_t algorithm, const uint8_t *input, size_t count, uint8_t *output, size_t capacity)
{
    static const uint8_t sha1Prefix[] = {0x30, 0x21, 0x30, 0x09, 0x06, 0x05, 0x2b, 0x0e, 0x03, 0x02, 0x1a, 0x05, 0x00, 0x04, 0x14};
    static const uint8_t sha256Prefix[] = {0x30, 0x31, 0x30, 0x0d, 0x06, 0x09, 0x60, 0x86, 0x48, 0x01, 0x65, 0x03, 0x04, 0x02, 0x01, 0x05, 0x00, 0x04, 0x20};
    static const uint8_t sha384Prefix[] = {0x30, 0x41, 0x30, 0x0d, 0x06, 0x09, 0x60, 0x86, 0x48, 0x01, 0x65, 0x03, 0x04, 0x02, 0x02, 0x05, 0x00, 0x04, 0x30};
    static const uint8_t sha512Prefix[] = {0x30, 0x51, 0x30, 0x0d, 0x06, 0x09, 0x60, 0x86, 0x48, 0x01, 0x65, 0x03, 0x04, 0x02, 0x03, 0x05, 0x00, 0x04, 0x40};
    const uint8_t *prefix = NULL;
    size_t prefixLength = 0, digestLength = 0;
    uint8_t digest[CC_SHA512_DIGEST_LENGTH];
    switch (algorithm) {
    case 0x0201:
        prefix = sha1Prefix, prefixLength = sizeof sha1Prefix;
        digestLength = CC_SHA1_DIGEST_LENGTH;
        CC_SHA1(input, (CC_LONG)count, digest);
        break;
    case 0x0401:
        prefix = sha256Prefix, prefixLength = sizeof sha256Prefix;
        digestLength = CC_SHA256_DIGEST_LENGTH;
        CC_SHA256(input, (CC_LONG)count, digest);
        break;
    case 0x0501:
        prefix = sha384Prefix, prefixLength = sizeof sha384Prefix;
        digestLength = CC_SHA384_DIGEST_LENGTH;
        CC_SHA384(input, (CC_LONG)count, digest);
        break;
    case 0x0601:
        prefix = sha512Prefix, prefixLength = sizeof sha512Prefix;
        digestLength = CC_SHA512_DIGEST_LENGTH;
        CC_SHA512(input, (CC_LONG)count, digest);
        break;
    default:
        return 0;
    }
    size_t length = prefixLength + digestLength;
    if (length > capacity)
        return 0;
    memcpy(output, prefix, prefixLength);
    memcpy(output + prefixLength, digest, digestLength);
    return length;
}

#if TARGET_OS_OSX
static SecKeyAlgorithm RevenantMessageAlgorithm(uint16_t algorithm)
{
    switch (algorithm) {
    case 0x0201:
        return kSecKeyAlgorithmRSASignatureMessagePKCS1v15SHA1;
    case 0x0401:
        return kSecKeyAlgorithmRSASignatureMessagePKCS1v15SHA256;
    case 0x0501:
        return kSecKeyAlgorithmRSASignatureMessagePKCS1v15SHA384;
    case 0x0601:
        return kSecKeyAlgorithmRSASignatureMessagePKCS1v15SHA512;
    case 0x0804:
        return kSecKeyAlgorithmRSASignatureMessagePSSSHA256;
    case 0x0805:
        return kSecKeyAlgorithmRSASignatureMessagePSSSHA384;
    case 0x0806:
        return kSecKeyAlgorithmRSASignatureMessagePSSSHA512;
    default:
        return NULL;
    }
}
#endif

static enum ssl_private_key_result_t RevenantSignWithKey(SSL *ssl, uint8_t *out, size_t *outLength, size_t maxOut,
                                                         uint16_t algorithm, const uint8_t *input, size_t inputLength);

static const SSL_PRIVATE_KEY_METHOD kRevenantPrivateKeyMethod = {
    .sign = RevenantSignWithKey,
    .decrypt = NULL,
    .complete = NULL,
};

static enum ssl_verify_result_t RevenantVerifyChain(SSL *ssl, uint8_t *alert);
static int RevenantClientCertificate(SSL *ssl, void *argument);
static unsigned RevenantClientPreSharedKey(SSL *ssl, const char *hint, char *identity, unsigned maximumIdentity,
                                           uint8_t *key, unsigned maximumKey);
static unsigned RevenantServerPreSharedKey(SSL *ssl, const char *identity, uint8_t *key, unsigned maximumKey);
static int RevenantSelectProtocol(SSL *ssl, const uint8_t **out, uint8_t *outLength, const uint8_t *input,
                                  unsigned inputLength, void *argument);

@interface RevenantTLSSession : NSObject {
@public
    SSL_CTX *_context;
    SSL *_ssl;
    RevenantSecProtocolOptions *_options;
    BOOL _serverSide;
    BOOL _established;
    BOOL _wantsWrite;
    BOOL _verifies;
    BOOL _challenges;
    BOOL _peerRequired;
    NSString *_serverName;
    NSData *_applicationProtocolOffer;
    NSArray<NSData *> *_preSharedKeys;
    NSArray<NSData *> *_preSharedKeyIdentities;
    SecKeyRef _signingKey;
    OSStatus _verifyFailure;
}
- (instancetype)initWithOptions:(RevenantSecProtocolOptions *)options descriptor:(int)descriptor
              defaultServerName:(NSString *)defaultServerName serverSide:(BOOL)serverSide
                         reason:(NSString **)reason status:(OSStatus *)status;
- (OSStatus)handshake;
- (OSStatus)readInto:(void *)buffer capacity:(size_t)capacity count:(size_t *)count;
- (OSStatus)writeBytes:(const void *)bytes count:(size_t)count written:(size_t *)written;
- (void)close;
- (OSStatus)statusForResult:(int)result;
- (enum ssl_verify_result_t)verifyChain;
- (BOOL)installClientIdentity;
- (enum ssl_private_key_result_t)signAlgorithm:(uint16_t)algorithm input:(const uint8_t *)input length:(size_t)length
                                           out:(uint8_t *)out outLength:(size_t *)outLength maxOut:(size_t)maxOut;
- (unsigned)clientPreSharedKeyIdentity:(char *)identity maximumIdentity:(unsigned)maximumIdentity
                                    key:(uint8_t *)key maximumKey:(unsigned)maximumKey;
- (unsigned)serverPreSharedKeyIdentity:(const char *)identity key:(uint8_t *)key maximumKey:(unsigned)maximumKey;
@end

@implementation RevenantTLSSession

- (instancetype)initWithOptions:(RevenantSecProtocolOptions *)options descriptor:(int)descriptor
              defaultServerName:(NSString *)defaultServerName serverSide:(BOOL)serverSide
                         reason:(NSString **)reason status:(OSStatus *)status
{
    self = [super init];
    if (!self)
        return nil;
    _options = options;
    _serverSide = serverSide;
    _verifyFailure = 0;

    const char *unsupported = [options revenantUnsupportedSettingForServer:serverSide];
    if (unsupported) {
        *reason = [NSString stringWithUTF8String:unsupported];
        *status = errSSLBadConfiguration;
        return nil;
    }
    BOOL usesPreSharedKeys = options.preSharedKeys.count > 0;
    BOOL verifies = options.verifyBlock != nil;
    BOOL challenges = options.challengeBlock != nil;
    if (usesPreSharedKeys && (options.peerAuthenticationRequired || verifies)) {
        *reason = @"pre-shared keys need peer authentication turned off and no verify block: a PSK handshake has no certificate to check";
        *status = errSSLBadConfiguration;
        return nil;
    }
    if (usesPreSharedKeys && (options.ciphersuites.count > 0 || [options revenantCiphersuiteGroups].count > 0)) {
        *reason = @"pre-shared keys cannot be combined with a ciphersuite list or group: Apple ciphersuite values have no PSK suites";
        *status = errSSLBadConfiguration;
        return nil;
    }
    uint16_t minimum = options.minTLSVersion;
    uint16_t maximum = options.maxTLSVersion;
    NSMutableArray<NSString *> *names = [NSMutableArray array];
    if (!RevenantCipherNames(RevenantSuiteList([options revenantCiphersuiteGroups]), RevenantSuiteList(options.ciphersuites),
                             maximum, names, reason, status))
        return nil;

    _context = SSL_CTX_new(TLS_method());
    if (!_context) {
        *reason = @"BoringSSL could not allocate a TLS context";
        *status = errSSLInternal;
        return nil;
    }
    if (SSL_CTX_set_min_proto_version(_context, minimum) != 1 || SSL_CTX_set_max_proto_version(_context, maximum) != 1) {
        *reason = @"BoringSSL rejected the TLS version range";
        *status = errSSLProtocol;
        return nil;
    }
    NSArray<NSString *> *suiteNames = usesPreSharedKeys ? [NSArray arrayWithObjects:kRevenantPreSharedKeyCipherNames count:3] : names;
    if (suiteNames.count > 0 && SSL_CTX_set_strict_cipher_list(_context, [suiteNames componentsJoinedByString:@":"].UTF8String) != 1) {
        *reason = @"BoringSSL rejected the ciphersuite list";
        *status = errSSLBadCipherSuite;
        return nil;
    }

    _peerRequired = options.peerAuthenticationRequired;
    _verifies = verifies;
    _challenges = challenges;
    _serverName = serverSide ? nil : (options.serverName ?: defaultServerName);
    NSString *serverName = options.serverName ?: defaultServerName;
    NSMutableData *offer = nil;
    if (options.applicationProtocols.count > 0) {
        offer = [NSMutableData data];
        for (NSString *protocol in options.applicationProtocols) {
            NSData *text = [protocol dataUsingEncoding:NSUTF8StringEncoding];
            uint8_t length = (uint8_t)text.length;
            [offer appendBytes:&length length:1];
            [offer appendData:text];
        }
    }
    _applicationProtocolOffer = offer;

    if (serverSide) {
        sec_identity_t localIdentity = options.localIdentity;
        SecIdentityRef identity = localIdentity ? [options revenantCopyIdentityRef] : NULL;
        if (identity) {
            SecKeyRef key = NULL;
            SecCertificateRef certificate = NULL;
            X509 *x509 = NULL;
            BOOL installed = NO;
            if (SecIdentityCopyCertificate(identity, &certificate) == errSecSuccess && SecIdentityCopyPrivateKey(identity, &key) == errSecSuccess) {
                NSData *der = (__bridge_transfer NSData *)SecCertificateCopyData(certificate);
                const uint8_t *cursor = der.bytes;
                x509 = d2i_X509(NULL, &cursor, der.length);
                if (x509 && SSL_CTX_use_certificate(_context, x509) == 1) {
                    installed = YES;
                }
            }
            if (x509)
                X509_free(x509);
            if (certificate)
                CFRelease(certificate);
            if (!installed) {
                if (key)
                    CFRelease(key);
                CFRelease(identity);
                *reason = @"the server identity has no usable private key";
                *status = errSSLBadConfiguration;
                return nil;
            }
            _signingKey = key;
            SSL_CTX_set_private_key_method(_context, &kRevenantPrivateKeyMethod);
            SSL_CTX_set_signing_algorithm_prefs(_context, kRevenantSignaturePreferences, sizeof kRevenantSignaturePreferences / sizeof kRevenantSignaturePreferences[0]);
            CFRelease(identity);
        } else if (options.preSharedKeys.count == 0) {
            *reason = @"a server needs a local identity or a pre-shared key";
            *status = errSSLBadConfiguration;
            return nil;
        }
        if (_peerRequired || verifies) {
            int mode = _peerRequired ? SSL_VERIFY_PEER | SSL_VERIFY_FAIL_IF_NO_PEER_CERT : SSL_VERIFY_PEER;
            SSL_CTX_set_custom_verify(_context, mode, RevenantVerifyChain);
        }
        if (offer)
            SSL_CTX_set_alpn_select_cb(_context, RevenantSelectProtocol, (__bridge void *)offer);
    } else {
        SSL_CTX_set_cert_cb(_context, RevenantClientCertificate, NULL);
        if (_peerRequired || verifies)
            SSL_CTX_set_custom_verify(_context, SSL_VERIFY_PEER, RevenantVerifyChain);
    }

    if (usesPreSharedKeys) {
        _preSharedKeys = [self dataArray:options kind:0];
        _preSharedKeyIdentities = [self dataArray:options kind:1];
        if (serverSide) {
            SSL_CTX_set_psk_server_callback(_context, RevenantServerPreSharedKey);
            NSData *hint = RevenantCopyData(options, 2, 0);
            if (hint.length > 0) {
                NSMutableData *terminated = [hint mutableCopy];
                uint8_t zero = 0;
                [terminated appendBytes:&zero length:1];
                SSL_CTX_use_psk_identity_hint(_context, terminated.bytes);
            }
        } else {
            SSL_CTX_set_psk_client_callback(_context, RevenantClientPreSharedKey);
        }
    }

    _ssl = SSL_new(_context);
    if (!_ssl) {
        *reason = @"BoringSSL could not allocate a TLS session";
        *status = errSSLInternal;
        return nil;
    }
    if (SSL_set_fd(_ssl, descriptor) != 1) {
        *reason = @"BoringSSL could not attach the socket";
        *status = errSSLInternal;
        return nil;
    }
    if (serverSide)
        SSL_set_accept_state(_ssl);
    else
        SSL_set_connect_state(_ssl);
    SSL_set_ex_data(_ssl, RevenantSessionIndex(), (__bridge void *)self);

    if (!serverSide) {
        if (serverName && !RevenantIsIPAddress(serverName))
            SSL_set_tlsext_host_name(_ssl, serverName.UTF8String);
        if (offer)
            SSL_set_alpn_protos(_ssl, offer.bytes, (unsigned)offer.length);
        if (options.ocspEnabled)
            SSL_enable_ocsp_stapling(_ssl);
        if (options.sctEnabled)
            SSL_enable_signed_cert_timestamps(_ssl);
    }
    return self;
}

- (NSArray<NSData *> *)dataArray:(RevenantSecProtocolOptions *)options kind:(NSInteger)kind
{
    NSMutableArray<NSData *> *items = [NSMutableArray array];
    for (NSUInteger index = 0; index < options.preSharedKeys.count; index++)
        [items addObject:RevenantCopyData(options, kind, index)];
    return items;
}

- (void)dealloc
{
    if (_ssl)
        SSL_free(_ssl);
    if (_context)
        SSL_CTX_free(_context);
    if (_signingKey)
        CFRelease(_signingKey);
}

- (OSStatus)handshake
{
    _wantsWrite = NO;
    int result = SSL_do_handshake(_ssl);
    if (result == 1) {
        _established = YES;
        return noErr;
    }
    OSStatus status = [self statusForResult:result];
    if (status == errSSLWouldBlock)
        return status;
    return _verifyFailure ? _verifyFailure : RevenantPeerFailure();
}

- (OSStatus)readInto:(void *)buffer capacity:(size_t)capacity count:(size_t *)count
{
    int result = SSL_read(_ssl, buffer, (int)RevenantMinimum(capacity, (size_t)INT_MAX));
    if (result > 0) {
        *count = (size_t)result;
        return noErr;
    }
    *count = 0;
    return [self statusForResult:result];
}

- (OSStatus)writeBytes:(const void *)bytes count:(size_t)count written:(size_t *)written
{
    int result = SSL_write(_ssl, bytes, (int)RevenantMinimum(count, (size_t)INT_MAX));
    if (result > 0) {
        *written = (size_t)result;
        return noErr;
    }
    *written = 0;
    return [self statusForResult:result];
}

- (void)close
{
    SSL_shutdown(_ssl);
    _established = NO;
}

- (OSStatus)statusForResult:(int)result
{
    switch (SSL_get_error(_ssl, result)) {
    case SSL_ERROR_WANT_READ:
        return errSSLWouldBlock;
    case SSL_ERROR_WANT_WRITE:
        _wantsWrite = YES;
        return errSSLWouldBlock;
    case SSL_ERROR_ZERO_RETURN:
        return errSSLClosedGraceful;
    case SSL_ERROR_SYSCALL:
        ERR_clear_error();
        return errSSLClosedNoNotify;
    default:
        return errSSLClosedAbort;
    }
}

- (enum ssl_verify_result_t)verifyChain
{
    STACK_OF(X509) *chain = SSL_get_peer_full_cert_chain(_ssl);
    if (!chain) {
        _verifyFailure = kRevenantCertificateChainInvalid;
        return ssl_verify_invalid;
    }
    NSMutableArray *certificates = [NSMutableArray array];
    for (size_t index = 0; index < sk_X509_num(chain); index++) {
        X509 *x509 = sk_X509_value(chain, index);
        uint8_t *der = NULL;
        int length = x509 ? i2d_X509(x509, &der) : 0;
        if (length <= 0 || !der) {
            _verifyFailure = kRevenantCertificateChainInvalid;
            return ssl_verify_invalid;
        }
        NSData *data = [NSData dataWithBytes:der length:(NSUInteger)length];
        OPENSSL_free(der);
        SecCertificateRef certificate = SecCertificateCreateWithData(NULL, (__bridge CFDataRef)data);
        if (!certificate) {
            _verifyFailure = kRevenantCertificateChainInvalid;
            return ssl_verify_invalid;
        }
        [certificates addObject:(__bridge_transfer id)certificate];
    }
    SecPolicyRef policy = SecPolicyCreateSSL(!_serverSide, (__bridge CFStringRef)_serverName);
    SecTrustRef trust = NULL;
    OSStatus created = certificates.count > 0 ? SecTrustCreateWithCertificates((__bridge CFArrayRef)certificates, policy, &trust) : errSecParam;
    if (policy)
        CFRelease(policy);
    if (created != errSecSuccess || !trust) {
        _verifyFailure = kRevenantCertificateChainInvalid;
        return ssl_verify_invalid;
    }
    enum ssl_verify_result_t result = ssl_verify_invalid;
    if (_verifies) {
        result = [_options revenantVerifyTrust:trust] ? ssl_verify_ok : ssl_verify_invalid;
    } else {
        SecTrustResultType trustResult = kSecTrustResultInvalid;
        if (SecTrustEvaluate(trust, &trustResult) == errSecSuccess && (trustResult == kSecTrustResultProceed || trustResult == kSecTrustResultUnspecified))
            result = ssl_verify_ok;
    }
    CFRelease(trust);
    if (result != ssl_verify_ok)
        _verifyFailure = kRevenantCertificateChainInvalid;
    return result;
}

- (BOOL)installClientIdentity
{
    SecIdentityRef identity = NULL;
    if (_challenges)
        identity = [_options revenantChallengeIdentity];
    if (!identity && _options.localIdentity)
        identity = [_options revenantCopyIdentityRef];
    if (!identity)
        return YES;
    SecKeyRef key = NULL;
    SecCertificateRef certificate = NULL;
    X509 *x509 = NULL;
    BOOL installed = NO;
    if (SecIdentityCopyPrivateKey(identity, &key) == errSecSuccess && SecIdentityCopyCertificate(identity, &certificate) == errSecSuccess) {
        NSData *der = (__bridge_transfer NSData *)SecCertificateCopyData(certificate);
        const uint8_t *cursor = der.bytes;
        x509 = d2i_X509(NULL, &cursor, der.length);
        if (x509 && SSL_use_certificate(_ssl, x509) == 1) {
            if (_signingKey)
                CFRelease(_signingKey);
            _signingKey = key;
            key = NULL;
            SSL_set_private_key_method(_ssl, &kRevenantPrivateKeyMethod);
            SSL_set_signing_algorithm_prefs(_ssl, kRevenantSignaturePreferences, sizeof kRevenantSignaturePreferences / sizeof kRevenantSignaturePreferences[0]);
            installed = YES;
        }
    }
    if (x509)
        X509_free(x509);
    if (certificate)
        CFRelease(certificate);
    if (key)
        CFRelease(key);
    CFRelease(identity);
    return installed;
}

- (enum ssl_private_key_result_t)signAlgorithm:(uint16_t)algorithm input:(const uint8_t *)input length:(size_t)length
                                           out:(uint8_t *)out outLength:(size_t *)outLength maxOut:(size_t)maxOut
{
    if (!_signingKey)
        return ssl_private_key_failure;
    NSData *signature = nil;
#if TARGET_OS_OSX
    SecKeyAlgorithm message = RevenantMessageAlgorithm(algorithm);
    if (!message)
        return ssl_private_key_failure;
    CFErrorRef error = NULL;
    NSData *data = [NSData dataWithBytes:input length:length];
    signature = (__bridge_transfer NSData *)SecKeyCreateSignature(_signingKey, message, (__bridge CFDataRef)data, &error);
    if (error)
        CFRelease(error);
#else
    uint8_t digest[CC_SHA512_DIGEST_LENGTH + 32];
    size_t digestLength = RevenantDigestInfo(algorithm, input, length, digest, sizeof digest);
    if (digestLength == 0)
        return ssl_private_key_failure;
    static void *handle = NULL;
    static OSStatus (*rawSign)(SecKeyRef, int, const uint8_t *, size_t, uint8_t *, size_t *);
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        handle = RTLD_DEFAULT;
        rawSign = (OSStatus (*)(SecKeyRef, int, const uint8_t *, size_t, uint8_t *, size_t *))dlsym(handle, "SecKeyRawSign");
    });
    if (!rawSign)
        return ssl_private_key_failure;
    size_t blockSize = SecKeyGetBlockSize(_signingKey);
    NSMutableData *buffer = [NSMutableData dataWithLength:blockSize];
    size_t signed_length = blockSize;
    if (rawSign(_signingKey, 1, digest, digestLength, buffer.mutableBytes, &signed_length) != errSecSuccess)
        return ssl_private_key_failure;
    signature = [buffer subdataWithRange:NSMakeRange(0, signed_length)];
#endif
    if (!signature || signature.length > maxOut)
        return ssl_private_key_failure;
    memcpy(out, signature.bytes, signature.length);
    *outLength = signature.length;
    return ssl_private_key_success;
}

- (unsigned)clientPreSharedKeyIdentity:(char *)identity maximumIdentity:(unsigned)maximumIdentity
                                    key:(uint8_t *)key maximumKey:(unsigned)maximumKey
{
    if (_preSharedKeys.count == 0 || _preSharedKeyIdentities.count == 0)
        return 0;
    NSData *name = _preSharedKeyIdentities.firstObject;
    NSData *secret = _preSharedKeys.firstObject;
    if (name.length >= maximumIdentity || secret.length > maximumKey)
        return 0;
    memcpy(identity, name.bytes, name.length);
    identity[name.length] = 0;
    memcpy(key, secret.bytes, secret.length);
    return (unsigned)secret.length;
}

- (unsigned)serverPreSharedKeyIdentity:(const char *)identity key:(uint8_t *)key maximumKey:(unsigned)maximumKey
{
    size_t length = strlen(identity);
    for (NSUInteger index = 0; index < _preSharedKeyIdentities.count; index++) {
        NSData *name = _preSharedKeyIdentities[index];
        if (name.length != length || memcmp(name.bytes, identity, length) != 0)
            continue;
        NSData *secret = _preSharedKeys[index];
        if (secret.length > maximumKey)
            return 0;
        memcpy(key, secret.bytes, secret.length);
        return (unsigned)secret.length;
    }
    return 0;
}

@end

static RevenantTLSSession *RevenantSessionOf(SSL *ssl)
{
    return (__bridge RevenantTLSSession *)SSL_get_ex_data(ssl, RevenantSessionIndex());
}

static enum ssl_private_key_result_t RevenantSignWithKey(SSL *ssl, uint8_t *out, size_t *outLength, size_t maxOut,
                                                         uint16_t algorithm, const uint8_t *input, size_t inputLength)
{
    RevenantTLSSession *session = RevenantSessionOf(ssl);
    if (!session || !out || !outLength)
        return ssl_private_key_failure;
    return [session signAlgorithm:algorithm input:input length:inputLength out:out outLength:outLength maxOut:maxOut];
}

static enum ssl_verify_result_t RevenantVerifyChain(SSL *ssl, uint8_t *alert)
{
    (void)alert;
    RevenantTLSSession *session = RevenantSessionOf(ssl);
    return session ? [session verifyChain] : ssl_verify_invalid;
}

static int RevenantClientCertificate(SSL *ssl, void *argument)
{
    (void)argument;
    RevenantTLSSession *session = RevenantSessionOf(ssl);
    return session && [session installClientIdentity] ? 1 : 0;
}

static unsigned RevenantClientPreSharedKey(SSL *ssl, const char *hint, char *identity, unsigned maximumIdentity,
                                           uint8_t *key, unsigned maximumKey)
{
    (void)hint;
    RevenantTLSSession *session = RevenantSessionOf(ssl);
    if (!session || !identity || !key)
        return 0;
    return [session clientPreSharedKeyIdentity:identity maximumIdentity:maximumIdentity key:key maximumKey:maximumKey];
}

static unsigned RevenantServerPreSharedKey(SSL *ssl, const char *identity, uint8_t *key, unsigned maximumKey)
{
    RevenantTLSSession *session = RevenantSessionOf(ssl);
    if (!session || !identity || !key)
        return 0;
    return [session serverPreSharedKeyIdentity:identity key:key maximumKey:maximumKey];
}

static int RevenantSelectProtocol(SSL *ssl, const uint8_t **out, uint8_t *outLength, const uint8_t *input,
                                  unsigned inputLength, void *argument)
{
    (void)ssl;
    if (!out || !outLength || !input || !argument)
        return SSL_TLSEXT_ERR_NOACK;
    NSData *offer = (__bridge NSData *)argument;
    uint8_t *selected = NULL;
    uint8_t selectedLength = 0;
    if (SSL_select_next_proto(&selected, &selectedLength, offer.bytes, (unsigned)offer.length, input, inputLength) != OPENSSL_NPN_NEGOTIATED || !selected)
        return SSL_TLSEXT_ERR_NOACK;
    *out = selected;
    *outLength = selectedLength;
    return SSL_TLSEXT_ERR_OK;
}

static RevenantTLSSession *RevenantSession(const RevenantTLSEngine *engine)
{
    return (__bridge RevenantTLSSession *)(const void *)engine;
}

void *RevenantTLSOptionsCreate(void)
{
    return (__bridge_retained void *)[[RevenantSecProtocolOptions alloc] init];
}

bool RevenantTLSOptionsHasServerCredentials(const void *options)
{
    RevenantSecProtocolOptions *value = (__bridge RevenantSecProtocolOptions *)options;
    return value.localIdentity != nil || value.preSharedKeys.count > 0;
}

RevenantTLSEngine *RevenantTLSEngineCreate(const void *options, int descriptor, const char *defaultServerName, bool serverSide,
                                           char *reason, size_t reasonCapacity, OSStatus *status)
{
    RevenantSecProtocolOptions *value = (__bridge RevenantSecProtocolOptions *)options;
    NSString *failure = nil;
    OSStatus failed = errSSLInternal;
    NSString *name = defaultServerName ? [NSString stringWithUTF8String:defaultServerName] : nil;
    RevenantTLSSession *session = [[RevenantTLSSession alloc] initWithOptions:value descriptor:descriptor defaultServerName:name
                                                                   serverSide:serverSide reason:&failure status:&failed];
    if (!session) {
        if (status)
            *status = failed;
        if (reason && reasonCapacity > 0) {
            const char *text = failure.UTF8String ?: "";
            strlcpy(reason, text, reasonCapacity);
        }
        return NULL;
    }
    return (RevenantTLSEngine *)(__bridge_retained void *)session;
}

void RevenantTLSEngineFree(RevenantTLSEngine *engine)
{
    RevenantTLSSession *session = (__bridge_transfer RevenantTLSSession *)(void *)engine;
    (void)session;
}

OSStatus RevenantTLSEngineHandshake(RevenantTLSEngine *engine)
{
    return [RevenantSession(engine) handshake];
}

OSStatus RevenantTLSEngineRead(RevenantTLSEngine *engine, void *buffer, size_t capacity, size_t *count)
{
    return [RevenantSession(engine) readInto:buffer capacity:capacity count:count];
}

OSStatus RevenantTLSEngineWrite(RevenantTLSEngine *engine, const void *bytes, size_t count, size_t *written)
{
    return [RevenantSession(engine) writeBytes:bytes count:count written:written];
}

void RevenantTLSEngineClose(RevenantTLSEngine *engine)
{
    [RevenantSession(engine) close];
}

bool RevenantTLSEngineIsEstablished(const RevenantTLSEngine *engine)
{
    return RevenantSession(engine)->_established;
}

bool RevenantTLSEngineWantsWrite(const RevenantTLSEngine *engine)
{
    return RevenantSession(engine)->_wantsWrite;
}

uint16_t RevenantTLSEngineNegotiatedVersion(const RevenantTLSEngine *engine)
{
    RevenantTLSSession *session = RevenantSession(engine);
    return session->_established ? (uint16_t)SSL_version(session->_ssl) : 0;
}

uint16_t RevenantTLSEngineNegotiatedCipherSuite(const RevenantTLSEngine *engine)
{
    RevenantTLSSession *session = RevenantSession(engine);
    if (!session->_established)
        return 0;
    const SSL_CIPHER *cipher = SSL_get_current_cipher(session->_ssl);
    return cipher ? SSL_CIPHER_get_protocol_id(cipher) : 0;
}

const uint8_t *RevenantTLSEngineNegotiatedProtocol(const RevenantTLSEngine *engine, size_t *length)
{
    RevenantTLSSession *session = RevenantSession(engine);
    const uint8_t *data = NULL;
    unsigned selected = 0;
    if (!session->_established)
        return NULL;
    SSL_get0_alpn_selected(session->_ssl, &data, &selected);
    if (!data || selected == 0)
        return NULL;
    *length = selected;
    return data;
}

const uint8_t *RevenantTLSEngineOCSPResponse(const RevenantTLSEngine *engine, size_t *length)
{
    RevenantTLSSession *session = RevenantSession(engine);
    const uint8_t *data = NULL;
    size_t selected = 0;
    if (!session->_established)
        return NULL;
    SSL_get0_ocsp_response(session->_ssl, &data, &selected);
    if (!data || selected == 0)
        return NULL;
    *length = selected;
    return data;
}
