# Custom animation of a transition, iOS 7

From iOS 7 a view controller can hand UIKit an animation controller for its transition: an object that adopts
`UIViewControllerAnimatedTransitioning` and is given a `UIViewControllerContextTransitioning` to animate in. A presented
controller's `transitioningDelegate` answers `-animationControllerForPresentedController:presentingController:sourceController:` and
`-animationControllerForDismissedController:`; a navigation controller's delegate answers
`-navigationController:animationControllerForOperation:fromViewController:toViewController:` for a push and a pop. iOS 6 has
no such thing: it only animates by its own rules and never asks.

Source: what the host's UIKit does with the same animators, recorded under Mac Catalyst by `tests/backports/host/customtransition/run.sh` for the
cases of `tests/backports/device/customtransition-cases.m` and held against the port on the iPad 2 by
`tests/backports/device/customtransition.m` (16 records); and `tests/backports/device/slidetransition.m`, which slides views with an
animator and reads the screen halfway and at the end.

## What the port does

When the controller asks for an animated presentation (full screen or a custom style 4 to 6), dismissal, push or pop, and its
delegate answers an animation controller, the port does the operation without animation and animates it itself:

1. It makes a container view, on the window for a presentation or a dismissal and inside the navigation transition view for a
   push or a pop, and puts the view of the from controller in it, as the release's own view of that controller left where it was;
   the view of the to controller is not in the container (the animator adds it, as the system's animators do).
2. It gives the animator the context: the container, the two controllers and their views, `isAnimated` YES, `isInteractive`
   NO, `transitionWasCancelled` NO, the presentation style (0 for a full screen presentation, -1 for a push or a pop), the
   identity as `targetTransform`, and the frames the system gives: the from view fills the container at the start; when it
   goes away its final frame is empty (a dismissal keeps its own frame); the to view starts empty and ends where the release
   puts it. `transitionDuration:` is asked, and the transition coordinator (see `TransitionCoordinator.md`) gets the container and
   that duration.
3. When the animator says `completeTransition:` the to view goes where the release put it (in the window, or in its wrapper in
   the navigation controller), the from view leaves, the container goes, and only then do `viewDidAppear:` and `viewDidDisappear:` run,
   in the order of the system (`didAppear` of the to controller first for a presentation or a dismissal, `didDisappear` of the from
   controller first for a push or a pop), then the completion handler, then `-animationEnded:`. `viewWillAppear:` and
   `viewWillDisappear:` run before `animateTransition:`, as they do on the system.

A delegate that answers nil, an operation without animation, and a presentation as a page or form sheet are left to the release.

## Where it differs from the system

- The release's own appearance callbacks would run before the animation; the port holds `viewDidAppear:` and `viewDidDisappear:` back by giving the
  controllers, for the time of the transition, a hidden subclass, and drops the appearance callbacks that moving the views
  into the container makes. A controller that is being key-value observed is not held back: its callbacks come early.
- The frames are the release's: on iOS 6 a presented view starts below the status bar and a pushed view below the navigation bar, so
  the final frame of the to view has that inset where iOS 7 has the whole container. The test counts a frame that reaches the bottom
  and has only a bar's height missing at the top as the full container. The navigation bar itself does not animate with
  the animator (the release changes it at once).
- A presentation with a custom style (4 to 6) is shown by the release as a full screen one; with `UIModalPresentationCustom`, `OverFullScreen` and
  `OverCurrentContext` the presenting view is put back under the presented one when the animation ends.
- Interaction is described in `TransitionInteractive.md`; there is no `UIPresentationController` yet.
