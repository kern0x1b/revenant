#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import "check.h"

static NSString *const results_folder = @"/private/var/backports";

@interface OpenDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) NSURL *url;
@property (nonatomic, strong) NSDictionary *options;
@property (nonatomic) int calls;
@end

@implementation OpenDelegate

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey, id> *)options
{
    self.url = url;
    self.options = options;
    self.calls++;
    return YES;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launch
{
    [[NSFileManager defaultManager] createDirectoryAtPath:results_folder withIntermediateDirectories:YES attributes:nil error:NULL];
    [[NSFileManager defaultManager] removeItemAtPath:[results_folder stringByAppendingPathComponent:@"openurl.done"] error:NULL];
    charon_log_to([results_folder stringByAppendingPathComponent:@"openurl.log"]);
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.rootViewController = [[UIViewController alloc] init];
    [self.window makeKeyAndVisible];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        SEL old = @selector(application:openURL:sourceApplication:annotation:);
        CHECK([self respondsToSelector:old], "a delegate with only the new form answers the old one the release sends");
        NSURL *url = [NSURL URLWithString:@"charonopenurltest://first?a=1"];
        BOOL handled = ((BOOL (*)(id, SEL, UIApplication *, NSURL *, NSString *, id))objc_msgSend)(self, old, application, url, @"com.example.sender", @{@"note": @"x"});
        CHECK(handled && self.calls == 1 && [self.url isEqual:url], "the old call reaches the new one with the URL and its answer");
        CHECK_EQUAL(self.options[UIApplicationOpenURLOptionsSourceApplicationKey], @"com.example.sender", "with the source application");
        CHECK_EQUAL(self.options[UIApplicationOpenURLOptionsAnnotationKey], (@{@"note": @"x"}), "with the annotation");
        CHECK_EQUAL(self.options[UIApplicationOpenURLOptionsOpenInPlaceKey], @NO, "and open in place as NO");
        ((BOOL (*)(id, SEL, UIApplication *, NSURL *, NSString *, id))objc_msgSend)(self, old, application, url, nil, nil);
        CHECK(self.options[UIApplicationOpenURLOptionsSourceApplicationKey] == nil && self.options[UIApplicationOpenURLOptionsAnnotationKey] == nil && [self.options[UIApplicationOpenURLOptionsOpenInPlaceKey] isEqual:@NO], "no source and no annotation leave those keys out");
        int before = self.calls;
        BOOL sent = [application openURL:[NSURL URLWithString:@"charonopenurltest://real"]];
        NSLog(@"openURL own scheme answered %d", sent);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            CHECK(self.calls > before && [self.url.absoluteString isEqual:@"charonopenurltest://real"], "a URL the system sends the application reaches its delegate");
            printf("checks=%d failures=%d\n", charon_checks, charon_failures);
            NSString *summary = [NSString stringWithFormat:@"%@ checks=%d failures=%d\n", charon_failures ? @"FAIL" : @"ok", charon_checks, charon_failures];
            [summary writeToFile:[results_folder stringByAppendingPathComponent:@"openurl.done"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
        });
    });
    return YES;
}

@end

int main(int argc, char **argv)
{
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([OpenDelegate class]));
    }
}
