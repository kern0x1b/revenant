#import <UIKit/UIKit.h>
#import "check.h"
#import "suitedefaults-cases.h"
#import "suitedefaults-expectations.h"

static NSString *const results_folder = @"/private/var/backports";

@interface SuiteDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation SuiteDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options
{
    [[NSFileManager defaultManager] createDirectoryAtPath:results_folder withIntermediateDirectories:YES attributes:nil error:NULL];
    [[NSFileManager defaultManager] removeItemAtPath:[results_folder stringByAppendingPathComponent:@"suitedefaults.done"] error:NULL];
    charon_log_to([results_folder stringByAppendingPathComponent:@"suitedefaults.log"]);
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.rootViewController = [[UIViewController alloc] init];
    [self.window makeKeyAndVisible];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSString *suite = [NSString stringWithFormat:@"charon.suite.%d", (int)getpid()];
        NSMutableArray *records = [NSMutableArray array];
        suite_run(^{ return [[NSUserDefaults alloc] initWithSuiteName:suite]; }, ^(NSString *name, NSString *value) { [records addObject:@[name, value]]; });
        CHECK(records.count == sizeof suitedefaults_expectations / sizeof suitedefaults_expectations[0], "there is one recorded answer for every case");
        for (NSUInteger index = 0; index < records.count && index < sizeof suitedefaults_expectations / sizeof suitedefaults_expectations[0]; index++)
            CHECK_EQUAL(records[index][1], @(suitedefaults_expectations[index]), [records[index][0] UTF8String]);
        CHECK([[NSUserDefaults alloc] initWithSuiteName:[NSBundle mainBundle].bundleIdentifier] == nil, "the suite of the application's own identifier is nil");
        CHECK([[NSUserDefaults alloc] initWithSuiteName:NSGlobalDomain] == nil, "and so is the global domain");
        NSUserDefaults *standard = [[NSUserDefaults alloc] initWithSuiteName:nil];
        CHECK(standard != nil, "no name gives the application's own defaults");
        NSUserDefaults *d = [[NSUserDefaults alloc] initWithSuiteName:suite];
        BOOL raised = NO;
        @try { [d setObject:[[NSObject alloc] init] forKey:@"bad"]; } @catch (NSException *e) { raised = [e.name isEqual:NSInvalidArgumentException]; }
        CHECK(raised, "an object that is not a property list is refused");
        CHECK(![[NSUserDefaults standardUserDefaults] objectForKey:@"arr"], "the suite does not write into the standard defaults");
        [d removeObjectForKey:@"arr"];
        NSString *plist = [NSString stringWithFormat:@"%@/Library/Preferences/%@.plist", NSHomeDirectory(), suite];
        [d synchronize];
        [[NSFileManager defaultManager] removeItemAtPath:plist error:NULL];
        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
        NSString *summary = [NSString stringWithFormat:@"%@ checks=%d failures=%d\n", charon_failures ? @"FAIL" : @"ok", charon_checks, charon_failures];
        [summary writeToFile:[results_folder stringByAppendingPathComponent:@"suitedefaults.done"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    });
    return YES;
}

@end

int main(int argc, char **argv)
{
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([SuiteDelegate class]));
    }
}
