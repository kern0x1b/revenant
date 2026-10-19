#import "CharonContacts.h"

#pragma clang diagnostic ignored "-Wdeprecated-declarations"

@implementation CharonContactPredicate

@synthesize match = _match, value = _value;

+ (instancetype)predicateWithMatch:(CharonContactMatch)match value:(id)value
{
    CharonContactPredicate *predicate = [[CharonContactPredicate alloc] init];
    predicate->_match = match;
    predicate->_value = value;
    return predicate;
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

// The factory each match is made by, the "kind" the release's own predicates name in their
// -description (measured on the macOS 26 host's Contacts, facts/Contacts/Fetching.md).
static NSString *CharonContactPredicateKind(CharonContactMatch match)
{
    switch (match) {
        case CharonContactMatchAll: return @"all contacts";
        case CharonContactMatchName: return @"-[CNContact predicateForContactsMatchingName:]";
        case CharonContactMatchIdentifiers: return @"-[CNContact predicateForContactsWithIdentifiers:]";
        case CharonContactMatchGroup: return @"-[CNContact predicateForContactsInGroupWithIdentifier:]";
        case CharonContactMatchContainer: return @"-[CNContact predicateForContactsInContainerWithIdentifier:]";
        case CharonContactMatchEmail: return @"-[CNContact predicateForContactsMatchingEmailAddress:]";
        case CharonContactMatchPhone: return @"-[CNContact predicateForContactsMatchingPhoneNumber:]";
        case CharonContactMatchGroupIdentifiers: return @"-[CNGroup predicateForGroupsWithIdentifiers:]";
        case CharonContactMatchGroupsInContainer: return @"-[CNGroup predicateForGroupsInContainerWithIdentifier:]";
        case CharonContactMatchContainerIdentifiers: return @"-[CNContainer predicateForContainersWithIdentifiers:]";
        case CharonContactMatchContainerOfContact: return @"-[CNContainer predicateForContainerOfContactWithIdentifier:]";
        case CharonContactMatchContainerOfGroup: return @"-[CNContainer predicateForContainerOfGroupWithIdentifier:]";
    }
    return [NSString stringWithFormat:@"match %ld", (long)match];
}

// The release answers a format only for the three identifier-list predicates
// (`identifier IN {"A", "B"}`), and nil, without raising, for the rest (measured on the host).
- (NSString *)predicateFormat
{
    switch (_match) {
        case CharonContactMatchIdentifiers:
        case CharonContactMatchGroupIdentifiers:
        case CharonContactMatchContainerIdentifiers:
            return [NSPredicate predicateWithFormat:@"identifier IN %@", _value].predicateFormat;
        default:
            return nil;
    }
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p: kind=%@, value=%@>", [self class], self, CharonContactPredicateKind(_match), _value];
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return YES;
    if (![object isKindOfClass:[CharonContactPredicate class]])
        return NO;
    CharonContactPredicate *other = object;
    return other->_match == _match && (other->_value == _value || [other->_value isEqual:_value]);
}

- (NSUInteger)hash
{
    return (NSUInteger)_match ^ [_value hash];
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeInteger:_match forKey:@"match"];
    [coder encodeObject:_value forKey:@"value"];
}

// Every value a factory stores is an NSString or an NSArray of them (CNContact9.m, CNGroup9.m,
// CNContainer9.m).
- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super init])) {
        _match = (CharonContactMatch)[coder decodeIntegerForKey:@"match"];
        _value = [coder decodeObjectOfClasses:[NSSet setWithObjects:[NSString class], [NSArray class], nil] forKey:@"value"];
    }
    return self;
}

- (BOOL)evaluateWithObject:(id)object substitutionVariables:(NSDictionary *)variables
{
    return [self evaluateWithObject:object];
}

