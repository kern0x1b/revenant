#import "CharonContacts.h"

#pragma clang diagnostic ignored "-Wincomplete-implementation"
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

@implementation CNContact {
@protected
    NSMutableDictionary *_charonValues;
    NSSet *_charonAvailable;
    NSString *_charonIdentifier;
    NSArray *_charonLinked;
}

@dynamic identifier, contactType, namePrefix, givenName, middleName, familyName, previousFamilyName, nameSuffix,
         nickname, organizationName, departmentName, jobTitle, phoneticGivenName, phoneticMiddleName,
         phoneticFamilyName, phoneticOrganizationName, note, imageData, thumbnailImageData, imageDataAvailable,
         phoneNumbers, emailAddresses, postalAddresses, urlAddresses, contactRelations, socialProfiles,
         instantMessageAddresses, birthday, nonGregorianBirthday, dates;

- (instancetype)init
{
    self = [super init];
    if (self) {
        _charonValues = [NSMutableDictionary dictionary];
        _charonIdentifier = [[NSUUID UUID] UUIDString];
    }
    return self;
}

- (id)charon_valueForContactKey:(NSString *)key
{
    if (_charonAvailable && ![_charonAvailable containsObject:key]) {
        [NSException raise:CNContactPropertyNotFetchedExceptionName
                    format:@"A property was not requested when contact was fetched: %@", key];
    }
    return _charonValues[key];
}

- (void)charon_setValue:(id)value forContactKey:(NSString *)key
{
    if (value)
        _charonValues[key] = value;
    else
        [_charonValues removeObjectForKey:key];
    if (_charonAvailable && ![_charonAvailable containsObject:key])
        _charonAvailable = [_charonAvailable setByAddingObject:key];
}

- (NSDictionary *)charon_values
{
    return _charonValues;
}

- (NSSet *)charon_availableKeys
{
    return _charonAvailable;
}

- (void)charon_setValues:(NSDictionary *)values available:(NSSet *)keys identifier:(NSString *)identifier
{
    _charonValues = [NSMutableDictionary dictionaryWithDictionary:values];
    _charonAvailable = [keys copy];
    if (identifier)
        _charonIdentifier = [identifier copy];
}

- (NSArray<NSString *> *)charon_linkedIdentifiers
{
    return _charonLinked ?: @[];
}

- (void)charon_setLinkedIdentifiers:(NSArray<NSString *> *)identifiers
{
    _charonLinked = [identifiers copy];
}

- (NSString *)charon_stringForKey:(NSString *)key
{
    return [self charon_valueForContactKey:key] ?: @"";
}

- (NSArray *)charon_arrayForKey:(NSString *)key
{
    return [self charon_valueForContactKey:key] ?: @[];
}

- (NSString *)identifier
{
    return _charonIdentifier;
}

- (CNContactType)contactType
{
    return (CNContactType)[[self charon_valueForContactKey:CNContactTypeKey] integerValue];
}

- (NSString *)namePrefix { return [self charon_stringForKey:CNContactNamePrefixKey]; }
- (NSString *)givenName { return [self charon_stringForKey:CNContactGivenNameKey]; }
- (NSString *)middleName { return [self charon_stringForKey:CNContactMiddleNameKey]; }
- (NSString *)familyName { return [self charon_stringForKey:CNContactFamilyNameKey]; }
- (NSString *)previousFamilyName { return [self charon_stringForKey:CNContactPreviousFamilyNameKey]; }
- (NSString *)nameSuffix { return [self charon_stringForKey:CNContactNameSuffixKey]; }
- (NSString *)nickname { return [self charon_stringForKey:CNContactNicknameKey]; }
- (NSString *)organizationName { return [self charon_stringForKey:CNContactOrganizationNameKey]; }
- (NSString *)departmentName { return [self charon_stringForKey:CNContactDepartmentNameKey]; }
- (NSString *)jobTitle { return [self charon_stringForKey:CNContactJobTitleKey]; }
- (NSString *)phoneticGivenName { return [self charon_stringForKey:CNContactPhoneticGivenNameKey]; }
- (NSString *)phoneticMiddleName { return [self charon_stringForKey:CNContactPhoneticMiddleNameKey]; }
- (NSString *)phoneticFamilyName { return [self charon_stringForKey:CNContactPhoneticFamilyNameKey]; }
- (NSString *)phoneticOrganizationName { return [self charon_stringForKey:CNContactPhoneticOrganizationNameKey]; }
- (NSString *)note { return [self charon_stringForKey:CNContactNoteKey]; }

- (NSData *)imageData { return [self charon_valueForContactKey:CNContactImageDataKey]; }
- (NSData *)thumbnailImageData { return [self charon_valueForContactKey:CNContactThumbnailImageDataKey]; }

- (BOOL)imageDataAvailable
{
    return [[self charon_valueForContactKey:CNContactImageDataAvailableKey] boolValue];
}

- (NSArray *)phoneNumbers { return [self charon_arrayForKey:CNContactPhoneNumbersKey]; }
- (NSArray *)emailAddresses { return [self charon_arrayForKey:CNContactEmailAddressesKey]; }
- (NSArray *)postalAddresses { return [self charon_arrayForKey:CNContactPostalAddressesKey]; }
- (NSArray *)urlAddresses { return [self charon_arrayForKey:CNContactUrlAddressesKey]; }
- (NSArray *)contactRelations { return [self charon_arrayForKey:CNContactRelationsKey]; }
- (NSArray *)socialProfiles { return [self charon_arrayForKey:CNContactSocialProfilesKey]; }
- (NSArray *)instantMessageAddresses { return [self charon_arrayForKey:CNContactInstantMessageAddressesKey]; }
- (NSArray *)dates { return [self charon_arrayForKey:CNContactDatesKey]; }

