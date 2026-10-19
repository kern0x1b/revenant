#import <UIKit/UIKit.h>
#import <objc/message.h>

void host_attach_prefixed(const char *prefix);

extern UITextContentType const CharonHostUITextContentTypeName;
extern UITextContentType const CharonHostUITextContentTypeNamePrefix;
extern UITextContentType const CharonHostUITextContentTypeGivenName;
extern UITextContentType const CharonHostUITextContentTypeMiddleName;
extern UITextContentType const CharonHostUITextContentTypeFamilyName;
extern UITextContentType const CharonHostUITextContentTypeNameSuffix;
extern UITextContentType const CharonHostUITextContentTypeNickname;
extern UITextContentType const CharonHostUITextContentTypeJobTitle;
extern UITextContentType const CharonHostUITextContentTypeOrganizationName;
extern UITextContentType const CharonHostUITextContentTypeLocation;
extern UITextContentType const CharonHostUITextContentTypeFullStreetAddress;
extern UITextContentType const CharonHostUITextContentTypeStreetAddressLine1;
extern UITextContentType const CharonHostUITextContentTypeStreetAddressLine2;
extern UITextContentType const CharonHostUITextContentTypeAddressCity;
extern UITextContentType const CharonHostUITextContentTypeAddressState;
extern UITextContentType const CharonHostUITextContentTypeAddressCityAndState;
extern UITextContentType const CharonHostUITextContentTypeSublocality;
extern UITextContentType const CharonHostUITextContentTypeCountryName;
extern UITextContentType const CharonHostUITextContentTypePostalCode;
extern UITextContentType const CharonHostUITextContentTypeTelephoneNumber;
extern UITextContentType const CharonHostUITextContentTypeEmailAddress;
extern UITextContentType const CharonHostUITextContentTypeURL;
extern UITextContentType const CharonHostUITextContentTypeCreditCardNumber;
extern UITextContentType const CharonHostUITextContentTypeUsername;
extern UITextContentType const CharonHostUITextContentTypePassword;
extern UITextContentType const CharonHostUITextContentTypeNewPassword;
extern UITextContentType const CharonHostUITextContentTypeOneTimeCode;

static int failures, checks;

static void compare(NSString *name, NSString *system, NSString *ours)
{
    checks++;
    if ([system isEqual:ours] || system == ours) {
        printf("ok   %s: %s\n", name.UTF8String, system.UTF8String);
        return;
    }
    failures++;
    printf("FAIL %s: the system answers %s, the backport answers %s\n", name.UTF8String, system.UTF8String, ours.UTF8String);
}

static NSString *(*getter)(id, SEL) = (NSString * (*)(id, SEL))objc_msgSend;
static void (*setter)(id, SEL, NSString *) = (void (*)(id, SEL, NSString *))objc_msgSend;

static NSString *system_get(id object) { return getter(object, @selector(textContentType)); }
static NSString *ours_get(id object) { return getter(object, NSSelectorFromString(@"charonHost_textContentType")); }
static void system_set(id object, NSString *value) { setter(object, @selector(setTextContentType:), value); }
static void ours_set(id object, NSString *value) { setter(object, NSSelectorFromString(@"charonHost_setTextContentType:"), value); }

static NSString *shown(NSString *text)
{
    return text ? [NSString stringWithFormat:@"'%@'", text] : @"nil";
}

