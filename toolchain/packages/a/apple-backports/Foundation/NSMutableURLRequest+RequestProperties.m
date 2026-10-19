#import <Foundation/Foundation.h>

static NSString *const RevenantAttributionKey = @"RevenantAttribution";
static NSString *const RevenantRequiresDNSSECKey = @"RevenantRequiresDNSSECValidation";
static NSString *const RevenantPersistentDNSKey = @"RevenantAllowsPersistentDNS";
static NSString *const RevenantUltraConstrainedKey = @"RevenantAllowsUltraConstrainedNetworkAccess";
static NSString *const RevenantPartitionIdentifierKey = @"RevenantCookiePartitionIdentifier";

static BOOL revenant_request_flag(NSURLRequest *request, NSString *key)
{
    NSNumber *value = [NSURLProtocol propertyForKey:key inRequest:request];
    return value ? value.boolValue : NO;
}

static void revenant_request_set_flag(NSMutableURLRequest *request, NSString *key, BOOL flag)
{
    [NSURLProtocol setProperty:@(flag) forKey:key inRequest:request];
}

@implementation NSMutableURLRequest (RevenantRequestProperties)

- (NSURLRequestAttribution)attribution
{
    NSNumber *value = [NSURLProtocol propertyForKey:RevenantAttributionKey inRequest:self];
    return value ? (NSURLRequestAttribution)value.integerValue : NSURLRequestAttributionDeveloper;
}

- (void)setAttribution:(NSURLRequestAttribution)attribution
{
    [NSURLProtocol setProperty:@(attribution) forKey:RevenantAttributionKey inRequest:self];
}

- (BOOL)requiresDNSSECValidation
{
    return revenant_request_flag(self, RevenantRequiresDNSSECKey);
}

- (void)setRequiresDNSSECValidation:(BOOL)requires
{
    revenant_request_set_flag(self, RevenantRequiresDNSSECKey, requires);
}

- (BOOL)allowsPersistentDNS
{
    return revenant_request_flag(self, RevenantPersistentDNSKey);
}

- (void)setAllowsPersistentDNS:(BOOL)allows
{
    revenant_request_set_flag(self, RevenantPersistentDNSKey, allows);
}

- (BOOL)allowsUltraConstrainedNetworkAccess
{
    return revenant_request_flag(self, RevenantUltraConstrainedKey);
}

- (void)setAllowsUltraConstrainedNetworkAccess:(BOOL)allows
{
    revenant_request_set_flag(self, RevenantUltraConstrainedKey, allows);
}

- (NSString *)cookiePartitionIdentifier
{
    return [NSURLProtocol propertyForKey:RevenantPartitionIdentifierKey inRequest:self];
}

- (void)setCookiePartitionIdentifier:(NSString *)identifier
{
    [NSURLProtocol setProperty:identifier forKey:RevenantPartitionIdentifierKey inRequest:self];
}

@end
