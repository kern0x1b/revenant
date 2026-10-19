#import <UIKit/UIKit.h>
#import "check.h"

static NSString *const results_folder = @"/private/var/backports";

@interface ReceiptDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation ReceiptDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options
{
    [[NSFileManager defaultManager] createDirectoryAtPath:results_folder withIntermediateDirectories:YES attributes:nil error:NULL];
    [[NSFileManager defaultManager] removeItemAtPath:[results_folder stringByAppendingPathComponent:@"receipturl.done"] error:NULL];
    charon_log_to([results_folder stringByAppendingPathComponent:@"receipturl.log"]);
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.rootViewController = [[UIViewController alloc] init];
    [self.window makeKeyAndVisible];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        BOOL raised = NO;
        NSURL *url = nil;
        @try { url = [[NSBundle mainBundle] appStoreReceiptURL]; } @catch (NSException *e) { raised = YES; }
        CHECK(!raised, "the main bundle answers its receipt URL and does not raise");
        CHECK(url.isFileURL && [url.path hasSuffix:@"/StoreKit/receipt"], "it is the file StoreKit/receipt");
        CHECK([url.path hasPrefix:[NSBundle mainBundle].bundlePath], "in the bundle of the application");
        CHECK(![[NSFileManager defaultManager] fileExistsAtPath:url.path], "where there is no receipt of a hand installed application");
        NSBundle *other = [NSBundle bundleWithPath:@"/System/Library/Frameworks/UIKit.framework"];
        NSURL *otherURL = other.appStoreReceiptURL;
        CHECK([otherURL.path hasSuffix:@"UIKit.framework/StoreKit/receipt"], "another bundle answers its own");
        CHECK([[NSBundle mainBundle] respondsToSelector:@selector(appStoreReceiptURL)], "and the bundle still answers the selector");
        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
        NSString *summary = [NSString stringWithFormat:@"%@ checks=%d failures=%d\n", charon_failures ? @"FAIL" : @"ok", charon_checks, charon_failures];
        [summary writeToFile:[results_folder stringByAppendingPathComponent:@"receipturl.done"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    });
    return YES;
}

@end

int main(int argc, char **argv)
{
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([ReceiptDelegate class]));
    }
}
