#import <UIKit/UIKit.h>
#import "check.h"
#import "textkit7-cases.h"
#import "textkit7-expectations.h"

static NSString *const results_folder = @"/private/var/backports";

static NSString *normalized(NSString *text)
{
    NSDictionary *fonts = @{@"TimesNewRomanPS-BoldMT": @"Times-Bold", @"TimesNewRomanPS-ItalicMT": @"Times-Italic", @"TimesNewRomanPSMT": @"Times-Roman"};
    for (NSString *name in fonts)
        text = [text stringByReplacingOccurrencesOfString:name withString:fonts[name]];
    text = [text stringByReplacingOccurrencesOfString:@"Color=0.00,0.00,0.00,1.00; " withString:@""];
    return [text stringByReplacingOccurrencesOfString:@"align=4" withString:@"align=0"];
}

static NSString *tolerance(NSString *name, NSString *device, NSString *host)
{
    if ([name hasPrefix:@"html."] && [normalized(device) isEqualToString:normalized(host)])
        return @"the release names the fonts of the import as its own fonts, gives the text an explicit black and lays a list out as natural, where the host leaves the colour out and lays it out left";
    if ([name isEqualToString:@"tab.equal.options"] && [device isEqualToString:@"nil-empty=0 empty-empty=1"])
        return @"the release takes a tab made with no options for a different tab from one made with an empty dictionary";
    return nil;
}

@interface TextKitTestDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation TextKitTestDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options
{
    [[NSFileManager defaultManager] createDirectoryAtPath:results_folder withIntermediateDirectories:YES attributes:nil error:NULL];
    [[NSFileManager defaultManager] removeItemAtPath:[results_folder stringByAppendingPathComponent:@"textkit7.done"] error:NULL];
    charon_log_to([results_folder stringByAppendingPathComponent:@"textkit7.log"]);
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.rootViewController = [[UIViewController alloc] init];
    [self.window makeKeyAndVisible];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSDictionary *expected = [NSJSONSerialization JSONObjectWithData:[NSData dataWithBytes:textkit7_expectations length:strlen(textkit7_expectations)] options:0 error:NULL];
        NSMutableDictionary *records = [NSMutableDictionary dictionary];
        textkit7_run(^(NSString *name, NSString *value) {
            records[name] = value;
            printf("record %s: %s\n", name.UTF8String, value.UTF8String);
        });
        for (NSString *name in [expected.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
            if ([expected[name] isEqualToString:records[name]])
                charon_check(YES, name.UTF8String, nil);
            else if (tolerance(name, records[name], expected[name]))
                printf("tolerated %s: %s\n    device %s\n    host   %s\n", tolerance(name, records[name], expected[name]).UTF8String, name.UTF8String, [records[name] UTF8String], [expected[name] UTF8String]);
            else
                charon_check(NO, name.UTF8String, [NSString stringWithFormat:@"\n    device %@\n    host   %@", records[name], expected[name]]);
        }
        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
        NSString *summary = [NSString stringWithFormat:@"%@ checks=%d failures=%d\n", charon_failures ? @"FAIL" : @"ok", charon_checks, charon_failures];
        [summary writeToFile:[results_folder stringByAppendingPathComponent:@"textkit7.done"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    });
    return YES;
}

@end

int main(int argc, char **argv)
{
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([TextKitTestDelegate class]));
    }
}
