#import <UIKit/UIKit.h>
#import "check.h"

static BOOL grey_with_alpha(NSString *actual, NSString *expected)
{
    NSArray *x = [actual componentsSeparatedByString:@","], *y = [expected componentsSeparatedByString:@","];
    return x.count == 4 && y.count == 4 && [x[0] intValue] == [x[1] intValue] && [x[1] intValue] == [x[2] intValue] && [y[0] intValue] == [y[1] intValue] && abs([x[3] intValue] - [y[3] intValue]) <= 3;
}

static BOOL close_enough(NSString *actual, NSString *expected)
{
    NSArray *left = [actual componentsSeparatedByString:@" "], *right = [expected componentsSeparatedByString:@" "];
    if (left.count != right.count)
        return NO;
    for (NSUInteger index = 0; index < left.count; index++) {
        NSString *a = left[index], *b = right[index];
        if ([a rangeOfString:@","].location == NSNotFound) {
            if (![a isEqualToString:b])
                return NO;
            continue;
        }
        NSArray *x = [a componentsSeparatedByString:@","], *y = [b componentsSeparatedByString:@","];
        if (x.count != y.count)
            return NO;
        for (NSUInteger channel = 0; channel < x.count; channel++)
            if (abs([x[channel] intValue] - [y[channel] intValue]) > 3)
                return NO;
    }
    return YES;
}
#import "template-cases.h"
#import "template-expectations.h"

static NSString *const results_folder = @"/private/var/backports";

@interface TemplateDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation TemplateDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options
{
    [[NSFileManager defaultManager] createDirectoryAtPath:results_folder withIntermediateDirectories:YES attributes:nil error:NULL];
    [[NSFileManager defaultManager] removeItemAtPath:[results_folder stringByAppendingPathComponent:@"template.done"] error:NULL];
    charon_log_to([results_folder stringByAppendingPathComponent:@"template.log"]);
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.rootViewController = [[UIViewController alloc] init];
    [self.window makeKeyAndVisible];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSDictionary *expected = [NSJSONSerialization JSONObjectWithData:[NSData dataWithBytes:template_expectations length:strlen(template_expectations)] options:0 error:NULL];
        NSMutableDictionary *records = [NSMutableDictionary dictionary];
        template_run(self.window, ^(NSString *name, NSString *value) {
            records[name] = value;
            printf("record %s: %s\n", name.UTF8String, value.UTF8String);
        });
        for (NSString *name in [expected.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
            if (close_enough(records[name], expected[name]) || ([name isEqualToString:@"dimmed"] && grey_with_alpha(records[name], expected[name])))
                charon_check(YES, name.UTF8String, nil);
            else
                charon_check(NO, name.UTF8String, [NSString stringWithFormat:@"\n    device %@\n    host   %@", records[name], expected[name]]);
        }
        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
        NSString *summary = [NSString stringWithFormat:@"%@ checks=%d failures=%d\n", charon_failures ? @"FAIL" : @"ok", charon_checks, charon_failures];
        [summary writeToFile:[results_folder stringByAppendingPathComponent:@"template.done"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    });
    return YES;
}

@end

int main(int argc, char **argv)
{
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([TemplateDelegate class]));
    }
}
