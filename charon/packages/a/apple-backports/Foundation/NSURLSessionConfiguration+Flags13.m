#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static char CharonConfigurationExtendedBackgroundKey;
static char CharonConfigurationTLSMaximumKey;
static char CharonConfigurationTLSMinimumKey;
static char CharonConfigurationDNSSECKey;
static char CharonConfigurationUltraConstrainedKey;
static char CharonConfigurationClassicLoadingKey;
static char CharonConfigurationEarlyDataKey;
static char CharonConfigurationMultipathKey;

@implementation NSURLSessionConfiguration (CharonFlags)

- (BOOL)shouldUseExtendedBackgroundIdleMode
{
    return [objc_getAssociatedObject(self, &CharonConfigurationExtendedBackgroundKey) boolValue];
}

- (void)setShouldUseExtendedBackgroundIdleMode:(BOOL)should
{
    objc_setAssociatedObject(self, &CharonConfigurationExtendedBackgroundKey, @(should), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (id)TLSMaximumSupportedProtocolVersion
{
    return objc_getAssociatedObject(self, &CharonConfigurationTLSMaximumKey);
}

- (void)setTLSMaximumSupportedProtocolVersion:(id)version
{
    objc_setAssociatedObject(self, &CharonConfigurationTLSMaximumKey, version, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (id)TLSMinimumSupportedProtocolVersion
{
    return objc_getAssociatedObject(self, &CharonConfigurationTLSMinimumKey);
}

- (void)setTLSMinimumSupportedProtocolVersion:(id)version
{
    objc_setAssociatedObject(self, &CharonConfigurationTLSMinimumKey, version, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)requiresDNSSECValidation
{
    return [objc_getAssociatedObject(self, &CharonConfigurationDNSSECKey) boolValue];
}

- (void)setRequiresDNSSECValidation:(BOOL)requires
{
    objc_setAssociatedObject(self, &CharonConfigurationDNSSECKey, @(requires), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)allowsUltraConstrainedNetworkAccess
{
    return [objc_getAssociatedObject(self, &CharonConfigurationUltraConstrainedKey) boolValue];
}

- (void)setAllowsUltraConstrainedNetworkAccess:(BOOL)allows
{
    objc_setAssociatedObject(self, &CharonConfigurationUltraConstrainedKey, @(allows), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)usesClassicLoadingMode
{
    return [objc_getAssociatedObject(self, &CharonConfigurationClassicLoadingKey) boolValue];
}

- (void)setUsesClassicLoadingMode:(BOOL)uses
{
    objc_setAssociatedObject(self, &CharonConfigurationClassicLoadingKey, @(uses), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)enablesEarlyData
{
    return [objc_getAssociatedObject(self, &CharonConfigurationEarlyDataKey) boolValue];
}

- (void)setEnablesEarlyData:(BOOL)enables
{
    objc_setAssociatedObject(self, &CharonConfigurationEarlyDataKey, @(enables), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSURLSessionMultipathServiceType)multipathServiceType
{
    NSNumber *stored = objc_getAssociatedObject(self, &CharonConfigurationMultipathKey);
    return (NSURLSessionMultipathServiceType)(stored ? stored.integerValue : NSURLSessionMultipathServiceTypeNone);
}

- (void)setMultipathServiceType:(NSURLSessionMultipathServiceType)type
{
    objc_setAssociatedObject(self, &CharonConfigurationMultipathKey, @(type), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
