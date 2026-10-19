#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifdef PORT
#define PREFIX "CharonHost"
#else
#define PREFIX ""
#endif

static Class class_named(const char *name)
{
    Class c = NSClassFromString([NSString stringWithFormat:@"%s%s", PREFIX, name]);
    if (!c) {
        fprintf(stderr, "FAIL: %s%s is not defined in this build\n", PREFIX, name);
        exit(2);
    }
    return c;
}

static const char *apple_class_name(id object)
{
    if (!object) return "nil";
    const char *runtime = class_getName([object class]);
    size_t prefix = strlen(PREFIX);
    return strncmp(runtime, PREFIX, prefix) == 0 ? runtime + prefix : runtime;
}

static NSString *text(id value)
{
    return value ? [NSString stringWithFormat:@"%@", value] : @"nil";
}

static void describe(const char *label, id driver)
{
    if (!driver) {
        printf("%s\tnil\n", label);
        return;
    }
    id handle = [driver valueForKey:@"personHandle"];
    id components = [driver valueForKey:@"nameComponents"];
    NSString *given = [components valueForKey:@"givenName"] ?: @"-";
    NSString *family = [components valueForKey:@"familyName"] ?: @"-";
    printf("%s\t%s\tdisplayName=%s\thandle=%s\thandleValue=%s\thandleType=%s\thandleLabel=%s\tgiven=%s\tfamily=%s\timage=%s\trating=%s\tphone=%s\n",
           label, apple_class_name(driver),
           [text([driver valueForKey:@"displayName"]) UTF8String],
           handle ? apple_class_name(handle) : "nil",
           handle ? [text([handle valueForKey:@"value"]) UTF8String] : "-",
           handle ? [text([handle valueForKey:@"type"]) UTF8String] : "-",
           handle ? [text([handle valueForKey:@"label"]) UTF8String] : "-",
           [given UTF8String], [family UTF8String],
           [text([driver valueForKey:@"image"]) UTF8String] ,
           [text([driver valueForKey:@"rating"]) UTF8String],
           [text([driver valueForKey:@"phoneNumber"]) UTF8String]);
}

typedef id (*HandleInit)(id, SEL, id, id, id, id, id);

static id init_handle_display(NSString *handle, NSString *displayName, NSString *rating, NSString *phone)
{
    SEL selector = NSSelectorFromString(@"initWithHandle:displayName:image:rating:phoneNumber:");
    HandleInit init = (HandleInit)objc_msgSend;
    return init([class_named("INRideDriver") alloc], selector, handle, displayName, nil, rating, phone);
}

static id init_handle_components(NSString *handle, NSPersonNameComponents *components, NSString *rating, NSString *phone)
{
    SEL selector = NSSelectorFromString(@"initWithHandle:nameComponents:image:rating:phoneNumber:");
    HandleInit init = (HandleInit)objc_msgSend;
    return init([class_named("INRideDriver") alloc], selector, handle, components, nil, rating, phone);
}

int main(void)
{
    @autoreleasepool {
        setvbuf(stdout, NULL, _IOLBF, 0);
        NSPersonNameComponents *alice = [[NSPersonNameComponents alloc] init];
        alice.givenName = @"Alice";
        alice.familyName = @"Smith";

        describe("display-all", init_handle_display(@"alice@example.com", @"Alice Smith", @"4.9", @"+15550100"));
        describe("display-nil-name", init_handle_display(@"alice@example.com", nil, @"4.9", @"+15550100"));
        describe("display-nil-handle", init_handle_display(nil, @"Bob", @"4.9", @"+15550100"));
        describe("display-empty", init_handle_display(@"", @"", @"", @""));
        describe("display-nil-rating", init_handle_display(@"alice@example.com", @"Alice Smith", nil, nil));
        describe("components-all", init_handle_components(@"alice@example.com", alice, @"4.9", @"+15550100"));
        describe("components-nil", init_handle_components(@"alice@example.com", nil, @"4.9", @"+15550100"));
        describe("components-nil-handle", init_handle_components(nil, alice, @"4.9", @"+15550100"));
        NSPersonNameComponents *givenOnly = [[NSPersonNameComponents alloc] init];
        givenOnly.givenName = @"Alice";
        NSPersonNameComponents *familyOnly = [[NSPersonNameComponents alloc] init];
        familyOnly.familyName = @"Smith";
        NSPersonNameComponents *empty = [[NSPersonNameComponents alloc] init];
        describe("components-given-only", init_handle_components(@"alice@example.com", givenOnly, @"4.9", @"+15550100"));
        describe("components-family-only", init_handle_components(@"alice@example.com", familyOnly, @"4.9", @"+15550100"));
        describe("components-empty", init_handle_components(@"alice@example.com", empty, @"4.9", @"+15550100"));
        describe("display-nil-both", init_handle_display(nil, nil, @"4.9", @"+15550100"));
        describe("components-nil-both", init_handle_components(nil, nil, @"4.9", @"+15550100"));
        NSPersonNameComponents *full = [[NSPersonNameComponents alloc] init];
        full.namePrefix = @"Dr.";
        full.givenName = @"Alice";
        full.middleName = @"Marie";
        full.familyName = @"Smith";
        full.nameSuffix = @"Jr.";
        full.nickname = @"Al";
        NSPersonNameComponents *withMiddle = [[NSPersonNameComponents alloc] init];
        withMiddle.givenName = @"Alice";
        withMiddle.middleName = @"Marie";
        NSPersonNameComponents *prefixFamily = [[NSPersonNameComponents alloc] init];
        prefixFamily.namePrefix = @"Dr.";
        prefixFamily.familyName = @"Smith";
        NSPersonNameComponents *suffixOnly = [[NSPersonNameComponents alloc] init];
        suffixOnly.nameSuffix = @"Jr.";
        NSPersonNameComponents *nicknameOnly = [[NSPersonNameComponents alloc] init];
        nicknameOnly.nickname = @"Al";
        NSPersonNameComponents *blanks = [[NSPersonNameComponents alloc] init];
        blanks.givenName = @" ";
        blanks.familyName = @"";
        describe("name-full", init_handle_components(@"alice@example.com", full, @"4.9", @"+15550100"));
        describe("name-middle", init_handle_components(@"alice@example.com", withMiddle, @"4.9", @"+15550100"));
        describe("name-prefix-family", init_handle_components(@"alice@example.com", prefixFamily, @"4.9", @"+15550100"));
        describe("name-suffix-only", init_handle_components(@"alice@example.com", suffixOnly, @"4.9", @"+15550100"));
        describe("name-nickname-only", init_handle_components(@"alice@example.com", nicknameOnly, @"4.9", @"+15550100"));
        describe("name-blanks", init_handle_components(@"alice@example.com", blanks, @"4.9", @"+15550100"));
    }
    return 0;
}
