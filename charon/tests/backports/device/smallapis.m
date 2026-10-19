#import <UIKit/UIKit.h>
#import "check.h"

static NSString *const results_folder = @"/private/var/backports";

@interface SmallDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation SmallDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options
{
    [[NSFileManager defaultManager] createDirectoryAtPath:results_folder withIntermediateDirectories:YES attributes:nil error:NULL];
    [[NSFileManager defaultManager] removeItemAtPath:[results_folder stringByAppendingPathComponent:@"smallapis.done"] error:NULL];
    charon_log_to([results_folder stringByAppendingPathComponent:@"smallapis.log"]);
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.rootViewController = [[UIViewController alloc] init];
    [self.window makeKeyAndVisible];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIActivityViewController *controller = [[UIActivityViewController alloc] initWithActivityItems:@[@"text"] applicationActivities:nil];
        CHECK(controller.completionWithItemsHandler == nil, "the handler with items is nil at first");
        __block NSArray *seen = nil;
        UIActivityViewControllerCompletionWithItemsHandler handler = ^(NSString *type, BOOL completed, NSArray *items, NSError *error) {
            seen = @[type ?: @"nil", @(completed), items ?: @"nil", error ?: @"nil"];
        };
        controller.completionWithItemsHandler = handler;
        CHECK(controller.completionWithItemsHandler != nil, "it is kept");
        CHECK(controller.completionHandler != nil, "and the release's own handler is set to call it");
        controller.completionHandler(UIActivityTypePostToTwitter, YES);
        CHECK(seen && [seen[0] isEqual:UIActivityTypePostToTwitter] && [seen[1] boolValue] && [seen[2] isEqual:@"nil"] && [seen[3] isEqual:@"nil"], "the handler with items answers the type and the outcome, and no items");
        controller.completionWithItemsHandler = nil;
        CHECK(controller.completionWithItemsHandler == nil && controller.completionHandler == nil, "setting it to nil clears both");

        UIApplication *app = [UIApplication sharedApplication];
        CHECK(!app.supportsAlternateIcons, "alternate icons are not supported");
        CHECK(app.alternateIconName == nil, "the alternate icon name is nil");
        __block NSError *error = nil;
        __block BOOL called = NO;
        [app setAlternateIconName:@"Other" completionHandler:^(NSError *e) { called = YES; error = e; }];
        [app setAlternateIconName:nil completionHandler:nil];
        CHECK(!called, "the completion of the change is asynchronous");
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            CHECK(called && [error.domain isEqual:NSCocoaErrorDomain] && error.code == NSFeatureUnsupportedError, "the change answers the error of a feature that is not supported");
            printf("checks=%d failures=%d\n", charon_checks, charon_failures);
            NSString *summary = [NSString stringWithFormat:@"%@ checks=%d failures=%d\n", charon_failures ? @"FAIL" : @"ok", charon_checks, charon_failures];
            [summary writeToFile:[results_folder stringByAppendingPathComponent:@"smallapis.done"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
        });
    });
    return YES;
}

@end

int main(int argc, char **argv)
{
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([SmallDelegate class]));
    }
}