- (BOOL)evaluateWithObject:(id)object
{
    if (![object isKindOfClass:[CNContact class]])
        return NO;
    CNContact *contact = object;
    NSDictionary *values = [contact charon_values];
    switch (_match) {
        case CharonContactMatchAll:
            return YES;
        case CharonContactMatchIdentifiers:
            return [_value containsObject:contact.identifier];
        case CharonContactMatchName: {
            for (NSString *key in @[CNContactGivenNameKey, CNContactMiddleNameKey, CNContactFamilyNameKey,
                                    CNContactNicknameKey, CNContactOrganizationNameKey]) {
                NSString *held = values[key];
                if (held.length > 0 && [held rangeOfString:_value options:NSCaseInsensitiveSearch].location != NSNotFound)
                    return YES;
            }
            return NO;
        }
        case CharonContactMatchEmail: {
            for (CNLabeledValue *labeled in values[CNContactEmailAddressesKey]) {
                if ([labeled.value isKindOfClass:[NSString class]] && [labeled.value caseInsensitiveCompare:_value] == NSOrderedSame)
                    return YES;
            }
            return NO;
        }
        case CharonContactMatchPhone: {
            NSString *wanted = [CharonContacts digitsOfPhoneNumber:_value];
            for (CNLabeledValue *labeled in values[CNContactPhoneNumbersKey]) {
                NSString *held = [CharonContacts digitsOfPhoneNumber:[labeled.value stringValue]];
                if (held.length > 0 && wanted.length > 0
                    && ([held hasSuffix:wanted] || [wanted hasSuffix:held]))
                    return YES;
            }
            return NO;
        }
        case CharonContactMatchGroup:
        case CharonContactMatchContainer:
            return NO;
    }
    return NO;
}

@end

@implementation CharonContactsBook

+ (ABAddressBookRef)createBook:(NSError **)error
{
    CFErrorRef failure = NULL;
    ABAddressBookRef book = ABAddressBookCreateWithOptions(NULL, &failure);
    if (!book) {
        if (error) {
            *error = failure ? (__bridge_transfer NSError *)failure
                             : [CharonContacts errorWithCode:CNErrorCodeAuthorizationDenied reason:@"The address book could not be opened."];
        } else if (failure) {
            CFRelease(failure);
        }
        return NULL;
    }
    if (failure)
        CFRelease(failure);
    if (ABAddressBookGetAuthorizationStatus() != kABAuthorizationStatusAuthorized) {
        CFRelease(book);
        if (error)
            *error = [CharonContacts errorWithCode:CNErrorCodeAuthorizationDenied reason:@"This application has not been granted permission to access Contacts."];
        return NULL;
    }
    [self watchForChanges];
    return book;
}

static ABAddressBookRef charon_watched;

static void charon_book_changed(ABAddressBookRef book, CFDictionaryRef info, void *context)
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:CNContactStoreDidChangeNotification object:nil userInfo:nil];
    });
}

+ (void)watchForChanges
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        charon_watched = ABAddressBookCreateWithOptions(NULL, NULL);
        if (charon_watched)
            ABAddressBookRegisterExternalChangeCallback(charon_watched, charon_book_changed, NULL);
    });
}

+ (NSSet *)keysFromDescriptors:(NSArray *)descriptors
{
    NSMutableSet *keys = [NSMutableSet set];
    for (id descriptor in descriptors) {
        if ([descriptor isKindOfClass:[NSString class]])
            [keys addObject:descriptor];
        else if ([descriptor isKindOfClass:[CharonContactsKeyDescriptor class]])
            [keys addObjectsFromArray:[(CharonContactsKeyDescriptor *)descriptor keys]];
        else if ([descriptor isKindOfClass:[NSArray class]])
            [keys unionSet:[self keysFromDescriptors:descriptor]];
    }
    [keys addObject:CNContactIdentifierKey];
    return keys;
}

+ (id)valueOfRecord:(ABRecordRef)record property:(ABPropertyID)property
{
    CFTypeRef held = ABRecordCopyValue(record, property);
    return held ? (__bridge_transfer id)held : nil;
}

