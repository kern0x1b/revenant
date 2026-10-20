# Edge pans, interactive transitions and the names that come with them, iOS 7 to 9

Source: the host's own UIKit for every value, default and answer, recorded by `host/uikitnames` from `device/uikitnames-cases.m` and
read again on the iPhone 4S by `device/uikitnames.m`; the shared caches of iOS 6.0 to 10 for what the release exports.

## UIScreenEdgePanGestureRecognizer

A pan gesture recognizer that begins only from an edge of the screen: `edges` (none by default) names which. The port is a
`UIPanGestureRecognizer` that fails at the first touch that does not start within 20 points of one of the edges, measured in
the view of the root view controller, so that it follows the interface's rotation. It is not the system's recognizer the
navigation controller takes for the back swipe, and it does not give way to a scroll view's pan the way that one does.

## UIPercentDrivenInteractiveTransition

The object a custom transition of iOS 7 drives with the fraction of a gesture: it keeps a percent between 0 and 1, the speed and the
curve of its completion, and passes the update, the cancel and the finish to the transition context it is started with. The
release starts no transition of iOS 7 - `transitioningDelegate`, animators and contexts are not in it - so nothing hands it a
context: an application that presents with an animator gets the release's own animation, and the object only keeps its state
(`inert`).

## The names

`UITransitionContext…Key`, the screenshot and background-refresh notifications, the keyboard's local flag and the open-URL option keys are the strings of the system; nothing is ever posted under any of them,
and The background fetch intervals are 0 and the largest double.
The activity types are the system's strings. `UIAccessibilityConvertFrameToScreenCoordinates` converts through the view's window;
a view with no window answers the frame it was given, as the system's does. The callout and title text styles are the strings
the release's font code already answers to. `UIAccessibilityTraitTabBar` is 0x8000.
