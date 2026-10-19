#import <UIKit/UIKit.h>
#import <objc/message.h>

void host_attach_prefixed(const char *prefix);

extern UITextContentType const RevenantHostUITextContentTypeName;
extern UITextContentType const RevenantHostUITextContentTypeNamePrefix;
extern UITextContentType const RevenantHostUITextContentTypeGivenName;
extern UITextContentType const RevenantHostUITextContentTypeMiddleName;
extern UITextContentType const RevenantHostUITextContentTypeFamilyName;
extern UITextContentType const RevenantHostUITextContentTypeNameSuffix;
extern UITextContentType const RevenantHostUITextContentTypeNickname;
extern UITextContentType const RevenantHostUITextContentTypeJobTitle;
extern UITextContentType const RevenantHostUITextContentTypeOrganizationName;
extern UITextContentType const RevenantHostUITextContentTypeLocation;
extern UITextContentType const RevenantHostUITextContentTypeFullStreetAddress;
extern UITextContentType const RevenantHostUITextContentTypeStreetAddressLine1;
extern UITextContentType const RevenantHostUITextContentTypeStreetAddressLine2;
extern UITextContentType const RevenantHostUITextContentTypeAddressCity;
extern UITextContentType const RevenantHostUITextContentTypeAddressState;
extern UITextContentType const RevenantHostUITextContentTypeAddressCityAndState;
extern UITextContentType const RevenantHostUITextContentTypeSublocality;
extern UITextContentType const RevenantHostUITextContentTypeCountryName;
extern UITextContentType const RevenantHostUITextContentTypePostalCode;
extern UITextContentType const RevenantHostUITextContentTypeTelephoneNumber;
extern UITextContentType const RevenantHostUITextContentTypeEmailAddress;
extern UITextContentType const RevenantHostUITextContentTypeURL;
extern UITextContentType const RevenantHostUITextContentTypeCreditCardNumber;
extern UITextContentType const RevenantHostUITextContentTypeUsername;
extern UITextContentType const RevenantHostUITextContentTypePassword;
extern UITextContentType const RevenantHostUITextContentTypeNewPassword;
extern UITextContentType const RevenantHostUITextContentTypeOneTimeCode;

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
static NSString *ours_get(id object) { return getter(object, NSSelectorFromString(@"revenantHost_textContentType")); }
static void system_set(id object, NSString *value) { setter(object, @selector(setTextContentType:), value); }
static void ours_set(id object, NSString *value) { setter(object, NSSelectorFromString(@"revenantHost_setTextContentType:"), value); }

static NSString *shown(NSString *text)
{
    return text ? [NSString stringWithFormat:@"'%@'", text] : @"nil";
}

int main(void)
{
    @autoreleasepool {
        host_attach_prefixed("");
        for (NSArray *pair in @[
        @[@"Name", UITextContentTypeName, RevenantHostUITextContentTypeName],
        @[@"NamePrefix", UITextContentTypeNamePrefix, RevenantHostUITextContentTypeNamePrefix],
        @[@"GivenName", UITextContentTypeGivenName, RevenantHostUITextContentTypeGivenName],
        @[@"MiddleName", UITextContentTypeMiddleName, RevenantHostUITextContentTypeMiddleName],
        @[@"FamilyName", UITextContentTypeFamilyName, RevenantHostUITextContentTypeFamilyName],
        @[@"NameSuffix", UITextContentTypeNameSuffix, RevenantHostUITextContentTypeNameSuffix],
        @[@"Nickname", UITextContentTypeNickname, RevenantHostUITextContentTypeNickname],
        @[@"JobTitle", UITextContentTypeJobTitle, RevenantHostUITextContentTypeJobTitle],
        @[@"OrganizationName", UITextContentTypeOrganizationName, RevenantHostUITextContentTypeOrganizationName],
        @[@"Location", UITextContentTypeLocation, RevenantHostUITextContentTypeLocation],
        @[@"FullStreetAddress", UITextContentTypeFullStreetAddress, RevenantHostUITextContentTypeFullStreetAddress],
        @[@"StreetAddressLine1", UITextContentTypeStreetAddressLine1, RevenantHostUITextContentTypeStreetAddressLine1],
        @[@"StreetAddressLine2", UITextContentTypeStreetAddressLine2, RevenantHostUITextContentTypeStreetAddressLine2],
        @[@"AddressCity", UITextContentTypeAddressCity, RevenantHostUITextContentTypeAddressCity],
        @[@"AddressState", UITextContentTypeAddressState, RevenantHostUITextContentTypeAddressState],
        @[@"AddressCityAndState", UITextContentTypeAddressCityAndState, RevenantHostUITextContentTypeAddressCityAndState],
        @[@"Sublocality", UITextContentTypeSublocality, RevenantHostUITextContentTypeSublocality],
        @[@"CountryName", UITextContentTypeCountryName, RevenantHostUITextContentTypeCountryName],
        @[@"PostalCode", UITextContentTypePostalCode, RevenantHostUITextContentTypePostalCode],
        @[@"TelephoneNumber", UITextContentTypeTelephoneNumber, RevenantHostUITextContentTypeTelephoneNumber],
        @[@"EmailAddress", UITextContentTypeEmailAddress, RevenantHostUITextContentTypeEmailAddress],
        @[@"URL", UITextContentTypeURL, RevenantHostUITextContentTypeURL],
        @[@"CreditCardNumber", UITextContentTypeCreditCardNumber, RevenantHostUITextContentTypeCreditCardNumber],
        @[@"Username", UITextContentTypeUsername, RevenantHostUITextContentTypeUsername],
        @[@"Password", UITextContentTypePassword, RevenantHostUITextContentTypePassword],
        @[@"NewPassword", UITextContentTypeNewPassword, RevenantHostUITextContentTypeNewPassword],
        @[@"OneTimeCode", UITextContentTypeOneTimeCode, RevenantHostUITextContentTypeOneTimeCode]
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
