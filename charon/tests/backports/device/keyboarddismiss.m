#import <UIKit/UIKit.h>
#import "check.h"
#import "gesture.h"

static NSString *const results_folder = @"/private/var/backports";

@interface KeyboardDismissDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) UITextField *field;
@property (nonatomic, strong) UIScrollView *scroll;
@property (nonatomic, assign) CGRect keyboard;
@end

@implementation KeyboardDismissDelegate

- (void)shown:(NSNotification *)note
{
    self.keyboard = [note.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
}

- (void)round:(NSString *)name mode:(UIScrollViewKeyboardDismissMode)mode from:(CGPoint)from to:(CGPoint)to stays:(BOOL)stays
{
    gesture_step(0.05, ^{
        self.scroll.keyboardDismissMode = mode;
        [self.field becomeFirstResponder];
    });
    gesture_step(1.2, ^{ CHECK(self.field.isFirstResponder, [[name stringByAppendingString:@": the field has the keyboard before the drag"] UTF8String]); });
    gesture_drag(^{ return from; }, ^{ return to; }, 12, 0.4);
    gesture_step(0.6, ^{
        CHECK(self.field.isFirstResponder == stays, [name UTF8String]);
        [self.field resignFirstResponder];
    });
    gesture_step(0.8, ^{});
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options
{
    [[NSFileManager defaultManager] createDirectoryAtPath:results_folder withIntermediateDirectories:YES attributes:nil error:NULL];
    [[NSFileManager defaultManager] removeItemAtPath:[results_folder stringByAppendingPathComponent:@"keyboarddismiss.done"] error:NULL];
    charon_log_to([results_folder stringByAppendingPathComponent:@"keyboarddismiss.log"]);
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(shown:) name:UIKeyboardDidShowNotification object:nil];
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.rootViewController = [[UIViewController alloc] init];
    [self.window makeKeyAndVisible];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIView *root = self.window.rootViewController.view;
        CGFloat width = root.bounds.size.width, height = root.bounds.size.height;
        self.field = [[UITextField alloc] initWithFrame:CGRectMake(10, 30, width - 20, 30)];
        self.field.borderStyle = UITextBorderStyleRoundedRect;
        [root addSubview:self.field];
        self.scroll = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 80, width, 150)];
        self.scroll.contentSize = CGSizeMake(width, 2000);
        self.scroll.backgroundColor = [UIColor lightGrayColor];
        [root addSubview:self.scroll];
        CHECK(self.scroll.keyboardDismissMode == UIScrollViewKeyboardDismissModeNone, "the default mode is none");
        self.scroll.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
        CHECK(self.scroll.keyboardDismissMode == UIScrollViewKeyboardDismissModeOnDrag, "the mode is kept");
        self.scroll.keyboardDismissMode = (UIScrollViewKeyboardDismissMode)7;
        CHECK((NSInteger)self.scroll.keyboardDismissMode == 7, "as is a number the release does not know");
        self.scroll.keyboardDismissMode = UIScrollViewKeyboardDismissModeNone;
        UITableView *table = [[UITableView alloc] init];
        CHECK(table.keyboardDismissMode == UIScrollViewKeyboardDismissModeNone, "a table view has the property too");
        gesture_step(0.01, ^{ CHECK(gesture_ready(), "touches can be sent"); });
        CGPoint above = CGPointMake(width / 2, 100), abovePlus = CGPointMake(width / 2, 200);
        [self round:@"none: the keyboard stays" mode:UIScrollViewKeyboardDismissModeNone from:above to:abovePlus stays:YES];
        [self round:@"on drag: the keyboard goes with the drag" mode:UIScrollViewKeyboardDismissModeOnDrag from:above to:abovePlus stays:NO];
        [self round:@"interactive above the keyboard: it stays" mode:UIScrollViewKeyboardDismissModeInteractive from:above to:abovePlus stays:YES];
        [self round:@"interactive into the keyboard: it goes" mode:UIScrollViewKeyboardDismissModeInteractive from:above to:CGPointMake(width / 2, height - 60) stays:NO];
        gesture_run(^{
            printf("checks=%d failures=%d\n", charon_checks, charon_failures);
            NSString *summary = [NSString stringWithFormat:@"%@ checks=%d failures=%d\n", charon_failures ? @"FAIL" : @"ok", charon_checks, charon_failures];
            [summary writeToFile:[results_folder stringByAppendingPathComponent:@"keyboarddismiss.done"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
        });
    });
    return YES;
}

@end

int main(int argc, char **argv)
{
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([KeyboardDismissDelegate class]));
    }
}
