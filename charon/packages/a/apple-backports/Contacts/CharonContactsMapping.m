#import "CharonContacts.h"

#pragma clang diagnostic ignored "-Wdeprecated-declarations"

@implementation CharonContactsKeyDescriptor

@synthesize keys = _keys;

+ (instancetype)descriptorWithKeys:(NSArray<NSString *> *)keys
{
    CharonContactsKeyDescriptor *descriptor = [[CharonContactsKeyDescriptor alloc] init];
    descriptor->_keys = [keys copy];
    return descriptor;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_keys forKey:@"keys"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self)
        _keys = [[coder decodeObjectOfClass:[NSArray class] forKey:@"keys"] copy];
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

@end

@implementation CharonContacts

+ (NSDictionary<NSString *, NSNumber *> *)properties
{
    static NSDictionary *properties;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        properties = @{CNContactGivenNameKey: @(kABPersonFirstNameProperty),
                       CNContactFamilyNameKey: @(kABPersonLastNameProperty),
                       CNContactMiddleNameKey: @(kABPersonMiddleNameProperty),
                       CNContactNamePrefixKey: @(kABPersonPrefixProperty),
                       CNContactNameSuffixKey: @(kABPersonSuffixProperty),
                       CNContactNicknameKey: @(kABPersonNicknameProperty),
                       CNContactPhoneticGivenNameKey: @(kABPersonFirstNamePhoneticProperty),
                       CNContactPhoneticMiddleNameKey: @(kABPersonMiddleNamePhoneticProperty),
                       CNContactPhoneticFamilyNameKey: @(kABPersonLastNamePhoneticProperty),
                       CNContactOrganizationNameKey: @(kABPersonOrganizationProperty),
                       CNContactDepartmentNameKey: @(kABPersonDepartmentProperty),
                       CNContactJobTitleKey: @(kABPersonJobTitleProperty),
                       CNContactNoteKey: @(kABPersonNoteProperty),
                       CNContactBirthdayKey: @(kABPersonBirthdayProperty),
                       CNContactTypeKey: @(kABPersonKindProperty),
                       CNContactDatesKey: @(kABPersonDateProperty),
                       CNContactPhoneNumbersKey: @(kABPersonPhoneProperty),
                       CNContactEmailAddressesKey: @(kABPersonEmailProperty),
                       CNContactUrlAddressesKey: @(kABPersonURLProperty),
                       CNContactPostalAddressesKey: @(kABPersonAddressProperty),
                       CNContactRelationsKey: @(kABPersonRelatedNamesProperty),
                       CNContactSocialProfilesKey: @(kABPersonSocialProfileProperty),
                       CNContactInstantMessageAddressesKey: @(kABPersonInstantMessageProperty)};
    });
    return properties;
}

+ (NSArray<NSString *> *)contactKeys
{
    static NSArray *keys;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        keys = @[CNContactIdentifierKey, CNContactNamePrefixKey, CNContactGivenNameKey, CNContactMiddleNameKey,
                 CNContactFamilyNameKey, CNContactPreviousFamilyNameKey, CNContactNameSuffixKey, CNContactNicknameKey,
                 CNContactOrganizationNameKey, CNContactDepartmentNameKey, CNContactJobTitleKey,
                 CNContactPhoneticGivenNameKey, CNContactPhoneticMiddleNameKey, CNContactPhoneticFamilyNameKey,
                 CNContactBirthdayKey, CNContactNonGregorianBirthdayKey, CNContactNoteKey, CNContactImageDataKey,
                 CNContactThumbnailImageDataKey, CNContactImageDataAvailableKey, CNContactTypeKey,
                 CNContactPhoneNumbersKey, CNContactEmailAddressesKey, CNContactPostalAddressesKey, CNContactDatesKey,
                 CNContactUrlAddressesKey, CNContactRelationsKey, CNContactSocialProfilesKey,
                 CNContactInstantMessageAddressesKey];
    });
    return keys;
}

