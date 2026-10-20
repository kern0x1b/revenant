#import <Foundation/Foundation.h>
#import "RevenantNetworkAccess.h"
#import <objc/runtime.h>
#include <dlfcn.h>
#include <netinet/in.h>
#include <string.h>

static NSString *const RevenantExpensiveKey = @"RevenantAllowsExpensiveNetworkAccess";
static NSString *const RevenantConstrainedKey = @"RevenantAllowsConstrainedNetworkAccess";

static BOOL revenant_network_local(NSURL *URL)
{
    NSString *host = URL.host.lowercaseString;
    return [host isEqualToString:@"localhost"] || [host isEqualToString:@"127.0.0.1"] || [host isEqualToString:@"::1"] || !host;
}

__attribute__((visibility("hidden")))
@interface RevenantNetworkGate : NSURLProtocol
@end

@implementation RevenantNetworkGate

+ (BOOL)canInitWithRequest:(NSURLRequest *)request
{
    return ![request allowsExpensiveNetworkAccess] && revenant_network_cellular() && !revenant_network_local(request.URL);
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request
{
    return request;
}

- (void)startLoading
{
    NSURL *URL = self.request.URL;
    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    info[NSLocalizedDescriptionKey] = @"The Internet connection appears to be offline.";
    info[NSURLErrorNetworkUnavailableReasonKey] = @(NSURLErrorNetworkUnavailableReasonExpensive);
    if (URL) {
        info[NSURLErrorFailingURLErrorKey] = URL;
        info[NSURLErrorFailingURLStringErrorKey] = URL.absoluteString;
    }
    [self.client URLProtocol:self didFailWithError:[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorNotConnectedToInternet userInfo:info]];
}

- (void)stopLoading
{
}

@end

static void revenant_network_install(void)
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        [NSURLProtocol registerClass:[RevenantNetworkGate class]];
    });
}

static BOOL revenant_network_allows(NSURLRequest *request, NSString *key)
{
    NSNumber *value = [NSURLProtocol propertyForKey:key inRequest:request];
    return value ? value.boolValue : YES;
}

static void revenant_network_set(NSMutableURLRequest *request, NSString *key, BOOL allows)
{
    if (allows)
        [NSURLProtocol removePropertyForKey:key inRequest:request];
    else
        [NSURLProtocol setProperty:@NO forKey:key inRequest:request];
}

@implementation NSURLRequest (RevenantNetworkAccess)

- (BOOL)allowsExpensiveNetworkAccess
{
    return revenant_network_allows(self, RevenantExpensiveKey);
}

- (BOOL)allowsConstrainedNetworkAccess
{
    return revenant_network_allows(self, RevenantConstrainedKey);
}

@end

@implementation NSMutableURLRequest (RevenantNetworkAccess)

- (void)setAllowsExpensiveNetworkAccess:(BOOL)allows
{
    if (!allows)
        revenant_network_install();
    revenant_network_set(self, RevenantExpensiveKey, allows);
}

- (void)setAllowsConstrainedNetworkAccess:(BOOL)allows
{
    if (!allows)
        revenant_network_install();
    revenant_network_set(self, RevenantConstrainedKey, allows);
}

@end
