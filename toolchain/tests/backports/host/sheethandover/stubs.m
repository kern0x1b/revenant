#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "RevenantCustomTransition.h"

BOOL revenant_custom_transition(RevenantTransitionKind kind, UIViewController *from, UIViewController *to, UIViewController *source, id<UIViewControllerAnimatedTransitioning> animator, id<UIViewControllerInteractiveTransitioning> interactor, UIModalPresentationStyle style, void (^native)(void), void (^undo)(void), void (^completion)(BOOL finished))
{
    return NO;
}

BOOL revenant_document_menu_present(UIViewController *presenting, UIViewController *presented, BOOL animated, void (^completion)(void))
{
    return NO;
}

BOOL revenant_popover_present(UIViewController *presenting, UIViewController *presented, BOOL animated, void (^completion)(void))
{
    return NO;
}

BOOL revenant_popover_dismiss(UIViewController *controller, BOOL animated, void (^completion)(void))
{
    return NO;
}

id<UIViewControllerAnimatedTransitioning> revenant_edge_pop_animator(UINavigationController *navigation)
{
    return nil;
}

id<UIViewControllerInteractiveTransitioning> revenant_edge_pop_interactor(UINavigationController *navigation)
{
    return nil;
}

void revenant_presentation_present(UIViewController *presenting, UIViewController *presented, UIPresentationController *presentation, id<UIViewControllerAnimatedTransitioning> animator, void (^native)(void), void (^completion)(BOOL finished))
{
}

void revenant_presentation_dismiss(UIViewController *presented, UIViewController *presenting, UIPresentationController *presentation, id<UIViewControllerAnimatedTransitioning> animator, void (^native)(void), void (^completion)(BOOL finished))
{
}

static const char revenant_presentation_key;

UIPresentationController *revenant_presentation_controller_of(UIViewController *controller)
{
    return objc_getAssociatedObject(controller, &revenant_presentation_key);
}

void revenant_set_presentation_controller(UIViewController *controller, UIPresentationController *presentation)
{
    objc_setAssociatedObject(controller, &revenant_presentation_key, presentation, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
