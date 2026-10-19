#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <fcntl.h>
#import <unistd.h>
#import "check.h"

#pragma clang diagnostic ignored "-Wdeprecated-declarations"

static const double pause_seconds = 4;
static const double step_timeout_seconds = 45;
static NSString *const results_folder = @"/private/var/backports";

typedef void (^Step)(void (^done)(void));

static void after(double seconds, dispatch_block_t block)
{
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(seconds * NSEC_PER_SEC)), dispatch_get_main_queue(), block);
}

static void screenshot(const char *name, const char *what)
{
    printf("SCREENSHOT %s: %s (pausing %.0f s)\n", name, what, pause_seconds);
    fflush(stdout);
}

static void collect_views(UIView *view, Class kind, NSMutableArray *found)
{
    if ([view isKindOfClass:kind])
        [found addObject:view];
    for (UIView *subview in view.subviews)
        collect_views(subview, kind, found);
}

static id shown_native_view(UIAlertController *alert, Class kind)
{
    NSMutableArray *found = [NSMutableArray array];
    for (UIWindow *window in [UIApplication sharedApplication].windows)
        collect_views(window, kind, found);
    for (id view in found) {
        if ([view delegate] == (id)alert)
            return view;
    }
    return nil;
}

static id native_view(UIAlertController *alert, Class kind, const char *name)
{
    id view = shown_native_view(alert, kind);
    charon_check(view != nil, name, [NSString stringWithFormat:@"no %@ with the controller as delegate among the app windows", kind]);
    if (!view)
        view = [alert valueForKey:kind == [UIAlertView class] ? @"alertView" : @"actionSheet"];
    return view;
}

static NSArray *button_titles(id view)
{
    NSMutableArray *titles = [NSMutableArray array];
    for (NSInteger index = 0; index < [view numberOfButtons]; index++)
        [titles addObject:[view buttonTitleAtIndex:index]];
    return titles;
}

static void collect_controls(UIView *view, NSString *title, NSMutableArray *found)
{
    for (UIView *subview in view.subviews) {
        if ([subview isKindOfClass:[UIControl class]]) {
            NSString *label = [subview respondsToSelector:@selector(titleForState:)] ? [(UIButton *)subview titleForState:UIControlStateNormal] : subview.accessibilityLabel;
            if ([label isEqualToString:title])
                [found addObject:subview];
        }
        collect_controls(subview, title, found);
    }
}

static NSString *controls_state(UIView *view, NSString *title)
{
    NSMutableArray *found = [NSMutableArray array];
    collect_controls(view, title, found);
    if (!found.count)
        return @"missing";
    for (UIControl *control in found) {
        if (!control.enabled)
            return @"disabled";
    }
    return @"enabled";
}

static NSString *exception_name(dispatch_block_t block)
{
    @try {
        block();
        return @"no exception";
    } @catch (NSException *exception) {
        return exception.name;
    }
}

@interface AlertTestDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) UINavigationController *navigation;
@property (nonatomic, strong) UIViewController *host;
@property (nonatomic, strong) UILabel *status;
@end

@implementation AlertTestDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options
{
    [[NSFileManager defaultManager] createDirectoryAtPath:results_folder withIntermediateDirectories:YES attributes:nil error:NULL];
    [[NSFileManager defaultManager] removeItemAtPath:[results_folder stringByAppendingPathComponent:@"alert.done"] error:NULL];
    charon_log_to([results_folder stringByAppendingPathComponent:@"alert.log"]);
    printf("alert device test started\n");
    self.host = [[UIViewController alloc] init];
    self.host.title = @"UIAlertController";
    self.host.view.backgroundColor = [UIColor whiteColor];
    self.status = [[UILabel alloc] initWithFrame:CGRectInset(self.host.view.bounds, 20, 20)];
    self.status.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.status.numberOfLines = 0;
    self.status.textAlignment = NSTextAlignmentCenter;
    self.status.text = @"Running";
    [self.host.view addSubview:self.status];
    self.navigation = [[UINavigationController alloc] initWithRootViewController:self.host];
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.rootViewController = self.navigation;
    [self.window makeKeyAndVisible];
    NSArray *steps = [self steps];
    after(1, ^{
        [self run:steps index:0];
    });
    return YES;
}

- (void)run:(NSArray *)steps index:(NSUInteger)index
{
    if (index == steps.count) {
        [self finish];
        return;
    }
    printf("step %lu\n", (unsigned long)index + 1);
    self.status.text = [NSString stringWithFormat:@"Step %lu of %lu", (unsigned long)index + 1, (unsigned long)steps.count];
    __block BOOL finished = NO;
    void (^done)(void) = ^{
        if (finished)
            return;
        finished = YES;
        after(1, ^{
            [self run:steps index:index + 1];
        });
    };
    after(step_timeout_seconds, ^{
        if (!finished) {
            charon_check(NO, "step finishes in time", [NSString stringWithFormat:@"step %lu timed out", (unsigned long)index + 1]);
            done();
        }
    });
    Step step = [steps objectAtIndex:index];
    step(done);
}

