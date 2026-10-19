#import <Foundation/Foundation.h>

/* The five request properties of iOS 15 to 26.1, carried the way `allowsExpensiveNetworkAccess` and
   `allowsConstrainedNetworkAccess` are in NSURLRequest+NetworkAccess13.m: the value rides on the
   request under a key it already carries, so a copy of the request keeps it.

   The defaults are the host's own, measured name by name in tests/backports/host/netext-requests/:
   four fresh BOOL properties answer NO and the partition identifier answers nil, and setting the other
   value reads back - which is what tells a carried property from one that only answers a default.
   `attribution` is the enumeration the 16.4 SDK declares - `NSURLRequestAttributionDeveloper` is 0
   and `NSURLRequestAttributionUser` is 1 - so a fresh request answers Developer, which is what the
   host answered for the BOOL read of the same property. */

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
    /* Stored, not encoded as absence: these default to NO, so "the key is not there" and "the caller
       set NO" would be the same reading and a YES would have nowhere to go. The two flags that
       default to YES in NSURLRequest+NetworkAccess13.m do it the other way round, which is why the
       two do not share this helper. */
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
