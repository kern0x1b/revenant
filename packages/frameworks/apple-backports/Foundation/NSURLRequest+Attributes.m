#import <Foundation/Foundation.h>
#import <objc/runtime.h>

typedef struct {
    __unsafe_unretained char *key;
    const char *name;
} RevenantRequestFlag;

static char RevenantRequestPersistentDNS;
static char RevenantRequestHTTP3;
static char RevenantRequestAttribution;
static char RevenantRequestPartition;
static char RevenantRequestDNSSEC;
static char RevenantRequestUltraConstrained;

@implementation NSURLRequest (RevenantAttributes)

- (BOOL)allowsPersistentDNS
{
    return [objc_getAssociatedObject(self, &RevenantRequestPersistentDNS) boolValue];
}

- (void)setAllowsPersistentDNS:(BOOL)allows
{
    objc_setAssociatedObject(self, &RevenantRequestPersistentDNS, @(allows), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)assumesHTTP3Capable
{
    return [objc_getAssociatedObject(self, &RevenantRequestHTTP3) boolValue];
}

- (void)setAssumesHTTP3Capable:(BOOL)assumes
{
    objc_setAssociatedObject(self, &RevenantRequestHTTP3, @(assumes), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)attribution
{
    return [objc_getAssociatedObject(self, &RevenantRequestAttribution) boolValue];
}

- (void)setAttribution:(BOOL)attribution
{
    objc_setAssociatedObject(self, &RevenantRequestAttribution, @(attribution), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSString *)cookiePartitionIdentifier
{
    return objc_getAssociatedObject(self, &RevenantRequestPartition);
}

- (void)setCookiePartitionIdentifier:(NSString *)identifier
{
    objc_setAssociatedObject(self, &RevenantRequestPartition, [identifier copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)requiresDNSSECValidation
{
    return [objc_getAssociatedObject(self, &RevenantRequestDNSSEC) boolValue];
}

- (void)setRequiresDNSSECValidation:(BOOL)requires
{
    objc_setAssociatedObject(self, &RevenantRequestDNSSEC, @(requires), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)allowsUltraConstrainedNetworkAccess
{
    return [objc_getAssociatedObject(self, &RevenantRequestUltraConstrained) boolValue];
}

- (void)setAllowsUltraConstrainedNetworkAccess:(BOOL)allows
{
    objc_setAssociatedObject(self, &RevenantRequestUltraConstrained, @(allows), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