+ (NSArray<CNLabeledValue *> *)labeledValuesOfRecord:(ABRecordRef)record key:(NSString *)key
{
    ABPropertyID property = [CharonContacts propertyForKey:key];
    ABMultiValueRef multi = (ABMultiValueRef)ABRecordCopyValue(record, property);
    if (!multi)
        return @[];
    NSMutableArray *found = [NSMutableArray array];
    for (CFIndex index = 0; index < ABMultiValueGetCount(multi); index++) {
        CFTypeRef raw = ABMultiValueCopyValueAtIndex(multi, index);
        CFStringRef rawLabel = ABMultiValueCopyLabelAtIndex(multi, index);
        NSString *label = rawLabel ? (__bridge_transfer NSString *)rawLabel : nil;
        id value = raw ? (__bridge_transfer id)raw : nil;
        id held = nil;
        if ([key isEqualToString:CNContactPhoneNumbersKey])
            held = [value isKindOfClass:[NSString class]] ? [CNPhoneNumber phoneNumberWithStringValue:value] : nil;
        else if ([key isEqualToString:CNContactPostalAddressesKey])
            held = [value isKindOfClass:[NSDictionary class]] ? [[CharonContacts postalAddressWithAddressBookAddress:value] copy] : nil;
        else if ([key isEqualToString:CNContactSocialProfilesKey])
            held = [value isKindOfClass:[NSDictionary class]] ? [CharonContacts socialProfileWithAddressBookProfile:value] : nil;
        else if ([key isEqualToString:CNContactInstantMessageAddressesKey])
            held = [value isKindOfClass:[NSDictionary class]] ? [CharonContacts instantMessageAddressWithAddressBookMessage:value] : nil;
        else if ([key isEqualToString:CNContactRelationsKey])
            held = [value isKindOfClass:[NSString class]] ? [CNContactRelation contactRelationWithName:value] : nil;
        else if ([key isEqualToString:CNContactDatesKey])
            held = [value isKindOfClass:[NSDate class]] ? [CharonContacts componentsWithDate:value] : nil;
        else
            held = [value isKindOfClass:[NSString class]] ? value : nil;
        if (held) {
            [found addObject:[CNLabeledValue charon_labeledValueWithLabel:label value:held
                                                               identifier:ABMultiValueGetIdentifierAtIndex(multi, index)]];
        }
    }
    CFRelease(multi);
    return found;
}

+ (void)readRecord:(ABRecordRef)record into:(NSMutableDictionary *)values keys:(NSSet *)keys filling:(BOOL)filling
{
    for (NSString *key in keys) {
        BOOL labeled = NO;
        if (![CharonContacts key:key holdsLabeledValues:&labeled]) {
            if ([key isEqualToString:CNContactImageDataKey]) {
                if (!filling || !values[key]) {
                    CFDataRef data = ABPersonCopyImageDataWithFormat(record, kABPersonImageFormatOriginalSize);
                    if (data)
                        values[key] = (__bridge_transfer NSData *)data;
                }
            } else if ([key isEqualToString:CNContactThumbnailImageDataKey]) {
                if (!filling || !values[key]) {
                    CFDataRef data = ABPersonCopyImageDataWithFormat(record, kABPersonImageFormatThumbnail);
                    if (data)
                        values[key] = (__bridge_transfer NSData *)data;
                }
            } else if ([key isEqualToString:CNContactImageDataAvailableKey]) {
                if (ABPersonHasImageData(record))
                    values[key] = @YES;
                else if (!filling)
                    values[key] = @NO;
            }
            continue;
        }
        if (labeled) {
            NSArray *held = [self labeledValuesOfRecord:record key:key];
            if (held.count == 0)
                continue;
            NSMutableArray *all = [NSMutableArray arrayWithArray:values[key] ?: @[]];
            for (CNLabeledValue *one in held) {
                BOOL seen = NO;
                for (CNLabeledValue *other in all)
                    seen = seen || [other.value isEqual:one.value];
                if (!seen)
                    [all addObject:one];
            }
            values[key] = all;
            continue;
        }
        if (filling && values[key])
            continue;
        id held = [self valueOfRecord:record property:[CharonContacts propertyForKey:key]];
        if (!held)
            continue;
        if ([key isEqualToString:CNContactBirthdayKey])
            values[key] = [CharonContacts componentsWithDate:held];
        else if ([key isEqualToString:CNContactTypeKey])
            values[key] = @([(__bridge id)kABPersonKindOrganization isEqual:held] ? CNContactTypeOrganization : CNContactTypePerson);
        else
            values[key] = held;
    }
}

