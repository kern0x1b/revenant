#import <UIKit/UIKit.h>
#import "check.h"
#import "toolbar-cases.h"
#import "toolbar-expectations.h"

// An application: a navigation controller that never asked for a toolbar, and one that shows one, in a window, held to what the
// host's own UIKit does (host/toolbar/run.sh writes toolbar-expectations.h), and to the geometry of the toolbar where the host has none.
// The log goes to /var/charon where there is one (the emulator keeps it with the run) and to /private/var/backports otherwise.
@interface ToolbarDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation ToolbarDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options
{
    BOOL emulated = [[NSFileManager defaultManager] fileExistsAtPath:@"/var/charon"];
    NSString *folder = emulated ? @"/var/charon" : @"/private/var/backports";
    [[NSFileManager defaultManager] createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:NULL];
    [[NSFileManager defaultManager] removeItemAtPath:[folder stringByAppendingPathComponent:@"toolbar.done"] error:NULL];
    charon_log_to([folder stringByAppendingPathComponent:@"toolbar.log"]);
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.rootViewController = [[UIViewController alloc] init];
    [self.window makeKeyAndVisible];
    [self performSelector:@selector(run:) withObject:folder afterDelay:1];
    return YES;
}

- (void)run:(NSString *)folder
{
    NSDictionary *expected = [NSJSONSerialization JSONObjectWithData:[NSData dataWithBytes:toolbar_expectations length:strlen(toolbar_expectations)] options:0 error:NULL];
    NSMutableDictionary *records = [NSMutableDictionary dictionary];
    toolbar_run(self.window, ^(NSString *name, NSString *value) {
        records[name] = value;
        printf("record %s: %s\n", name.UTF8String, value.UTF8String);
    });
    for (NSString *name in [expected.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
        if ([expected[name] isEqualToString:records[name]])
            charon_check(YES, name.UTF8String, nil);
        else
            charon_check(NO, name.UTF8String, [NSString stringWithFormat:@"\n    device %@\n    host   %@", records[name], expected[name]]);
    }
    // The host's windows keep a toolbar out of the view tree, so the shown toolbar's cover is the device's own measurement: the bar
    // has to cover something, or the case does not tell a safe area that reads the bar from one that does not.
    int cover = -1, bottom = -2;
    sscanf([records[@"measuredShown"] UTF8String], "cover=%d bottom=%d", &cover, &bottom);
    charon_check(cover > 0, "shownToolbarCoversTheView", [NSString stringWithFormat:@"cover=%d", cover]);
    charon_check(bottom == cover, "shownToolbarIsTheBottomInset", [NSString stringWithFormat:@"cover=%d bottom=%d", cover, bottom]);
    printf("checks=%d failures=%d\n", charon_checks, charon_failures);
    NSString *summary = [NSString stringWithFormat:@"%@ checks=%d failures=%d\n", charon_failures ? @"FAIL" : @"ok", charon_checks, charon_failures];
    [summary writeToFile:[folder stringByAppendingPathComponent:@"toolbar.done"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    if ([folder isEqualToString:@"/var/charon"])
        exit(charon_failures ? 1 : 0);
}

@end

int main(int argc, char **argv)
{
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([ToolbarDelegate class]));
    }
}
