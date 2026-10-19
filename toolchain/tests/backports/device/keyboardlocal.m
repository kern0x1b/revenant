#import <UIKit/UIKit.h>
#import "check.h"

static NSString *const results_folder = @"/private/var/backports";
static NSMutableDictionary *seen;

@interface KeyboardDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) UITextField *field;
@end

@implementation KeyboardDelegate

- (void)noted:(NSNotification *)notification
{
    seen[notification.name] = notification.userInfo[UIKeyboardIsLocalUserInfoKey] ?: [NSNull null];
}

- (void)finish
{
    NSArray *names = @[UIKeyboardWillShowNotification, UIKeyboardDidShowNotification, UIKeyboardWillHideNotification, UIKeyboardDidHideNotification];
    for (NSString *name in names) {
        id value = seen[name];
        CHECK(value && value != [NSNull null] && [value boolValue], [[name stringByAppendingString:@" carries UIKeyboardIsLocalUserInfoKey as YES"] UTF8String]);
    }
    NSNotification *own = [NSNotification notificationWithName:UIKeyboardWillShowNotification object:nil userInfo:@{UIKeyboardIsLocalUserInfoKey: @NO}];
    __block id got = nil;
    id token = [[NSNotificationCenter defaultCenter] addObserverForName:UIKeyboardWillShowNotification object:nil queue:nil usingBlock:^(NSNotification *n) { got = n.userInfo[UIKeyboardIsLocalUserInfoKey]; }];
    [[NSNotificationCenter defaultCenter] postNotification:own];
    CHECK([got isEqual:@NO], "a value that is there already is not overwritten");
    [[NSNotificationCenter defaultCenter] removeObserver:token];
    __block NSDictionary *other = nil;
    token = [[NSNotificationCenter defaultCenter] addObserverForName:@"SomethingElse" object:nil queue:nil usingBlock:^(NSNotification *n) { other = n.userInfo; }];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"SomethingElse" object:nil userInfo:@{@"a": @1}];
    [[NSNotificationCenter defaultCenter] removeObserver:token];
    CHECK([other isEqual:@{@"a": @1}], "a notification that is no keyboard's is left as it was");
    printf("checks=%d failures=%d\n", charon_checks, charon_failures);
    NSString *summary = [NSString stringWithFormat:@"%@ checks=%d failures=%d\n", charon_failures ? @"FAIL" : @"ok", charon_checks, charon_failures];
    [summary writeToFile:[results_folder stringByAppendingPathComponent:@"keyboardlocal.done"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options
{
    [[NSFileManager defaultManager] createDirectoryAtPath:results_folder withIntermediateDirectories:YES attributes:nil error:NULL];
    [[NSFileManager defaultManager] removeItemAtPath:[results_folder stringByAppendingPathComponent:@"keyboardlocal.done"] error:NULL];
    charon_log_to([results_folder stringByAppendingPathComponent:@"keyboardlocal.log"]);
    seen = [NSMutableDictionary dictionary];
    for (NSString *name in @[UIKeyboardWillShowNotification, UIKeyboardDidShowNotification, UIKeyboardWillHideNotification, UIKeyboardDidHideNotification])
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(noted:) name:name object:nil];
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.rootViewController = [[UIViewController alloc] init];
    self.field = [[UITextField alloc] initWithFrame:CGRectMake(20, 60, 280, 40)];
    self.field.borderStyle = UITextBorderStyleRoundedRect;
    [self.window.rootViewController.view addSubview:self.field];
    [self.window makeKeyAndVisible];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ [self.field becomeFirstResponder]; });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ [self.field resignFirstResponder]; });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(7 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ [self finish]; });
    return YES;
}

@end

int main(int argc, char **argv)
{
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([KeyboardDelegate class]));
    }
}
