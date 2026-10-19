#import <UIKit/UIKit.h>
#import "check.h"
#import "flowauto-cases.h"
#import "flowauto-expectations.h"

static NSString *const results_folder = @"/private/var/backports";

static NSArray<NSNumber *> *flowauto_numbers(NSString *text)
{
    NSMutableArray *numbers = [NSMutableArray array];
    NSScanner *scanner = [NSScanner scannerWithString:text];
    NSCharacterSet *digits = [NSCharacterSet characterSetWithCharactersInString:@"-0123456789."];
    while (!scanner.isAtEnd) {
        NSString *token = nil;
        if ([scanner scanCharactersFromSet:digits intoString:&token]) {
            if (token.length > 0 && ![token isEqualToString:@"-"] && ![token isEqualToString:@"."])
                [numbers addObject:@(token.doubleValue)];
        } else {
            scanner.scanLocation++;
        }
    }
    return numbers;
}

static BOOL flowauto_agree(NSString *name, NSString *device, NSString *host, NSString **why)
{
    NSArray *a = flowauto_numbers(device), *b = flowauto_numbers(host);
    if (a.count != b.count) {
        *why = @"different number of values";
        return NO;
    }
    double tolerance = [UIScreen mainScreen].scale >= 2 ? 0.01 : 0.51;
    if ([name hasPrefix:@"intrinsic"] || [name hasPrefix:@"lastLine"])
        tolerance = 1.01;
    else if ([UIScreen mainScreen].scale < 2 && [name isEqual:@"grid90"])
        tolerance = 1.01;
    for (NSUInteger index = 0; index < a.count; index++)
        if (fabs([a[index] doubleValue] - [b[index] doubleValue]) > tolerance) {
            *why = [NSString stringWithFormat:@"value %lu is %@ and not %@", (unsigned long)index, a[index], b[index]];
            return NO;
        }
    return YES;
}

@interface FlowAutoDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation FlowAutoDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options
{
    [[NSFileManager defaultManager] createDirectoryAtPath:results_folder withIntermediateDirectories:YES attributes:nil error:NULL];
    [[NSFileManager defaultManager] removeItemAtPath:[results_folder stringByAppendingPathComponent:@"flowauto.done"] error:NULL];
    charon_log_to([results_folder stringByAppendingPathComponent:@"flowauto.log"]);
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.rootViewController = [[UIViewController alloc] init];
    [self.window makeKeyAndVisible];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSDictionary *expected = [NSJSONSerialization JSONObjectWithData:[NSData dataWithBytes:flowauto_expectations length:strlen(flowauto_expectations)] options:0 error:NULL];
        NSMutableDictionary *records = [NSMutableDictionary dictionary];
        flowauto_run(self.window, ^(NSString *name, NSString *value) {
            records[name] = value;
            printf("record %s: %s\n", name.UTF8String, value.UTF8String);
        });
        for (NSString *name in [expected.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
            if ([@[@"horizontal", @"longList", @"longListDelegate"] containsObject:name])
                continue;
            NSString *why = nil;
            if (flowauto_agree(name, records[name], expected[name], &why))
                charon_check(YES, name.UTF8String, nil);
            else
                charon_check(NO, name.UTF8String, [NSString stringWithFormat:@"%@\n    device %@\n    host   %@", why, records[name], expected[name]]);
        }
        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
        NSString *summary = [NSString stringWithFormat:@"%@ checks=%d failures=%d\n", charon_failures ? @"FAIL" : @"ok", charon_checks, charon_failures];
        [summary writeToFile:[results_folder stringByAppendingPathComponent:@"flowauto.done"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    });
    return YES;
}

@end

int main(int argc, char **argv)
{
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([FlowAutoDelegate class]));
    }
}
