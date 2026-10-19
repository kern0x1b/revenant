#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "check.h"
#import "RevenantCustomTransition.h"

@implementation UISheetPresentationController (RevenantHostStandIn)
- (id<UIViewControllerAnimatedTransitioning>)revenant_transitionAnimator
{
    return nil;
}
@end

static int asked;

@implementation UIViewController (RevenantHostCount)
- (UISheetPresentationController *)revenantHost_sheetPresentationController
{
    asked++;
    UISheetPresentationController *sheet = [self revenantHost_sheetPresentationController];
    revenant_set_presentation_controller(self, sheet);
    return sheet;
}
@end

void host_attach_prefixed(const char *prefix);

@interface UIViewController (RevenantHostSheetHold)
- (void)revenantHost_revenant_sheetDidDismiss:(UIPresentationController *)sheet;
@end

@implementation UISheetPresentationController (RevenantHostEnd)
- (void)revenantHost_dismissalTransitionDidEnd:(BOOL)completed
{
    [self revenantHost_dismissalTransitionDidEnd:completed];
    if (completed)
        [self.presentedViewController revenantHost_revenant_sheetDidDismiss:self];
}
@end

@interface CallerDelegate : NSObject <UIViewControllerTransitioningDelegate>
@property (nonatomic) int presented, dismissed;
@end

@implementation CallerDelegate
- (id<UIViewControllerAnimatedTransitioning>)animationControllerForPresentedController:(UIViewController *)presented presentingController:(UIViewController *)presenting sourceController:(UIViewController *)source
{
    self.presented++;
    return nil;
}
- (id<UIViewControllerAnimatedTransitioning>)animationControllerForDismissedController:(UIViewController *)dismissed
{
    self.dismissed++;
    return nil;
}
@end

@interface RecordDelegate : UIResponder <UIApplicationDelegate>
@end

@implementation RecordDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options { return YES; }
@end

@interface RecordScene : UIResponder <UIWindowSceneDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

static NSMutableArray<void (^)(void)> *steps;

static void step(void (^body)(void))
{
    if (!steps)
        steps = [NSMutableArray array];
    [steps addObject:[body copy]];
}

static void advance(void)
{
    if (!steps.count) {
        printf("checks=%d failures=%d\n", revenant_checks, revenant_failures);
        fflush(stdout);
        exit(revenant_failures ? 1 : 0);
    }
    void (^body)(void) = steps.firstObject;
    [steps removeObjectAtIndex:0];
    body();
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        advance();
    });
}

static __weak UIPresentationController *sheetSeen;

static UIViewController *presenter(UIViewController *root, UIUserInterfaceSizeClass width)
{
    UIViewController *child = [[UIViewController alloc] init];
    child.definesPresentationContext = YES;
    [root addChildViewController:child];
    [root.view addSubview:child.view];
    [child didMoveToParentViewController:root];
    [root setOverrideTraitCollection:[UITraitCollection traitCollectionWithHorizontalSizeClass:width] forChildViewController:child];
    return child;
}

