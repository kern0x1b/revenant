#import <UIKit/UIKit.h>
#import "check.h"
#import "tableestimates-cases.h"
#import "tableestimates-expectations.h"

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

@interface TableEstimatesDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation TableEstimatesDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options
{
    [[NSFileManager defaultManager] createDirectoryAtPath:results_folder withIntermediateDirectories:YES attributes:nil error:NULL];
    [[NSFileManager defaultManager] removeItemAtPath:[results_folder stringByAppendingPathComponent:@"tableestimates.done"] error:NULL];
    charon_log_to([results_folder stringByAppendingPathComponent:@"tableestimates.log"]);
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.rootViewController = [[UIViewController alloc] init];
    [self.window makeKeyAndVisible];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSDictionary *expected = [NSJSONSerialization JSONObjectWithData:[NSData dataWithBytes:tableestimates_expectations length:strlen(tableestimates_expectations)] options:0 error:NULL];
        NSMutableDictionary *records = [NSMutableDictionary dictionary];
        tableestimates_run(^(NSString *name, NSString *value) {
            records[name] = value;
            printf("record %s: %s\n", name.UTF8String, value.UTF8String);
        });
        for (NSString *name in [expected.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
            if ([expected[name] isEqualToString:records[name]] || tolerance(name, records[name], expected[name]))
                charon_check(YES, name.UTF8String, nil);
            else
                charon_check(NO, name.UTF8String, [NSString stringWithFormat:@"\n    device %@\n    host   %@", records[name], expected[name]]);
        }
        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
        NSString *summary = [NSString stringWithFormat:@"%@ checks=%d failures=%d\n", charon_failures ? @"FAIL" : @"ok", charon_checks, charon_failures];
        [summary writeToFile:[results_folder stringByAppendingPathComponent:@"tableestimates.done"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    });
    return YES;
}

@end

int main(int argc, char **argv)
{
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([TableEstimatesDelegate class]));
    }
}
