#import <UIKit/UIKit.h>
#import <Security/Security.h>
#include <dlfcn.h>
#import "check.h"

static NSString *const results_folder = @"/private/var/backports";

static NSDictionary *item(NSString *account, id sync, BOOL data)
{
    NSMutableDictionary *d = [NSMutableDictionary dictionaryWithDictionary:@{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: @"charon.secitem",
        (__bridge id)kSecAttrAccount: account}];
    if (sync)
        d[(__bridge id)kSecAttrSynchronizable] = sync;
    if (data)
        d[(__bridge id)kSecValueData] = [@"secret" dataUsingEncoding:NSUTF8StringEncoding];
    return d;
}

static OSStatus copy(NSDictionary *query, NSData **data)
{
    NSMutableDictionary *q = [query mutableCopy];
    q[(__bridge id)kSecReturnData] = @YES;
    CFTypeRef out = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)q, &out);
    if (data)
        *data = status == errSecSuccess ? CFBridgingRelease(out) : nil;
    return status;
}

static OSStatus add_with(NSString *account, NSDictionary *extra)
{
    NSMutableDictionary *d = [item(account, nil, YES) mutableCopy];
    [d addEntriesFromDictionary:extra];
    return SecItemAdd((__bridge CFDictionaryRef)d, NULL);
}

static void check_refusals(void)
{
    if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 7.0)
        return;
    SecItemDelete((__bridge CFDictionaryRef)item(@"r", nil, NO));
    CHECK(add_with(@"r", @{(__bridge id)kSecAttrAccessible: (__bridge id)kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly}) == errSecParam, "the keychain of the release refuses the passcode accessibility with -50");
    CHECK(add_with(@"r", @{(__bridge id)kSecAttrAccessControl: [NSData data]}) == errSecParam, "and an access control value");
    CHECK(add_with(@"r", @{(__bridge id)kSecAttrAccessible: (__bridge id)kSecAttrAccessibleWhenUnlockedThisDeviceOnly}) == errSecSuccess, "and takes the unlocked accessibility of this device");
    NSDictionary *base = item(@"r", nil, NO);
    NSArray *keys = @[(__bridge id)kSecUseOperationPrompt, (__bridge id)kSecUseAuthenticationContext, (__bridge id)kSecUseAuthenticationUI];
    for (id key in keys) {
        NSMutableDictionary *q = [base mutableCopy];
        q[(__bridge id)kSecReturnData] = @YES;
        q[key] = key == (__bridge id)kSecUseAuthenticationUI ? (__bridge id)kSecUseAuthenticationUIFail : @"x";
        CFTypeRef out = NULL;
        OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)q, &out);
        CHECK(status == errSecParam, [[@"a query with the key is refused with -50: " stringByAppendingString:key] UTF8String]);
    }
    SecItemDelete((__bridge CFDictionaryRef)base);
}

static void run(void)
{
    Dl_info info;
    CHECK(dladdr(&kSecAttrSynchronizable, &info) != 0, "the address of kSecAttrSynchronizable is known");
    CHECK_EQUAL(@(info.dli_fname).lastPathComponent, @"libSecurityBackports.dylib", "kSecAttrSynchronizable comes from the backports");
    CHECK_EQUAL((__bridge NSString *)kSecAttrSynchronizable, @"sync", "the attribute is sync");
    CHECK_EQUAL((__bridge NSString *)kSecAttrSynchronizableAny, @"syna", "the any value is syna");

    NSData *data = nil;
    SecItemDelete((__bridge CFDictionaryRef)item(@"a", (__bridge id)kSecAttrSynchronizableAny, NO));
    SecItemDelete((__bridge CFDictionaryRef)item(@"b", nil, NO));
    CHECK(SecItemAdd((__bridge CFDictionaryRef)item(@"a", @YES, YES), NULL) == errSecSuccess, "an item marked synchronizable is added");
    CHECK(copy(item(@"a", nil, NO), &data) == errSecSuccess && [data length] == 6, "a query with no attribute finds it");
    CHECK(copy(item(@"a", (__bridge id)kSecAttrSynchronizableAny, NO), &data) == errSecSuccess && [data length] == 6, "a query for Any finds it");
    CHECK(copy(item(@"a", @YES, NO), &data) == errSecSuccess, "a query for synchronizable finds it");
    CHECK(copy(item(@"a", @NO, NO), &data) == errSecSuccess, "a query for not synchronizable finds it too: the release keeps every item on the device");
    CHECK(SecItemAdd((__bridge CFDictionaryRef)item(@"a", @YES, YES), NULL) == errSecDuplicateItem, "the same item added again is a duplicate");
    CHECK(SecItemAdd((__bridge CFDictionaryRef)item(@"b", @NO, YES), NULL) == errSecSuccess, "an item marked not synchronizable is added");
    CHECK(copy(item(@"b", (__bridge id)kSecAttrSynchronizableAny, NO), &data) == errSecSuccess, "Any finds it");
    CHECK(SecItemDelete((__bridge CFDictionaryRef)item(@"a", (__bridge id)kSecAttrSynchronizableAny, NO)) == errSecSuccess, "a delete for Any removes the item");
    CHECK(copy(item(@"a", nil, NO), &data) == errSecItemNotFound, "it is gone");
    CHECK(SecItemDelete((__bridge CFDictionaryRef)item(@"b", nil, NO)) == errSecSuccess, "the other item is removed");
    check_refusals();
}

@interface Delegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation Delegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options
{
    [[NSFileManager defaultManager] createDirectoryAtPath:results_folder withIntermediateDirectories:YES attributes:nil error:NULL];
    [[NSFileManager defaultManager] removeItemAtPath:[results_folder stringByAppendingPathComponent:@"secitem.done"] error:NULL];
    charon_log_to([results_folder stringByAppendingPathComponent:@"secitem.log"]);
    run();
    NSString *summary = [NSString stringWithFormat:@"%d checks, %d failed\n", charon_checks, charon_failures];
    [summary writeToFile:[results_folder stringByAppendingPathComponent:@"secitem.done"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.backgroundColor = [UIColor whiteColor];
    [self.window makeKeyAndVisible];
    return YES;
}
@end

int main(int argc, char **argv)
{
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([Delegate class]));
    }
}
