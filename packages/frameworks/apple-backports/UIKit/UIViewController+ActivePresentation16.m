#import "RevenantCustomTransition.h"
#import <UIKit/UIKit.h>

@implementation UIViewController (RevenantActivePresentation16)

- (UIPresentationController *)activePresentationController
{
    UIPresentationController *current = revenant_presentation_controller_of(self);
    return current.presentedViewController == self ? current : nil;
}

@end
