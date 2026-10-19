#import "CharonCustomTransition.h"
#import <UIKit/UIKit.h>

// -[UIViewController activePresentationController], iOS 16.0.
//
// The header says the property gives the presentation controller that governs this view controller. When the initial
// presentation controller has adapted, the adaptive presentation controller is returned, and until presentation happens the property is nil.
//
// The port keeps one presentation controller per presented view controller: charon_set_presentation_controller
// stores it when a presentation starts and CharonCustomTransition.h reads it back through
// charon_presentation_controller_of, which is what -presentationController answers. So the question
// this row asks is whether that controller is one that has begun managing its view controller, and
// -presentedViewController says so: it is the controller's own public property, set by the port's
// UIPresentationController when the presentation is made and cleared when it ends.

@implementation UIViewController (CharonActivePresentation16)

- (UIPresentationController *)activePresentationController
{
    UIPresentationController *current = charon_presentation_controller_of(self);
    return current.presentedViewController == self ? current : nil;
}

@end