#import "CharonContacts.h"

#pragma clang diagnostic ignored "-Wincomplete-implementation"

@implementation CNPostalAddress {
@protected
    NSMutableDictionary *_charonFields;
}

@dynamic street, subLocality, city, subAdministrativeArea, state, postalCode, country, ISOCountryCode;

- (instancetype)init
{
    self = [super init];
    if (self)
        _charonFields = [NSMutableDictionary dictionary];
    return self;
}

- (NSString *)charon_fieldForKey:(NSString *)key
{
    return _charonFields[key] ?: @"";
}

- (void)charon_setField:(NSString *)value forKey:(NSString *)key
{
    if (value)
        _charonFields[key] = [value copy];
    else
        [_charonFields removeObjectForKey:key];
}

- (NSDictionary *)charon_fields
{
    return _charonFields;
}

- (NSString *)street { return [self charon_fieldForKey:CNPostalAddressStreetKey]; }
- (NSString *)subLocality { return [self charon_fieldForKey:CNPostalAddressSubLocalityKey]; }
- (NSString *)city { return [self charon_fieldForKey:CNPostalAddressCityKey]; }
- (NSString *)subAdministrativeArea { return [self charon_fieldForKey:CNPostalAddressSubAdministrativeAreaKey]; }
- (NSString *)state { return [self charon_fieldForKey:CNPostalAddressStateKey]; }
- (NSString *)postalCode { return [self charon_fieldForKey:CNPostalAddressPostalCodeKey]; }
- (NSString *)country { return [self charon_fieldForKey:CNPostalAddressCountryKey]; }
- (NSString *)ISOCountryCode { return [self charon_fieldForKey:CNPostalAddressISOCountryCodeKey]; }

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
    for (NSString *key in _charonFields)
        [copied charon_setField:_charonFields[key] forKey:key];
    return copied;
}

- (id)mutableCopyWithZone:(NSZone *)zone
{
    CNMutablePostalAddress *copied = [[CNMutablePostalAddress allocWithZone:zone] init];
    for (NSString *key in _charonFields)
        [copied charon_setField:_charonFields[key] forKey:key];
    return copied;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_charonFields forKey:@"fields"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [self init];
    if (self) {
        NSDictionary *fields = [coder decodeObjectOfClass:[NSDictionary class] forKey:@"fields"];
        _charonFields = [NSMutableDictionary dictionaryWithDictionary:fields ?: @{}];
    }
    return self;
}

- (BOOL)isEqual:(id)object
{
    return self == object || ([object isKindOfClass:[CNPostalAddress class]] && [_charonFields isEqualToDictionary:[object charon_fields]]);
}

- (NSUInteger)hash
{
    return _charonFields.hash;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p: %@>", NSStringFromClass([self class]), self, _charonFields];
}

@end
