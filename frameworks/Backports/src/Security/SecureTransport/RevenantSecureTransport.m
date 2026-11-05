#import <Foundation/Foundation.h>
#import <Security/SecureTransport.h>
#import <Security/SecTrust.h>
#import <dispatch/dispatch.h>
#import <dlfcn.h>
#import <stdio.h>
#import <string.h>
#import "../../TLS/RevenantSecProtocolOptions.h"
#import "../../TLS/RevenantTLS/RevenantTLSEngine.h"

#if !defined(REVENANT_SECURITY_LIBRARY)
#define REVENANT_SECURITY_LIBRARY "/System/Library/Frameworks/Security.framework/Security"
#endif

#if !defined(REVENANT_SYSTEM_PROBE)
#define REVENANT_SYSTEM_PROBE "SecTrustGetTrustResult"
#endif

@interface RevenantSSLContext : NSObject {
@public
    RevenantSecProtocolOptions *options;
    SSLConnectionRef connection;
    SSLReadFunc readFunc;
    SSLWriteFunc writeFunc;
    NSString *peerDomainName;
    RevenantTLSEngine *engine;
}
@end

@implementation RevenantSSLContext

- (void)dealloc
{
    if (engine)
        RevenantTLSEngineFree(engine);
}

@end

static RevenantSSLContext *RevenantSSLOf(SSLContextRef context)
{
    return (__bridge RevenantSSLContext *)(void *)context;
}

static void *RevenantSecurityLibrary(void)
{
    static void *library;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        library = dlopen(REVENANT_SECURITY_LIBRARY, RTLD_LAZY);
    });
    return library;
}

static void *RevenantSystemSymbol(const char *name)
{
    void *library = RevenantSecurityLibrary();
    return library ? dlsym(library, name) : NULL;
}

static BOOL RevenantSystemTransportIsAdequate(void)
{
    static BOOL adequate;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        adequate = RevenantSystemSymbol(REVENANT_SYSTEM_PROBE) != NULL;
    });
    return adequate;
}

static CFMutableSetRef RevenantVeneerContexts(void)
{
    static CFMutableSetRef contexts;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        contexts = CFSetCreateMutable(NULL, 0, NULL);
    });
    return contexts;
}

static void RevenantRememberContext(SSLContextRef context)
{
    @synchronized (RevenantSSLContext.class) {
        CFSetAddValue(RevenantVeneerContexts(), context);
    }
}

static void RevenantForgetContext(SSLContextRef context)
{
    @synchronized (RevenantSSLContext.class) {
        CFSetRemoveValue(RevenantVeneerContexts(), context);
    }
}

static BOOL RevenantOwnsContext(SSLContextRef context)
{
    if (!context || RevenantSystemTransportIsAdequate())
        return NO;
    @synchronized (RevenantSSLContext.class) {
        return CFSetContainsValue(RevenantVeneerContexts(), context);
    }
}

