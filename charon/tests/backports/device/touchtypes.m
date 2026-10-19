#import <UIKit/UIKit.h>
#import "check.h"
#import "gesture.h"
#import "touchtypes-cases.h"
#import "touchtypes-expectations.h"

static NSString *const results_folder = @"/private/var/backports";

@interface TouchTypesDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) NSMutableArray *fired;
@end

@implementation TouchTypesDelegate

- (void)tapped:(UITapGestureRecognizer *)tap
{
    [self.fired addObject:tap.view.accessibilityLabel];
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options
{
    [[NSFileManager defaultManager] createDirectoryAtPath:results_folder withIntermediateDirectories:YES attributes:nil error:NULL];
    [[NSFileManager defaultManager] removeItemAtPath:[results_folder stringByAppendingPathComponent:@"touchtypes.done"] error:NULL];
    charon_log_to([results_folder stringByAppendingPathComponent:@"touchtypes.log"]);
    self.fired = [NSMutableArray array];
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.rootViewController = [[UIViewController alloc] init];
    [self.window makeKeyAndVisible];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSDictionary *expected = [NSJSONSerialization JSONObjectWithData:[NSData dataWithBytes:touchtypes_expectations length:strlen(touchtypes_expectations)] options:0 error:NULL];
        NSMutableDictionary *records = [NSMutableDictionary dictionary];
        touchtypes_run(self.window, ^(NSString *name, NSString *value) { records[name] = value; printf("record %s: %s\n", name.UTF8String, value.UTF8String); });
        for (NSString *name in [expected.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
            if ([expected[name] isEqualToString:records[name]])
                charon_check(YES, name.UTF8String, nil);
            else
                charon_check(NO, name.UTF8String, [NSString stringWithFormat:@"\n    device %@\n    host   %@", records[name], expected[name]]);
        }
        UIViewController *controller = self.window.rootViewController;
        NSArray *cases = @[@[@"default", [NSNull null]], @[@"direct", @[@(UITouchTypeDirect)]], @[@"indirect", @[@(UITouchTypeIndirect)]], @[@"empty", @[]], @[@"both", @[@(UITouchTypeIndirect), @(UITouchTypeDirect)]]];
        CGFloat width = self.window.bounds.size.width;
        for (NSUInteger index = 0; index < cases.count; index++) {
            UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 60 + 70 * index, width, 60)];
            view.accessibilityLabel = cases[index][0];
            view.backgroundColor = [UIColor colorWithWhite:0.9f alpha:1];
            UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapped:)];
            if (![cases[index][1] isKindOfClass:[NSNull class]])
                tap.allowedTouchTypes = cases[index][1];
            [view addGestureRecognizer:tap];
            [controller.view addSubview:view];
        }
        gesture_step(0.01, ^{ CHECK(gesture_ready(), "touches can be sent"); });
        gesture_tap(^{ return CGPointMake(width / 2, 30); }, 0.3);
        for (NSUInteger index = 0; index < cases.count; index++) {
            NSString *name = cases[index][0];
            BOOL should = [name isEqual:@"default"] || [name isEqual:@"direct"] || [name isEqual:@"both"];
            gesture_tap(^{ return CGPointMake(width / 2, 90 + 70 * index); }, 0.4);
            gesture_step(0.1, ^{
                BOOL did = [self.fired containsObject:name];
                charon_check(did == should, [[NSString stringWithFormat:@"a real finger %@ a tap recognizer that allows %@", should ? @"runs" : @"does not run", name] UTF8String], nil);
            });
        }
        gesture_run(^{
            UITouch *probe = nil;
            (void)probe;
            printf("checks=%d failures=%d\n", charon_checks, charon_failures);
            NSString *summary = [NSString stringWithFormat:@"%@ checks=%d failures=%d\n", charon_failures ? @"FAIL" : @"ok", charon_checks, charon_failures];
            [summary writeToFile:[results_folder stringByAppendingPathComponent:@"touchtypes.done"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
        });
    });
    return YES;
}

@end

int main(int argc, char **argv)
{
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([TouchTypesDelegate class]));
    }
}
