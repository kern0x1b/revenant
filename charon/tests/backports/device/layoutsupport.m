#import <UIKit/UIKit.h>
#import "check.h"
#import "layoutsupport-cases.h"
#import "layoutsupport-expectations.h"

static NSString *const results_folder = @"/private/var/backports";

@interface LayoutSupportDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation LayoutSupportDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options
{
    [[NSFileManager defaultManager] createDirectoryAtPath:results_folder withIntermediateDirectories:YES attributes:nil error:NULL];
    [[NSFileManager defaultManager] removeItemAtPath:[results_folder stringByAppendingPathComponent:@"layoutsupport.done"] error:NULL];
    charon_log_to([results_folder stringByAppendingPathComponent:@"layoutsupport.log"]);
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.rootViewController = [[UIViewController alloc] init];
    [self.window makeKeyAndVisible];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSDictionary *expected = [NSJSONSerialization JSONObjectWithData:[NSData dataWithBytes:layoutsupport_expectations length:strlen(layoutsupport_expectations)] options:0 error:NULL];
        NSMutableDictionary *records = [NSMutableDictionary dictionary];
        layoutsupport_run(self.window, ^(NSString *name, NSString *value) {
            records[name] = value;
            printf("record %s: %s\n", name.UTF8String, value.UTF8String);
        });
        for (NSString *name in [expected.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
            if ([expected[name] isEqualToString:records[name]] )
                charon_check(YES, name.UTF8String, nil);
            else
                charon_check(NO, name.UTF8String, [NSString stringWithFormat:@"\n    device %@\n    host   %@", records[name], expected[name]]);
        }
        UIViewController *page = [[UIViewController alloc] init];
        page.wantsFullScreenLayout = YES;
        page.view.backgroundColor = [UIColor whiteColor];
        UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:page];
        navigation.navigationBar.barStyle = UIBarStyleBlackTranslucent;
        navigation.toolbarHidden = NO;
        navigation.toolbar.barStyle = UIBarStyleBlackTranslucent;
        self.window.rootViewController = navigation;
        [self.window layoutIfNeeded];
        UIView *content = [[UIView alloc] init];
        content.translatesAutoresizingMaskIntoConstraints = NO;
        [page.view addSubview:content];
        id<UILayoutSupport> top = page.topLayoutGuide, bottom = page.bottomLayoutGuide;
        [NSLayoutConstraint activateConstraints:@[
            [content.leadingAnchor constraintEqualToAnchor:page.view.leadingAnchor],
            [content.trailingAnchor constraintEqualToAnchor:page.view.trailingAnchor],
            [content.topAnchor constraintEqualToAnchor:top.bottomAnchor],
            [content.bottomAnchor constraintEqualToAnchor:bottom.topAnchor]
        ]];
        [page.view setNeedsLayout];
        [page.view layoutIfNeeded];
        CGFloat bar = navigation.navigationBar.frame.size.height, status = [UIApplication sharedApplication].statusBarFrame.size.height;
        printf("bars: status %g bar %g top %g bottom %g content %s\n", status, bar, top.length, bottom.length, NSStringFromCGRect(content.frame).UTF8String);
        CHECK(fabs(page.view.safeAreaInsets.top - (status + bar)) < 1, "the safe area of the view under a translucent navigation bar that sits below the status bar has both");
        CHECK(fabs(top.length - (status + bar)) < 1, "under a translucent navigation bar the top guide is the status bar and the bar");
        CHECK(fabs(bottom.length - navigation.toolbar.frame.size.height) < 1, "over a translucent toolbar the bottom guide is the toolbar");
        CHECK(fabs(content.frame.origin.y - top.length) < 1 && fabs(CGRectGetMaxY(content.frame) - (page.view.bounds.size.height - bottom.length)) < 1, "a view between the guides fits between the bars");
        navigation.toolbarHidden = YES;
        [page.view layoutIfNeeded];
        CHECK(bottom.length == 0 || fabs(bottom.length) < 1, "the bottom guide is nothing with the toolbar away");
        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
        NSString *summary = [NSString stringWithFormat:@"%@ checks=%d failures=%d\n", charon_failures ? @"FAIL" : @"ok", charon_checks, charon_failures];
        [summary writeToFile:[results_folder stringByAppendingPathComponent:@"layoutsupport.done"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    });
    return YES;
}

@end

int main(int argc, char **argv)
{
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([LayoutSupportDelegate class]));
    }
}
