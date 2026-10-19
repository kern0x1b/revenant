#import <UIKit/UIKit.h>
#import "check.h"
#import "toolbar-cases.h"
#import "toolbar-expectations.h"

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
