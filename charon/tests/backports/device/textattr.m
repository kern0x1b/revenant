#import <UIKit/UIKit.h>
#import "check.h"
#import "textattr-cases.h"
#import "textattr-expectations.h"

static NSArray *numbers(NSString *text)
{
    NSMutableArray *found = [NSMutableArray array];
    for (NSString *part in [text componentsSeparatedByString:@" "])
        if (part.length && (isdigit([part characterAtIndex:0]) || [part hasPrefix:@"-"]))
            [found addObject:@([part doubleValue])];
    return found;
}

static NSString *agree(NSString *name, NSString *device, NSString *host)
{
    BOOL leanMatters = NO;
    NSArray *a = numbers(device), *b = numbers(host);
    if (a.count != b.count)
        return @"different shape";
    for (NSUInteger index = 0; index < a.count; index++) {
        double left = [a[index] doubleValue], right = [b[index] doubleValue];
        double allowed = index < 3 ? MAX(12, 0.35 * fabs(right)) : (index == 8 ? MAX(40, 0.4 * fabs(right)) : (index == 7 ? (leanMatters ? 3 : 1000) : 3));
        if (fabs(left - right) > allowed)
            return [NSString stringWithFormat:@"value %lu is %g and not %g", (unsigned long)index, left, right];
    }
    return nil;
}

static NSString *unchanged(NSString *device)
{
    NSArray *a = numbers(device);
    if (a.count != 10)
        return @"different shape";
    if ([a[0] doubleValue] != 0 || [a[1] doubleValue] != 0)
        return @"colour ink appeared";
    for (NSUInteger index = 3; index < 10; index++)
        if (index != 8 && fabs([a[index] doubleValue]) > 3)
            return [NSString stringWithFormat:@"value %lu moved by %@", (unsigned long)index, a[index]];
    return nil;
}

static NSString *const results_folder = @"/private/var/backports";

@interface TextAttrDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation TextAttrDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options
{
    [[NSFileManager defaultManager] createDirectoryAtPath:results_folder withIntermediateDirectories:YES attributes:nil error:NULL];
    [[NSFileManager defaultManager] removeItemAtPath:[results_folder stringByAppendingPathComponent:@"textattr.done"] error:NULL];
    charon_log_to([results_folder stringByAppendingPathComponent:@"textattr.log"]);
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.rootViewController = [[UIViewController alloc] init];
    [self.window makeKeyAndVisible];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSDictionary *expected = [NSJSONSerialization JSONObjectWithData:[NSData dataWithBytes:textattr_expectations length:strlen(textattr_expectations)] options:0 error:NULL];
        NSMutableDictionary *records = [NSMutableDictionary dictionary];
        textattr_run(^(NSString *name, NSString *value) {
            records[name] = value;
            printf("record %s: %s\n", name.UTF8String, value.UTF8String);
        });
        for (NSString *name in [expected.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
            BOOL drawnPlain = [name rangeOfString:@"letterpress"].location != NSNotFound;
            NSString *why = drawnPlain ? unchanged(records[name]) : ([expected[name] isEqualToString:records[name]] ? nil : agree(name, records[name], expected[name]));
            if (!why)
                charon_check(YES, name.UTF8String, nil);
            else
                charon_check(NO, name.UTF8String, [NSString stringWithFormat:@"%@\n    device %@\n    host   %@", why, records[name], expected[name]]);
        }
        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
        NSString *summary = [NSString stringWithFormat:@"%@ checks=%d failures=%d\n", charon_failures ? @"FAIL" : @"ok", charon_checks, charon_failures];
        [summary writeToFile:[results_folder stringByAppendingPathComponent:@"textattr.done"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    });
    return YES;
}

@end

int main(int argc, char **argv)
{
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([TextAttrDelegate class]));
    }
}
