#import "RevenantContacts.h"

#pragma clang diagnostic ignored "-Wincomplete-implementation"

@implementation CNPostalAddress {
@protected
    NSMutableDictionary *_revenantFields;
}

@dynamic street, subLocality, city, subAdministrativeArea, state, postalCode, country, ISOCountryCode;

- (instancetype)init
{
    self = [super init];
    if (self)
        _revenantFields = [NSMutableDictionary dictionary];
    return self;
}

- (NSString *)revenant_fieldForKey:(NSString *)key
{
    return _revenantFields[key] ?: @"";
}

- (void)revenant_setField:(NSString *)value forKey:(NSString *)key
{
    if (value)
        _revenantFields[key] = [value copy];
    else
        [_revenantFields removeObjectForKey:key];
}

- (NSDictionary *)revenant_fields
{
    return _revenantFields;
}

- (NSString *)street { return [self revenant_fieldForKey:CNPostalAddressStreetKey]; }
- (NSString *)subLocality { return [self revenant_fieldForKey:CNPostalAddressSubLocalityKey]; }
- (NSString *)city { return [self revenant_fieldForKey:CNPostalAddressCityKey]; }
- (NSString *)subAdministrativeArea { return [self revenant_fieldForKey:CNPostalAddressSubAdministrativeAreaKey]; }
- (NSString *)state { return [self revenant_fieldForKey:CNPostalAddressStateKey]; }
- (NSString *)postalCode { return [self revenant_fieldForKey:CNPostalAddressPostalCodeKey]; }
- (NSString *)country { return [self revenant_fieldForKey:CNPostalAddressCountryKey]; }
- (NSString *)ISOCountryCode { return [self revenant_fieldForKey:CNPostalAddressISOCountryCodeKey]; }

+ (NSString *)localizedStringForKey:(NSString *)key
{
    static NSDictionary *named;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        named = @{CNPostalAddressStreetKey: @"Street",
                  CNPostalAddressCityKey: @"City",
                  CNPostalAddressStateKey: @"State",
                  CNPostalAddressPostalCodeKey: @"ZIP",
                  CNPostalAddressCountryKey: @"Country",
                  CNPostalAddressISOCountryCodeKey: @"CountryCode"};
    });
    return named[key] ?: key;
}

- (id)copyWithZone:(NSZone *)zone
{
    CNPostalAddress *copied = [[CNPostalAddress allocWithZone:zone] init];
    for (NSString *key in _revenantFields)
        [copied revenant_setField:_revenantFields[key] forKey:key];
    return copied;
}

- (id)mutableCopyWithZone:(NSZone *)zone
{
    CNMutablePostalAddress *copied = [[CNMutablePostalAddress allocWithZone:zone] init];
    for (NSString *key in _revenantFields)
        [copied revenant_setField:_revenantFields[key] forKey:key];
    return copied;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_revenantFields forKey:@"fields"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [self init];
    if (self) {
        NSDictionary *fields = [coder decodeObjectOfClass:[NSDictionary class] forKey:@"fields"];
        _revenantFields = [NSMutableDictionary dictionaryWithDictionary:fields ?: @{}];
    }
    return self;
}

- (BOOL)isEqual:(id)object
{
    return self == object || ([object isKindOfClass:[CNPostalAddress class]] && [_revenantFields isEqualToDictionary:[object revenant_fields]]);
}

- (NSUInteger)hash
{
    return _revenantFields.hash;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p: %@>", NSStringFromClass([self class]), self, _revenantFields];
}

@end
