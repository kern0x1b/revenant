#import <UIKit/UIKit.h>
#import "check.h"
#import "errorprovider-cases.h"
#import "errorprovider-expectations.h"

static NSString *const results_folder = @"/private/var/backports";

@interface ErrorProviderDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation ErrorProviderDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options
{
    [[NSFileManager defaultManager] createDirectoryAtPath:results_folder withIntermediateDirectories:YES attributes:nil error:NULL];
    [[NSFileManager defaultManager] removeItemAtPath:[results_folder stringByAppendingPathComponent:@"errorprovider.done"] error:NULL];
    charon_log_to([results_folder stringByAppendingPathComponent:@"errorprovider.log"]);
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.rootViewController = [[UIViewController alloc] init];
    [self.window makeKeyAndVisible];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSDictionary *expected = [NSJSONSerialization JSONObjectWithData:[NSData dataWithBytes:errorprovider_expectations length:strlen(errorprovider_expectations)] options:0 error:NULL];
        NSMutableDictionary *records = [NSMutableDictionary dictionary];
        errorprovider_run([NSError class], ^(Class error_class, NSString *domain, id provider) {
            [NSError setUserInfoValueProviderForDomain:domain provider:provider];
        }, ^(NSString *name, NSString *value) {
            records[name] = value;
            printf("record %s: %s\n", name.UTF8String, value.UTF8String);
        });
        for (NSString *name in [expected.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
            if ([expected[name] isEqualToString:records[name]])
                charon_check(YES, name.UTF8String, nil);
            else
                charon_check(NO, name.UTF8String, [NSString stringWithFormat:@"\n    device %@\n    expected %@", records[name], expected[name]]);
        }
        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
        NSString *summary = [NSString stringWithFormat:@"%@ checks=%d failures=%d\n", charon_failures ? @"FAIL" : @"ok", charon_checks, charon_failures];
        [summary writeToFile:[results_folder stringByAppendingPathComponent:@"errorprovider.done"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    });
    return YES;
}

@end

int main(int argc, char **argv)
{
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([ErrorProviderDelegate class]));
    }
}
