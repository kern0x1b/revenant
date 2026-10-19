#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <dlfcn.h>
#import "check.h"

extern CFStringRef SecCopyErrorMessageString(OSStatus status, void *reserved) __attribute__((weak_import));

static NSString *image_of(void *address)
{
    Dl_info info;
    return address && dladdr(address, &info) && info.dli_fname ? @(info.dli_fname).lastPathComponent : @"?";
}

static NSString *message(OSStatus status)
{
    CFStringRef string = SecCopyErrorMessageString(status, NULL);
    return string ? CFBridgingRelease(string) : @"(null)";
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        if (argc > 1)
            charon_log_to(@(argv[1]));
        CHECK(SecCopyErrorMessageString != NULL, "the function is there");
        CHECK_EQUAL(image_of((void *)SecCopyErrorMessageString), @"libSecurityBackports.dylib", "it comes from the backports");
        CHECK_EQUAL(message(errSecItemNotFound), @"The specified item could not be found in the keychain.", "item not found");
        CHECK_EQUAL(message(errSecDuplicateItem), @"The specified item already exists in the keychain.", "duplicate item");
        CHECK_EQUAL(message(errSecAuthFailed), @"The user name or passphrase you entered is not correct.", "authentication failed");
        CHECK_EQUAL(message(errSecParam), @"One or more parameters passed to a function were not valid.", "parameters");
        CHECK_EQUAL(message(errSecAllocate), @"Failed to allocate memory.", "allocation");
        CHECK_EQUAL(message(errSSLProtocol), @"SSL protocol error", "an SSL error");
        CHECK_EQUAL(message(0), @"No error.", "success");
        CHECK_EQUAL(message(12345), @"OSStatus 12345", "an unknown code is named by its number");
        CHECK_EQUAL(message(-1), @"OSStatus -1", "a negative unknown code too");
        CHECK_EQUAL(message(INT_MIN), @"OSStatus -2147483648", "the smallest status");
        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
    }
    return charon_failures ? 1 : 0;
}
