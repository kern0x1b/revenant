#import <Foundation/Foundation.h>
#import <objc/runtime.h>

/* The request flags that arrived between iOS 13 and iOS 26. Each is kept beside the request, which is
   what the header promises: a request carries them and the session reads them.

   Three of the six the port's own session can honour -- allowsUltraConstrainedNetworkAccess joins
   allowsExpensiveAccess and allowsConstrainedAccess, which NSURLRequest+NetworkAccess13.m already
   reads; assumesHTTP3Capable is what the session would use to pick a protocol, and the port's
   session speaks HTTP/1.1 over the release's own NSURLConnection, so it is kept and reported rather
   than acted on. The other three -- allowsPersistentDNS, requiresDNSSECValidation and
   cookiePartitionIdentifier -- ask of the release's resolver, its TLS stack and its cookie storage
   things no 6.1.3 entry point takes, so they are kept for the application to read and the facts file
   says so. */

typedef struct {
    __unsafe_unretained char *key;
    const char *name;
} CharonRequestFlag;

static char CharonRequestPersistentDNS;
static char CharonRequestHTTP3;
static char CharonRequestAttribution;
static char CharonRequestPartition;
static char CharonRequestDNSSEC;
static char CharonRequestUltraConstrained;

@implementation NSURLRequest (CharonAttributes)

- (BOOL)allowsPersistentDNS
{
    return [objc_getAssociatedObject(self, &CharonRequestPersistentDNS) boolValue];
}

- (void)setAllowsPersistentDNS:(BOOL)allows
{
    objc_setAssociatedObject(self, &CharonRequestPersistentDNS, @(allows), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)assumesHTTP3Capable
{
    return [objc_getAssociatedObject(self, &CharonRequestHTTP3) boolValue];
}

- (void)setAssumesHTTP3Capable:(BOOL)assumes
{
    objc_setAssociatedObject(self, &CharonRequestHTTP3, @(assumes), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)attribution
{
    return [objc_getAssociatedObject(self, &CharonRequestAttribution) boolValue];
}

- (void)setAttribution:(BOOL)attribution
{
    objc_setAssociatedObject(self, &CharonRequestAttribution, @(attribution), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSString *)cookiePartitionIdentifier
{
    return objc_getAssociatedObject(self, &CharonRequestPartition);
}

- (void)setCookiePartitionIdentifier:(NSString *)identifier
{
    objc_setAssociatedObject(self, &CharonRequestPartition, [identifier copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)requiresDNSSECValidation
{
    return [objc_getAssociatedObject(self, &CharonRequestDNSSEC) boolValue];
}

- (void)setRequiresDNSSECValidation:(BOOL)requires
{
    objc_setAssociatedObject(self, &CharonRequestDNSSEC, @(requires), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)allowsUltraConstrainedNetworkAccess
{
    return [objc_getAssociatedObject(self, &CharonRequestUltraConstrained) boolValue];
}

- (void)setAllowsUltraConstrainedNetworkAccess:(BOOL)allows
{
    objc_setAssociatedObject(self, &CharonRequestUltraConstrained, @(allows), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
