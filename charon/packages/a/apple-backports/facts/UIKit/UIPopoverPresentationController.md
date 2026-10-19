# UIPopoverPresentationController, iOS 8

Introduced in iOS 8.0: the presentation controller of a view controller presented with `UIModalPresentationPopover`, reached through
`-[UIViewController popoverPresentationController]`, where an application says what the popover comes from (`sourceView` and
`sourceRect`, or `barButtonItem`), which way its arrow may point, which views keep working while it is up, and who to tell
(`UIPopoverPresentationControllerDelegate`).

Source: the host's own UIKit under Mac Catalyst (`host/popover/run.sh`): 28 answers of what a controller with the popover style has -
no popover controller before the style is set, the same one every time, one for a navigation controller, none for the full screen and
form sheet styles, the defaults of every property (the arrow directions `Any`, the source rectangle `CGRectNull`, the arrow direction
`Unknown`, no margins, no delegate, no source view) and that what is set is kept. `device/popover.m` repeats them and then presents
on an iPad 2 and an iPhone 4S with real touches (IOHID).

## How the port carries it

On an iPad the popover is the release's own `UIPopoverController`, which the port makes when the controller is presented: over the source
rectangle in the source view (the bounds when the rectangle is null) or from the bar button item, with the permitted directions and, once it
is up, the passthrough views; its content size is the controller's `preferredContentSize`, and its layout margins and background
view class are the presentation controller's. The application sees the presentation of iOS 8: the presenting controller's
`presentedViewController` is the popover's controller and its `presentingViewController` is the presenter, `presentationController` is the
popover presentation controller, `dismissViewControllerAnimated:completion:` from either takes the popover away and calls the completion,
a touch outside asks the delegate `popoverPresentationControllerShouldDismissPopover:` and a yes tells it
`popoverPresentationControllerDidDismissPopover:` - which a dismissal by the application does not, as on the release. The delegate is asked
`prepareForPopoverPresentation:` first, and `popoverPresentationController:willRepositionPopoverToRect:inView:` where the release repositions.
A popover with neither a source view nor a bar button item raises `NSGenericException`, in the words of the release.

On an iPhone a popover is presented as iOS 8 adapts it in a narrow width, full screen: the delegate is asked
`adaptivePresentationStyleForPresentationController:` (full screen, or over the full screen when it says so) and
`presentationController:viewControllerForAdaptivePresentationStyle:`, whose answer - a navigation controller around the content, most often -
is what is presented. A delegate that asks to keep a popover on a phone is not obeyed: iOS 6 has none.

## What differs

The colour of the popover (`backgroundColor`) and `canOverlapSourceViewRect` are kept and do nothing: the popover of the release draws its
own arrow and body, and always keeps clear of the source. The popover has the release's look, not iOS 8's. The size of a popover whose
controller sets no `preferredContentSize` is the release's default for a controller in a popover, not iOS 8's.
The presentation controller is not asked to lay out or animate the presentation (`frameOfPresentedViewInContainerView`,
`presentationTransitionWillBegin` and the like are not sent), and a transition coordinator does not run for it.

## The delegate, through the superclass

`UIPopoverPresentationController` redeclares `delegate` and has no accessor of its own: the getter and setter are those of
`UIPresentationController`, which holds the delegate weakly. The `@dynamic` line is redundant and resolves to the superclass at run
time. Measured by `tests/backports/host/presentation-delegate` (5 checks: the accessors answer for the subclass, a set reads back, and
nil clears it; the port's and the host's print the same values). The sheet controller has the same superclass accessors; it is not
built by that test, since its file needs the sheet's shadow and layout code.