+ (CNContact *)contactWithRecord:(ABRecordRef)record keys:(NSSet *)keys unify:(BOOL)unify mutable:(BOOL)mutableObjects
{
    NSMutableDictionary *values = [NSMutableDictionary dictionary];
    [self readRecord:record into:values keys:keys filling:NO];
    NSMutableArray *linked = [NSMutableArray array];
    if (unify) {
        CFArrayRef people = ABPersonCopyArrayOfAllLinkedPeople(record);
        if (people) {
            for (CFIndex index = 0; index < CFArrayGetCount(people); index++) {
                ABRecordRef other = (ABRecordRef)CFArrayGetValueAtIndex(people, index);
                if (ABRecordGetRecordID(other) == ABRecordGetRecordID(record))
                    continue;
                [linked addObject:[NSString stringWithFormat:@"%d", (int)ABRecordGetRecordID(other)]];
                [self readRecord:other into:values keys:keys filling:YES];
            }
            CFRelease(people);
        }
    }
    NSString *identifier = [NSString stringWithFormat:@"%d", (int)ABRecordGetRecordID(record)];
    values[CNContactIdentifierKey] = identifier;
    CNContact *contact = mutableObjects ? [[CNMutableContact alloc] init] : [[CNContact alloc] init];
    [contact charon_setValues:values available:keys identifier:identifier];
    [contact charon_setLinkedIdentifiers:linked];
    return contact;
}

+ (NSArray *)recordsInBook:(ABAddressBookRef)book matching:(NSPredicate *)predicate error:(NSError **)error
{
    CharonContactMatch match = CharonContactMatchAll;
    id wanted = nil;
    if ([predicate isKindOfClass:[CharonContactPredicate class]]) {
        match = [(CharonContactPredicate *)predicate match];
        wanted = [(CharonContactPredicate *)predicate value];
    } else if (predicate) {
        if (error)
            *error = [CharonContacts errorWithCode:CNErrorCodePredicateInvalid reason:@"The predicate is not one the Contacts framework makes."];
        return nil;
    }
    NSMutableArray *found = [NSMutableArray array];
    if (match == CharonContactMatchIdentifiers) {
        for (NSString *identifier in wanted) {
            ABRecordRef record = ABAddressBookGetPersonWithRecordID(book, (ABRecordID)[identifier intValue]);
            if (record)
                [found addObject:(__bridge id)record];
        }
        return found;
    }
    if (match == CharonContactMatchGroup) {
        ABRecordRef group = ABAddressBookGetGroupWithRecordID(book, (ABRecordID)[wanted intValue]);
        CFArrayRef members = group ? ABGroupCopyArrayOfAllMembers(group) : NULL;
        if (members) {
            [found addObjectsFromArray:(__bridge NSArray *)members];
            CFRelease(members);
        }
        return found;
    }
    if (match == CharonContactMatchContainer) {
        ABRecordRef source = ABAddressBookGetSourceWithRecordID(book, (ABRecordID)[wanted intValue]);
        CFArrayRef people = source ? ABAddressBookCopyArrayOfAllPeopleInSource(book, source) : NULL;
        if (people) {
            [found addObjectsFromArray:(__bridge NSArray *)people];
            CFRelease(people);
        }
        return found;
    }
    if (match == CharonContactMatchName) {
        CFArrayRef people = ABAddressBookCopyPeopleWithName(book, (__bridge CFStringRef)wanted);
        if (people) {
            [found addObjectsFromArray:(__bridge NSArray *)people];
            CFRelease(people);
        }
        return found;
    }
    CFArrayRef people = ABAddressBookCopyArrayOfAllPeople(book);
    if (people) {
        [found addObjectsFromArray:(__bridge NSArray *)people];
        CFRelease(people);
    }
    return found;
}

