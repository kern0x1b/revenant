#import <Foundation/Foundation.h>
#import <UIKit/UIViewController.h>
#import <UIKit/UIViewControllerTransitioning.h>

#import "UIDocumentBrowserTransitionController.h"

#if defined(REVENANT_TRANSITION_ANIMATION_STANDIN)
void RevenantAnimate(NSTimeInterval duration, void (^animations)(void), void (^completion)(BOOL));
#else
static inline void RevenantAnimate(NSTimeInterval duration, void (^animations)(void),
                                 void (^completion)(BOOL finished))
{
    [UIView animateWithDuration:duration animations:animations completion:completion];
}
#endif

@implementation UIDocumentBrowserTransitionController
{
@private
    NSProgress *_loadingProgress;
    __weak UIView *_targetView;
}

static const NSTimeInterval kRevenantDocumentRevealDuration = 0.25;

@synthesize loadingProgress = _loadingProgress;
@synthesize targetView = _targetView;


- (NSTimeInterval)transitionDuration:(id<UIViewControllerContextTransitioning>)transitionContext
{
    if (!_loadingProgress || _loadingProgress.finished)
        return kRevenantDocumentRevealDuration;
    return 0;
}

- (void)animateTransition:(id<UIViewControllerContextTransitioning>)transitionContext
{
    UIView *target = _targetView;
    if (!target) {
        if ([transitionContext respondsToSelector:@selector(completeTransition:)])
            [transitionContext completeTransition:NO];
        return;
    }
    NSTimeInterval duration = [self transitionDuration:transitionContext];
    target.alpha = 0;
    RevenantAnimate(duration, ^{ target.alpha = 1; }, ^(BOOL finished) {
        target.alpha = 1;
        if ([transitionContext respondsToSelector:@selector(completeTransition:)])
            [transitionContext completeTransition:finished];
    });
}

@end
