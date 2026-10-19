#import "CharonContacts.h"

#pragma clang diagnostic ignored "-Wincomplete-implementation"

@implementation CNMutableContact

@dynamic contactType, namePrefix, givenName, middleName, familyName, previousFamilyName, nameSuffix, nickname,
         organizationName, departmentName, jobTitle, phoneticGivenName, phoneticMiddleName, phoneticFamilyName,
         phoneticOrganizationName, note, imageData, phoneNumbers, emailAddresses, postalAddresses, urlAddresses,
         contactRelations, socialProfiles, instantMessageAddresses, birthday, nonGregorianBirthday, dates;

- (void)setContactType:(CNContactType)contactType
{
    [self charon_setValue:@(contactType) forContactKey:CNContactTypeKey];
}

- (void)setNamePrefix:(NSString *)value { [self charon_setValue:[value copy] forContactKey:CNContactNamePrefixKey]; }
- (void)setGivenName:(NSString *)value { [self charon_setValue:[value copy] forContactKey:CNContactGivenNameKey]; }
- (void)setMiddleName:(NSString *)value { [self charon_setValue:[value copy] forContactKey:CNContactMiddleNameKey]; }
- (void)setFamilyName:(NSString *)value { [self charon_setValue:[value copy] forContactKey:CNContactFamilyNameKey]; }
- (void)setPreviousFamilyName:(NSString *)value { [self charon_setValue:[value copy] forContactKey:CNContactPreviousFamilyNameKey]; }
- (void)setNameSuffix:(NSString *)value { [self charon_setValue:[value copy] forContactKey:CNContactNameSuffixKey]; }
- (void)setNickname:(NSString *)value { [self charon_setValue:[value copy] forContactKey:CNContactNicknameKey]; }
- (void)setOrganizationName:(NSString *)value { [self charon_setValue:[value copy] forContactKey:CNContactOrganizationNameKey]; }
- (void)setDepartmentName:(NSString *)value { [self charon_setValue:[value copy] forContactKey:CNContactDepartmentNameKey]; }
- (void)setJobTitle:(NSString *)value { [self charon_setValue:[value copy] forContactKey:CNContactJobTitleKey]; }
- (void)setPhoneticGivenName:(NSString *)value { [self charon_setValue:[value copy] forContactKey:CNContactPhoneticGivenNameKey]; }
- (void)setPhoneticMiddleName:(NSString *)value { [self charon_setValue:[value copy] forContactKey:CNContactPhoneticMiddleNameKey]; }
- (void)setPhoneticFamilyName:(NSString *)value { [self charon_setValue:[value copy] forContactKey:CNContactPhoneticFamilyNameKey]; }
- (void)setPhoneticOrganizationName:(NSString *)value { [self charon_setValue:[value copy] forContactKey:CNContactPhoneticOrganizationNameKey]; }
- (void)setNote:(NSString *)value { [self charon_setValue:[value copy] forContactKey:CNContactNoteKey]; }
- (void)setImageData:(NSData *)value { [self charon_setValue:[value copy] forContactKey:CNContactImageDataKey]; }
- (void)setPhoneNumbers:(NSArray *)value { [self charon_setValue:[value copy] forContactKey:CNContactPhoneNumbersKey]; }
- (void)setEmailAddresses:(NSArray *)value { [self charon_setValue:[value copy] forContactKey:CNContactEmailAddressesKey]; }
- (void)setPostalAddresses:(NSArray *)value { [self charon_setValue:[value copy] forContactKey:CNContactPostalAddressesKey]; }
- (void)setUrlAddresses:(NSArray *)value { [self charon_setValue:[value copy] forContactKey:CNContactUrlAddressesKey]; }
- (void)setContactRelations:(NSArray *)value { [self charon_setValue:[value copy] forContactKey:CNContactRelationsKey]; }
- (void)setSocialProfiles:(NSArray *)value { [self charon_setValue:[value copy] forContactKey:CNContactSocialProfilesKey]; }
- (void)setInstantMessageAddresses:(NSArray *)value { [self charon_setValue:[value copy] forContactKey:CNContactInstantMessageAddressesKey]; }
- (void)setDates:(NSArray *)value { [self charon_setValue:[value copy] forContactKey:CNContactDatesKey]; }
- (void)setBirthday:(NSDateComponents *)value { [self charon_setValue:[value copy] forContactKey:CNContactBirthdayKey]; }
- (void)setNonGregorianBirthday:(NSDateComponents *)value { [self charon_setValue:[value copy] forContactKey:CNContactNonGregorianBirthdayKey]; }

@end
