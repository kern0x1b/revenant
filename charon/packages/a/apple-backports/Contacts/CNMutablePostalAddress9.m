#import "CharonContacts.h"

#pragma clang diagnostic ignored "-Wincomplete-implementation"

@implementation CNMutablePostalAddress

@dynamic street, subLocality, city, subAdministrativeArea, state, postalCode, country, ISOCountryCode;

- (void)setStreet:(NSString *)value { [self charon_setField:value forKey:CNPostalAddressStreetKey]; }
- (void)setSubLocality:(NSString *)value { [self charon_setField:value forKey:CNPostalAddressSubLocalityKey]; }
- (void)setCity:(NSString *)value { [self charon_setField:value forKey:CNPostalAddressCityKey]; }
- (void)setSubAdministrativeArea:(NSString *)value { [self charon_setField:value forKey:CNPostalAddressSubAdministrativeAreaKey]; }
- (void)setState:(NSString *)value { [self charon_setField:value forKey:CNPostalAddressStateKey]; }
- (void)setPostalCode:(NSString *)value { [self charon_setField:value forKey:CNPostalAddressPostalCodeKey]; }
- (void)setCountry:(NSString *)value { [self charon_setField:value forKey:CNPostalAddressCountryKey]; }
- (void)setISOCountryCode:(NSString *)value { [self charon_setField:value forKey:CNPostalAddressISOCountryCodeKey]; }

@end
