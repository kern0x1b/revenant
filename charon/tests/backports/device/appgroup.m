#import <UIKit/UIKit.h>
#import "check.h"
#import "appgroup-cases.h"
#import "appgroup-expectations.h"

static NSString *const results_folder = @"/private/var/backports";

@interface AppGroupDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation AppGroupDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options
{
    [[NSFileManager defaultManager] createDirectoryAtPath:results_folder withIntermediateDirectories:YES attributes:nil error:NULL];
    [[NSFileManager defaultManager] removeItemAtPath:[results_folder stringByAppendingPathComponent:@"appgroup.done"] error:NULL];
    charon_log_to([results_folder stringByAppendingPathComponent:@"appgroup.log"]);
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.rootViewController = [[UIViewController alloc] init];
    [self.window makeKeyAndVisible];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSFileManager *manager = [NSFileManager defaultManager];
        NSArray *identifiers = APPGROUP_IDENTIFIERS;
        CHECK(sizeof appgroup_expectations / sizeof appgroup_expectations[0] == identifiers.count, "there is one recorded answer for every identifier");
        for (NSUInteger index = 0; index < identifiers.count; index++) {
            NSString *identifier = identifiers[index];
            NSURL *url = [manager containerURLForSecurityApplicationGroupIdentifier:identifier];
            NSString *name = [NSString stringWithFormat:@"%@ answers as the system does", identifier.length ? identifier : @"(empty)"];
            CHECK_EQUAL(appgroup_relative(url, NSHomeDirectory()), @(appgroup_expectations[index]), name.UTF8String);
            if (url) {
                BOOL directory = NO;
                CHECK([manager fileExistsAtPath:url.path isDirectory:&directory] && directory, "the container is a directory that exists");
            }
        }
        NSURL *first = [manager containerURLForSecurityApplicationGroupIdentifier:@"group.charon.test"];
        NSURL *again = [manager containerURLForSecurityApplicationGroupIdentifier:@"group.charon.test"];
        NSURL *other = [manager containerURLForSecurityApplicationGroupIdentifier:@"group.charon.other"];
        CHECK([first isEqual:again], "the same group gives the same container");
        CHECK(![first isEqual:other], "another group gives another container");
        NSURL *file = [first URLByAppendingPathComponent:@"shared.txt"];
        CHECK([@"kept" writeToURL:file atomically:YES encoding:NSUTF8StringEncoding error:NULL], "the container can be written");
        NSURL *reopened = [[manager containerURLForSecurityApplicationGroupIdentifier:@"group.charon.test"] URLByAppendingPathComponent:@"shared.txt"];
        CHECK_EQUAL([NSString stringWithContentsOfURL:reopened encoding:NSUTF8StringEncoding error:NULL], @"kept", "and what was written is found again");
        CHECK([[first.path stringByStandardizingPath] hasPrefix:[NSHomeDirectory() stringByStandardizingPath]], "the container lies in the application's own data");
        [manager removeItemAtURL:first error:NULL];
        [manager removeItemAtURL:other error:NULL];
        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
        NSString *summary = [NSString stringWithFormat:@"%@ checks=%d failures=%d\n", charon_failures ? @"FAIL" : @"ok", charon_checks, charon_failures];
        [summary writeToFile:[results_folder stringByAppendingPathComponent:@"appgroup.done"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    });
    return YES;
}

@end

int main(int argc, char **argv)
{
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppGroupDelegate class]));
    }
}
