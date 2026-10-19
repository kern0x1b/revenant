/* stubs.m - what UIViewController+TransitionCoordinator.m calls in the rest of the port, for the host. Nothing here is
   reached on the host except the sheet's stand-in: below 8.0 the port's engine presents, and the host's UIKit is a release
   that presents the custom styles itself (charon_release_presents() is YES, as on a device from 8.0 on). */
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "CharonCustomTransition.h"

BOOL charon_custom_transition(CharonTransitionKind kind, UIViewController *from, UIViewController *to, UIViewController *source, id<UIViewControllerAnimatedTransitioning> animator, id<UIViewControllerInteractiveTransitioning> interactor, UIModalPresentationStyle style, void (^native)(void), void (^undo)(void), void (^completion)(BOOL finished))
{
    return NO;
}

BOOL charon_document_menu_present(UIViewController *presenting, UIViewController *presented, BOOL animated, void (^completion)(void))
{
    return NO;
}

BOOL charon_popover_present(UIViewController *presenting, UIViewController *presented, BOOL animated, void (^completion)(void))
{
    return NO;
}

BOOL charon_popover_dismiss(UIViewController *controller, BOOL animated, void (^completion)(void))
{
    return NO;
}

id<UIViewControllerAnimatedTransitioning> charon_edge_pop_animator(UINavigationController *navigation)
{
    return nil;
}

id<UIViewControllerInteractiveTransitioning> charon_edge_pop_interactor(UINavigationController *navigation)
{
    return nil;
}

void charon_presentation_present(UIViewController *presenting, UIViewController *presented, UIPresentationController *presentation, id<UIViewControllerAnimatedTransitioning> animator, void (^native)(void), void (^completion)(BOOL finished))
{
}

void charon_presentation_dismiss(UIViewController *presented, UIViewController *presenting, UIPresentationController *presentation, id<UIViewControllerAnimatedTransitioning> animator, void (^native)(void), void (^completion)(BOOL finished))
{
}

/* The port keeps a controller's presentation controller in an association (CharonCustomTransition.m); the host's
   UIKit keeps its own, so this one is a separate key the recorder reads to see what the installer left. */
static const char charon_presentation_key;

UIPresentationController *charon_presentation_controller_of(UIViewController *controller)
{
    return objc_getAssociatedObject(controller, &charon_presentation_key);
}

void charon_set_presentation_controller(UIViewController *controller, UIPresentationController *presentation)
{
    objc_setAssociatedObject(controller, &charon_presentation_key, presentation, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