- (void)finish
{
    printf("checks=%d failures=%d\n", charon_checks, charon_failures);
    self.status.text = [NSString stringWithFormat:@"%@\nchecks=%d failures=%d", charon_failures ? @"FAIL" : @"ok", charon_checks, charon_failures];
    screenshot("result", "result label");
    after(1, ^{
        NSString *summary = [NSString stringWithFormat:@"%@ checks=%d failures=%d\n", charon_failures ? @"FAIL" : @"ok", charon_checks, charon_failures];
        [summary writeToFile:[results_folder stringByAppendingPathComponent:@"alert.done"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    });
}

- (NSArray *)steps
{
    UINavigationController *navigation = self.navigation;
    UIViewController *host = self.host;
    return @[
        [^(void (^done)(void)) {
            CHECK([@(class_getImageName([UIAlertController class])) hasSuffix:@"libUIKitBackports.dylib"], "UIAlertController comes from the backports library");
            CHECK([@(class_getImageName([UIAlertAction class])) hasSuffix:@"libUIKitBackports.dylib"], "UIAlertAction comes from the backports library");
            UIViewController *modal = [[UIViewController alloc] init];
            modal.view.backgroundColor = [UIColor darkGrayColor];
            [navigation presentViewController:modal animated:NO completion:^{
                CHECK(navigation.presentedViewController == modal, "a plain modal presentation still works");
                CHECK(modal.presentingViewController == navigation, "a plain modal still reports its presenter");
                [navigation dismissViewControllerAnimated:NO completion:^{
                    CHECK(navigation.presentedViewController == nil, "a plain modal dismissal still works");
                    done();
                }];
            }];
        } copy],
        [^(void (^done)(void)) {
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Alert" message:@"Basic alert" preferredStyle:UIAlertControllerStyleAlert];
            __weak UIAlertController *weakAlert = alert;
            NSMutableArray *fired = [NSMutableArray array];
            UIViewController *other = [[UIViewController alloc] init];
            __block BOOL otherShown = NO;
            void (^record)(UIAlertAction *) = ^(UIAlertAction *action) {
                [fired addObject:action.title];
                CHECK(navigation.presentedViewController == nil, "handler runs once the alert is no longer presented");
                CHECK(weakAlert.presentingViewController == nil, "alert has no presenter in its handler");
                after(1, ^{
                    CHECK_EQUAL(fired, (@[@"OK"]), "clicked button runs only its own handler");
                    CHECK(shown_native_view(weakAlert, [UIAlertView class]) == nil, "alert view is gone after the click");
                    CHECK(!otherShown, "the refused presentation never completed");
                    done();
                });
            };
            [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:record]];
            [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:record]];
            [alert addAction:[UIAlertAction actionWithTitle:@"Delete" style:UIAlertActionStyleDestructive handler:record]];
            __block BOOL completed = NO;
            [host presentViewController:alert animated:YES completion:^{
                completed = YES;
                UIAlertView *view = native_view(weakAlert, [UIAlertView class], "alert shows a UIAlertView in the app windows");
                CHECK(view.visible, "alert view is visible when the presentation completes");
                CHECK_EQUAL(button_titles(view), (@[@"Cancel", @"OK", @"Delete"]), "alert view shows cancel first, then the others in order");
                CHECK_EQUAL(@(view.cancelButtonIndex), @0, "alert view cancel index");
                CHECK_EQUAL(view.title, @"Alert", "alert view title");
                CHECK_EQUAL(view.message, @"Basic alert", "alert view message");
                CHECK(weakAlert.presentingViewController == navigation, "alert presenter is the root of the presenting hierarchy");
                CHECK(navigation.presentedViewController == weakAlert, "navigation controller reports the presented alert");
                CHECK(host.presentedViewController == weakAlert, "child controller reports the presented alert");
                CHECK_EQUAL(exception_name(^{ [host presentViewController:weakAlert animated:YES completion:nil]; }), NSInvalidArgumentException, "presenting a presented alert again raises");
                [navigation presentViewController:other animated:NO completion:^{ otherShown = YES; }];
                CHECK(navigation.presentedViewController == weakAlert && other.presentingViewController == nil, "another presentation is refused while the alert is presented");
                screenshot("alert-basic", "UIAlertView 'Alert' / 'Basic alert' with Cancel, OK, Delete");
                after(pause_seconds, ^{
                    [view dismissWithClickedButtonIndex:1 animated:YES];
                });
            }];
            CHECK(navigation.presentedViewController == alert, "alert counts as presented right after the call");
            CHECK(!completed, "presentation completion waits for the alert view to show");
        } copy],
        [^(void (^done)(void)) {
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Sign In" message:@"Two fields" preferredStyle:UIAlertControllerStyleAlert];
            __weak UIAlertController *weakAlert = alert;
            __block UITextField *login, *password;
            [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
                login = field;
                field.placeholder = @"Login";
                field.text = @"user";
            }];
            [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
                password = field;
                field.placeholder = @"Password";
                field.secureTextEntry = YES;
            }];
            __block NSInteger changes = 0;
            id observer = [[NSNotificationCenter defaultCenter] addObserverForName:UITextFieldTextDidChangeNotification object:password queue:nil usingBlock:^(NSNotification *notification) {
                changes++;
            }];
            [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
                CHECK(NO, "cancel handler does not run when sign in is clicked");
            }]];
            UIAlertAction *signIn = [UIAlertAction actionWithTitle:@"Sign In" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                CHECK_EQUAL([[weakAlert.textFields objectAtIndex:1] text], @"secret", "handler sees the typed password");
                CHECK_EQUAL(login.text, @"user", "handler sees the configured login");
                CHECK(weakAlert.textFields.count == 2 && [weakAlert.textFields objectAtIndex:0] == login, "text fields keep their identity");
                [[NSNotificationCenter defaultCenter] removeObserver:observer];
                done();
            }];
            signIn.enabled = NO;
            [alert addAction:signIn];
            [navigation presentViewController:alert animated:YES completion:^{
                UIAlertView *view = native_view(weakAlert, [UIAlertView class], "login alert shows a UIAlertView in the app windows");
                CHECK_EQUAL(@(view.alertViewStyle), @(UIAlertViewStyleLoginAndPasswordInput), "two fields show as login and password input");
                CHECK_EQUAL([view textFieldAtIndex:0].text, @"user", "configured login text is shown");
                CHECK_EQUAL([view textFieldAtIndex:0].placeholder, @"Login", "configured login placeholder is shown");
                CHECK_EQUAL([view textFieldAtIndex:1].placeholder, @"Password", "configured password placeholder is shown");
                CHECK([view textFieldAtIndex:1].secureTextEntry, "password field is secure");
                CHECK(![view.delegate alertViewShouldEnableFirstOtherButton:view], "delegate keeps a disabled action's button disabled");
                CHECK_EQUAL(controls_state(view, @"Sign In"), @"disabled", "disabled action's button is disabled");
                screenshot("alert-login-disabled", "login/password alert, 'Sign In' disabled");
                after(pause_seconds, ^{
                    UITextField *nativePassword = [view textFieldAtIndex:1];
                    signIn.enabled = YES;
                    [nativePassword becomeFirstResponder];
                    [nativePassword insertText:@"secret"];
                    after(0.5, ^{
                        CHECK_EQUAL(password.text, @"secret", "typed text reaches the configured field");
                        CHECK(changes >= 1, "change notification is posted for the configured field");
                        CHECK([view.delegate alertViewShouldEnableFirstOtherButton:view], "delegate enables the button of an enabled action");
                        CHECK_EQUAL(controls_state(view, @"Sign In"), @"enabled", "an action enabled while typing enables its button");
                        screenshot("alert-login-enabled", "login/password alert, password filled, 'Sign In' enabled");
                        after(pause_seconds, ^{
                            [view dismissWithClickedButtonIndex:view.firstOtherButtonIndex animated:YES];
                        });
                    });
                });
            }];
        } copy],
        [^(void (^done)(void)) {
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Dismiss" message:@"Closed by the presenter" preferredStyle:UIAlertControllerStyleAlert];
            __weak UIAlertController *weakAlert = alert;
            __block NSInteger handlers = 0;
            [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) { handlers++; }]];
            [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) { handlers++; }]];
            [host presentViewController:alert animated:YES completion:^{
                CHECK(shown_native_view(weakAlert, [UIAlertView class]) != nil, "alert to dismiss is shown");
                screenshot("alert-dismiss-before", "UIAlertView 'Dismiss' about to be closed by dismissViewControllerAnimated");
                after(pause_seconds, ^{
                    [host dismissViewControllerAnimated:YES completion:^{
                        CHECK(handlers == 0, "dismissViewController runs no action handler");
                        CHECK(navigation.presentedViewController == nil, "nothing is presented after dismissal");
                        CHECK(weakAlert.presentingViewController == nil, "dismissed alert has no presenter");
                        after(0.5, ^{
                            CHECK(shown_native_view(weakAlert, [UIAlertView class]) == nil, "alert view is gone after dismissViewController");
                            done();
                        });
                    }];
                });
            }];
        } copy],
        [^(void (^done)(void)) {
            UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"Sheet" message:@"Pick one" preferredStyle:UIAlertControllerStyleActionSheet];
            __weak UIAlertController *weakSheet = sheet;
            NSMutableArray *fired = [NSMutableArray array];
            void (^record)(UIAlertAction *) = ^(UIAlertAction *action) {
                [fired addObject:action.title];
                CHECK(navigation.presentedViewController == nil, "sheet handler runs once the sheet is no longer presented");
                after(1, ^{
                    CHECK_EQUAL(fired, (@[@"Delete"]), "clicked sheet button runs only its own handler");
                    done();
                });
            };
            [sheet addAction:[UIAlertAction actionWithTitle:@"Share" style:UIAlertActionStyleDefault handler:record]];
            [sheet addAction:[UIAlertAction actionWithTitle:@"Delete" style:UIAlertActionStyleDestructive handler:record]];
            [sheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:record]];
            [sheet addAction:[UIAlertAction actionWithTitle:@"Erase" style:UIAlertActionStyleDestructive handler:record]];
            [host presentViewController:sheet animated:YES completion:^{
                UIActionSheet *view = native_view(weakSheet, [UIActionSheet class], "sheet shows a UIActionSheet in the app windows");
                CHECK(view.visible, "action sheet is visible when the presentation completes");
                CHECK_EQUAL(button_titles(view), (@[@"Share", @"Delete", @"Erase", @"Cancel"]), "action sheet keeps order and puts cancel last");
                CHECK_EQUAL(@(view.cancelButtonIndex), @3, "action sheet cancel index");
                CHECK_EQUAL(@(view.destructiveButtonIndex), @1, "action sheet destructive index");
                CHECK_EQUAL(view.title, @"Sheet\nPick one", "action sheet shows title and message");
                CHECK(view.window != nil && view.window.screen == navigation.view.window.screen, "action sheet is shown on the presenter's screen");
                CHECK(navigation.presentedViewController == weakSheet, "navigation controller reports the presented sheet");
                screenshot("sheet", "UIActionSheet 'Sheet / Pick one' with Share, Delete (red), Erase, Cancel");
                after(pause_seconds, ^{
                    [view dismissWithClickedButtonIndex:1 animated:YES];
                });
            }];
        } copy],
        [^(void (^done)(void)) {
            UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"Again" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
            __weak UIAlertController *weakSheet = sheet;
            NSMutableArray *fired = [NSMutableArray array];
            [sheet addAction:[UIAlertAction actionWithTitle:@"Share" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                [fired addObject:action.title];
            }]];
            [sheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
                [fired addObject:action.title];
                after(1, ^{
                    CHECK_EQUAL(fired, (@[@"Cancel"]), "re-presented sheet runs the cancel handler");
                    done();
                });
            }]];
            __block NSInteger presentations = 0;
            [navigation presentViewController:sheet animated:YES completion:^{
                presentations++;
                after(1, ^{
                    [weakSheet dismissViewControllerAnimated:NO completion:^{
                        CHECK(fired.count == 0, "sheet dismissViewController runs no handler");
                        CHECK(navigation.presentedViewController == nil, "nothing is presented after the sheet dismisses itself");
                        [navigation presentViewController:weakSheet animated:YES completion:^{
                            presentations++;
                            UIActionSheet *view = native_view(weakSheet, [UIActionSheet class], "re-presented sheet shows a UIActionSheet");
                            CHECK(presentations == 2, "a dismissed sheet can be presented again");
                            screenshot("sheet-again", "UIActionSheet 'Again' with Share, Cancel");
                            after(pause_seconds, ^{
                                [view dismissWithClickedButtonIndex:view.cancelButtonIndex animated:YES];
                            });
                        }];
                    }];
                });
            }];
        } copy],
        [^(void (^done)(void)) {
            __weak UIAlertController *weakAlert;
            @autoreleasepool {
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Lifetime" message:@"Nobody else keeps this alert" preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
                weakAlert = alert;
                [navigation presentViewController:alert animated:YES completion:^{
                    after(1, ^{
                        UIAlertController *strongAlert = weakAlert;
                        CHECK(strongAlert != nil, "a presented alert stays alive without client references");
                        UIAlertView *view = native_view(strongAlert, [UIAlertView class], "lifetime alert shows a UIAlertView");
                        strongAlert = nil;
                        [view dismissWithClickedButtonIndex:0 animated:NO];
                        after(2, ^{
                            CHECK(weakAlert == nil, "a dismissed alert is released");
                            done();
                        });
                    });
                }];
            }
        } copy],
    ];
}

@end

int main(int argc, char **argv)
{
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([AlertTestDelegate class]));
    }
}