+ (ABPropertyID)propertyForKey:(NSString *)key
{
    NSNumber *found = key ? [self properties][key] : nil;
    return found ? found.intValue : kABPropertyInvalidID;
}

+ (NSString *)keyForProperty:(ABPropertyID)property
{
    for (NSString *key in [self properties]) {
        if ([[self properties][key] intValue] == property)
            return key;
    }
    return nil;
}

+ (BOOL)key:(NSString *)key holdsLabeledValues:(BOOL *)labeled
{
    static NSSet *multiple;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        multiple = [NSSet setWithArray:@[CNContactPhoneNumbersKey, CNContactEmailAddressesKey, CNContactPostalAddressesKey,
                                         CNContactUrlAddressesKey, CNContactRelationsKey, CNContactSocialProfilesKey,
                                         CNContactInstantMessageAddressesKey, CNContactDatesKey]];
    });
    if (labeled)
        *labeled = [multiple containsObject:key];
    return [[self properties] objectForKey:key] != nil;
}

+ (NSDictionary<NSString *, NSString *> *)services
{
    static NSDictionary *services;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        services = @{(__bridge NSString *)kABPersonSocialProfileServiceTwitter: CNSocialProfileServiceTwitter,
                     (__bridge NSString *)kABPersonSocialProfileServiceFacebook: CNSocialProfileServiceFacebook,
                     (__bridge NSString *)kABPersonSocialProfileServiceLinkedIn: CNSocialProfileServiceLinkedIn,
                     (__bridge NSString *)kABPersonSocialProfileServiceFlickr: CNSocialProfileServiceFlickr,
                     (__bridge NSString *)kABPersonSocialProfileServiceMyspace: CNSocialProfileServiceMySpace,
                     (__bridge NSString *)kABPersonSocialProfileServiceSinaWeibo: CNSocialProfileServiceSinaWeibo,
                     (__bridge NSString *)kABPersonSocialProfileServiceGameCenter: CNSocialProfileServiceGameCenter};
    });
    return services;
}

+ (NSString *)serviceForAddressBookService:(NSString *)service
{
    if (!service)
        return nil;
    NSString *found = [self services][service];
    return found ?: service;
}

+ (NSString *)addressBookServiceForService:(NSString *)service
{
    if (!service)
        return nil;
    for (NSString *spelled in [self services]) {
        if ([[self services][spelled] caseInsensitiveCompare:service] == NSOrderedSame)
            return spelled;
    }
    return service;
}

+ (NSDictionary *)addressBookAddressWithPostalAddress:(CNPostalAddress *)address
{
    NSMutableDictionary *found = [NSMutableDictionary dictionary];
    NSDictionary *fields = @{(__bridge NSString *)kABPersonAddressStreetKey: address.street ?: @"",
                             (__bridge NSString *)kABPersonAddressCityKey: address.city ?: @"",
                             (__bridge NSString *)kABPersonAddressStateKey: address.state ?: @"",
                             (__bridge NSString *)kABPersonAddressZIPKey: address.postalCode ?: @"",
                             (__bridge NSString *)kABPersonAddressCountryKey: address.country ?: @"",
                             (__bridge NSString *)kABPersonAddressCountryCodeKey: address.ISOCountryCode ?: @""};
    for (NSString *key in fields) {
        if ([fields[key] length] > 0)
            found[key] = fields[key];
    }
    return found;
}

+ (CNMutablePostalAddress *)postalAddressWithAddressBookAddress:(NSDictionary *)dictionary
{
    CNMutablePostalAddress *address = [[CNMutablePostalAddress alloc] init];
    address.street = dictionary[(__bridge NSString *)kABPersonAddressStreetKey] ?: @"";
    address.city = dictionary[(__bridge NSString *)kABPersonAddressCityKey] ?: @"";
    address.state = dictionary[(__bridge NSString *)kABPersonAddressStateKey] ?: @"";
    address.postalCode = dictionary[(__bridge NSString *)kABPersonAddressZIPKey] ?: @"";
    address.country = dictionary[(__bridge NSString *)kABPersonAddressCountryKey] ?: @"";
    address.ISOCountryCode = dictionary[(__bridge NSString *)kABPersonAddressCountryCodeKey] ?: @"";
    return address;
}

