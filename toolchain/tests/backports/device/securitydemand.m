#import <Foundation/Foundation.h>
#import <Security/Security.h>
#include <dlfcn.h>
#import "check.h"

#pragma clang diagnostic ignored "-Wunguarded-availability-new"

static NSString *image_of(void *symbol)
{
    Dl_info info;
    return dladdr(symbol, &info) ? @(info.dli_fname).lastPathComponent : @"?";
}

static void check_constants(void)
{
    CHECK_EQUAL(image_of((void *)&kSecAttrAccessControl), @"libSecurityBackports.dylib", "kSecAttrAccessControl comes from the backports");
    CHECK_EQUAL((__bridge NSString *)kSecAttrAccessControl, @"accc", "the access control key");
    CHECK_EQUAL((__bridge NSString *)kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly, @"akpu", "the passcode accessibility");
    CHECK_EQUAL((__bridge NSString *)kSecUseOperationPrompt, @"u_OpPrompt", "the operation prompt key");
    CHECK_EQUAL((__bridge NSString *)kSecUseNoAuthenticationUI, @"u_NoAuthUI", "the no authentication UI key");
    CHECK_EQUAL((__bridge NSString *)kSecSharedPassword, @"spwd", "the shared password key");
    CHECK_EQUAL((__bridge NSString *)kSecUseAuthenticationContext, @"u_AuthCtx", "the authentication context key");
    CHECK_EQUAL((__bridge NSString *)kSecUseAuthenticationUI, @"u_AuthUI", "the authentication UI key");
    CHECK_EQUAL((__bridge NSString *)kSecUseAuthenticationUIAllow, @"u_AuthUIA", "allow");
    CHECK_EQUAL((__bridge NSString *)kSecUseAuthenticationUIFail, @"u_AuthUIF", "fail");
    CHECK_EQUAL((__bridge NSString *)kSecUseAuthenticationUISkip, @"u_AuthUIS", "skip");
}

static void check_access_control(void)
{
    CFErrorRef error = NULL;
    SecAccessControlRef control = SecAccessControlCreateWithFlags(kCFAllocatorDefault, kSecAttrAccessibleWhenUnlocked, kSecAccessControlUserPresence, &error);
    CHECK(control == NULL, "there is no access control object");
    CHECK(error != NULL, "the error is set");
    NSError *reason = CFBridgingRelease(error);
    CHECK_EQUAL(reason.domain, NSOSStatusErrorDomain, "the domain of the error");
    CHECK(reason.code == errSecUnimplemented, "the code of the error");
    CHECK(SecAccessControlCreateWithFlags(kCFAllocatorDefault, kSecAttrAccessibleWhenUnlocked, 0, NULL) == NULL, "no error asked for is fine");
}

static void check_shared_credentials(void)
{
    dispatch_semaphore_t done = dispatch_semaphore_create(0);
    __block NSError *added = nil;
    __block BOOL addedOnMain = YES;
    SecAddSharedWebCredential(CFSTR("example.com"), CFSTR("user"), CFSTR("secret"), ^(CFErrorRef error) {
        added = error ? (__bridge NSError *)error : nil;
        added = [added copy];
        addedOnMain = [NSThread isMainThread];
        dispatch_semaphore_signal(done);
    });
    CHECK(dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC)) == 0, "the add calls its block");
    CHECK(added != nil && added.code == errSecUnimplemented, "the add fails with errSecUnimplemented");
    CHECK(!addedOnMain, "off the main thread");
    __block CFIndex count = -1;
    __block BOOL gotError = YES;
    SecRequestSharedWebCredential(CFSTR("example.com"), NULL, ^(CFArrayRef credentials, CFErrorRef error) {
        count = credentials ? CFArrayGetCount(credentials) : -1;
        gotError = error != NULL;
        dispatch_semaphore_signal(done);
    });
    CHECK(dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC)) == 0, "the request calls its block");
    CHECK(count == 0 && !gotError, "the request finds no credential and no error");
    SecAddSharedWebCredential(CFSTR("example.com"), CFSTR("user"), NULL, NULL);
    SecRequestSharedWebCredential(NULL, NULL, NULL);
    CHECK(YES, "a nil block is allowed");
}

static void check_password(void)
{
    NSMutableSet *seen = [NSMutableSet set];
    NSString *digits = @"23456789", *upper = @"ABCDEFGHJKLMNPQRSTUVWXYZ", *lower = @"abcdefghkmnopqrstuvwxyz";
    int badShape = 0, badClasses = 0;
    for (int i = 0; i < 2000; i++) {
        NSString *password = CFBridgingRelease(SecCreateSharedWebCredentialPassword());
        [seen addObject:password];
        if (password.length != 15 || [password characterAtIndex:3] != '-' || [password characterAtIndex:7] != '-' || [password characterAtIndex:11] != '-')
            badShape++;
        BOOL hasDigit = NO, hasUpper = NO, hasLower = NO, bad = NO;
        for (NSUInteger k = 0; k < password.length; k++) {
            NSString *c = [password substringWithRange:NSMakeRange(k, 1)];
            if (k == 3 || k == 7 || k == 11)
                continue;
            hasDigit = hasDigit || [digits containsString:c];
            hasUpper = hasUpper || [upper containsString:c];
            hasLower = hasLower || [lower containsString:c];
            if (![digits containsString:c] && ![upper containsString:c] && ![lower containsString:c])
                bad = YES;
        }
        if (!(hasDigit && hasUpper && hasLower) || bad)
            badClasses++;
    }
    CHECK(badShape == 0, "every password is xxx-xxx-xxx-xxx");
    CHECK(badClasses == 0, "every password has a digit, a capital and a small letter, and only the letters of the set");
    CHECK(seen.count > 1990, "the passwords are not repeated");
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        if (argc > 1)
            charon_log_to(@(argv[1]));
        check_constants();
        check_access_control();
        check_shared_credentials();
        check_password();
        printf("%d checks, %d failed\n", charon_checks, charon_failures);
    }
    return charon_failures;
}
