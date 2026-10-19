# The transition coordinator, iOS 7

From iOS 7 a view controller that is part of a transition - a push, a pop, a presentation or a dismissal - answers
`-transitionCoordinator`, an object that adopts `UIViewControllerTransitionCoordinator` (and the context protocol) and lets
the controller run an animation beside the transition and be told when it is over: `-animateAlongsideTransition:completion:`.
Outside a transition the property is nil, so `self.transitionCoordinator` can be sent messages that do nothing.
iOS 6 has none of it: the selector is not there, and an application that sends it fails with an unrecognized selector.

## What the port does

`-transitionCoordinator` answers a real coordinator from the moment an animated or a plain
`-presentViewController:animated:completion:`, `-dismissViewControllerAnimated:completion:`,
`-[UINavigationController pushViewController:animated:]`, `-popViewControllerAnimated:`, `-popToViewController:animated:` or
`-popToRootViewControllerAnimated:` is called until the release's own transition is over, for both controllers of it, so
`viewWillAppear:` and `viewWillDisappear:` of both see it; before and after, it is nil. The coordinator is one object for both
controllers. Its context answers `isAnimated` as it was asked, `isInteractive` and `isCancelled` NO (the release has no
interactive transition, and `-notifyWhenInteractionEndsUsingBlock:` never calls its block), the presentation style of the
presented controller, the two controllers through `-viewControllerForKey:` (the from controller is the one that goes, the to
controller the one that comes) and their views through `-viewForKey:`. `containerView` is nil: the release's transitions have
one of its own that an application cannot reach; `targetTransform` is the identity.

`-animateAlongsideTransition:completion:` runs its animation block at once inside a `UIView` animation of the duration of the
transition (0.35 seconds for a push or a pop and 0.4 for a presentation or a dismissal; measured, see below), so it
runs beside the release's own animation; without animation the block just runs. The completion runs when the release says the
transition is over: the completion handler of a presentation or a dismissal, the duration after the call for the navigation
controller (which has no such handler). A coordinator that is asked after its transition ended runs both blocks at once and
answers NO, as the system's answers for an interactive one that ended. `-animateAlongsideTransitionInView:animation:completion:`
does the same for a view.

## What is not the system's

There is no interaction (the swipe back of iOS 7 does not exist on this release) and no cancellation. A transition that
is called and does nothing (a pop of the root controller, a dismissal with nothing presented) leaves the coordinator attached until
three seconds have passed, and then it ends it. `setViewControllers:animated:` and the transitions the release runs by itself
(a tab change) do not make a coordinator. `UIViewController.transitioningDelegate` is asked for the animation controllers of a presentation and a dismissal, and
the navigation controller's delegate for those of a push and a pop; `TransitionAnimators.md` describes it.

Source: `tests/backports/device/transition.m` on iOS 6.1.3: it pushes, pops, presents and dismisses with and without animation,
reads the coordinator in the appearance callbacks of both controllers, and checks that the alongside animation and its
completion ran, and that the coordinator is nil before and after. The durations are the release's own, measured there.