+ (NSArray<CNContact *> *)contactsInBook:(ABAddressBookRef)book matching:(NSPredicate *)predicate keys:(NSSet *)keys
                                   unify:(BOOL)unify mutable:(BOOL)mutableObjects error:(NSError **)error
{
    NSArray *records = [self recordsInBook:book matching:predicate error:error];
    if (!records)
        return nil;
    BOOL filters = [predicate isKindOfClass:[CharonContactPredicate class]]
        && ([(CharonContactPredicate *)predicate match] == CharonContactMatchEmail
            || [(CharonContactPredicate *)predicate match] == CharonContactMatchPhone);
    NSMutableArray *contacts = [NSMutableArray array];
    NSMutableSet *taken = [NSMutableSet set];
    for (id held in records) {
        ABRecordRef record = (__bridge ABRecordRef)held;
        NSString *identifier = [NSString stringWithFormat:@"%d", (int)ABRecordGetRecordID(record)];
        if ([taken containsObject:identifier])
            continue;
        NSSet *wanted = keys;
        if (filters) {
            NSMutableSet *both = [NSMutableSet setWithSet:keys];
            [both addObject:CNContactEmailAddressesKey];
            [both addObject:CNContactPhoneNumbersKey];
            wanted = both;
        }
        CNContact *contact = [self contactWithRecord:record keys:wanted unify:unify mutable:mutableObjects];
        if (filters && ![predicate evaluateWithObject:contact])
            continue;
        if (filters)
            contact = [self contactWithRecord:record keys:keys unify:unify mutable:mutableObjects];
        [taken addObject:identifier];
        for (NSString *other in [contact charon_linkedIdentifiers])
            [taken addObject:other];
        [contacts addObject:contact];
    }
    return contacts;
}


+ (ABPropertyType)typeOfKey:(NSString *)key
{
    if ([key isEqualToString:CNContactPostalAddressesKey] || [key isEqualToString:CNContactSocialProfilesKey]
        || [key isEqualToString:CNContactInstantMessageAddressesKey])
        return kABMultiDictionaryPropertyType;
    if ([key isEqualToString:CNContactDatesKey])
        return kABMultiDateTimePropertyType;
    return kABMultiStringPropertyType;
}

+ (id)addressBookValueOfLabeledValue:(CNLabeledValue *)labeled key:(NSString *)key
{
    id value = labeled.value;
    if ([key isEqualToString:CNContactPhoneNumbersKey])
        return [value isKindOfClass:[CNPhoneNumber class]] ? [value stringValue] : nil;
    if ([key isEqualToString:CNContactPostalAddressesKey])
        return [value isKindOfClass:[CNPostalAddress class]] ? [CharonContacts addressBookAddressWithPostalAddress:value] : nil;
    if ([key isEqualToString:CNContactSocialProfilesKey])
        return [value isKindOfClass:[CNSocialProfile class]] ? [CharonContacts addressBookProfileWithSocialProfile:value] : nil;
    if ([key isEqualToString:CNContactInstantMessageAddressesKey])
        return [value isKindOfClass:[CNInstantMessageAddress class]] ? [CharonContacts addressBookMessageWithInstantMessageAddress:value] : nil;
    if ([key isEqualToString:CNContactRelationsKey])
        return [value isKindOfClass:[CNContactRelation class]] ? [value name] : nil;
    if ([key isEqualToString:CNContactDatesKey])
        return [value isKindOfClass:[NSDateComponents class]] ? [CharonContacts dateWithComponents:value] : nil;
    return [value isKindOfClass:[NSString class]] ? value : nil;
}

+ (BOOL)applyContact:(CNContact *)contact toRecord:(ABRecordRef)record error:(NSError **)error
{
    NSDictionary *values = [contact charon_values];
    NSSet *available = [contact charon_availableKeys];
    for (NSString *key in [CharonContacts contactKeys]) {
        if (available && ![available containsObject:key])
            continue;
        BOOL labeled = NO;
        id value = values[key];
        if (![CharonContacts key:key holdsLabeledValues:&labeled]) {
            if ([key isEqualToString:CNContactImageDataKey]) {
                if ([value isKindOfClass:[NSData class]])
                    ABPersonSetImageData(record, (__bridge CFDataRef)value, NULL);
                else if (ABPersonHasImageData(record))
                    ABPersonRemoveImageData(record, NULL);
            }
            continue;
        }
        ABPropertyID property = [CharonContacts propertyForKey:key];
        if (!labeled) {
            id held = value;
            if ([key isEqualToString:CNContactBirthdayKey])
                held = [CharonContacts dateWithComponents:value];
            else if ([key isEqualToString:CNContactTypeKey])
                held = (__bridge id)([value integerValue] == CNContactTypeOrganization ? kABPersonKindOrganization : kABPersonKindPerson);
            if (held == nil || ([held isKindOfClass:[NSString class]] && [held length] == 0))
                ABRecordRemoveValue(record, property, NULL);
            else
                ABRecordSetValue(record, property, (__bridge CFTypeRef)held, NULL);
            continue;
        }
        NSArray *entries = [value isKindOfClass:[NSArray class]] ? value : nil;
        if (entries.count == 0) {
            ABRecordRemoveValue(record, property, NULL);
            continue;
        }
        ABMutableMultiValueRef multi = ABMultiValueCreateMutable([self typeOfKey:key]);
        for (CNLabeledValue *one in entries) {
            id held = [self addressBookValueOfLabeledValue:one key:key];
            if (!held)
                continue;
            ABMultiValueAddValueAndLabel(multi, (__bridge CFTypeRef)held, (__bridge CFStringRef)one.label, NULL);
        }
        ABRecordSetValue(record, property, multi, NULL);
        CFRelease(multi);
    }
    return YES;
}

