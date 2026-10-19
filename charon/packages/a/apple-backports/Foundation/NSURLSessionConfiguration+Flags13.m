#import <Foundation/Foundation.h>
#import <objc/runtime.h>

/* The eight configuration settings of iOS 9 to 26 that the port's own configuration did not carry.
   Each is kept beside the configuration, which is what the header promises: a configuration carries
   them and a session built from it reads them.

   Which of them the port can act on is a question with a different answer each way, and the answer is
   here rather than in the reader's head:

   - `shouldUseExtendedBackgroundIdleMode` is read by the port's own session, which is the only thing
     that could idle a background session at all: the release has no such mode and the port's session
     is the code that would enter it.
   - The two TLS versions are read by the port's *stream* task, which negotiates its own TLS over the
     release's CFStream, and by nothing else: the port's data path runs over the release's own
     NSURLConnection, which is the system's TLS and takes no version from a port.
   - `requiresDNSSECValidation`, `allowsUltraConstrainedNetworkAccess` and `usesClassicLoadingMode`
     are kept and answered. The release's resolver validates what it validates, the release has no
     such validation to ask for, and the release's connection is not a port's to change; the value the
     application sets is the value it reads back.
   - `enablesEarlyData` and `multipathServiceType` are kept and answered for the same reason, and for a
     second one: 6.1.3 has neither early data nor multipath, so there is nothing here to switch on,
     and the header's own answer on a system without them is the default. */

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
