#import <Foundation/Foundation.h>
#import <UIKit/UIViewController.h>
#import <UIKit/UIViewControllerTransitioning.h>

#import "UIDocumentBrowserTransitionController.h"

// UIView's own animation on a device, and the harness's stand-in when one is compiled in, so the
// same body animates here and there. Neither is a transcription of Apple's: the host's is a block
// runner that remembers the duration it was asked for.
#if defined(CHARON_TRANSITION_ANIMATION_STANDIN)
void CharonAnimate(NSTimeInterval duration, void (^animations)(void), void (^completion)(BOOL));
#else
static inline void CharonAnimate(NSTimeInterval duration, void (^animations)(void),
                                 void (^completion)(BOOL finished))
{
    [UIView animateWithDuration:duration animations:animations completion:completion];
}
#endif

// The transition controller's own storage. A 6.1.3-era SDK has no document browser at all, so the
// class is the port's, and its two properties are what the header declares: the progress of the
// document being brought across, which may be nil when nothing is, and the view the transition
// animates to, held weakly as the header says, so a transition that outlives its target does not
// keep it alive.

@implementation UIDocumentBrowserTransitionController
{
@private
    NSProgress *_loadingProgress;
    __weak UIView *_targetView;
}

// How long showing a document takes once it has arrived. The header gives no duration and Apple
// names none this port can read, so this is the port's own number and is written down as one: a
// cross-dissolve of a document appearing, which is why it is short enough not to be waited on and
// long enough to be seen.
static const NSTimeInterval kCharonDocumentRevealDuration = 0.25;

@synthesize loadingProgress = _loadingProgress;
@synthesize targetView = _targetView;


// The two methods UIViewControllerAnimatedTransitioning requires, which the review found missing and
// clang -Wprotocol names: how long the transition takes, and doing it.
//
// Neither is transcribed from Apple: what these do is a plain cross-dissolve of the view this
// transition was aimed at, over the duration the header's own loading progress implies, and where
// there is no target there is nothing to animate and the duration is zero, which is what the
// protocol's contract asks for when there is no transition to run.
- (NSTimeInterval)transitionDuration:(id<UIViewControllerContextTransitioning>)transitionContext
{
    // A document being brought across is a document appearing, and it is shown once its load has
    // finished; until then there is nothing on screen to move, so there is nothing to take time.
    if (!_loadingProgress || _loadingProgress.finished)
        return kCharonDocumentRevealDuration;
    return 0;
}

- (void)animateTransition:(id<UIViewControllerContextTransitioning>)transitionContext
{
    UIView *target = _targetView;
    if (!target) {
        // Nowhere to animate to. The transition is still completed, because a caller that waits for
        // it and never hears would wait for ever.
        if ([transitionContext respondsToSelector:@selector(completeTransition:)])
            [transitionContext completeTransition:NO];
        return;
    }
    NSTimeInterval duration = [self transitionDuration:transitionContext];
    // The cross-dissolve: the view arrives from nothing and is drawn at full opacity when it is done,
    // which is the whole of what showing a document looks like.
    target.alpha = 0;
    CharonAnimate(duration, ^{ target.alpha = 1; }, ^(BOOL finished) {
        target.alpha = 1;
        if ([transitionContext respondsToSelector:@selector(completeTransition:)])
            [transitionContext completeTransition:finished];
    });
}

@end