static void run(UIViewController *root)
{
    host_attach_prefixed("revenantHost_");
    Method original = class_getInstanceMethod([UIViewController class], @selector(sheetPresentationController));
    method_exchangeImplementations(original, class_getInstanceMethod([UIViewController class], @selector(revenantHost_sheetPresentationController)));

    method_exchangeImplementations(class_getInstanceMethod([UISheetPresentationController class], @selector(dismissalTransitionDidEnd:)), class_getInstanceMethod([UISheetPresentationController class], @selector(revenantHost_dismissalTransitionDidEnd:)));

    CHECK([UIPresentationController instancesRespondToSelector:@selector(revenant_setContainerView:)] == NO, "host.presents");

    UIViewController *compact = presenter(root, UIUserInterfaceSizeClassCompact);
    UIViewController *regular = presenter(root, UIUserInterfaceSizeClassRegular);

    CallerDelegate *caller = [[CallerDelegate alloc] init];
    UIViewController *controller = [[UIViewController alloc] init];
    controller.modalPresentationStyle = UIModalPresentationPageSheet;
    controller.transitioningDelegate = caller;
    __block UIPresentationController *first = nil;

    step(^{
        controller.sheetPresentationController.detents = @[ [UISheetPresentationControllerDetent mediumDetent] ];
        asked = 0;
        [compact presentViewController:controller animated:YES completion:nil];
    });
    step(^{
        UIPresentationController *sheet = revenant_presentation_controller_of(controller);
        first = sheet;
        sheetSeen = sheet;
        CHECK(asked == 1, "compact.asked.once");
        CHECK([sheet isKindOfClass:[UISheetPresentationController class]], "compact.sheet");
        CHECK(controller.presentingViewController != nil, "compact.presented");
        CHECK(controller.modalPresentationStyle == UIModalPresentationPageSheet, "compact.style.back");
        CHECK(controller.presentationController == sheet, "compact.release.uses.sheet");
        CHECK(controller.transitioningDelegate != caller && [NSStringFromClass([controller.transitioningDelegate class]) isEqualToString:@"RevenantSheetHandover"], "compact.delegate.handover");
        CHECK(caller.presented >= 1, "compact.caller.asked.first");
        CHECK([controller.presentationController isKindOfClass:[UISheetPresentationController class]] && [((UISheetPresentationController *)controller.presentationController).detents.firstObject.identifier isEqual:UISheetPresentationControllerDetentIdentifierMedium], "compact.detents.of.caller");
        [compact dismissViewControllerAnimated:YES completion:nil];
    });
    step(^{
        CHECK(controller.presentingViewController == nil, "compact.dismissed");
        CHECK(controller.transitioningDelegate == caller, "compact.delegate.back");
        CHECK(caller.dismissed >= 1, "compact.caller.asked.dismiss");
        CHECK(revenant_presentation_controller_of(controller) == nil, "compact.sheet.dropped");
        CHECK([controller.sheetPresentationController.detents.firstObject.identifier isEqual:UISheetPresentationControllerDetentIdentifierLarge], "host.sheet.detents.not.kept");
        first = nil;
        asked = 0;
        [compact presentViewController:controller animated:NO completion:nil];
    });
    step(^{
        CHECK(sheetSeen == nil, "compact.first.sheet.freed");
        UIPresentationController *again = revenant_presentation_controller_of(controller);
        CHECK(asked == 1 && again != nil, "compact.second.sheet.is.new");
        [compact dismissViewControllerAnimated:NO completion:nil];
    });

    step(^{
        asked = 0;
        [regular presentViewController:controller animated:NO completion:nil];
    });
    step(^{
        CHECK(controller.presentingViewController != nil, "regular.presented");
        CHECK(asked == 0, "regular.asked.none");
        CHECK(revenant_presentation_controller_of(controller) == nil, "regular.none.held");
        CHECK(controller.transitioningDelegate == caller, "regular.delegate.untouched");
        [regular dismissViewControllerAnimated:NO completion:nil];
    });
    UIViewController *full = [[UIViewController alloc] init];
    full.modalPresentationStyle = UIModalPresentationFullScreen;
    step(^{
        asked = 0;
        [compact presentViewController:full animated:NO completion:nil];
    });
    step(^{
        CHECK(asked == 0 && revenant_presentation_controller_of(full) == nil, "fullscreen.asked.none");
        [compact dismissViewControllerAnimated:NO completion:nil];
    });

    UIViewController *ancestor = [[UIViewController alloc] init];
    ancestor.modalPresentationStyle = UIModalPresentationFullScreen;
    UIViewController *chained = [[UIViewController alloc] init];
    chained.modalPresentationStyle = UIModalPresentationPageSheet;
    CallerDelegate *chainCaller = [[CallerDelegate alloc] init];
    chained.transitioningDelegate = chainCaller;
    static __weak UIPresentationController *chainSheet;
    step(^{
        [compact presentViewController:ancestor animated:NO completion:nil];
    });
    step(^{
        asked = 0;
        [ancestor presentViewController:chained animated:NO completion:nil];
    });
    step(^{
        UIPresentationController *sheet = revenant_presentation_controller_of(chained);
        chainSheet = sheet;
        CHECK(chained.presentingViewController == ancestor && asked == 1, "chain.presented");
        CHECK([sheet isKindOfClass:[UISheetPresentationController class]] && [NSStringFromClass([chained.transitioningDelegate class]) isEqualToString:@"RevenantSheetHandover"], "chain.has.sheet.while.presented");
        [compact dismissViewControllerAnimated:NO completion:nil];
    });
    step(^{
        CHECK(chained.presentingViewController == nil && ancestor.presentingViewController == nil, "chain.dismissed");
        CHECK(revenant_presentation_controller_of(chained) == nil, "chain.sheet.dropped");
        CHECK(chainSheet == nil, "chain.sheet.freed");
        CHECK(chained.transitioningDelegate == chainCaller, "chain.delegate.back");
    });
    advance();
}

@implementation RecordScene

- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)connectionOptions
{
    self.window = [[UIWindow alloc] initWithWindowScene:(UIWindowScene *)scene];
    self.window.frame = CGRectMake(0, 0, 320, 480);
    UIViewController *root = [[UIViewController alloc] init];
    self.window.rootViewController = root;
    [self.window makeKeyAndVisible];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        run(root);
    });
}

@end

int main(int argc, char **argv)
{
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, @"RecordDelegate");
    }
}