+ (NSDictionary *)addressBookProfileWithSocialProfile:(CNSocialProfile *)profile
{
    NSMutableDictionary *found = [NSMutableDictionary dictionary];
    if (profile.urlString.length > 0)
        found[(__bridge NSString *)kABPersonSocialProfileURLKey] = profile.urlString;
    if (profile.username.length > 0)
        found[(__bridge NSString *)kABPersonSocialProfileUsernameKey] = profile.username;
    if (profile.userIdentifier.length > 0)
        found[(__bridge NSString *)kABPersonSocialProfileUserIdentifierKey] = profile.userIdentifier;
    if (profile.service.length > 0)
        found[(__bridge NSString *)kABPersonSocialProfileServiceKey] = [self addressBookServiceForService:profile.service];
    return found;
}

+ (CNSocialProfile *)socialProfileWithAddressBookProfile:(NSDictionary *)dictionary
{
    return [[CNSocialProfile alloc] initWithUrlString:dictionary[(__bridge NSString *)kABPersonSocialProfileURLKey]
                                             username:dictionary[(__bridge NSString *)kABPersonSocialProfileUsernameKey]
                                       userIdentifier:dictionary[(__bridge NSString *)kABPersonSocialProfileUserIdentifierKey]
                                              service:[self serviceForAddressBookService:dictionary[(__bridge NSString *)kABPersonSocialProfileServiceKey]]];
}

+ (NSDictionary *)addressBookMessageWithInstantMessageAddress:(CNInstantMessageAddress *)address
{
    NSMutableDictionary *found = [NSMutableDictionary dictionary];
    if (address.username.length > 0)
        found[(__bridge NSString *)kABPersonInstantMessageUsernameKey] = address.username;
    if (address.service.length > 0)
        found[(__bridge NSString *)kABPersonInstantMessageServiceKey] = address.service;
    return found;
}

+ (CNInstantMessageAddress *)instantMessageAddressWithAddressBookMessage:(NSDictionary *)dictionary
{
    return [[CNInstantMessageAddress alloc] initWithUsername:dictionary[(__bridge NSString *)kABPersonInstantMessageUsernameKey] ?: @""
                                                     service:dictionary[(__bridge NSString *)kABPersonInstantMessageServiceKey] ?: @""];
}

+ (NSString *)digitsOfPhoneNumber:(NSString *)number
{
    if (!number)
        return @"";
    NSMutableString *digits = [NSMutableString string];
    for (NSUInteger index = 0; index < number.length; index++) {
        unichar one = [number characterAtIndex:index];
        if (one >= '0' && one <= '9')
            [digits appendFormat:@"%C", one];
    }
    return digits;
}

+ (NSCalendar *)gregorian
{
    static NSCalendar *calendar;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
    });
    return calendar;
}

+ (NSDateComponents *)componentsWithDate:(NSDate *)date
{
    if (!date)
        return nil;
    NSDateComponents *components = [[self gregorian] components:NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit
                                                       fromDate:date];
    components.calendar = [self gregorian];
    return components;
}

+ (NSDate *)dateWithComponents:(NSDateComponents *)components
{
    if (!components)
        return nil;
    NSDateComponents *copied = [components copy];
    copied.calendar = nil;
    copied.timeZone = nil;
    return [[self gregorian] dateFromComponents:copied];
}

+ (NSError *)errorWithCode:(CNErrorCode)code reason:(NSString *)reason
{
    NSDictionary *info = reason ? @{NSLocalizedDescriptionKey: reason} : nil;
    return [NSError errorWithDomain:CNErrorDomain code:code userInfo:info];
}

@end
