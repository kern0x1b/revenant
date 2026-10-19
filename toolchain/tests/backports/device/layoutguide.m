#import <UIKit/UIKit.h>
#import "check.h"
#import "layoutguide-cases.h"
#import "layoutguide-expectations.h"

@interface NSObject (GuideProbe)
- (BOOL)_supportsContentDimensionVariables;
- (void)_rememberDependentConstraint:(NSLayoutConstraint *)constraint;
- (void)_setWantsAutolayout;
@end

static NSString *const results_folder = @"/private/var/backports";

@interface LayoutGuideDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation LayoutGuideDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options
{
    [[NSFileManager defaultManager] createDirectoryAtPath:results_folder withIntermediateDirectories:YES attributes:nil error:NULL];
    [[NSFileManager defaultManager] removeItemAtPath:[results_folder stringByAppendingPathComponent:@"layoutguide.done"] error:NULL];
    charon_log_to([results_folder stringByAppendingPathComponent:@"layoutguide.log"]);
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.rootViewController = [[UIViewController alloc] init];
    [self.window makeKeyAndVisible];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSDictionary *expected = [NSJSONSerialization JSONObjectWithData:[NSData dataWithBytes:layoutguide_expectations length:strlen(layoutguide_expectations)] options:0 error:NULL];
        NSMutableDictionary *records = [NSMutableDictionary dictionary];
        layoutguide_run(self.window, ^(NSString *name, NSString *value) {
            records[name] = value;
            printf("record %s: %s\n", name.UTF8String, value.UTF8String);
        });
        for (NSString *name in [expected.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
            if ([expected[name] isEqualToString:records[name]] )
                charon_check(YES, name.UTF8String, nil);
            else
                charon_check(NO, name.UTF8String, [NSString stringWithFormat:@"\n    device %@\n    host   %@", records[name], expected[name]]);
        }
        UIView *host = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 200, 100)];
        UILayoutGuide *guide = [[UILayoutGuide alloc] init];
        CHECK([(id)guide superview] == nil, "a guide with no owner has no superview");
        [host addLayoutGuide:guide];
        CHECK([(id)guide superview] == host, "a guide's superview is its owning view, which the release asks of a constraint's items");
        CHECK(![(id)guide _supportsContentDimensionVariables], "a guide has no content dimension variables");
        NSLayoutConstraint *constraint = [guide.widthAnchor constraintEqualToConstant:50];
        BOOL raised = NO;
        @try {
            [(id)guide _rememberDependentConstraint:constraint];
            [(id)guide _setWantsAutolayout];
        } @catch (NSException *e) { raised = YES; }
        CHECK(!raised, "the calls the release makes on the item of a constraint are answered");
        constraint.active = YES;
        [host layoutIfNeeded];
        CHECK(fabs(guide.layoutFrame.size.width - 50) < 0.5, "and a constraint on the guide is solved");
        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
        NSString *summary = [NSString stringWithFormat:@"%@ checks=%d failures=%d\n", charon_failures ? @"FAIL" : @"ok", charon_checks, charon_failures];
        [summary writeToFile:[results_folder stringByAppendingPathComponent:@"layoutguide.done"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    });
    return YES;
}

@end

int main(int argc, char **argv)
{
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([LayoutGuideDelegate class]));
    }
}
