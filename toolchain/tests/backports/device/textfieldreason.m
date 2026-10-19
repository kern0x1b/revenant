#import <UIKit/UIKit.h>
#import "check.h"

static NSString *const results_folder = @"/private/var/backports";

@interface ReasonOnly : NSObject <UITextFieldDelegate>
@property (nonatomic, strong) NSMutableArray *log;
@end

@implementation ReasonOnly

@synthesize log;

- (void)textFieldDidEndEditing:(UITextField *)textField reason:(UITextFieldDidEndEditingReason)reason
{
    [self.log addObject:[NSString stringWithFormat:@"reason %ld", (long)reason]];
}

@end

@interface PlainOnly : NSObject <UITextFieldDelegate>
@property (nonatomic, strong) NSMutableArray *log;
@end

@implementation PlainOnly

@synthesize log;

- (void)textFieldDidEndEditing:(UITextField *)textField
{
    [self.log addObject:@"plain"];
}

@end

@interface TextFieldReasonDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation TextFieldReasonDelegate

- (NSString *)edit:(UITextField *)field with:(id)delegate log:(NSMutableArray *)log
{
    field.delegate = delegate;
    [field becomeFirstResponder];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.2]];
    [log removeAllObjects];
    [field resignFirstResponder];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.2]];
    return [log componentsJoinedByString:@","];
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options
{
    [[NSFileManager defaultManager] createDirectoryAtPath:results_folder withIntermediateDirectories:YES attributes:nil error:NULL];
    [[NSFileManager defaultManager] removeItemAtPath:[results_folder stringByAppendingPathComponent:@"textfieldreason.done"] error:NULL];
    charon_log_to([results_folder stringByAppendingPathComponent:@"textfieldreason.log"]);
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.rootViewController = [[UIViewController alloc] init];
    UITextField *field = [[UITextField alloc] initWithFrame:CGRectMake(20, 80, 200, 30)];
    [self.window.rootViewController.view addSubview:field];
    [self.window makeKeyAndVisible];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSMutableArray *log = [NSMutableArray array];
        ReasonOnly *reason = [[ReasonOnly alloc] init];
        reason.log = log;
        PlainOnly *plain = [[PlainOnly alloc] init];
        plain.log = log;
        charon_check([[self edit:field with:reason log:log] isEqualToString:@"reason 0"], "a delegate with the reason method is sent it once, committed", [log componentsJoinedByString:@","]);
        charon_check([[self edit:field with:plain log:log] isEqualToString:@"plain"], "a delegate with the old method is sent only that", [log componentsJoinedByString:@","]);
        charon_check([[self edit:field with:nil log:log] isEqualToString:@""], "no delegate, nothing is sent", nil);
        [self edit:field with:reason log:log];
        charon_check([[self edit:field with:reason log:log] isEqualToString:@"reason 0"], "again, once more", [log componentsJoinedByString:@","]);
        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
        NSString *summary = [NSString stringWithFormat:@"%@ checks=%d failures=%d\n", charon_failures ? @"FAIL" : @"ok", charon_checks, charon_failures];
        [summary writeToFile:[results_folder stringByAppendingPathComponent:@"textfieldreason.done"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    });
    return YES;
}

@end

int main(int argc, char **argv)
{
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([TextFieldReasonDelegate class]));
    }
}
