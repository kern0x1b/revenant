#import "CharonURLSessionMetrics.h"
#include <SystemConfiguration/SystemConfiguration.h>
#import <objc/runtime.h>

static char CharonTransactionCountsKey;
static char CharonTransactionFlagsKey;
static char CharonTransactionSocketKey;

@implementation NSURLSessionTaskTransactionMetrics (CharonCounts)

- (void)charon_noteBytesSent:(int64_t)sent beforeEncoding:(int64_t)before received:(int64_t)received
{
    NSMutableDictionary *counts = objc_getAssociatedObject(self, &CharonTransactionCountsKey);
    if (!counts) {
        counts = [NSMutableDictionary dictionary];
        objc_setAssociatedObject(self, &CharonTransactionCountsKey, counts, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    counts[@"sent"] = @(sent);
    counts[@"before"] = @(before);
    counts[@"received"] = @(received);
    counts[@"decoded"] = @(received);
}

- (void)charon_noteConnectionReused:(BOOL)reused
{
    NSMutableDictionary *flags = objc_getAssociatedObject(self, &CharonTransactionFlagsKey);
    if (!flags) {
        flags = [NSMutableDictionary dictionary];
        objc_setAssociatedObject(self, &CharonTransactionFlagsKey, flags, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    flags[@"reused"] = @(reused);
}

- (void)charon_noteInterfaceFlags:(BOOL)cellular expensive:(BOOL)expensive constrained:(BOOL)constrained proxy:(BOOL)proxy
{
    NSMutableDictionary *flags = objc_getAssociatedObject(self, &CharonTransactionFlagsKey);
    if (!flags) {
        flags = [NSMutableDictionary dictionary];
        objc_setAssociatedObject(self, &CharonTransactionFlagsKey, flags, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    flags[@"cellular"] = @(cellular);
    flags[@"expensive"] = @(expensive);
    flags[@"constrained"] = @(constrained);
    flags[@"proxy"] = @(proxy);
}

static int64_t charon_count(NSDictionary *counts, NSString *key)
{
    return [counts[key] longLongValue];
}

- (void)charon_noteSocketLocalAddress:(NSString *)address port:(NSNumber *)port
                        remoteAddress:(NSString *)remote remotePort:(NSNumber *)remotePortNumber
                    tlsProtocolVersion:(NSNumber *)version cipherSuite:(NSNumber *)cipher
{
    NSMutableDictionary *socket = objc_getAssociatedObject(self, &CharonTransactionSocketKey);
    if (!socket) {
        socket = [NSMutableDictionary dictionary];
        objc_setAssociatedObject(self, &CharonTransactionSocketKey, socket, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (address) socket[@"localAddress"] = address;
    if (port) socket[@"localPort"] = port;
    if (remote) socket[@"remoteAddress"] = remote;
    if (remotePortNumber) socket[@"remotePort"] = remotePortNumber;
    if (version) socket[@"tls"] = version;
    if (cipher) socket[@"cipher"] = cipher;
}

- (NSString *)localAddress { return objc_getAssociatedObject(self, &CharonTransactionSocketKey)[@"localAddress"]; }
- (NSNumber *)localPort { return objc_getAssociatedObject(self, &CharonTransactionSocketKey)[@"localPort"]; }
- (NSString *)remoteAddress { return objc_getAssociatedObject(self, &CharonTransactionSocketKey)[@"remoteAddress"]; }
- (NSNumber *)remotePort { return objc_getAssociatedObject(self, &CharonTransactionSocketKey)[@"remotePort"]; }
- (id)negotiatedTLSProtocolVersion { return objc_getAssociatedObject(self, &CharonTransactionSocketKey)[@"tls"]; }
- (id)negotiatedTLSCipherSuite { return objc_getAssociatedObject(self, &CharonTransactionSocketKey)[@"cipher"]; }

- (int64_t)countOfRequestBodyBytesSent { return charon_count(objc_getAssociatedObject(self, &CharonTransactionCountsKey), @"sent"); }
- (int64_t)countOfRequestBodyBytesBeforeEncoding { return charon_count(objc_getAssociatedObject(self, &CharonTransactionCountsKey), @"before"); }
- (int64_t)countOfResponseBodyBytesReceived { return charon_count(objc_getAssociatedObject(self, &CharonTransactionCountsKey), @"received"); }
- (int64_t)countOfResponseBodyBytesAfterDecoding { return charon_count(objc_getAssociatedObject(self, &CharonTransactionCountsKey), @"decoded"); }

- (BOOL)isCellular { return [objc_getAssociatedObject(self, &CharonTransactionFlagsKey)[@"cellular"] boolValue]; }
- (BOOL)isExpensive { return [objc_getAssociatedObject(self, &CharonTransactionFlagsKey)[@"expensive"] boolValue]; }
- (BOOL)isConstrained { return [objc_getAssociatedObject(self, &CharonTransactionFlagsKey)[@"constrained"] boolValue]; }
- (BOOL)isProxyConnection { return [objc_getAssociatedObject(self, &CharonTransactionFlagsKey)[@"proxy"] boolValue]; }
- (BOOL)isReusedConnection { return [objc_getAssociatedObject(self, &CharonTransactionFlagsKey)[@"reused"] boolValue]; }

- (BOOL)isMultipath { return NO; }

- (NSURLSessionTaskMetricsDomainResolutionProtocol)domainResolutionProtocol
{
    return NSURLSessionTaskMetricsDomainResolutionProtocolUnknown;
}

@end