+ (ABRecordRef)createRecordWithContact:(CNContact *)contact
{
    ABRecordRef record = ABPersonCreate();
    [self applyContact:contact toRecord:record error:NULL];
    return record;
}

+ (BOOL)contactFitsTheBook:(CNContact *)contact error:(NSError **)error
{
    NSDictionary *values = [contact charon_values];
    for (NSString *key in @[CNContactPreviousFamilyNameKey, CNContactNonGregorianBirthdayKey]) {
        id held = values[key];
        BOOL empty = held == nil || ([held respondsToSelector:@selector(length)] && [held length] == 0);
        if (!empty) {
            if (error) {
                *error = [CharonContacts errorWithCode:CNErrorCodeValidationConfigurationError
                                                reason:[NSString stringWithFormat:@"The address book of this release has no field for %@, so the value would be dropped by the save.", key]];
            }
            return NO;
        }
    }
    return YES;
}

+ (NSString *)compositeNameOfContact:(CNContact *)contact
{
    ABRecordRef record = [self createRecordWithContact:contact];
    CFStringRef composite = ABRecordCopyCompositeName(record);
    NSString *name = composite ? (__bridge_transfer NSString *)composite : nil;
    CFRelease(record);
    return name;
}

+ (CNGroup *)groupWithRecord:(ABRecordRef)record mutable:(BOOL)mutableObjects
{
    NSString *identifier = [NSString stringWithFormat:@"%d", (int)ABRecordGetRecordID(record)];
    NSString *name = [self valueOfRecord:record property:kABGroupNameProperty];
    return [CNGroup charon_groupWithIdentifier:identifier name:name mutable:mutableObjects];
}

+ (NSArray<CNGroup *> *)groupsInBook:(ABAddressBookRef)book matching:(NSPredicate *)predicate
                              mutable:(BOOL)mutableObjects error:(NSError **)error
{
    CharonContactMatch match = CharonContactMatchAll;
    id wanted = nil;
    if ([predicate isKindOfClass:[CharonContactPredicate class]]) {
        match = [(CharonContactPredicate *)predicate match];
        wanted = [(CharonContactPredicate *)predicate value];
    } else if (predicate) {
        if (error)
            *error = [CharonContacts errorWithCode:CNErrorCodePredicateInvalid reason:@"The predicate is not one the Contacts framework makes."];
        return nil;
    }
    NSMutableArray *found = [NSMutableArray array];
    if (match == CharonContactMatchGroupIdentifiers) {
        for (NSString *identifier in wanted) {
            ABRecordRef record = ABAddressBookGetGroupWithRecordID(book, (ABRecordID)[identifier intValue]);
            if (record)
                [found addObject:[self groupWithRecord:record mutable:mutableObjects]];
        }
        return found;
    }
    if (match == CharonContactMatchGroupsInContainer) {
        ABRecordRef source = ABAddressBookGetSourceWithRecordID(book, (ABRecordID)[wanted intValue]);
        CFArrayRef groups = source ? ABAddressBookCopyArrayOfAllGroupsInSource(book, source) : NULL;
        if (groups) {
            for (CFIndex index = 0; index < CFArrayGetCount(groups); index++)
                [found addObject:[self groupWithRecord:(ABRecordRef)CFArrayGetValueAtIndex(groups, index) mutable:mutableObjects]];
            CFRelease(groups);
        }
        return found;
    }
    CFArrayRef groups = ABAddressBookCopyArrayOfAllGroups(book);
    if (groups) {
        for (CFIndex index = 0; index < CFArrayGetCount(groups); index++)
            [found addObject:[self groupWithRecord:(ABRecordRef)CFArrayGetValueAtIndex(groups, index) mutable:mutableObjects]];
        CFRelease(groups);
    }
    return found;
}

