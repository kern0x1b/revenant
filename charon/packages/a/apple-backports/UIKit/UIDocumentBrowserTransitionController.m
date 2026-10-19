#import <Foundation/Foundation.h>
#import <UIKit/UIViewController.h>
#import <UIKit/UIViewControllerTransitioning.h>

#import "UIDocumentBrowserTransitionController.h"

#if defined(CHARON_TRANSITION_ANIMATION_STANDIN)
void CharonAnimate(NSTimeInterval duration, void (^animations)(void), void (^completion)(BOOL));
#else
static inline void CharonAnimate(NSTimeInterval duration, void (^animations)(void),
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

static const NSTimeInterval kCharonDocumentRevealDuration = 0.25;

@synthesize loadingProgress = _loadingProgress;
@synthesize targetView = _targetView;


- (NSTimeInterval)transitionDuration:(id<UIViewControllerContextTransitioning>)transitionContext
{
    if (!_loadingProgress || _loadingProgress.finished)
        return kCharonDocumentRevealDuration;
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
    CharonAnimate(duration, ^{ target.alpha = 1; }, ^(BOOL finished) {
        target.alpha = 1;
        if ([transitionContext respondsToSelector:@selector(completeTransition:)])
            [transitionContext completeTransition:finished];
    });
}

@end
