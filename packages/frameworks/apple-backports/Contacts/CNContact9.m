#import "RevenantContacts.h"

#pragma clang diagnostic ignored "-Wincomplete-implementation"
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

@implementation CNContact {
@protected
    NSMutableDictionary *_revenantValues;
    NSSet *_revenantAvailable;
    NSString *_revenantIdentifier;
    NSArray *_revenantLinked;
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
        _revenantValues = [NSMutableDictionary dictionary];
        _revenantIdentifier = [[NSUUID UUID] UUIDString];
    }
    return self;
}

- (id)revenant_valueForContactKey:(NSString *)key
{
    if (_revenantAvailable && ![_revenantAvailable containsObject:key]) {
        [NSException raise:CNContactPropertyNotFetchedExceptionName
                    format:@"A property was not requested when contact was fetched: %@", key];
    }
    return _revenantValues[key];
}

- (void)revenant_setValue:(id)value forContactKey:(NSString *)key
{
    if (value)
        _revenantValues[key] = value;
    else
        [_revenantValues removeObjectForKey:key];
    if (_revenantAvailable && ![_revenantAvailable containsObject:key])
        _revenantAvailable = [_revenantAvailable setByAddingObject:key];
}

- (NSDictionary *)revenant_values
{
    return _revenantValues;
}

- (NSSet *)revenant_availableKeys
{
    return _revenantAvailable;
}

- (void)revenant_setValues:(NSDictionary *)values available:(NSSet *)keys identifier:(NSString *)identifier
{
    _revenantValues = [NSMutableDictionary dictionaryWithDictionary:values];
    _revenantAvailable = [keys copy];
    if (identifier)
        _revenantIdentifier = [identifier copy];
}

- (NSArray<NSString *> *)revenant_linkedIdentifiers
{
    return _revenantLinked ?: @[];
}

- (void)revenant_setLinkedIdentifiers:(NSArray<NSString *> *)identifiers
{
    _revenantLinked = [identifiers copy];
}

- (NSString *)revenant_stringForKey:(NSString *)key
{
    return [self revenant_valueForContactKey:key] ?: @"";
}

- (NSArray *)revenant_arrayForKey:(NSString *)key
{
    return [self revenant_valueForContactKey:key] ?: @[];
}

- (NSString *)identifier
{
    return _revenantIdentifier;
}

- (CNContactType)contactType
{
    return (CNContactType)[[self revenant_valueForContactKey:CNContactTypeKey] integerValue];
}

- (NSString *)namePrefix { return [self revenant_stringForKey:CNContactNamePrefixKey]; }
- (NSString *)givenName { return [self revenant_stringForKey:CNContactGivenNameKey]; }
- (NSString *)middleName { return [self revenant_stringForKey:CNContactMiddleNameKey]; }
- (NSString *)familyName { return [self revenant_stringForKey:CNContactFamilyNameKey]; }
- (NSString *)previousFamilyName { return [self revenant_stringForKey:CNContactPreviousFamilyNameKey]; }
- (NSString *)nameSuffix { return [self revenant_stringForKey:CNContactNameSuffixKey]; }
- (NSString *)nickname { return [self revenant_stringForKey:CNContactNicknameKey]; }
- (NSString *)organizationName { return [self revenant_stringForKey:CNContactOrganizationNameKey]; }
- (NSString *)departmentName { return [self revenant_stringForKey:CNContactDepartmentNameKey]; }
- (NSString *)jobTitle { return [self revenant_stringForKey:CNContactJobTitleKey]; }
- (NSString *)phoneticGivenName { return [self revenant_stringForKey:CNContactPhoneticGivenNameKey]; }
- (NSString *)phoneticMiddleName { return [self revenant_stringForKey:CNContactPhoneticMiddleNameKey]; }
- (NSString *)phoneticFamilyName { return [self revenant_stringForKey:CNContactPhoneticFamilyNameKey]; }
- (NSString *)phoneticOrganizationName { return [self revenant_stringForKey:CNContactPhoneticOrganizationNameKey]; }
- (NSString *)note { return [self revenant_stringForKey:CNContactNoteKey]; }

- (NSData *)imageData { return [self revenant_valueForContactKey:CNContactImageDataKey]; }
- (NSData *)thumbnailImageData { return [self revenant_valueForContactKey:CNContactThumbnailImageDataKey]; }

- (BOOL)imageDataAvailable
{
    return [[self revenant_valueForContactKey:CNContactImageDataAvailableKey] boolValue];
}

- (NSArray *)phoneNumbers { return [self revenant_arrayForKey:CNContactPhoneNumbersKey]; }
- (NSArray *)emailAddresses { return [self revenant_arrayForKey:CNContactEmailAddressesKey]; }
- (NSArray *)postalAddresses { return [self revenant_arrayForKey:CNContactPostalAddressesKey]; }
- (NSArray *)urlAddresses { return [self revenant_arrayForKey:CNContactUrlAddressesKey]; }
- (NSArray *)contactRelations { return [self revenant_arrayForKey:CNContactRelationsKey]; }
- (NSArray *)socialProfiles { return [self revenant_arrayForKey:CNContactSocialProfilesKey]; }
- (NSArray *)instantMessageAddresses { return [self revenant_arrayForKey:CNContactInstantMessageAddressesKey]; }
- (NSArray *)dates { return [self revenant_arrayForKey:CNContactDatesKey]; }