+ (CNContainerType)typeOfSource:(ABRecordRef)source
{
    NSNumber *type = [self valueOfRecord:source property:kABSourceTypeProperty];
    switch ([type intValue]) {
        case kABSourceTypeLocal:
            return CNContainerTypeLocal;
        case kABSourceTypeExchange:
        case kABSourceTypeExchangeGAL:
            return CNContainerTypeExchange;
        case kABSourceTypeCardDAV:
        case kABSourceTypeCardDAVSearch:
            return CNContainerTypeCardDAV;
        default:
            return CNContainerTypeUnassigned;
    }
}

+ (CNContainer *)containerWithRecord:(ABRecordRef)source
{
    NSString *identifier = [NSString stringWithFormat:@"%d", (int)ABRecordGetRecordID(source)];
    NSString *name = [self valueOfRecord:source property:kABSourceNameProperty];
    return [CNContainer charon_containerWithIdentifier:identifier name:name type:[self typeOfSource:source]];
}

+ (ABRecordRef)sourceOfPersonWithIdentifier:(NSString *)identifier inBook:(ABAddressBookRef)book
{
    ABRecordRef person = ABAddressBookGetPersonWithRecordID(book, (ABRecordID)[identifier intValue]);
    if (!person)
        return NULL;
    ABRecordRef source = ABPersonCopySource(person);
    return source ? (ABRecordRef)CFAutorelease(source) : NULL;
}

+ (ABRecordRef)sourceOfGroupWithIdentifier:(NSString *)identifier inBook:(ABAddressBookRef)book
{
    ABRecordRef group = ABAddressBookGetGroupWithRecordID(book, (ABRecordID)[identifier intValue]);
    if (!group)
        return NULL;
    ABRecordRef source = ABGroupCopySource(group);
    return source ? (ABRecordRef)CFAutorelease(source) : NULL;
}

+ (NSArray<CNContainer *> *)containersInBook:(ABAddressBookRef)book matching:(NSPredicate *)predicate error:(NSError **)error
{
    CharonContactMatch match = CharonContactMatchAll;
    id wanted = nil;
    if ([predicate isKindOfClass:[CharonContactPredicate class]]) {
        match = [(CharonContactPredicate *)predicate match];
        wanted = [(CharonContactPredicate *)predicate value];
    } else if (predicate) {
        if (error)
            *error = [CharonContacts errorWithCode:CNErrorCodePredicateInvalid reason:@"The predicate is not one the Contacts framework makes."];
        return nil;
    }
    NSMutableArray *found = [NSMutableArray array];
    if (match == CharonContactMatchContainerIdentifiers) {
        for (NSString *identifier in wanted) {
            ABRecordRef source = ABAddressBookGetSourceWithRecordID(book, (ABRecordID)[identifier intValue]);
            if (source)
                [found addObject:[self containerWithRecord:source]];
        }
        return found;
    }
    if (match == CharonContactMatchContainerOfContact) {
        ABRecordRef source = [self sourceOfPersonWithIdentifier:wanted inBook:book];
        if (source)
            [found addObject:[self containerWithRecord:source]];
        return found;
    }
    if (match == CharonContactMatchContainerOfGroup) {
        ABRecordRef source = [self sourceOfGroupWithIdentifier:wanted inBook:book];
        if (source)
            [found addObject:[self containerWithRecord:source]];
        return found;
    }
    CFArrayRef sources = ABAddressBookCopyArrayOfAllSources(book);
    if (sources) {
        for (CFIndex index = 0; index < CFArrayGetCount(sources); index++)
            [found addObject:[self containerWithRecord:(ABRecordRef)CFArrayGetValueAtIndex(sources, index)]];
        CFRelease(sources);
    }
    return found;
}

@end
