#import <UIKit/UIKit.h>
#import "check.h"
#import "webkit-cases.h"
#import "webkit-expectations.h"

static NSString *const results_folder = @"/private/var/backports";

static NSString *tolerance(NSString *name)
{
    if ([name isEqualToString:@"new.scrollView"])
        return @"the scroll view of the release's UIWebView is a private subclass of UIScrollView";
    if ([name isEqualToString:@"new.userAgent"])
        return @"the host answers the user agent it sends and the port names none, which is nil";
    if ([name isEqualToString:@"iframe.events"])
        return @"the title of a page with a frame reaches WebKit's view before the navigation finishes, which the release's UIWebView does not report";
    return nil;
}

@interface WebKitTestDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation WebKitTestDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options
{
    [[NSFileManager defaultManager] createDirectoryAtPath:results_folder withIntermediateDirectories:YES attributes:nil error:NULL];
    [[NSFileManager defaultManager] removeItemAtPath:[results_folder stringByAppendingPathComponent:@"webkit.done"] error:NULL];
    charon_log_to([results_folder stringByAppendingPathComponent:@"webkit.log"]);
    printf("webkit device test started on iOS %s\n", [UIDevice currentDevice].systemVersion.UTF8String);
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    UIViewController *controller = [[UIViewController alloc] init];
    controller.view.backgroundColor = [UIColor whiteColor];
    self.window.rootViewController = controller;
    [self.window makeKeyAndVisible];
    NSTimer *timer = [NSTimer timerWithTimeInterval:2 target:[NSBlockOperation blockOperationWithBlock:^{
        NSDictionary *expected = [NSJSONSerialization JSONObjectWithData:[NSData dataWithBytes:webkit_expectations length:strlen(webkit_expectations)] options:0 error:NULL];
        NSMutableDictionary *records = [NSMutableDictionary dictionary];
        webkit_run(controller.view, ^(NSString *name, NSString *value) {
            records[name] = value;
            printf("record %s: %s\n", name.UTF8String, value.UTF8String);
        });
        NSInteger matched = 0, tolerated = 0;
        for (NSString *name in [expected.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
            NSString *want = expected[name], *got = records[name];
            if ([want isEqualToString:got]) {
                matched++;
                charon_check(YES, name.UTF8String, nil);
            } else if (tolerance(name)) {
                tolerated++;
                printf("tolerated %s: %s\n    device %s\n    host   %s\n", tolerance(name).UTF8String, name.UTF8String, got.UTF8String, want.UTF8String);
            } else {
                charon_check(NO, name.UTF8String, [NSString stringWithFormat:@"\n    device %@\n    host   %@", got, want]);
            }
        }
        printf("records matched=%ld tolerated=%ld\n", (long)matched, (long)tolerated);
        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
        NSString *summary = [NSString stringWithFormat:@"%@ checks=%d failures=%d\n", charon_failures ? @"FAIL" : @"ok", charon_checks, charon_failures];
        [summary writeToFile:[results_folder stringByAppendingPathComponent:@"webkit.done"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    }] selector:@selector(main) userInfo:nil repeats:NO];
    [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
    return YES;
}

@end

int main(int argc, char **argv)
{
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([WebKitTestDelegate class]));
    }
}