#define RevenantDefer(Name, Unavailable, ...) \
    do { \
        __typeof__(&Name) function = (__typeof__(&Name))RevenantSystemSymbol(#Name); \
        return function ? function(__VA_ARGS__) : (Unavailable); \
    } while (0)

static BOOL RevenantWireVersion(SSLProtocol protocol, uint16_t *version)
{
    switch (protocol) {
    case kSSLProtocol3:
        *version = 0x0300;
        return YES;
    case kTLSProtocol1:
        *version = 0x0301;
        return YES;
    case kTLSProtocol11:
        *version = 0x0302;
        return YES;
    case kTLSProtocol12:
        *version = 0x0303;
        return YES;
    case kTLSProtocol13:
        *version = 0x0304;
        return YES;
    default:
        return NO;
    }
}

static SSLProtocol RevenantProtocolOfWireVersion(uint16_t version)
{
    switch (version) {
    case 0x0300:
        return kSSLProtocol3;
    case 0x0301:
        return kTLSProtocol1;
    case 0x0302:
        return kTLSProtocol11;
    case 0x0303:
        return kTLSProtocol12;
    case 0x0304:
        return kTLSProtocol13;
    default:
        return kSSLProtocolUnknown;
    }
}

SSLContextRef SSLCreateContext(CFAllocatorRef alloc, SSLProtocolSide protocolSide, SSLConnectionType connectionType)
{
    if (RevenantSystemTransportIsAdequate() || protocolSide != kSSLClientSide || connectionType != kSSLStreamType)
        RevenantDefer(SSLCreateContext, NULL, alloc, protocolSide, connectionType);
    RevenantSSLContext *context = [[RevenantSSLContext alloc] init];
    context->options = [[RevenantSecProtocolOptions alloc] init];
    SSLContextRef reference = (SSLContextRef)(__bridge_retained void *)context;
    RevenantRememberContext(reference);
    return reference;
}

OSStatus SSLDisposeContext(SSLContextRef context)
{
    if (!RevenantOwnsContext(context))
        RevenantDefer(SSLDisposeContext, errSecParam, context);
    RevenantForgetContext(context);
    RevenantSSLContext *value = (__bridge_transfer RevenantSSLContext *)(void *)context;
    return value ? noErr : errSecParam;
}

OSStatus SSLSetConnection(SSLContextRef context, SSLConnectionRef connection)
{
    if (!RevenantOwnsContext(context))
        RevenantDefer(SSLSetConnection, errSecParam, context, connection);
    RevenantSSLContext *value = RevenantSSLOf(context);
    if (value->engine)
        return errSSLBadConfiguration;
    value->connection = connection;
    return noErr;
}

OSStatus SSLGetConnection(SSLContextRef context, SSLConnectionRef *connection)
{
    if (!RevenantOwnsContext(context))
        RevenantDefer(SSLGetConnection, errSecParam, context, connection);
    RevenantSSLContext *value = RevenantSSLOf(context);
    if (!connection)
        return errSecParam;
    *connection = value->connection;
    return noErr;
}

OSStatus SSLSetIOFuncs(SSLContextRef context, SSLReadFunc readFunc, SSLWriteFunc writeFunc)
{
    if (!RevenantOwnsContext(context))
        RevenantDefer(SSLSetIOFuncs, errSecParam, context, readFunc, writeFunc);
    RevenantSSLContext *value = RevenantSSLOf(context);
    if (!readFunc || !writeFunc)
        return errSecParam;
    if (value->engine)
        return errSSLBadConfiguration;
    value->readFunc = readFunc;
    value->writeFunc = writeFunc;
    return noErr;
}

OSStatus SSLSetPeerDomainName(SSLContextRef context, const char *peerName, size_t peerNameLen)
{
    if (!RevenantOwnsContext(context))
        RevenantDefer(SSLSetPeerDomainName, errSecParam, context, peerName, peerNameLen);
    RevenantSSLContext *value = RevenantSSLOf(context);
    if (!peerName && peerNameLen)
        return errSecParam;
    if (value->engine)
        return errSSLBadConfiguration;
    NSString *name = peerNameLen ? [[NSString alloc] initWithBytes:peerName length:peerNameLen encoding:NSUTF8StringEncoding] : nil;
    if (peerNameLen && !name)
        return errSecParam;
    value->peerDomainName = name;
    value->options.serverName = name;
    return noErr;
}

OSStatus SSLGetPeerDomainNameLength(SSLContextRef context, size_t *peerNameLen)
{
    if (!RevenantOwnsContext(context))
        RevenantDefer(SSLGetPeerDomainNameLength, errSecParam, context, peerNameLen);
    RevenantSSLContext *value = RevenantSSLOf(context);
    if (!peerNameLen)
        return errSecParam;
    *peerNameLen = [value->peerDomainName lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
    return noErr;
}

OSStatus SSLGetPeerDomainName(SSLContextRef context, char *peerName, size_t *peerNameLen)
{
    if (!RevenantOwnsContext(context))
        RevenantDefer(SSLGetPeerDomainName, errSecParam, context, peerName, peerNameLen);
    RevenantSSLContext *value = RevenantSSLOf(context);
    if (!peerName || !peerNameLen)
        return errSecParam;
    size_t length = [value->peerDomainName lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
    if (*peerNameLen < length)
        return errSecBufferTooSmall;
    memcpy(peerName, value->peerDomainName.UTF8String, length);
    *peerNameLen = length;
    return noErr;
}

OSStatus SSLSetProtocolVersionMin(SSLContextRef context, SSLProtocol minVersion)
{
    if (!RevenantOwnsContext(context))
        RevenantDefer(SSLSetProtocolVersionMin, errSecParam, context, minVersion);
    RevenantSSLContext *value = RevenantSSLOf(context);
    uint16_t version = 0;
    if (!RevenantWireVersion(minVersion, &version))
        return errSecParam;
    if (value->engine)
        return errSSLBadConfiguration;
    value->options.minTLSVersion = version;
    return noErr;
}

OSStatus SSLSetProtocolVersionMax(SSLContextRef context, SSLProtocol maxVersion)
{
    if (!RevenantOwnsContext(context))
        RevenantDefer(SSLSetProtocolVersionMax, errSecParam, context, maxVersion);
    RevenantSSLContext *value = RevenantSSLOf(context);
    uint16_t version = 0;
    if (!RevenantWireVersion(maxVersion, &version))
        return errSecParam;
    if (value->engine)
        return errSSLBadConfiguration;
    value->options.maxTLSVersion = version;
    return noErr;
}

OSStatus SSLSetEnabledCiphers(SSLContextRef context, const SSLCipherSuite *ciphers, size_t numCiphers)
{
    if (!RevenantOwnsContext(context))
        RevenantDefer(SSLSetEnabledCiphers, errSecParam, context, ciphers, numCiphers);
    RevenantSSLContext *value = RevenantSSLOf(context);
    if (!ciphers && numCiphers)
        return errSecParam;
    if (value->engine)
        return errSSLBadConfiguration;
    NSMutableArray<NSNumber *> *suites = [NSMutableArray arrayWithCapacity:numCiphers];
    for (size_t index = 0; index < numCiphers; index++)
        [suites addObject:@(ciphers[index])];
    value->options.ciphersuites = suites;
    return noErr;
}

OSStatus SSLSetSessionOption(SSLContextRef context, SSLSessionOption option, Boolean value)
{
    if (!RevenantOwnsContext(context))
        RevenantDefer(SSLSetSessionOption, errSecParam, context, option, value);
    RevenantSSLContext *target = RevenantSSLOf(context);
    if (target->engine)
        return errSSLBadConfiguration;
    if (option != kSSLSessionOptionBreakOnServerAuth)
        return errSecUnimplemented;
    target->options.breaksOnServerAuth = value;
    return noErr;
}

OSStatus SSLHandshake(SSLContextRef context)
{
    if (!RevenantOwnsContext(context))
        RevenantDefer(SSLHandshake, errSecParam, context);
    RevenantSSLContext *value = RevenantSSLOf(context);
    if (!value->engine) {
        char reason[512] = "";
        OSStatus status = noErr;
        if (value->readFunc)
            value->engine = RevenantTLSEngineCreateWithCallbacks((__bridge const void *)value->options, value->connection,
                                                                 value->readFunc, value->writeFunc, value->peerDomainName.UTF8String,
                                                                 false, reason, sizeof reason, &status);
        else
            value->engine = RevenantTLSEngineCreate((__bridge const void *)value->options, (int)(intptr_t)value->connection,
                                                    value->peerDomainName.UTF8String, false, reason, sizeof reason, &status);
        if (!value->engine) {
            fprintf(stderr, "SecureTransport: TLS setting refused: %s\n", reason);
            return status == noErr ? errSSLBadConfiguration : status;
        }
    }
    return RevenantTLSEngineHandshake(value->engine);
}

OSStatus SSLRead(SSLContextRef context, void *data, size_t dataLength, size_t *processed)
{
    if (!RevenantOwnsContext(context))
        RevenantDefer(SSLRead, errSecParam, context, data, dataLength, processed);
    RevenantSSLContext *value = RevenantSSLOf(context);
    if (!processed)
        return errSecParam;
    if (!value->engine || !RevenantTLSEngineIsEstablished(value->engine))
        return errSSLProtocol;
    return RevenantTLSEngineRead(value->engine, data, dataLength, processed);
}

OSStatus SSLWrite(SSLContextRef context, const void *data, size_t dataLength, size_t *processed)
{
    if (!RevenantOwnsContext(context))
        RevenantDefer(SSLWrite, errSecParam, context, data, dataLength, processed);
    RevenantSSLContext *value = RevenantSSLOf(context);
    if (!processed)
        return errSecParam;
    if (!value->engine || !RevenantTLSEngineIsEstablished(value->engine))
        return errSSLProtocol;
    return RevenantTLSEngineWrite(value->engine, data, dataLength, processed);
}

OSStatus SSLClose(SSLContextRef context)
{
    if (!RevenantOwnsContext(context))
        RevenantDefer(SSLClose, errSecParam, context);
    RevenantSSLContext *value = RevenantSSLOf(context);
    if (value->engine)
        RevenantTLSEngineClose(value->engine);
    return noErr;
}

OSStatus SSLGetNegotiatedProtocolVersion(SSLContextRef context, SSLProtocol *protocol)
{
    if (!RevenantOwnsContext(context))
        RevenantDefer(SSLGetNegotiatedProtocolVersion, errSecParam, context, protocol);
    RevenantSSLContext *value = RevenantSSLOf(context);
    if (!protocol)
        return errSecParam;
    uint16_t version = value->engine ? RevenantTLSEngineNegotiatedVersion(value->engine) : 0;
    *protocol = RevenantProtocolOfWireVersion(version);
    return noErr;
}

OSStatus SSLGetNegotiatedCipher(SSLContextRef context, SSLCipherSuite *cipherSuite)
{
    if (!RevenantOwnsContext(context))
        RevenantDefer(SSLGetNegotiatedCipher, errSecParam, context, cipherSuite);
    RevenantSSLContext *value = RevenantSSLOf(context);
    if (!cipherSuite)
        return errSecParam;
    *cipherSuite = value->engine ? RevenantTLSEngineNegotiatedCipherSuite(value->engine) : 0;
    return noErr;
}

OSStatus SSLCopyPeerTrust(SSLContextRef context, SecTrustRef *trust)
{
    if (!RevenantOwnsContext(context))
        RevenantDefer(SSLCopyPeerTrust, errSecParam, context, trust);
    RevenantSSLContext *value = RevenantSSLOf(context);
    if (!trust)
        return errSecParam;
    *trust = value->engine ? (SecTrustRef)RevenantTLSEngineCopyPeerTrust(value->engine) : NULL;
    return noErr;
}

OSStatus SSLGetSessionOption(SSLContextRef context, SSLSessionOption option, Boolean *value)
{
    if (!RevenantOwnsContext(context))
        RevenantDefer(SSLGetSessionOption, errSecUnimplemented, context, option, value);
    RevenantSSLContext *target = RevenantSSLOf(context);
    if (!value)
        return errSecParam;
    if (option != kSSLSessionOptionBreakOnServerAuth)
        return errSecUnimplemented;
    *value = target->options.breaksOnServerAuth;
    return noErr;
}

OSStatus SSLGetProtocolVersionMin(SSLContextRef context, SSLProtocol *minVersion)
{
    if (!RevenantOwnsContext(context))
        RevenantDefer(SSLGetProtocolVersionMin, errSecUnimplemented, context, minVersion);
    RevenantSSLContext *value = RevenantSSLOf(context);
    if (!minVersion)
        return errSecParam;
    *minVersion = RevenantProtocolOfWireVersion(value->options.minTLSVersion);
    return noErr;
}

OSStatus SSLGetProtocolVersionMax(SSLContextRef context, SSLProtocol *maxVersion)
{
    if (!RevenantOwnsContext(context))
        RevenantDefer(SSLGetProtocolVersionMax, errSecUnimplemented, context, maxVersion);
    RevenantSSLContext *value = RevenantSSLOf(context);
    if (!maxVersion)
        return errSecParam;
    *maxVersion = RevenantProtocolOfWireVersion(value->options.maxTLSVersion);
    return noErr;
}

OSStatus SSLSetALPNProtocols(SSLContextRef context, CFArrayRef protocols)
{
    if (!RevenantOwnsContext(context))
        RevenantDefer(SSLSetALPNProtocols, errSecUnimplemented, context, protocols);
    RevenantSSLContext *value = RevenantSSLOf(context);
    if (value->engine)
        return errSSLBadConfiguration;
    NSMutableArray<NSString *> *names = [NSMutableArray array];
    for (id name in (__bridge NSArray *)protocols) {
        if (![name isKindOfClass:NSString.class])
            return errSecParam;
        NSUInteger length = [name lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
        if (length == 0 || length > UINT8_MAX)
            return errSecParam;
        [names addObject:name];
    }
    value->options.applicationProtocols = names;
    return noErr;
}

OSStatus SSLGetSessionState(SSLContextRef context, SSLSessionState *state)
{
    if (!RevenantOwnsContext(context))
        RevenantDefer(SSLGetSessionState, errSecUnimplemented, context, state);
    return errSecUnimplemented;
}

OSStatus SSLSetSessionConfig(SSLContextRef context, CFStringRef config)
{
    if (!RevenantOwnsContext(context))
        RevenantDefer(SSLSetSessionConfig, errSecUnimplemented, context, config);
    return errSecUnimplemented;
}

OSStatus SSLSetProtocolVersionEnabled(SSLContextRef context, SSLProtocol protocol, Boolean enable)
{
    if (!RevenantOwnsContext(context))
        RevenantDefer(SSLSetProtocolVersionEnabled, errSecUnimplemented, context, protocol, enable);
    return errSecUnimplemented;
}

OSStatus SSLGetProtocolVersionEnabled(SSLContextRef context, SSLProtocol protocol, Boolean *enable)
{
    if (!RevenantOwnsContext(context))
        RevenantDefer(SSLGetProtocolVersionEnabled, errSecUnimplemented, context, protocol, enable);
    return errSecUnimplemented;
}

OSStatus SSLSetProtocolVersion(SSLContextRef context, SSLProtocol version)
{
    if (!RevenantOwnsContext(context))
        RevenantDefer(SSLSetProtocolVersion, errSecUnimplemented, context, version);
    return errSecUnimplemented;
}

OSStatus SSLGetProtocolVersion(SSLContextRef context, SSLProtocol *protocol)
{
    if (!RevenantOwnsContext(context))
        RevenantDefer(SSLGetProtocolVersion, errSecUnimplemented, context, protocol);
    return errSecUnimplemented;
}

OSStatus SSLSetCertificate(SSLContextRef context, CFArrayRef certRefs)
{
    if (!RevenantOwnsContext(context))
        RevenantDefer(SSLSetCertificate, errSecUnimplemented, context, certRefs);
    return errSecUnimplemented;
}

OSStatus SSLCopyRequestedPeerNameLength(SSLContextRef ctx, size_t *peerNameLen)
{
    if (!RevenantOwnsContext(ctx))
        RevenantDefer(SSLCopyRequestedPeerNameLength, errSecUnimplemented, ctx, peerNameLen);
    return errSecUnimplemented;
}

OSStatus SSLCopyRequestedPeerName(SSLContextRef context, char *peerName, size_t *peerNameLen)
{
    if (!RevenantOwnsContext(context))
        RevenantDefer(SSLCopyRequestedPeerName, errSecUnimplemented, context, peerName, peerNameLen);
    return errSecUnimplemented;
}

OSStatus SSLSetDatagramHelloCookie(SSLContextRef dtlsContext, const void *cookie, size_t cookieLen)
{
    if (!RevenantOwnsContext(dtlsContext))
        RevenantDefer(SSLSetDatagramHelloCookie, errSecUnimplemented, dtlsContext, cookie, cookieLen);
    return errSecUnimplemented;
}

OSStatus SSLSetMaxDatagramRecordSize(SSLContextRef dtlsContext, size_t maxSize)
{
    if (!RevenantOwnsContext(dtlsContext))
        RevenantDefer(SSLSetMaxDatagramRecordSize, errSecUnimplemented, dtlsContext, maxSize);
    return errSecUnimplemented;
}

OSStatus SSLGetMaxDatagramRecordSize(SSLContextRef dtlsContext, size_t *maxSize)
{
    if (!RevenantOwnsContext(dtlsContext))
        RevenantDefer(SSLGetMaxDatagramRecordSize, errSecUnimplemented, dtlsContext, maxSize);
    return errSecUnimplemented;
}

OSStatus SSLGetNumberSupportedCiphers(SSLContextRef context, size_t *numCiphers)
{
    if (!RevenantOwnsContext(context))
        RevenantDefer(SSLGetNumberSupportedCiphers, errSecUnimplemented, context, numCiphers);
    return errSecUnimplemented;
}

OSStatus SSLGetSupportedCiphers(SSLContextRef context, SSLCipherSuite *ciphers, size_t *numCiphers)
{
    if (!RevenantOwnsContext(context))
        RevenantDefer(SSLGetSupportedCiphers, errSecUnimplemented, context, ciphers, numCiphers);
    return errSecUnimplemented;
}

OSStatus SSLGetNumberEnabledCiphers(SSLContextRef context, size_t *numCiphers)
{
    if (!RevenantOwnsContext(context))
        RevenantDefer(SSLGetNumberEnabledCiphers, errSecUnimplemented, context, numCiphers);
    return errSecUnimplemented;
}

OSStatus SSLGetEnabledCiphers(SSLContextRef context, SSLCipherSuite *ciphers, size_t *numCiphers)
{
    if (!RevenantOwnsContext(context))
        RevenantDefer(SSLGetEnabledCiphers, errSecUnimplemented, context, ciphers, numCiphers);
    return errSecUnimplemented;
}

OSStatus SSLSetSessionTicketsEnabled(SSLContextRef context, Boolean enabled)
{
    if (!RevenantOwnsContext(context))
        RevenantDefer(SSLSetSessionTicketsEnabled, errSecUnimplemented, context, enabled);
    return errSecUnimplemented;
}

OSStatus SSLSetEnableCertVerify(SSLContextRef context, Boolean enableVerify)
{
    if (!RevenantOwnsContext(context))
        RevenantDefer(SSLSetEnableCertVerify, errSecUnimplemented, context, enableVerify);
    return errSecUnimplemented;
}

OSStatus SSLGetEnableCertVerify(SSLContextRef context, Boolean *enableVerify)
{
    if (!RevenantOwnsContext(context))
        RevenantDefer(SSLGetEnableCertVerify, errSecUnimplemented, context, enableVerify);
    return errSecUnimplemented;
}

OSStatus SSLSetAllowsExpiredCerts(SSLContextRef context, Boolean allowsExpired)
{
    if (!RevenantOwnsContext(context))
        RevenantDefer(SSLSetAllowsExpiredCerts, errSecUnimplemented, context, allowsExpired);
    return errSecUnimplemented;
}

OSStatus SSLGetAllowsExpiredCerts(SSLContextRef context, Boolean *allowsExpired)
{
    if (!RevenantOwnsContext(context))
        RevenantDefer(SSLGetAllowsExpiredCerts, errSecUnimplemented, context, allowsExpired);
    return errSecUnimplemented;
}

OSStatus SSLSetAllowsExpiredRoots(SSLContextRef context, Boolean allowsExpired)
{
    if (!RevenantOwnsContext(context))
        RevenantDefer(SSLSetAllowsExpiredRoots, errSecUnimplemented, context, allowsExpired);
    return errSecUnimplemented;
}

OSStatus SSLGetAllowsExpiredRoots(SSLContextRef context, Boolean *allowsExpired)
{
    if (!RevenantOwnsContext(context))
        RevenantDefer(SSLGetAllowsExpiredRoots, errSecUnimplemented, context, allowsExpired);
    return errSecUnimplemented;
}

OSStatus SSLSetAllowsAnyRoot(SSLContextRef context, Boolean anyRoot)
{
    if (!RevenantOwnsContext(context))
        RevenantDefer(SSLSetAllowsAnyRoot, errSecUnimplemented, context, anyRoot);
    return errSecUnimplemented;
}

OSStatus SSLGetAllowsAnyRoot(SSLContextRef context, Boolean *anyRoot)
{
    if (!RevenantOwnsContext(context))
        RevenantDefer(SSLGetAllowsAnyRoot, errSecUnimplemented, context, anyRoot);
    return errSecUnimplemented;
}

OSStatus SSLSetTrustedRoots(SSLContextRef context, CFArrayRef trustedRoots, Boolean replaceExisting)
{
    if (!RevenantOwnsContext(context))
        RevenantDefer(SSLSetTrustedRoots, errSecUnimplemented, context, trustedRoots, replaceExisting);
    return errSecUnimplemented;
}

OSStatus SSLCopyTrustedRoots(SSLContextRef context, CFArrayRef *trustedRoots)
{
    if (!RevenantOwnsContext(context))
        RevenantDefer(SSLCopyTrustedRoots, errSecUnimplemented, context, trustedRoots);
    return errSecUnimplemented;
}

OSStatus SSLCopyPeerCertificates(SSLContextRef context, CFArrayRef *certs)
{
    if (!RevenantOwnsContext(context))
        RevenantDefer(SSLCopyPeerCertificates, errSecUnimplemented, context, certs);
    return errSecUnimplemented;
}

OSStatus SSLSetPeerID(SSLContextRef context, const void *peerID, size_t peerIDLen)
{
    if (!RevenantOwnsContext(context))
        RevenantDefer(SSLSetPeerID, errSecUnimplemented, context, peerID, peerIDLen);
    return errSecUnimplemented;
}

OSStatus SSLGetPeerID(SSLContextRef context, const void **peerID, size_t *peerIDLen)
{
    if (!RevenantOwnsContext(context))
        RevenantDefer(SSLGetPeerID, errSecUnimplemented, context, peerID, peerIDLen);
    return errSecUnimplemented;
}

OSStatus SSLCopyALPNProtocols(SSLContextRef context, CFArrayRef *protocols)
{
    if (!RevenantOwnsContext(context))
        RevenantDefer(SSLCopyALPNProtocols, errSecUnimplemented, context, protocols);
    return errSecUnimplemented;
}

OSStatus SSLSetOCSPResponse(SSLContextRef context, CFDataRef response)
{
    if (!RevenantOwnsContext(context))
        RevenantDefer(SSLSetOCSPResponse, errSecUnimplemented, context, response);
    return errSecUnimplemented;
}

OSStatus SSLSetEncryptionCertificate(SSLContextRef context, CFArrayRef certRefs)
{
    if (!RevenantOwnsContext(context))
        RevenantDefer(SSLSetEncryptionCertificate, errSecUnimplemented, context, certRefs);
    return errSecUnimplemented;
}

OSStatus SSLSetClientSideAuthenticate(SSLContextRef context, SSLAuthenticate auth)
{
    if (!RevenantOwnsContext(context))
        RevenantDefer(SSLSetClientSideAuthenticate, errSecUnimplemented, context, auth);
    return errSecUnimplemented;
}

OSStatus SSLAddDistinguishedName(SSLContextRef context, const void *derDN, size_t derDNLen)
{
    if (!RevenantOwnsContext(context))
        RevenantDefer(SSLAddDistinguishedName, errSecUnimplemented, context, derDN, derDNLen);
    return errSecUnimplemented;
}

OSStatus SSLSetCertificateAuthorities(SSLContextRef context, CFTypeRef certificateOrArray, Boolean replaceExisting)
{
    if (!RevenantOwnsContext(context))
        RevenantDefer(SSLSetCertificateAuthorities, errSecUnimplemented, context, certificateOrArray, replaceExisting);
    return errSecUnimplemented;
}

OSStatus SSLCopyCertificateAuthorities(SSLContextRef context, CFArrayRef *certificates)
{
    if (!RevenantOwnsContext(context))
        RevenantDefer(SSLCopyCertificateAuthorities, errSecUnimplemented, context, certificates);
    return errSecUnimplemented;
}

OSStatus SSLCopyDistinguishedNames(SSLContextRef context, CFArrayRef *names)
{
    if (!RevenantOwnsContext(context))
        RevenantDefer(SSLCopyDistinguishedNames, errSecUnimplemented, context, names);
    return errSecUnimplemented;
}

OSStatus SSLGetClientCertificateState(SSLContextRef context, SSLClientCertificateState *clientState)
{
    if (!RevenantOwnsContext(context))
        RevenantDefer(SSLGetClientCertificateState, errSecUnimplemented, context, clientState);
    return errSecUnimplemented;
}

OSStatus SSLSetDiffieHellmanParams(SSLContextRef context, const void *dhParams, size_t dhParamsLen)
{
    if (!RevenantOwnsContext(context))
        RevenantDefer(SSLSetDiffieHellmanParams, errSecUnimplemented, context, dhParams, dhParamsLen);
    return errSecUnimplemented;
}

OSStatus SSLGetDiffieHellmanParams(SSLContextRef context, const void **dhParams, size_t *dhParamsLen)
{
    if (!RevenantOwnsContext(context))
        RevenantDefer(SSLGetDiffieHellmanParams, errSecUnimplemented, context, dhParams, dhParamsLen);
    return errSecUnimplemented;
}

OSStatus SSLSetRsaBlinding(SSLContextRef context, Boolean blinding)
{
    if (!RevenantOwnsContext(context))
        RevenantDefer(SSLSetRsaBlinding, errSecUnimplemented, context, blinding);
    return errSecUnimplemented;
}

OSStatus SSLGetRsaBlinding(SSLContextRef context, Boolean *blinding)
{
    if (!RevenantOwnsContext(context))
        RevenantDefer(SSLGetRsaBlinding, errSecUnimplemented, context, blinding);
    return errSecUnimplemented;
}

OSStatus SSLReHandshake(SSLContextRef context)
{
    if (!RevenantOwnsContext(context))
        RevenantDefer(SSLReHandshake, errSecUnimplemented, context);
    return errSecUnimplemented;
}

OSStatus SSLGetBufferedReadSize(SSLContextRef context, size_t *bufferSize)
{
    if (!RevenantOwnsContext(context))
        RevenantDefer(SSLGetBufferedReadSize, errSecUnimplemented, context, bufferSize);
    return errSecUnimplemented;
}

OSStatus SSLGetDatagramWriteSize(SSLContextRef dtlsContext, size_t *bufSize)
{
    if (!RevenantOwnsContext(dtlsContext))
        RevenantDefer(SSLGetDatagramWriteSize, errSecUnimplemented, dtlsContext, bufSize);
    return errSecUnimplemented;
}

OSStatus SSLSetError(SSLContextRef context, OSStatus status)
{
    if (!RevenantOwnsContext(context))
        RevenantDefer(SSLSetError, errSecUnimplemented, context, status);
    return errSecUnimplemented;
}
