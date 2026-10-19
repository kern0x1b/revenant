#import <UIKit/UIKit.h>
#import "check.h"
#import "gesture.h"
#import "popover-cases.h"
#import "popover-expectations.h"

#ifndef POPOVER_NAME
#define POPOVER_NAME @"popover"
#endif

static NSString *const results_folder = @"/private/var/backports";

@interface PopoverDelegate : UIResponder <UIApplicationDelegate, UIPopoverPresentationControllerDelegate>
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) UIViewController *root;
@property (nonatomic, strong) UIButton *button;
@property (nonatomic, strong) UIButton *passthrough;
@property (nonatomic, strong) NSMutableArray *events;
@property (nonatomic, assign) BOOL allowDismiss;
@property (nonatomic, assign) NSInteger tapped;
@end

@implementation PopoverDelegate

- (void)prepareForPopoverPresentation:(UIPopoverPresentationController *)controller { [self.events addObject:@"prepare"]; }
- (BOOL)popoverPresentationControllerShouldDismissPopover:(UIPopoverPresentationController *)controller { [self.events addObject:@"should"]; return self.allowDismiss; }
- (void)popoverPresentationControllerDidDismissPopover:(UIPopoverPresentationController *)controller { [self.events addObject:@"did"]; }
- (UIModalPresentationStyle)adaptivePresentationStyleForPresentationController:(UIPresentationController *)controller { return UIModalPresentationFullScreen; }
- (UIViewController *)presentationController:(UIPresentationController *)controller viewControllerForAdaptivePresentationStyle:(UIModalPresentationStyle)style
{
    [self.events addObject:@"adaptive"];
    return [[UINavigationController alloc] initWithRootViewController:controller.presentedViewController];
}
- (void)passthroughTapped { self.tapped++; }

