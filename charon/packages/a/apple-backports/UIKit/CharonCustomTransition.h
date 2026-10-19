#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, CharonTransitionKind) {
    CharonTransitionPresent,
    CharonTransitionDismiss,
    CharonTransitionPush,
    CharonTransitionPop
};

@interface CharonTransitionContext : NSObject <UIViewControllerContextTransitioning>
- (id<UIViewControllerAnimatedTransitioning>)charon_animator;
@end

BOOL charon_custom_transition(CharonTransitionKind kind, UIViewController *from, UIViewController *to, UIViewController *source, id<UIViewControllerAnimatedTransitioning> animator, id<UIViewControllerInteractiveTransitioning> interactor, UIModalPresentationStyle style, void (^native)(void), void (^undo)(void), void (^completion)(BOOL finished));

@interface UIPresentationController (CharonContainer)
- (void)charon_setContainerView:(UIView *)view;
- (void)charon_ownedByPresentedViewController;
- (id<UIViewControllerAnimatedTransitioning>)charon_transitionAnimator;
- (BOOL)charon_containerIgnoresDirectTouches;
@end

@interface UIViewController (CharonSheetHold)
- (void)charon_sheetDidDismiss:(UIPresentationController *)sheet;
@end

static inline BOOL charon_sheet_style(UIModalPresentationStyle style)
{
    return style == UIModalPresentationPageSheet || style == UIModalPresentationFormSheet || style == UIModalPresentationAutomatic;
}

UIPresentationController *charon_presentation_controller_of(UIViewController *controller);
void charon_set_presentation_controller(UIViewController *controller, UIPresentationController *presentation);

void charon_presentation_present(UIViewController *presenting, UIViewController *presented, UIPresentationController *presentation, id<UIViewControllerAnimatedTransitioning> animator, void (^native)(void), void (^completion)(BOOL finished));
void charon_presentation_dismiss(UIViewController *presented, UIViewController *presenting, UIPresentationController *presentation, id<UIViewControllerAnimatedTransitioning> animator, void (^native)(void), void (^completion)(BOOL finished));

id<UIViewControllerAnimatedTransitioning> charon_edge_pop_animator(UINavigationController *navigation);
id<UIViewControllerInteractiveTransitioning> charon_edge_pop_interactor(UINavigationController *navigation);

BOOL charon_popover_present(UIViewController *presenting, UIViewController *presented, BOOL animated, void (^completion)(void));
BOOL charon_popover_dismiss(UIViewController *controller, BOOL animated, void (^completion)(void));

BOOL charon_document_menu_present(UIViewController *presenting, UIViewController *presented, BOOL animated, void (^completion)(void));