int main(void)
{
    @autoreleasepool {
        host_attach_prefixed("");
        for (NSArray *pair in @[
        @[@"Name", UITextContentTypeName, CharonHostUITextContentTypeName],
        @[@"NamePrefix", UITextContentTypeNamePrefix, CharonHostUITextContentTypeNamePrefix],
        @[@"GivenName", UITextContentTypeGivenName, CharonHostUITextContentTypeGivenName],
        @[@"MiddleName", UITextContentTypeMiddleName, CharonHostUITextContentTypeMiddleName],
        @[@"FamilyName", UITextContentTypeFamilyName, CharonHostUITextContentTypeFamilyName],
        @[@"NameSuffix", UITextContentTypeNameSuffix, CharonHostUITextContentTypeNameSuffix],
        @[@"Nickname", UITextContentTypeNickname, CharonHostUITextContentTypeNickname],
        @[@"JobTitle", UITextContentTypeJobTitle, CharonHostUITextContentTypeJobTitle],
        @[@"OrganizationName", UITextContentTypeOrganizationName, CharonHostUITextContentTypeOrganizationName],
        @[@"Location", UITextContentTypeLocation, CharonHostUITextContentTypeLocation],
        @[@"FullStreetAddress", UITextContentTypeFullStreetAddress, CharonHostUITextContentTypeFullStreetAddress],
        @[@"StreetAddressLine1", UITextContentTypeStreetAddressLine1, CharonHostUITextContentTypeStreetAddressLine1],
        @[@"StreetAddressLine2", UITextContentTypeStreetAddressLine2, CharonHostUITextContentTypeStreetAddressLine2],
        @[@"AddressCity", UITextContentTypeAddressCity, CharonHostUITextContentTypeAddressCity],
        @[@"AddressState", UITextContentTypeAddressState, CharonHostUITextContentTypeAddressState],
        @[@"AddressCityAndState", UITextContentTypeAddressCityAndState, CharonHostUITextContentTypeAddressCityAndState],
        @[@"Sublocality", UITextContentTypeSublocality, CharonHostUITextContentTypeSublocality],
        @[@"CountryName", UITextContentTypeCountryName, CharonHostUITextContentTypeCountryName],
        @[@"PostalCode", UITextContentTypePostalCode, CharonHostUITextContentTypePostalCode],
        @[@"TelephoneNumber", UITextContentTypeTelephoneNumber, CharonHostUITextContentTypeTelephoneNumber],
        @[@"EmailAddress", UITextContentTypeEmailAddress, CharonHostUITextContentTypeEmailAddress],
        @[@"URL", UITextContentTypeURL, CharonHostUITextContentTypeURL],
        @[@"CreditCardNumber", UITextContentTypeCreditCardNumber, CharonHostUITextContentTypeCreditCardNumber],
        @[@"Username", UITextContentTypeUsername, CharonHostUITextContentTypeUsername],
        @[@"Password", UITextContentTypePassword, CharonHostUITextContentTypePassword],
        @[@"NewPassword", UITextContentTypeNewPassword, CharonHostUITextContentTypeNewPassword],
        @[@"OneTimeCode", UITextContentTypeOneTimeCode, CharonHostUITextContentTypeOneTimeCode]
        ])
            compare([@"the constant " stringByAppendingString:pair[0]], pair[1], pair[2]);

        for (NSString *name in @[@"UITextField", @"UITextView", @"UISearchBar"]) {
            Class cls = NSClassFromString(name);
            id system = [[cls alloc] init], ours = [[cls alloc] init], other = [[cls alloc] init];
            compare([name stringByAppendingString:@" default"], shown(system_get(system)), shown(ours_get(ours)));
            system_set(system, UITextContentTypeEmailAddress);
            ours_set(ours, UITextContentTypeEmailAddress);
            compare([name stringByAppendingString:@" after a known type"], shown(system_get(system)), shown(ours_get(ours)));
            system_set(system, @"not-a-known-type");
            ours_set(ours, @"not-a-known-type");
            compare([name stringByAppendingString:@" after an unknown string"], shown(system_get(system)), shown(ours_get(ours)));
            system_set(system, @"");
            ours_set(ours, @"");
            compare([name stringByAppendingString:@" after an empty string"], shown(system_get(system)), shown(ours_get(ours)));
            system_set(system, nil);
            ours_set(ours, nil);
            compare([name stringByAppendingString:@" after nil"], shown(system_get(system)), shown(ours_get(ours)));
            NSMutableString *mutable_system = [NSMutableString stringWithString:@"tel"], *mutable_ours = [NSMutableString stringWithString:@"tel"];
            system_set(system, mutable_system);
            ours_set(ours, mutable_ours);
            [mutable_system appendString:@"x"];
            [mutable_ours appendString:@"x"];
            compare([name stringByAppendingString:@" keeps a copy"], shown(system_get(system)), shown(ours_get(ours)));
            compare([name stringByAppendingString:@" of its own, another one untouched"], shown(system_get(other)), shown(ours_get(other)));
        }
        printf("%d checks, %d failures\n", checks, failures);
        return failures;
    }
}