- (UIViewController *)contentOfSize:(CGSize)size
{
    UIViewController *content = [[UIViewController alloc] init];
    content.view.backgroundColor = [UIColor colorWithRed:0.8f green:0.9f blue:1 alpha:1];
    content.preferredContentSize = size;
    content.modalPresentationStyle = UIModalPresentationPopover;
    return content;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options
{
    [[NSFileManager defaultManager] createDirectoryAtPath:results_folder withIntermediateDirectories:YES attributes:nil error:NULL];
    [[NSFileManager defaultManager] removeItemAtPath:[results_folder stringByAppendingPathComponent:POPOVER_NAME @".done"] error:NULL];
    charon_log_to([results_folder stringByAppendingPathComponent:POPOVER_NAME @".log"]);
    self.events = [NSMutableArray array];
    self.root = [[UIViewController alloc] init];
    self.root.view.backgroundColor = [UIColor whiteColor];
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.rootViewController = self.root;
    [self.window makeKeyAndVisible];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        BOOL pad = UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad;
        NSDictionary *expected = [NSJSONSerialization JSONObjectWithData:[NSData dataWithBytes:popover_expectations length:strlen(popover_expectations)] options:0 error:NULL];
        NSMutableDictionary *records = [NSMutableDictionary dictionary];
        UIWindow *scratch = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        popover_defaults(scratch, ^(NSString *name, NSString *value) { records[name] = value; });
        for (NSString *name in [expected.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
            if ([expected[name] isEqualToString:records[name]])
                charon_check(YES, name.UTF8String, nil);
            else
                charon_check(NO, name.UTF8String, [NSString stringWithFormat:@"\n    device %@\n    host   %@", records[name], expected[name]]);
        }
        self.button = [UIButton buttonWithType:UIButtonTypeRoundedRect];
        self.button.frame = CGRectMake(40, 120, 120, 44);
        [self.button setTitle:@"Source" forState:UIControlStateNormal];
        [self.root.view addSubview:self.button];
        self.passthrough = [UIButton buttonWithType:UIButtonTypeRoundedRect];
        self.passthrough.frame = CGRectMake(40, self.window.bounds.size.height - 110, 120, 44);
        [self.passthrough setTitle:@"Pass" forState:UIControlStateNormal];
        [self.passthrough addTarget:self action:@selector(passthroughTapped) forControlEvents:UIControlEventTouchUpInside];
        [self.root.view addSubview:self.passthrough];
        CGFloat width = self.window.bounds.size.width, height = self.window.bounds.size.height;
        UIViewController *content = [self contentOfSize:CGSizeMake(300, 200)];
        UIPopoverPresentationController *presentation = content.popoverPresentationController;
        presentation.sourceView = self.button;
        presentation.delegate = self;
        presentation.passthroughViews = @[self.passthrough];
        self.allowDismiss = NO;
        gesture_step(0.01, ^{ CHECK(gesture_ready(), "touches can be sent"); });
        gesture_step(0.05, ^{
            [self.root presentViewController:content animated:NO completion:nil];
        });
        gesture_step(1.0, ^{
            if (pad) {
                CHECK(self.root.presentedViewController == content, "the presenting controller answers the popover's controller as presented");
                CHECK(content.presentingViewController == self.root, "and the controller answers it as the presenting one");
            } else {
                UIViewController *shown = self.root.presentedViewController;
                CHECK([shown isKindOfClass:[UINavigationController class]] && [(UINavigationController *)shown topViewController] == content, "on a phone what the delegate answered for the adaptive style is presented");
            }
            CHECK([self.events containsObject:@"prepare"], "the delegate is asked to prepare");
            CHECK(content.view.window != nil, "the content is on the screen");
            if (pad) {
                CGSize size = content.view.bounds.size;
                CHECK(fabs(size.width - 300) < 2 && fabs(size.height - 200) < 2, "at the preferred content size");
                CHECK(presentation.arrowDirection != (UIPopoverArrowDirection)NSUIntegerMax && presentation.arrowDirection != 0, "the arrow direction is known");
            } else {
                CHECK(content.view.window.bounds.size.width == width, "on a phone the content is taken full screen");
                CHECK([self.events containsObject:@"adaptive"], "the delegate was asked for the controller of the adaptive style");
            }
        });
        if (pad) {
            gesture_tap(^{ return CGPointMake(width - 20, height - 20); }, 0.8);
            gesture_step(0.5, ^{
                CHECK([self.events containsObject:@"should"], "a touch outside asks the delegate whether to dismiss");
                CHECK(self.root.presentedViewController == content, "and the answer no keeps the popover");
                self.allowDismiss = YES;
            });
            gesture_tap(^{ return CGPointMake(40 + 60, height - 110 + 22); }, 0.8);
            gesture_step(0.5, ^{
                CHECK(self.tapped == 1, "a passthrough view takes the touch while the popover stays");
                CHECK(self.root.presentedViewController == content, "the popover is still there");
            });
            gesture_tap(^{ return CGPointMake(width - 20, height - 20); }, 1.0);
            gesture_step(0.6, ^{
                CHECK([self.events containsObject:@"did"], "a touch outside with the answer yes dismisses it and tells the delegate");
                CHECK(self.root.presentedViewController == nil, "the presenting controller has no presented controller after");
                CHECK(content.view.window == nil, "and the content is off the screen");
            });
        }
        __block BOOL completed = NO;
        gesture_step(0.05, ^{
            [self.events removeAllObjects];
            if (!pad && self.root.presentedViewController)
                [self.root dismissViewControllerAnimated:NO completion:nil];
        });
        gesture_step(0.6, ^{
            UIViewController *again = [self contentOfSize:CGSizeMake(260, 180)];
            again.popoverPresentationController.sourceView = self.button;
            again.popoverPresentationController.sourceRect = CGRectMake(0, 0, 60, 30);
            again.popoverPresentationController.delegate = self;
            [self.root presentViewController:again animated:NO completion:nil];
            self.events = [NSMutableArray arrayWithObject:again];
        });
        gesture_step(0.9, ^{
            UIViewController *again = self.events.firstObject;
            UIViewController *shown = self.root.presentedViewController;
            CHECK(shown == again || ([shown isKindOfClass:[UINavigationController class]] && [(UINavigationController *)shown topViewController] == again), "a second popover from a rectangle is presented");
            [self.root dismissViewControllerAnimated:NO completion:^{ completed = YES; }];
        });
        gesture_step(0.9, ^{
            UIViewController *again = self.events.firstObject;
            CHECK(completed, "dismissing from the presenting controller calls the completion");
            CHECK(self.root.presentedViewController == nil && again.view.window == nil, "and takes the popover away");
            NSMutableArray *rest = [self.events mutableCopy];
            [rest removeObject:again];
            CHECK(![rest containsObject:@"did"], "a dismissal by the application is not told to the delegate");
            BOOL raised = NO;
            UIViewController *bare = [self contentOfSize:CGSizeMake(100, 100)];
            @try { [self.root presentViewController:bare animated:NO completion:nil]; } @catch (NSException *e) { raised = [e.name isEqual:NSGenericException]; }
            CHECK(raised == pad, pad ? "a popover with no source is refused as the release refuses it" : "and on a phone the missing source does not matter");
            if (!pad && self.root.presentedViewController)
                [self.root dismissViewControllerAnimated:NO completion:nil];
        });
        gesture_run(^{
            printf("checks=%d failures=%d\n", charon_checks, charon_failures);
            NSString *summary = [NSString stringWithFormat:@"%@ checks=%d failures=%d\n", charon_failures ? @"FAIL" : @"ok", charon_checks, charon_failures];
            [summary writeToFile:[results_folder stringByAppendingPathComponent:POPOVER_NAME @".done"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
        });
    });
    return YES;
}

@end

int main(int argc, char **argv)
{
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([PopoverDelegate class]));
    }
}
