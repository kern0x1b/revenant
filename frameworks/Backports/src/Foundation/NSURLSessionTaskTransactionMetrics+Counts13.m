#import "RevenantURLSessionMetrics.h"
#include <SystemConfiguration/SystemConfiguration.h>
#import <objc/runtime.h>

static char RevenantTransactionCountsKey;
static char RevenantTransactionFlagsKey;
static char RevenantTransactionSocketKey;

@implementation NSURLSessionTaskTransactionMetrics (RevenantCounts)

- (void)revenant_noteBytesSent:(int64_t)sent beforeEncoding:(int64_t)before received:(int64_t)received
{
    NSMutableDictionary *counts = objc_getAssociatedObject(self, &RevenantTransactionCountsKey);
    if (!counts) {
        counts = [NSMutableDictionary dictionary];
        objc_setAssociatedObject(self, &RevenantTransactionCountsKey, counts, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    counts[@"sent"] = @(sent);
    counts[@"before"] = @(before);
    counts[@"received"] = @(received);
    counts[@"decoded"] = @(received);
}

- (void)revenant_noteConnectionReused:(BOOL)reused
{
    NSMutableDictionary *flags = objc_getAssociatedObject(self, &RevenantTransactionFlagsKey);
    if (!flags) {
        flags = [NSMutableDictionary dictionary];
        objc_setAssociatedObject(self, &RevenantTransactionFlagsKey, flags, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    flags[@"reused"] = @(reused);
}

- (void)revenant_noteInterfaceFlags:(BOOL)cellular expensive:(BOOL)expensive constrained:(BOOL)constrained proxy:(BOOL)proxy
{
    NSMutableDictionary *flags = objc_getAssociatedObject(self, &RevenantTransactionFlagsKey);
    if (!flags) {
        flags = [NSMutableDictionary dictionary];
        objc_setAssociatedObject(self, &RevenantTransactionFlagsKey, flags, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    flags[@"cellular"] = @(cellular);
    flags[@"expensive"] = @(expensive);
    flags[@"constrained"] = @(constrained);
    flags[@"proxy"] = @(proxy);
}

static int64_t revenant_count(NSDictionary *counts, NSString *key)
{
    return [counts[key] longLongValue];
}

- (void)revenant_noteSocketLocalAddress:(NSString *)address port:(NSNumber *)port
                        remoteAddress:(NSString *)remote remotePort:(NSNumber *)remotePortNumber
                    tlsProtocolVersion:(NSNumber *)version cipherSuite:(NSNumber *)cipher
{
    NSMutableDictionary *socket = objc_getAssociatedObject(self, &RevenantTransactionSocketKey);
    if (!socket) {
        socket = [NSMutableDictionary dictionary];
        objc_setAssociatedObject(self, &RevenantTransactionSocketKey, socket, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (address) socket[@"localAddress"] = address;
    if (port) socket[@"localPort"] = port;
    if (remote) socket[@"remoteAddress"] = remote;
    if (remotePortNumber) socket[@"remotePort"] = remotePortNumber;
    if (version) socket[@"tls"] = version;
    if (cipher) socket[@"cipher"] = cipher;
}

- (NSString *)localAddress { return objc_getAssociatedObject(self, &RevenantTransactionSocketKey)[@"localAddress"]; }
- (NSNumber *)localPort { return objc_getAssociatedObject(self, &RevenantTransactionSocketKey)[@"localPort"]; }
- (NSString *)remoteAddress { return objc_getAssociatedObject(self, &RevenantTransactionSocketKey)[@"remoteAddress"]; }
- (NSNumber *)remotePort { return objc_getAssociatedObject(self, &RevenantTransactionSocketKey)[@"remotePort"]; }
- (id)negotiatedTLSProtocolVersion { return objc_getAssociatedObject(self, &RevenantTransactionSocketKey)[@"tls"]; }
- (id)negotiatedTLSCipherSuite { return objc_getAssociatedObject(self, &RevenantTransactionSocketKey)[@"cipher"]; }

- (int64_t)countOfRequestBodyBytesSent { return revenant_count(objc_getAssociatedObject(self, &RevenantTransactionCountsKey), @"sent"); }
- (int64_t)countOfRequestBodyBytesBeforeEncoding { return revenant_count(objc_getAssociatedObject(self, &RevenantTransactionCountsKey), @"before"); }
- (int64_t)countOfResponseBodyBytesReceived { return revenant_count(objc_getAssociatedObject(self, &RevenantTransactionCountsKey), @"received"); }
- (int64_t)countOfResponseBodyBytesAfterDecoding { return revenant_count(objc_getAssociatedObject(self, &RevenantTransactionCountsKey), @"decoded"); }

- (BOOL)isCellular { return [objc_getAssociatedObject(self, &RevenantTransactionFlagsKey)[@"cellular"] boolValue]; }
- (BOOL)isExpensive { return [objc_getAssociatedObject(self, &RevenantTransactionFlagsKey)[@"expensive"] boolValue]; }
- (BOOL)isConstrained { return [objc_getAssociatedObject(self, &RevenantTransactionFlagsKey)[@"constrained"] boolValue]; }
- (BOOL)isProxyConnection { return [objc_getAssociatedObject(self, &RevenantTransactionFlagsKey)[@"proxy"] boolValue]; }
- (BOOL)isReusedConnection { return [objc_getAssociatedObject(self, &RevenantTransactionFlagsKey)[@"reused"] boolValue]; }

- (BOOL)isMultipath { return NO; }

- (NSURLSessionTaskMetricsDomainResolutionProtocol)domainResolutionProtocol
{
    return NSURLSessionTaskMetricsDomainResolutionProtocolUnknown;
}

@end
