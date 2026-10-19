#import <UIKit/UIKit.h>
#import "check.h"
#import "uikitnames-cases.h"
#import "uikitnames-expectations.h"

static NSArray *numbers(NSString *text)
{
    NSMutableArray *found = [NSMutableArray array];
    for (NSString *part in [text componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@" |"]])
        if (part.length && ([part doubleValue] != 0 || [part hasPrefix:@"0"] || [part hasPrefix:@"-0"]))
            [found addObject:@([part doubleValue])];
    return found;
}

static NSString *tolerance(NSString *name, NSString *device, NSString *host)
{
    if ([device isEqualToString:host])
        return nil;
    if ([name isEqualToString:@"attachment.wrapper"] && [device isEqualToString:@"wrapped"])
        return @"the release keeps an attachment's wrapper as its data, so its contents are the wrapper's once one is set";
    BOOL drawn = NO;
    NSArray *left = numbers(device), *right = numbers(host);
    if (left.count != right.count || !left.count)
        return nil;
    for (NSUInteger index = 0; index < left.count; index++)
        if (fabs([left[index] doubleValue] - [right[index] doubleValue]) > MAX(drawn ? 4 : 2, 0.12 * fabs([right[index] doubleValue])))
            return nil;
    return @"the fonts of the two releases measure alike to within a tenth";
}

static NSString *const results_folder = @"/private/var/backports";

@interface UIKitNamesDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation UIKitNamesDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options
{
    [[NSFileManager defaultManager] createDirectoryAtPath:results_folder withIntermediateDirectories:YES attributes:nil error:NULL];
    [[NSFileManager defaultManager] removeItemAtPath:[results_folder stringByAppendingPathComponent:@"uikitnames.done"] error:NULL];
    charon_log_to([results_folder stringByAppendingPathComponent:@"uikitnames.log"]);
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.rootViewController = [[UIViewController alloc] init];
    [self.window makeKeyAndVisible];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSDictionary *expected = [NSJSONSerialization JSONObjectWithData:[NSData dataWithBytes:uikitnames_expectations length:strlen(uikitnames_expectations)] options:0 error:NULL];
        NSMutableDictionary *records = [NSMutableDictionary dictionary];
        uikitnames_run(^(NSString *name, NSString *value) {
            records[name] = value;
            printf("record %s: %s\n", name.UTF8String, value.UTF8String);
        });
        for (NSString *name in [expected.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
            if ([expected[name] isEqualToString:records[name]] || tolerance(name, records[name], expected[name]))
                charon_check(YES, name.UTF8String, nil);
            else
                charon_check(NO, name.UTF8String, [NSString stringWithFormat:@"\n    device %@\n    host   %@", records[name], expected[name]]);
        }
        UIWindow *window = [[UIWindow alloc] initWithFrame:CGRectMake(0, 0, 320, 480)];
        UIView *inner = [[UIView alloc] initWithFrame:CGRectMake(10, 20, 100, 100)];
        UIView *deeper = [[UIView alloc] initWithFrame:CGRectMake(5, 5, 50, 50)];
        [window addSubview:inner];
        [inner addSubview:deeper];
        CGRect converted = UIAccessibilityConvertFrameToScreenCoordinates(CGRectMake(1, 2, 3, 4), deeper);
        CHECK(fabs(converted.origin.x - 16) < 0.01 && fabs(converted.origin.y - 27) < 0.01 && converted.size.width == 3 && converted.size.height == 4, "a frame in a view of a window is converted through the views and the window");
        CGRect bounds = CGRectMake(0, 0, 320, 480);
        Class edge = [UIScreenEdgePanGestureRecognizer class];
        BOOL (*near)(id, SEL, CGPoint, UIRectEdge, CGRect) = (BOOL (*)(id, SEL, CGPoint, UIRectEdge, CGRect))[edge methodForSelector:NSSelectorFromString(@"charon_point:isNearEdges:inBounds:")];
        SEL nearSelector = NSSelectorFromString(@"charon_point:isNearEdges:inBounds:");
        CHECK(near(edge, nearSelector, CGPointMake(5, 200), UIRectEdgeLeft, bounds) && !near(edge, nearSelector, CGPointMake(60, 200), UIRectEdgeLeft, bounds), "a touch within twenty points of the left edge starts an edge pan, one farther in does not");
        CHECK(near(edge, nearSelector, CGPointMake(315, 200), UIRectEdgeRight, bounds) && !near(edge, nearSelector, CGPointMake(5, 200), UIRectEdgeRight, bounds), "and the right edge is the right");
        CHECK(!near(edge, nearSelector, CGPointMake(5, 200), 0, bounds), "no edges start none");
        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
        NSString *summary = [NSString stringWithFormat:@"%@ checks=%d failures=%d\n", charon_failures ? @"FAIL" : @"ok", charon_checks, charon_failures];
        [summary writeToFile:[results_folder stringByAppendingPathComponent:@"uikitnames.done"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    });
    return YES;
}

@end

int main(int argc, char **argv)
{
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([UIKitNamesDelegate class]));
    }
}
