#import <UIKit/UIKit.h>
#import "presentation-cases.h"

@interface PresentationCounting : UIPresentationController
@property (nonatomic, strong) NSMutableArray *calls;
@end

@implementation PresentationCounting
- (void)note:(NSString *)name
{
    if (!self.calls)
        self.calls = [NSMutableArray array];
    [self.calls addObject:name];
}
- (void)presentationTransitionWillBegin { [self note:@"willPresent"]; [super presentationTransitionWillBegin]; }
- (void)presentationTransitionDidEnd:(BOOL)completed { [self note:@"didPresent"]; [super presentationTransitionDidEnd:completed]; }
- (void)dismissalTransitionWillBegin { [self note:@"willDismiss"]; [super dismissalTransitionWillBegin]; }
- (void)dismissalTransitionDidEnd:(BOOL)completed { [self note:@"didDismiss"]; [super dismissalTransitionDidEnd:completed]; }
- (void)containerViewWillLayoutSubviews { [self note:@"willLayout"]; [super containerViewWillLayoutSubviews]; }
- (void)containerViewDidLayoutSubviews { [self note:@"didLayout"]; [super containerViewDidLayoutSubviews]; }
- (BOOL)shouldPresentInFullscreen { return NO; }
- (BOOL)shouldRemovePresentersView { return YES; }
- (CGRect)frameOfPresentedViewInContainerView { return CGRectMake(10, 20, 30, 40); }
@end

static NSString *rect_text(CGRect rect)
{
    return [NSString stringWithFormat:@"%.0f %.0f %.0f %.0f", rect.origin.x, rect.origin.y, rect.size.width, rect.size.height];
}

void presentation_run(UIWindow *window, PresentationRecorder record)
{
    UIViewController *presenting = window.rootViewController;
    for (NSNumber *style in @[@0, @1, @2, @3, @4, @5, @7, @-1]) {
        UIViewController *presented = [[UIViewController alloc] init];
        presented.modalPresentationStyle = style.integerValue;
        UIPresentationController *controller = [[UIPresentationController alloc] initWithPresentedViewController:presented presentingViewController:presenting];
        UITraitCollection *traits = [UITraitCollection traitCollectionWithUserInterfaceIdiom:UIUserInterfaceIdiomPhone];
        record([NSString stringWithFormat:@"style.%@", style], [NSString stringWithFormat:@"style=%ld fullscreen=%d removes=%d adaptive=%ld adaptiveForTraits=%ld", (long)controller.presentationStyle, controller.shouldPresentInFullscreen, controller.shouldRemovePresentersView, (long)controller.adaptivePresentationStyle, (long)[controller adaptivePresentationStyleForTraitCollection:traits]]);
    }
    UIViewController *presented = [[UIViewController alloc] init];
    UIPresentationController *controller = [[UIPresentationController alloc] initWithPresentedViewController:presented presentingViewController:presenting];
    record(@"new", [NSString stringWithFormat:@"super=%@ presented=%d presenting=%d container=%d delegate=%d override=%d view=%d frame=%@", NSStringFromClass([controller superclass]), controller.presentedViewController == presented, controller.presentingViewController == presenting, controller.containerView == nil, controller.delegate == nil, controller.overrideTraitCollection == nil, controller.presentedView == presented.view, rect_text(controller.frameOfPresentedViewInContainerView)]);
    record(@"size", NSStringFromCGSize([controller sizeForChildContentContainer:presented withParentContainerSize:CGSizeMake(320, 480)]));
    record(@"protocols", [NSString stringWithFormat:@"content=%d", [controller conformsToProtocol:@protocol(UIContentContainer)]]);
    UIPresentationController *orphan = [[UIPresentationController alloc] initWithPresentedViewController:presented presentingViewController:nil];
    record(@"orphan", [NSString stringWithFormat:@"presenting=%d presented=%d", orphan.presentingViewController == nil, orphan.presentedViewController == presented]);
    id delegate = [[NSObject alloc] init];
    controller.delegate = delegate;
    UITraitCollection *override = [UITraitCollection traitCollectionWithUserInterfaceIdiom:UIUserInterfaceIdiomPad];
    controller.overrideTraitCollection = override;
    record(@"set", [NSString stringWithFormat:@"delegate=%d override=%d", controller.delegate == delegate, controller.overrideTraitCollection == override]);
    [controller presentationTransitionWillBegin];
    [controller presentationTransitionDidEnd:YES];
    [controller dismissalTransitionWillBegin];
    [controller dismissalTransitionDidEnd:YES];
    [controller containerViewWillLayoutSubviews];
    [controller containerViewDidLayoutSubviews];
    record(@"hooks", @"survive");
    PresentationCounting *counting = [[PresentationCounting alloc] initWithPresentedViewController:presented presentingViewController:presenting];
    [counting presentationTransitionWillBegin];
    [counting presentationTransitionDidEnd:YES];
    [counting dismissalTransitionWillBegin];
    [counting dismissalTransitionDidEnd:NO];
    [counting containerViewWillLayoutSubviews];
    [counting containerViewDidLayoutSubviews];
    record(@"subclass", [NSString stringWithFormat:@"%@ fullscreen=%d removes=%d frame=%@", [counting.calls componentsJoinedByString:@","], counting.shouldPresentInFullscreen, counting.shouldRemovePresentersView, rect_text(counting.frameOfPresentedViewInContainerView)]);
    UIViewController *custom = [[UIViewController alloc] init];
    custom.modalPresentationStyle = UIModalPresentationCustom;
    record(@"custom.presentationController", [NSString stringWithFormat:@"%d", custom.presentationController == nil]);
}