- (NSDateComponents *)birthday { return [self revenant_valueForContactKey:CNContactBirthdayKey]; }
- (NSDateComponents *)nonGregorianBirthday { return [self revenant_valueForContactKey:CNContactNonGregorianBirthdayKey]; }

- (BOOL)isKeyAvailable:(NSString *)key
{
    return _revenantAvailable == nil || [_revenantAvailable containsObject:key];
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
    return [_revenantIdentifier isEqualToString:contactIdentifier] || [_revenantLinked containsObject:contactIdentifier];
}

+ (NSPredicate *)predicateForContactsMatchingName:(NSString *)name
{
    return [RevenantContactPredicate predicateWithMatch:RevenantContactMatchName value:[name copy]];
}

+ (NSPredicate *)predicateForContactsWithIdentifiers:(NSArray<NSString *> *)identifiers
{
    return [RevenantContactPredicate predicateWithMatch:RevenantContactMatchIdentifiers value:[identifiers copy]];
}

+ (NSPredicate *)predicateForContactsInGroupWithIdentifier:(NSString *)groupIdentifier
{
    return [RevenantContactPredicate predicateWithMatch:RevenantContactMatchGroup value:[groupIdentifier copy]];
}

+ (NSPredicate *)predicateForContactsInContainerWithIdentifier:(NSString *)containerIdentifier
{
    return [RevenantContactPredicate predicateWithMatch:RevenantContactMatchContainer value:[containerIdentifier copy]];
}

+ (NSPredicate *)predicateForContactsMatchingEmailAddress:(NSString *)emailAddress
{
    return [RevenantContactPredicate predicateWithMatch:RevenantContactMatchEmail value:[emailAddress copy]];
}

+ (NSPredicate *)predicateForContactsMatchingPhoneNumber:(CNPhoneNumber *)phoneNumber
{
    return [RevenantContactPredicate predicateWithMatch:RevenantContactMatchPhone value:[phoneNumber.stringValue copy]];
}

+ (NSString *)localizedStringForKey:(NSString *)key
{
    ABPropertyID property = [RevenantContacts propertyForKey:key];
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
            NSString *one = [left revenant_values][key] ?: @"";
            NSString *other = [right revenant_values][key] ?: @"";
            NSComparisonResult answer = [one localizedStandardCompare:other];
            if (answer != NSOrderedSame)
                return answer;
        }
        return NSOrderedSame;
    } copy];
}

+ (id<CNKeyDescriptor>)descriptorForAllComparatorKeys
{
    return [RevenantContactsKeyDescriptor descriptorWithKeys:@[CNContactGivenNameKey, CNContactFamilyNameKey, CNContactOrganizationNameKey]];
}

- (id)copyWithZone:(NSZone *)zone
{
    CNContact *copied = [[CNContact allocWithZone:zone] init];
    [copied revenant_setValues:_revenantValues available:_revenantAvailable identifier:_revenantIdentifier];
    [copied revenant_setLinkedIdentifiers:_revenantLinked];
    return copied;
}

- (id)mutableCopyWithZone:(NSZone *)zone
{
    CNMutableContact *copied = [[CNMutableContact allocWithZone:zone] init];
    [copied revenant_setValues:_revenantValues available:_revenantAvailable identifier:_revenantIdentifier];
    [copied revenant_setLinkedIdentifiers:_revenantLinked];
    return copied;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_revenantValues forKey:@"values"];
    [coder encodeObject:[_revenantAvailable allObjects] forKey:@"available"];
    [coder encodeObject:_revenantIdentifier forKey:@"identifier"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [self init];
    if (self) {
        NSDictionary *values = [coder decodeObjectOfClass:[NSDictionary class] forKey:@"values"];
        NSArray *available = [coder decodeObjectOfClass:[NSArray class] forKey:@"available"];
        NSString *identifier = [coder decodeObjectOfClass:[NSString class] forKey:@"identifier"];
        [self revenant_setValues:values ?: @{} available:available ? [NSSet setWithArray:available] : nil identifier:identifier];
    }
    return self;
}

- (BOOL)isEqual:(id)object
{
    if (self == object)
        return YES;
    if (![object isKindOfClass:[CNContact class]])
        return NO;
    return [_revenantIdentifier isEqualToString:[object identifier]] && [_revenantValues isEqualToDictionary:[object revenant_values]];
}

- (NSUInteger)hash
{
    return _revenantIdentifier.hash;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p: identifier=%@>", NSStringFromClass([self class]), self, _revenantIdentifier];
}

@end
