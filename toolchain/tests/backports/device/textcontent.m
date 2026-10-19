#import <UIKit/UIKit.h>
#include <dlfcn.h>
#import <objc/runtime.h>
#import "check.h"

static NSString *image_of(const void *address)
{
    Dl_info info;
    return dladdr(address, &info) ? @(info.dli_fname).lastPathComponent : @"?";
}

static id raw_instance(Class cls)
{
    id view = class_createInstance(cls, 0);
    CFRetain((__bridge CFTypeRef)view);
    return view;
}

int main(void)
{
    @autoreleasepool {
        NSDictionary *expected = @{@"Name": @"name", @"NamePrefix": @"honorifix-prefix", @"GivenName": @"given-name", @"MiddleName": @"additional-name",
                                   @"FamilyName": @"family-name", @"NameSuffix": @"honorifix-suffix", @"Nickname": @"nickname",
                                   @"JobTitle": @"organization-title", @"OrganizationName": @"organization", @"Location": @"location",
                                   @"FullStreetAddress": @"street-address", @"StreetAddressLine1": @"address-line1",
                                   @"StreetAddressLine2": @"address-line2", @"AddressCity": @"address-level2", @"AddressState": @"address-level1",
                                   @"AddressCityAndState": @"address-level1+2", @"Sublocality": @"address-level3", @"CountryName": @"country-name",
                                   @"PostalCode": @"postal-code", @"TelephoneNumber": @"tel", @"EmailAddress": @"email", @"URL": @"url",
                                   @"CreditCardNumber": @"cc-number"};
        BOOL all = YES, carried = YES;
        for (NSString *name in expected) {
            void *symbol = dlsym(RTLD_DEFAULT, [[@"UITextContentType" stringByAppendingString:name] UTF8String]);
            NSString *value = symbol ? *(__unsafe_unretained NSString **)symbol : nil;
            all = all && [value isEqual:expected[name]];
            carried = carried && [image_of(symbol) isEqual:@"libUIKitBackports.dylib"];
        }
        CHECK(all, "the 23 constants of iOS 10 have the strings read off iOS 10.3.4");
        CHECK(carried, "and come from the backports library");
        NSDictionary *later = @{@"Username": @"username", @"Password": @"password", @"NewPassword": @"new-password", @"OneTimeCode": @"one-time-code"};
        BOOL laterAll = YES;
        for (NSString *name in later) {
            void *symbol = dlsym(RTLD_DEFAULT, [[@"UITextContentType" stringByAppendingString:name] UTF8String]);
            NSString *value = symbol ? *(__unsafe_unretained NSString **)symbol : nil;
            laterAll = laterAll && [value isEqual:later[name]] && [image_of(symbol) isEqual:@"libUIKitBackports.dylib"];
        }
        CHECK(laterAll, "the four constants of iOS 11 and 12 have their strings and come from the backports library");

        for (NSString *name in @[@"UITextField", @"UITextView", @"UISearchBar"]) {
            Class cls = NSClassFromString(name);
            id view = raw_instance(cls), other = raw_instance(cls);
            CHECK([view respondsToSelector:@selector(textContentType)] && [view respondsToSelector:@selector(setTextContentType:)],
                  ([[NSString stringWithFormat:@"%@ answers to textContentType and its setter", name] UTF8String]));
            CHECK_EQUAL(image_of((const void *)[cls instanceMethodForSelector:@selector(textContentType)]), @"libUIKitBackports.dylib",
                        ([[NSString stringWithFormat:@"and %@'s getter comes from the backports library", name] UTF8String]));
            CHECK([view textContentType] == nil, ([[NSString stringWithFormat:@"%@ has none by default", name] UTF8String]));
            [view setTextContentType:UITextContentTypeEmailAddress];
            CHECK_EQUAL([view textContentType], @"email", ([[NSString stringWithFormat:@"%@ keeps a known type", name] UTF8String]));
            [view setTextContentType:@"not-a-known-type"];
            CHECK_EQUAL([view textContentType], @"not-a-known-type", ([[NSString stringWithFormat:@"%@ keeps an unknown string as well", name] UTF8String]));
            [view setTextContentType:@""];
            CHECK_EQUAL([view textContentType], @"", ([[NSString stringWithFormat:@"%@ keeps the empty string", name] UTF8String]));
            [view setTextContentType:nil];
            CHECK([view textContentType] == nil, ([[NSString stringWithFormat:@"%@ lets go of it for nil", name] UTF8String]));
            NSMutableString *mutable = [NSMutableString stringWithString:@"tel"];
            [view setTextContentType:mutable];
            [mutable appendString:@"x"];
            CHECK_EQUAL([view textContentType], @"tel", ([[NSString stringWithFormat:@"%@ keeps a copy of a mutable string", name] UTF8String]));
            CHECK([other textContentType] == nil, ([[NSString stringWithFormat:@"and another %@ is not touched", name] UTF8String]));
        }
        printf("%d checks, %d failures\n", charon_checks, charon_failures);
        return charon_failures;
    }
}
