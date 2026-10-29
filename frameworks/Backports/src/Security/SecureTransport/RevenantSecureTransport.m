#import <Foundation/Foundation.h>
#import <Security/SecureTransport.h>
#import <Security/SecTrust.h>
#import <stdio.h>
#import <string.h>
#import "../../TLS/RevenantSecProtocolOptions.h"
#import "../../TLS/RevenantTLS/RevenantTLSEngine.h"

@interface RevenantSSLContext : NSObject {
@public
    RevenantSecProtocolOptions *options;
    SSLConnectionRef connection;
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
    if (protocolSide != kSSLClientSide || connectionType != kSSLStreamType)
        return NULL;
    RevenantSSLContext *context = [[RevenantSSLContext alloc] init];
    context->options = [[RevenantSecProtocolOptions alloc] init];
    return (SSLContextRef)(__bridge_retained void *)context;
}

OSStatus SSLDisposeContext(SSLContextRef context)
{
    RevenantSSLContext *value = (__bridge_transfer RevenantSSLContext *)(void *)context;
    if (!value)
        return errSecParam;
    return noErr;
}

OSStatus SSLSetConnection(SSLContextRef context, SSLConnectionRef connection)
{
    RevenantSSLContext *value = RevenantSSLOf(context);
    if (!value)
        return errSecParam;
    if (value->engine)
        return errSSLBadConfiguration;
    value->connection = connection;
    return noErr;
}

OSStatus SSLGetConnection(SSLContextRef context, SSLConnectionRef *connection)
{
    RevenantSSLContext *value = RevenantSSLOf(context);
    if (!value || !connection)
        return errSecParam;
    *connection = value->connection;
    return noErr;
}

OSStatus SSLSetPeerDomainName(SSLContextRef context, const char *peerName, size_t peerNameLen)
{
    RevenantSSLContext *value = RevenantSSLOf(context);
    if (!value || (!peerName && peerNameLen))
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
    RevenantSSLContext *value = RevenantSSLOf(context);
    if (!value || !peerNameLen)
        return errSecParam;
    *peerNameLen = [value->peerDomainName lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
    return noErr;
}

OSStatus SSLGetPeerDomainName(SSLContextRef context, char *peerName, size_t *peerNameLen)
{
    RevenantSSLContext *value = RevenantSSLOf(context);
    if (!value || !peerName || !peerNameLen)
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
    RevenantSSLContext *value = RevenantSSLOf(context);
    uint16_t version = 0;
    if (!value || !RevenantWireVersion(minVersion, &version))
        return errSecParam;
    if (value->engine)
        return errSSLBadConfiguration;
    value->options.minTLSVersion = version;
    return noErr;
}

OSStatus SSLSetProtocolVersionMax(SSLContextRef context, SSLProtocol maxVersion)
{
    RevenantSSLContext *value = RevenantSSLOf(context);
    uint16_t version = 0;
    if (!value || !RevenantWireVersion(maxVersion, &version))
        return errSecParam;
    if (value->engine)
        return errSSLBadConfiguration;
    value->options.maxTLSVersion = version;
    return noErr;
}

OSStatus SSLSetEnabledCiphers(SSLContextRef context, const SSLCipherSuite *ciphers, size_t numCiphers)
{
    RevenantSSLContext *value = RevenantSSLOf(context);
    if (!value || (!ciphers && numCiphers))
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
    RevenantSSLContext *target = RevenantSSLOf(context);
    if (!target)
        return errSecParam;
    if (target->engine)
        return errSSLBadConfiguration;
    if (option != kSSLSessionOptionBreakOnServerAuth)
        return errSecUnimplemented;
    target->options.breaksOnServerAuth = value;
    return noErr;
}

OSStatus SSLHandshake(SSLContextRef context)
{
    RevenantSSLContext *value = RevenantSSLOf(context);
    if (!value)
        return errSecParam;
    if (!value->engine) {
        char reason[512] = "";
        OSStatus status = noErr;
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
    RevenantSSLContext *value = RevenantSSLOf(context);
    if (!value || !processed)
        return errSecParam;
    if (!value->engine || !RevenantTLSEngineIsEstablished(value->engine))
        return errSSLProtocol;
    return RevenantTLSEngineRead(value->engine, data, dataLength, processed);
}

OSStatus SSLWrite(SSLContextRef context, const void *data, size_t dataLength, size_t *processed)
{
    RevenantSSLContext *value = RevenantSSLOf(context);
    if (!value || !processed)
        return errSecParam;
    if (!value->engine || !RevenantTLSEngineIsEstablished(value->engine))
        return errSSLProtocol;
    return RevenantTLSEngineWrite(value->engine, data, dataLength, processed);
}

OSStatus SSLClose(SSLContextRef context)
{
    RevenantSSLContext *value = RevenantSSLOf(context);
    if (!value)
        return errSecParam;
    if (value->engine)
        RevenantTLSEngineClose(value->engine);
    return noErr;
}

OSStatus SSLGetNegotiatedProtocolVersion(SSLContextRef context, SSLProtocol *protocol)
{
    RevenantSSLContext *value = RevenantSSLOf(context);
    if (!value || !protocol)
        return errSecParam;
    uint16_t version = value->engine ? RevenantTLSEngineNegotiatedVersion(value->engine) : 0;
    *protocol = RevenantProtocolOfWireVersion(version);
    return noErr;
}

OSStatus SSLGetNegotiatedCipher(SSLContextRef context, SSLCipherSuite *cipherSuite)
{
    RevenantSSLContext *value = RevenantSSLOf(context);
    if (!value || !cipherSuite)
        return errSecParam;
    *cipherSuite = value->engine ? RevenantTLSEngineNegotiatedCipherSuite(value->engine) : 0;
    return noErr;
}

OSStatus SSLCopyPeerTrust(SSLContextRef context, SecTrustRef *trust)
{
    RevenantSSLContext *value = RevenantSSLOf(context);
    if (!value || !trust)
        return errSecParam;
    *trust = value->engine ? (SecTrustRef)RevenantTLSEngineCopyPeerTrust(value->engine) : NULL;
    return noErr;
}
