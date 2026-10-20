#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, RevenantTransitionKind) {
    RevenantTransitionPresent,
    RevenantTransitionDismiss,
    RevenantTransitionPush,
    RevenantTransitionPop
};

@interface RevenantTransitionContext : NSObject <UIViewControllerContextTransitioning>
- (id<UIViewControllerAnimatedTransitioning>)revenant_animator;
@end

BOOL revenant_custom_transition(RevenantTransitionKind kind, UIViewController *from, UIViewController *to, UIViewController *source, id<UIViewControllerAnimatedTransitioning> animator, id<UIViewControllerInteractiveTransitioning> interactor, UIModalPresentationStyle style, void (^native)(void), void (^undo)(void), void (^completion)(BOOL finished));

@interface UIPresentationController (RevenantContainer)
- (void)revenant_setContainerView:(UIView *)view;
- (void)revenant_ownedByPresentedViewController;
- (id<UIViewControllerAnimatedTransitioning>)revenant_transitionAnimator;
- (BOOL)revenant_containerIgnoresDirectTouches;
@end

@interface UIViewController (RevenantSheetHold)
- (void)revenant_sheetDidDismiss:(UIPresentationController *)sheet;
@end

static inline BOOL revenant_sheet_style(UIModalPresentationStyle style)
{
    return style == UIModalPresentationPageSheet || style == UIModalPresentationFormSheet || style == UIModalPresentationAutomatic;
}

UIPresentationController *revenant_presentation_controller_of(UIViewController *controller);
void revenant_set_presentation_controller(UIViewController *controller, UIPresentationController *presentation);

void revenant_presentation_present(UIViewController *presenting, UIViewController *presented, UIPresentationController *presentation, id<UIViewControllerAnimatedTransitioning> animator, void (^native)(void), void (^completion)(BOOL finished));
void revenant_presentation_dismiss(UIViewController *presented, UIViewController *presenting, UIPresentationController *presentation, id<UIViewControllerAnimatedTransitioning> animator, void (^native)(void), void (^completion)(BOOL finished));

id<UIViewControllerAnimatedTransitioning> revenant_edge_pop_animator(UINavigationController *navigation);
id<UIViewControllerInteractiveTransitioning> revenant_edge_pop_interactor(UINavigationController *navigation);

BOOL revenant_popover_present(UIViewController *presenting, UIViewController *presented, BOOL animated, void (^completion)(void));
BOOL revenant_popover_dismiss(UIViewController *controller, BOOL animated, void (^completion)(void));

BOOL revenant_document_menu_present(UIViewController *presenting, UIViewController *presented, BOOL animated, void (^completion)(void));
