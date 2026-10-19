#import "CharonCustomTransition.h"
#import <UIKit/UIKit.h>

@implementation UIViewController (CharonActivePresentation16)

- (UIPresentationController *)activePresentationController
{
    UIPresentationController *current = charon_presentation_controller_of(self);
    return current.presentedViewController == self ? current : nil;
}

@end
