#import <Foundation/Foundation.h>

static NSString *const CharonAttributionKey = @"CharonAttribution";
static NSString *const CharonRequiresDNSSECKey = @"CharonRequiresDNSSECValidation";
static NSString *const CharonPersistentDNSKey = @"CharonAllowsPersistentDNS";
static NSString *const CharonUltraConstrainedKey = @"CharonAllowsUltraConstrainedNetworkAccess";
static NSString *const CharonPartitionIdentifierKey = @"CharonCookiePartitionIdentifier";

static BOOL charon_request_flag(NSURLRequest *request, NSString *key)
{
    NSNumber *value = [NSURLProtocol propertyForKey:key inRequest:request];
    return value ? value.boolValue : NO;
}

static void charon_request_set_flag(NSMutableURLRequest *request, NSString *key, BOOL flag)
{
    [NSURLProtocol setProperty:@(flag) forKey:key inRequest:request];
}

@implementation NSMutableURLRequest (CharonRequestProperties)

- (NSURLRequestAttribution)attribution
{
    NSNumber *value = [NSURLProtocol propertyForKey:CharonAttributionKey inRequest:self];
    return value ? (NSURLRequestAttribution)value.integerValue : NSURLRequestAttributionDeveloper;
}

- (void)setAttribution:(NSURLRequestAttribution)attribution
{
    [NSURLProtocol setProperty:@(attribution) forKey:CharonAttributionKey inRequest:self];
}

- (BOOL)requiresDNSSECValidation
{
    return charon_request_flag(self, CharonRequiresDNSSECKey);
}

- (void)setRequiresDNSSECValidation:(BOOL)requires
{
    charon_request_set_flag(self, CharonRequiresDNSSECKey, requires);
}

- (BOOL)allowsPersistentDNS
{
    return charon_request_flag(self, CharonPersistentDNSKey);
}

- (void)setAllowsPersistentDNS:(BOOL)allows
{
    charon_request_set_flag(self, CharonPersistentDNSKey, allows);
}

- (BOOL)allowsUltraConstrainedNetworkAccess
{
    return charon_request_flag(self, CharonUltraConstrainedKey);
}

- (void)setAllowsUltraConstrainedNetworkAccess:(BOOL)allows
{
    charon_request_set_flag(self, CharonUltraConstrainedKey, allows);
}

- (NSString *)cookiePartitionIdentifier
{
    return [NSURLProtocol propertyForKey:CharonPartitionIdentifierKey inRequest:self];
}

- (void)setCookiePartitionIdentifier:(NSString *)identifier
{
    [NSURLProtocol setProperty:identifier forKey:CharonPartitionIdentifierKey inRequest:self];
}

@end
