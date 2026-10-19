#import <Foundation/Foundation.h>
#import "CharonNetworkAccess.h"
#import <objc/runtime.h>
#include <dlfcn.h>
#include <netinet/in.h>
#include <string.h>

/* The two keys the port keeps the expensive and constrained answers under, beside the category that
   reads them. */
static NSString *const CharonExpensiveKey = @"CharonAllowsExpensiveNetworkAccess";
static NSString *const CharonConstrainedKey = @"CharonAllowsConstrainedNetworkAccess";

static BOOL charon_network_local(NSURL *URL)
{
    NSString *host = URL.host.lowercaseString;
    return [host isEqualToString:@"localhost"] || [host isEqualToString:@"127.0.0.1"] || [host isEqualToString:@"::1"] || !host;
}

__attribute__((visibility("hidden")))
@interface CharonNetworkGate : NSURLProtocol
@end

@implementation CharonNetworkGate

+ (BOOL)canInitWithRequest:(NSURLRequest *)request
{
    return ![request allowsExpensiveNetworkAccess] && charon_network_cellular() && !charon_network_local(request.URL);
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

static void charon_network_install(void)
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        [NSURLProtocol registerClass:[CharonNetworkGate class]];
    });
}

static BOOL charon_network_allows(NSURLRequest *request, NSString *key)
{
    NSNumber *value = [NSURLProtocol propertyForKey:key inRequest:request];
    return value ? value.boolValue : YES;
}

static void charon_network_set(NSMutableURLRequest *request, NSString *key, BOOL allows)
{
    if (allows)
        [NSURLProtocol removePropertyForKey:key inRequest:request];
    else
        [NSURLProtocol setProperty:@NO forKey:key inRequest:request];
}

@implementation NSURLRequest (CharonNetworkAccess)

- (BOOL)allowsExpensiveNetworkAccess
{
    return charon_network_allows(self, CharonExpensiveKey);
}

- (BOOL)allowsConstrainedNetworkAccess
{
    return charon_network_allows(self, CharonConstrainedKey);
}

@end

@implementation NSMutableURLRequest (CharonNetworkAccess)

- (void)setAllowsExpensiveNetworkAccess:(BOOL)allows
{
    if (!allows)
        charon_network_install();
    charon_network_set(self, CharonExpensiveKey, allows);
}

- (void)setAllowsConstrainedNetworkAccess:(BOOL)allows
{
    if (!allows)
        charon_network_install();
    charon_network_set(self, CharonConstrainedKey, allows);
}

@end
