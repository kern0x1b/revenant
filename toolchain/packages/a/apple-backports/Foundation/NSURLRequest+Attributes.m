#import <Foundation/Foundation.h>
#import <objc/runtime.h>

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
