/* record.m - the cases of run.sh: the port's installer (UIViewController+TransitionCoordinator.m) presenting and dismissing
   on the host's UIKit. */
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "check.h"
#import "CharonCustomTransition.h"

/* Stands in for the port's sheet class, which the installer asks for a selector only it carries. */
@implementation UISheetPresentationController (CharonHostStandIn)
- (id<UIViewControllerAnimatedTransitioning>)charon_transitionAnimator
{
    return nil;
}
@end

static int asked;

/* Counts the asks, and keeps what it answers for the controller as the port's getter does (UISheetPresentationController.m),
   which the host does not carry. */
@implementation UIViewController (CharonHostCount)
- (UISheetPresentationController *)charonHost_sheetPresentationController
{
    asked++;
    UISheetPresentationController *sheet = [self charonHost_sheetPresentationController];
    charon_set_presentation_controller(self, sheet);
    return sheet;
}
@end

/* The categories of the installer file are attached to the host's classes under a prefix (host-attach.c), as the host's UIKit
   has some of their selectors already: the one the sheet sends its controller is then charonHost_charon_sheetDidDismiss:. */
void host_attach_prefixed(const char *prefix);

@interface UIViewController (CharonHostSheetHold)
- (void)charonHost_charon_sheetDidDismiss:(UIPresentationController *)sheet;
@end

/* What the port's sheet does when its dismissal ends (UISheetPresentationController.m, dismissalTransitionDidEnd:): it says so to
   its controller. The host's class of that name is the release's, so its method is exchanged for one that says the same. */
@implementation UISheetPresentationController (CharonHostEnd)
- (void)charonHost_dismissalTransitionDidEnd:(BOOL)completed
{
    [self charonHost_dismissalTransitionDidEnd:completed];
    if (completed)
        [self.presentedViewController charonHost_charon_sheetDidDismiss:self];
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

/* UIKit finishes a presentation or a dismissal on the main run loop after the block that began it returns, so the cases
   are steps, each run in a turn of its own. */
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
        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
        fflush(stdout);
        exit(charon_failures ? 1 : 0);
    }
    void (^body)(void) = steps.firstObject;
    [steps removeObjectAtIndex:0];
    body();
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        advance();
    });
}

static __weak UIPresentationController *sheetSeen;

/* One controller, presented from a presenter of the given width class and dismissed. */
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
    host_attach_prefixed("charonHost_");
    Method original = class_getInstanceMethod([UIViewController class], @selector(sheetPresentationController));
    method_exchangeImplementations(original, class_getInstanceMethod([UIViewController class], @selector(charonHost_sheetPresentationController)));

    method_exchangeImplementations(class_getInstanceMethod([UISheetPresentationController class], @selector(dismissalTransitionDidEnd:)), class_getInstanceMethod([UISheetPresentationController class], @selector(charonHost_dismissalTransitionDidEnd:)));

    CHECK([UIPresentationController instancesRespondToSelector:@selector(charon_setContainerView:)] == NO, "host.presents");

    UIViewController *compact = presenter(root, UIUserInterfaceSizeClassCompact);
    UIViewController *regular = presenter(root, UIUserInterfaceSizeClassRegular);

    CallerDelegate *caller = [[CallerDelegate alloc] init];
    UIViewController *controller = [[UIViewController alloc] init];
    controller.modalPresentationStyle = UIModalPresentationPageSheet;
    controller.transitioningDelegate = caller;
    __block UIPresentationController *first = nil;

    /* A page sheet from a compact width: the sheet is asked for and the release presents it through the handover. */
    step(^{
        /* The caller configures the sheet before presenting, as the sheet's own API asks. */
        controller.sheetPresentationController.detents = @[ [UISheetPresentationControllerDetent mediumDetent] ];
        asked = 0;
        [compact presentViewController:controller animated:YES completion:nil];
    });
    step(^{
        UIPresentationController *sheet = charon_presentation_controller_of(controller);
        first = sheet;
        sheetSeen = sheet;
        CHECK(asked == 1, "compact.asked.once");
        CHECK([sheet isKindOfClass:[UISheetPresentationController class]], "compact.sheet");
        CHECK(controller.presentingViewController != nil, "compact.presented");
        CHECK(controller.modalPresentationStyle == UIModalPresentationPageSheet, "compact.style.back");
        CHECK(controller.presentationController == sheet, "compact.release.uses.sheet");
        CHECK(controller.transitioningDelegate != caller && [NSStringFromClass([controller.transitioningDelegate class]) isEqualToString:@"CharonSheetHandover"], "compact.delegate.handover");
        CHECK(caller.presented >= 1, "compact.caller.asked.first");
        CHECK([controller.presentationController isKindOfClass:[UISheetPresentationController class]] && [((UISheetPresentationController *)controller.presentationController).detents.firstObject.identifier isEqual:UISheetPresentationControllerDetentIdentifierMedium], "compact.detents.of.caller");
        [compact dismissViewControllerAnimated:YES completion:nil];
    });
    step(^{
        CHECK(controller.presentingViewController == nil, "compact.dismissed");
        CHECK(controller.transitioningDelegate == caller, "compact.delegate.back");
        CHECK(caller.dismissed >= 1, "compact.caller.asked.dismiss");
        CHECK(charon_presentation_controller_of(controller) == nil, "compact.sheet.dropped");
        /* UIKit's controller has none either: asked again after its dismissal it makes another, with the default detents. */
        CHECK([controller.sheetPresentationController.detents.firstObject.identifier isEqual:UISheetPresentationControllerDetentIdentifierLarge], "host.sheet.detents.not.kept");
        first = nil;
        asked = 0;
        /* Presented again, it is another sheet, as UIKit's controller makes another after its dismissal. */
        [compact presentViewController:controller animated:NO completion:nil];
    });
    step(^{
        CHECK(sheetSeen == nil, "compact.first.sheet.freed");
        UIPresentationController *again = charon_presentation_controller_of(controller);
        CHECK(asked == 1 && again != nil, "compact.second.sheet.is.new");
        [compact dismissViewControllerAnimated:NO completion:nil];
    });

    /* Neither a regular width nor another style asks for a sheet. */
    step(^{
        asked = 0;
        [regular presentViewController:controller animated:NO completion:nil];
    });
    step(^{
        CHECK(controller.presentingViewController != nil, "regular.presented");
        CHECK(asked == 0, "regular.asked.none");
        CHECK(charon_presentation_controller_of(controller) == nil, "regular.none.held");
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
        CHECK(asked == 0 && charon_presentation_controller_of(full) == nil, "fullscreen.asked.none");
        [compact dismissViewControllerAnimated:NO completion:nil];
    });

    /* A controller presented on top of another (compact -> ancestor -> chained) that goes down with its ancestor: the dismissal is the
       ancestor's, not its own, and the release ends the sheet's dismissal all the same. */
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
        UIPresentationController *sheet = charon_presentation_controller_of(chained);
        chainSheet = sheet;
        CHECK(chained.presentingViewController == ancestor && asked == 1, "chain.presented");
        CHECK([sheet isKindOfClass:[UISheetPresentationController class]] && [NSStringFromClass([chained.transitioningDelegate class]) isEqualToString:@"CharonSheetHandover"], "chain.has.sheet.while.presented");
        [compact dismissViewControllerAnimated:NO completion:nil];
    });
    step(^{
        CHECK(chained.presentingViewController == nil && ancestor.presentingViewController == nil, "chain.dismissed");
        CHECK(charon_presentation_controller_of(chained) == nil, "chain.sheet.dropped");
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
