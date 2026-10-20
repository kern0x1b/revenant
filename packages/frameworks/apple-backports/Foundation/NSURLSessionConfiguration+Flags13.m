#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static char RevenantConfigurationExtendedBackgroundKey;
static char RevenantConfigurationTLSMaximumKey;
static char RevenantConfigurationTLSMinimumKey;
static char RevenantConfigurationDNSSECKey;
static char RevenantConfigurationUltraConstrainedKey;
static char RevenantConfigurationClassicLoadingKey;
static char RevenantConfigurationEarlyDataKey;
static char RevenantConfigurationMultipathKey;

@implementation NSURLSessionConfiguration (RevenantFlags)

- (BOOL)shouldUseExtendedBackgroundIdleMode
{
    return [objc_getAssociatedObject(self, &RevenantConfigurationExtendedBackgroundKey) boolValue];
}

- (void)setShouldUseExtendedBackgroundIdleMode:(BOOL)should
{
    objc_setAssociatedObject(self, &RevenantConfigurationExtendedBackgroundKey, @(should), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (id)TLSMaximumSupportedProtocolVersion
{
    return objc_getAssociatedObject(self, &RevenantConfigurationTLSMaximumKey);
}

- (void)setTLSMaximumSupportedProtocolVersion:(id)version
{
    objc_setAssociatedObject(self, &RevenantConfigurationTLSMaximumKey, version, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (id)TLSMinimumSupportedProtocolVersion
{
    return objc_getAssociatedObject(self, &RevenantConfigurationTLSMinimumKey);
}

- (void)setTLSMinimumSupportedProtocolVersion:(id)version
{
    objc_setAssociatedObject(self, &RevenantConfigurationTLSMinimumKey, version, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)requiresDNSSECValidation
{
    return [objc_getAssociatedObject(self, &RevenantConfigurationDNSSECKey) boolValue];
}

- (void)setRequiresDNSSECValidation:(BOOL)requires
{
    objc_setAssociatedObject(self, &RevenantConfigurationDNSSECKey, @(requires), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)allowsUltraConstrainedNetworkAccess
{
    return [objc_getAssociatedObject(self, &RevenantConfigurationUltraConstrainedKey) boolValue];
}

- (void)setAllowsUltraConstrainedNetworkAccess:(BOOL)allows
{
    objc_setAssociatedObject(self, &RevenantConfigurationUltraConstrainedKey, @(allows), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)usesClassicLoadingMode
{
    return [objc_getAssociatedObject(self, &RevenantConfigurationClassicLoadingKey) boolValue];
}

- (void)setUsesClassicLoadingMode:(BOOL)uses
{
    objc_setAssociatedObject(self, &RevenantConfigurationClassicLoadingKey, @(uses), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)enablesEarlyData
{
    return [objc_getAssociatedObject(self, &RevenantConfigurationEarlyDataKey) boolValue];
}

- (void)setEnablesEarlyData:(BOOL)enables
{
    objc_setAssociatedObject(self, &RevenantConfigurationEarlyDataKey, @(enables), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSURLSessionMultipathServiceType)multipathServiceType
{
    NSNumber *stored = objc_getAssociatedObject(self, &RevenantConfigurationMultipathKey);
    return (NSURLSessionMultipathServiceType)(stored ? stored.integerValue : NSURLSessionMultipathServiceTypeNone);
}

- (void)setMultipathServiceType:(NSURLSessionMultipathServiceType)type
{
    objc_setAssociatedObject(self, &RevenantConfigurationMultipathKey, @(type), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
