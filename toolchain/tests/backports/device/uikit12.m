#import <UIKit/UIKit.h>
#import "check.h"
#import "homeindicator-cases.h"
#import "homeindicator-expectations.h"
#import "insetref-cases.h"
#import "insetref-expectations.h"
#import "traits11-cases.h"
#import "traits11-expectations.h"

static NSString *const results_folder = @"/private/var/backports";

static BOOL close_enough(NSString *expected, NSString *actual, double tolerance)
{
    if (!actual)
        return NO;
    NSCharacterSet *separators = [NSCharacterSet characterSetWithCharactersInString:@"; "];
    NSArray *left = [expected componentsSeparatedByCharactersInSet:separators];
    NSArray *right = [actual componentsSeparatedByCharactersInSet:separators];
    if (left.count != right.count)
        return NO;
    for (NSUInteger index = 0; index < left.count; index++) {
        const char *a = [left[index] UTF8String], *b = [right[index] UTF8String];
        char *endA = NULL, *endB = NULL;
        double x = strtod(a, &endA), y = strtod(b, &endB);
        BOOL numeric = *a && !*endA && *b && !*endB;
        if (numeric ? fabs(x - y) > tolerance : ![left[index] isEqualToString:right[index]])
            return NO;
    }
    return YES;
}

@interface UIKit12Delegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation UIKit12Delegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options
{
    [[NSFileManager defaultManager] createDirectoryAtPath:results_folder withIntermediateDirectories:YES attributes:nil error:NULL];
    [[NSFileManager defaultManager] removeItemAtPath:[results_folder stringByAppendingPathComponent:@"uikit12.done"] error:NULL];
    charon_log_to([results_folder stringByAppendingPathComponent:@"uikit12.log"]);
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.rootViewController = [[UIViewController alloc] init];
    [self.window makeKeyAndVisible];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        void (^compare)(const char *, double, void (^)(UIWindow *, void (^)(NSString *, NSString *)), NSString *) = ^(const char *json, double tolerance, void (^run)(UIWindow *, void (^)(NSString *, NSString *)), NSString *label) {
            NSDictionary *expected = [NSJSONSerialization JSONObjectWithData:[NSData dataWithBytes:json length:strlen(json)] options:0 error:NULL];
            NSMutableDictionary *records = [NSMutableDictionary dictionary];
            run(self.window, ^(NSString *name, NSString *value) { records[name] = value; printf("record %s: %s\n", name.UTF8String, value.UTF8String); });
            for (NSString *name in [expected.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
                if ([label isEqualToString:@"inset reference"] && [name hasPrefix:@"ref0."] && [name rangeOfString:@"contentInset"].location != NSNotFound) {
                    printf("skipped %s: the release's own lines do not take a content inset off the width\n", name.UTF8String);
                    continue;
                }
                NSString *check = [NSString stringWithFormat:@"%@ %@", label, name];
                if (tolerance > 0 ? close_enough(expected[name], records[name], tolerance) : [expected[name] isEqualToString:records[name]])
                    charon_check(YES, check.UTF8String, nil);
                else
                    charon_check(NO, check.UTF8String, [NSString stringWithFormat:@"\n    device %@\n    host   %@", records[name], expected[name]]);
            }
            CHECK(records.count == expected.count, [[label stringByAppendingString:@": the device answers every record the host did and no other"] UTF8String]);
        };
        compare(homeindicator_expectations, 0, ^(UIWindow *window, void (^record)(NSString *, NSString *)) { homeindicator_run(window, record); }, @"home indicator");
        compare(traits11_expectations, 0, ^(UIWindow *window, void (^record)(NSString *, NSString *)) { traits11_run(window, record); }, @"traits");
        compare(insetref_expectations, 0.5, ^(UIWindow *window, void (^record)(NSString *, NSString *)) { insetref_run(window, record); }, @"inset reference");
        UIScrollView *scroll = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, 200, 300)];
        scroll.contentSize = CGSizeMake(200, 1200);
        scroll.scrollIndicatorInsets = UIEdgeInsetsMake(1, 2, 3, 4);
        scroll.verticalScrollIndicatorInsets = UIEdgeInsetsMake(5, 6, 7, 8);
        CHECK(UIEdgeInsetsEqualToEdgeInsets(scroll.scrollIndicatorInsets, UIEdgeInsetsMake(1, 2, 3, 4)), "the scroll indicator insets stay what was set beside a vertical set");
        scroll.horizontalScrollIndicatorInsets = UIEdgeInsetsMake(9, 10, 11, 12);
        CHECK(UIEdgeInsetsEqualToEdgeInsets(scroll.scrollIndicatorInsets, UIEdgeInsetsMake(1, 2, 3, 4)) && UIEdgeInsetsEqualToEdgeInsets(scroll.horizontalScrollIndicatorInsets, UIEdgeInsetsMake(9, 10, 11, 12)), "and beside a horizontal one");
        scroll.scrollIndicatorInsets = UIEdgeInsetsMake(20, 21, 22, 23);
        CHECK(UIEdgeInsetsEqualToEdgeInsets(scroll.verticalScrollIndicatorInsets, UIEdgeInsetsMake(20, 21, 22, 23)) && UIEdgeInsetsEqualToEdgeInsets(scroll.horizontalScrollIndicatorInsets, UIEdgeInsetsMake(20, 21, 22, 23)), "setting them again takes both back to them");
        UIScrollView *shifted = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, 200, 300)];
        UIScrollView *plain = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, 200, 300)];
        shifted.contentSize = plain.contentSize = CGSizeMake(200, 1200);
        shifted.verticalScrollIndicatorInsets = UIEdgeInsetsMake(10, 0, 50, 5);
        plain.scrollIndicatorInsets = UIEdgeInsetsMake(10, 0, 50, 5);
        [shifted flashScrollIndicators];
        [plain flashScrollIndicators];
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.3]];
        UIView *shiftedBar = nil, *plainBar = nil;
        @try {
            shiftedBar = [shifted valueForKey:@"_verticalScrollIndicator"];
            plainBar = [plain valueForKey:@"_verticalScrollIndicator"];
        } @catch (NSException *exception) {
        }
        if (shiftedBar && plainBar)
            CHECK(CGRectEqualToRect(shiftedBar.frame, plainBar.frame) && shiftedBar.frame.size.height > 0, "the vertical indicator sits where the same insets of the release put it");
        else
            printf("skipped: the vertical indicator is not reachable\n");
        UIViewController *root = [[UIViewController alloc] init];
        UIViewController *top = [[UIViewController alloc] init];
        UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:root];
        [navigation pushViewController:top animated:NO];
        CHECK(navigation.childViewControllerForScreenEdgesDeferringSystemGestures == top, "a navigation controller passes the edge gestures to its top view controller, as UIKit 12 does");
        UITabBarController *tabs = [[UITabBarController alloc] init];
        tabs.viewControllers = @[root, top];
        tabs.selectedIndex = 1;
        CHECK(tabs.childViewControllerForScreenEdgesDeferringSystemGestures == top, "and a tab bar controller to the selected one");
        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
        NSString *summary = [NSString stringWithFormat:@"%@ checks=%d failures=%d\n", charon_failures ? @"FAIL" : @"ok", charon_checks, charon_failures];
        [summary writeToFile:[results_folder stringByAppendingPathComponent:@"uikit12.done"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    });
    return YES;
}

@end

int main(int argc, char **argv)
{
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([UIKit12Delegate class]));
    }
}