- (NSDateComponents *)birthday { return [self charon_valueForContactKey:CNContactBirthdayKey]; }
- (NSDateComponents *)nonGregorianBirthday { return [self charon_valueForContactKey:CNContactNonGregorianBirthdayKey]; }

- (BOOL)isKeyAvailable:(NSString *)key
{
    return _charonAvailable == nil || [_charonAvailable containsObject:key];
}

- (BOOL)areKeysAvailable:(NSArray *)keyDescriptors
{
    for (id descriptor in keyDescriptors) {
        if ([descriptor isKindOfClass:[NSString class]] && ![self isKeyAvailable:descriptor])
            return NO;
    }
    return YES;
}

- (BOOL)isUnifiedWithContactWithIdentifier:(NSString *)contactIdentifier
{
    return [_charonIdentifier isEqualToString:contactIdentifier] || [_charonLinked containsObject:contactIdentifier];
}

+ (NSPredicate *)predicateForContactsMatchingName:(NSString *)name
{
    return [CharonContactPredicate predicateWithMatch:CharonContactMatchName value:[name copy]];
}

+ (NSPredicate *)predicateForContactsWithIdentifiers:(NSArray<NSString *> *)identifiers
{
    return [CharonContactPredicate predicateWithMatch:CharonContactMatchIdentifiers value:[identifiers copy]];
}

+ (NSPredicate *)predicateForContactsInGroupWithIdentifier:(NSString *)groupIdentifier
{
    return [CharonContactPredicate predicateWithMatch:CharonContactMatchGroup value:[groupIdentifier copy]];
}

+ (NSPredicate *)predicateForContactsInContainerWithIdentifier:(NSString *)containerIdentifier
{
    return [CharonContactPredicate predicateWithMatch:CharonContactMatchContainer value:[containerIdentifier copy]];
}

+ (NSPredicate *)predicateForContactsMatchingEmailAddress:(NSString *)emailAddress
{
    return [CharonContactPredicate predicateWithMatch:CharonContactMatchEmail value:[emailAddress copy]];
}

+ (NSPredicate *)predicateForContactsMatchingPhoneNumber:(CNPhoneNumber *)phoneNumber
{
    return [CharonContactPredicate predicateWithMatch:CharonContactMatchPhone value:[phoneNumber.stringValue copy]];
}

+ (NSString *)localizedStringForKey:(NSString *)key
{
    ABPropertyID property = [CharonContacts propertyForKey:key];
    if (property != kABPropertyInvalidID) {
        CFStringRef name = ABPersonCopyLocalizedPropertyName(property);
        if (name)
            return (__bridge_transfer NSString *)name;
    }
    return key;
}

+ (NSComparator)comparatorForNameSortOrder:(CNContactSortOrder)sortOrder
{
    CNContactSortOrder ordering = sortOrder;
    if (ordering == CNContactSortOrderUserDefault)
        ordering = ABPersonGetSortOrdering() == kABPersonSortByLastName ? CNContactSortOrderFamilyName : CNContactSortOrderGivenName;
    return [^NSComparisonResult (id left, id right) {
        for (NSString *key in ordering == CNContactSortOrderFamilyName
                 ? @[CNContactFamilyNameKey, CNContactGivenNameKey, CNContactOrganizationNameKey]
                 : @[CNContactGivenNameKey, CNContactFamilyNameKey, CNContactOrganizationNameKey]) {
            NSString *one = [left charon_values][key] ?: @"";
            NSString *other = [right charon_values][key] ?: @"";
            NSComparisonResult answer = [one localizedStandardCompare:other];
            if (answer != NSOrderedSame)
                return answer;
        }
        return NSOrderedSame;
    } copy];
}

+ (id<CNKeyDescriptor>)descriptorForAllComparatorKeys
{
    return [CharonContactsKeyDescriptor descriptorWithKeys:@[CNContactGivenNameKey, CNContactFamilyNameKey, CNContactOrganizationNameKey]];
}

- (id)copyWithZone:(NSZone *)zone
{
    CNContact *copied = [[CNContact allocWithZone:zone] init];
    [copied charon_setValues:_charonValues available:_charonAvailable identifier:_charonIdentifier];
    [copied charon_setLinkedIdentifiers:_charonLinked];
    return copied;
}

- (id)mutableCopyWithZone:(NSZone *)zone
{
    CNMutableContact *copied = [[CNMutableContact allocWithZone:zone] init];
    [copied charon_setValues:_charonValues available:_charonAvailable identifier:_charonIdentifier];
    [copied charon_setLinkedIdentifiers:_charonLinked];
    return copied;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_charonValues forKey:@"values"];
    [coder encodeObject:[_charonAvailable allObjects] forKey:@"available"];
    [coder encodeObject:_charonIdentifier forKey:@"identifier"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [self init];
    if (self) {
        NSDictionary *values = [coder decodeObjectOfClass:[NSDictionary class] forKey:@"values"];
        NSArray *available = [coder decodeObjectOfClass:[NSArray class] forKey:@"available"];
        NSString *identifier = [coder decodeObjectOfClass:[NSString class] forKey:@"identifier"];
        [self charon_setValues:values ?: @{} available:available ? [NSSet setWithArray:available] : nil identifier:identifier];
    }
    return self;
}

- (BOOL)isEqual:(id)object
{
    if (self == object)
        return YES;
    if (![object isKindOfClass:[CNContact class]])
        return NO;
    return [_charonIdentifier isEqualToString:[object identifier]] && [_charonValues isEqualToDictionary:[object charon_values]];
}

- (NSUInteger)hash
{
    return _charonIdentifier.hash;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p: identifier=%@>", NSStringFromClass([self class]), self, _charonIdentifier];
}

@end
