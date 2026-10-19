# showViewController:sender:, showDetailViewController:sender: and targetViewControllerForAction:sender:, iOS 8

Introduced in iOS 8.0: a view controller shows another one without knowing how its container presents it. `-showViewController:sender:` pushes on a navigation controller and presents modally when nothing in the hierarchy
handles it; `-showDetailViewController:sender:` is the same for the detail of a split view controller, and `-targetViewControllerForAction:sender:` finds the controller that handles an action.

Source: the host's own UIKit under Mac Catalyst (`host/show/run.sh`) over `device/show-cases.m`, and the same cases on iOS 6 in `device/show.m`. From the results: a controller in a navigation controller, or a child of
one, that shows pushes on it; with no container it presents; a controller in a tab bar controller presents (the tab bar controller does not handle it); a parent that overrides `-showViewController:sender:` is sent it by a child;
`-showDetailViewController:sender:` with no split view controller presents. The target of an action is the nearest controller, the receiver and then its parents, that responds to the action *and, when `UIViewController`
implements it, overrides it*: a plain controller has none for `showViewController:sender:` and a child in a navigation controller has the navigation controller; an action nobody responds to has nil. The responder version,
`-targetForAction:withSender:`, is the first responder in the chain that answers `-canPerformAction:withSender:`, which any controller does for the show methods - a child is its own target.

## How the port does it

`-showViewController:sender:` and `-showDetailViewController:sender:` ask for the target of their own action and forward to it when it is not the receiver, and present the controller otherwise; `UINavigationController` overrides the first to
push with animation. Split view controllers are not carried by this (their display modes are not in the release), so a show reaches them as a modal presentation.
