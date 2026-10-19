#import <UIKit/UIKit.h>
#import "check.h"
#import "exclusion-cases.h"
#import "exclusion-expectations.h"

static NSArray *fragments(NSString *text)
{
    return [text componentsSeparatedByString:@" ; "];
}

static NSArray *numbers(NSString *text)
{
    NSMutableArray *found = [NSMutableArray array];
    NSScanner *scanner = [NSScanner scannerWithString:text];
    NSCharacterSet *digits = [NSCharacterSet characterSetWithCharactersInString:@"-0123456789."];
    while (!scanner.isAtEnd) {
        NSString *token = nil;
        if ([scanner scanCharactersFromSet:digits intoString:&token]) {
            if (![token isEqualToString:@"-"] && ![token isEqualToString:@"."])
                [found addObject:@(token.doubleValue)];
        } else {
            scanner.scanLocation++;
        }
    }
    return found;
}

static NSString *agree(NSString *name, NSString *device, NSString *host, double tolerance)
{
    NSArray *left = fragments(device), *right = fragments(host);
    if (left.count != right.count)
        return [NSString stringWithFormat:@"%lu lines and not %lu", (unsigned long)left.count, (unsigned long)right.count];
    for (NSUInteger index = 0; index < left.count; index++) {
        NSArray *a = numbers(left[index]), *b = numbers(right[index]);
        if (a.count != b.count)
            return [NSString stringWithFormat:@"line %lu differs in shape", (unsigned long)index];
        for (NSUInteger number = 0; number < a.count; number++) {
            double delta = fabs([a[number] doubleValue] - [b[number] doubleValue]);
            double allowed = number < 2 ? 0 : tolerance;
            if (delta > allowed)
                return [NSString stringWithFormat:@"line %lu value %lu is %@ and not %@", (unsigned long)index, (unsigned long)number, a[number], b[number]];
        }
    }
    return nil;
}

static NSString *const results_folder = @"/private/var/backports";

@interface ExclusionDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation ExclusionDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options
{
    [[NSFileManager defaultManager] createDirectoryAtPath:results_folder withIntermediateDirectories:YES attributes:nil error:NULL];
    [[NSFileManager defaultManager] removeItemAtPath:[results_folder stringByAppendingPathComponent:@"exclusion.done"] error:NULL];
    charon_log_to([results_folder stringByAppendingPathComponent:@"exclusion.log"]);
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.rootViewController = [[UIViewController alloc] init];
    [self.window makeKeyAndVisible];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSDictionary *expected = [NSJSONSerialization JSONObjectWithData:[NSData dataWithBytes:exclusion_expectations length:strlen(exclusion_expectations)] options:0 error:NULL];
        NSMutableDictionary *records = [NSMutableDictionary dictionary];
        exclusion_run(^(NSString *name, NSString *value) {
            records[name] = value;
            printf("record %s: %s\n", name.UTF8String, value.UTF8String);
        });
        for (NSString *name in [expected.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
            NSString *why = [expected[name] isEqualToString:records[name]] ? nil : agree(name, records[name], expected[name], 2.0);
            if (!why)
                charon_check(YES, name.UTF8String, nil);
            else
                charon_check(NO, name.UTF8String, [NSString stringWithFormat:@"%@\n    device %@\n    host   %@", why, records[name], expected[name]]);
        }
        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
        NSString *summary = [NSString stringWithFormat:@"%@ checks=%d failures=%d\n", charon_failures ? @"FAIL" : @"ok", charon_checks, charon_failures];
        [summary writeToFile:[results_folder stringByAppendingPathComponent:@"exclusion.done"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    });
    return YES;
}

@end

int main(int argc, char **argv)
{
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([ExclusionDelegate class]));
    }
}
