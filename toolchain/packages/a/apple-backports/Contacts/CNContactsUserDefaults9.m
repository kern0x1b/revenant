#import "CharonContacts.h"

#pragma clang diagnostic ignored "-Wincomplete-implementation"
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

@implementation CNContactsUserDefaults

@dynamic sortOrder, countryCode;

+ (instancetype)sharedDefaults
{
    static CNContactsUserDefaults *shared;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        shared = [[CNContactsUserDefaults alloc] init];
    });
    return shared;
}

- (CNContactSortOrder)sortOrder
{
    return ABPersonGetSortOrdering() == kABPersonSortByLastName ? CNContactSortOrderFamilyName : CNContactSortOrderGivenName;
}

- (NSString *)countryCode
{
    NSString *code = [[NSLocale currentLocale] objectForKey:NSLocaleCountryCode];
    return code.length > 0 ? [code lowercaseString] : @"us";
}

@end
