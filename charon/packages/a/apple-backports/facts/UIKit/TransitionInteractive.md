# Interactive transitions, iOS 7

A transitioning delegate answers `-interactionControllerForPresentation:` and `-interactionControllerForDismissal:`, and a navigation
controller's delegate `-navigationController:interactionControllerForAnimationController:`, with an object that adopts
`UIViewControllerInteractiveTransitioning`; when one is answered the transition is driven by the application (a pan gesture, usually):
`UIPercentDrivenInteractiveTransition` moves the animator's animation to a fraction with `-updateInteractiveTransition:` and then
`-finishInteractiveTransition` or `-cancelInteractiveTransition`. iOS 6 has none of it.

Source: the host's own UIKit under Mac Catalyst, recorded by `tests/backports/host/customtransition/run.sh` for an interactive dismissal and an
interactive pop, each finished and each cancelled after `-updateInteractiveTransition:0.4`, and held against the port by
`tests/backports/device/customtransition.m` on the iPad 2 (20 of its 36 records are the interactive ones);
`tests/backports/device/interactivepan.m`, in which a pan gesture driven by real touches (HID digitizer events) pulls a
presented controller down, lets go at 30% (cancelled) and at 70% (finished).

## What the port does

When the interaction controller is answered (and it does not answer NO to `wantsInteractiveStart`) the port does not do the release's
operation at the start, as it does for an animated transition that nobody drives: it leaves the controllers where they are, puts the
from view into the container, sends `viewWillDisappear:` to the from controller and `viewWillAppear:` to the to controller, and
gives the interaction controller the context (`isInteractive` YES). Only when the transition finishes does it do the release's
operation without animation, so the views a gesture is on are not taken out from under it. A cancelled transition changes
nothing of the release's state.

In an interactive dismissal the final frame of the presenting controller is the frame its view has while it is out of the window: the
release frames that view again only in its own dismissal, at the end, and on the iPad 2 (6.1.3) it gives a root view the application
frame again, whatever the view was moved to meanwhile. When that dismissal has run, the view stays at the frame it gave; before, the
port put it at the window's bounds, under the status bar.

`UIPercentDrivenInteractiveTransition` starts the animator itself (`-startInteractiveTransition:` is what calls `animateTransition:`),
pauses the container's layer (`speed` 0) and moves its `timeOffset`, which is what moves every animation of the animator by a fraction
of `duration` (the animator's `transitionDuration:`). `-finishInteractiveTransition` lets the layer run on from where it is at
`completionSpeed`, so the animator's own completion handler is called, and the transition is completed as the animator says.
`-cancelInteractiveTransition` runs the layer back to zero over the fraction times the duration divided by `completionSpeed`, copies what the
presentation layers show into the model layers, removes the animations (their completion handlers are called with `finished` NO) and
completes the transition with `transitionWasCancelled` YES. `percentComplete`, `duration`, `completionSpeed`, `completionCurve` and
`wantsInteractiveStart` are kept as the system keeps them; `timingCurve` is kept and not used (`inert`, see the registry).

On a cancel the controllers are told as the host tells them: `viewWillDisappear:` and `viewDidDisappear:` of the to controller, then `viewWillAppear:`
and `viewDidAppear:` of the from controller, then the completion handler of a presentation or a dismissal and `-animationEnded:` with NO.
The transition coordinator (see `TransitionCoordinator.md`) is interactive while the interaction runs, is told through
`-notifyWhenInteractionEndsUsingBlock:` and `-notifyWhenInteractionChangesUsingBlock:` when it ends, and answers `isCancelled` for a cancelled one.

## Where it differs from the system

- The interaction controller is kept by the transition until it ends, as the system keeps it, so the application need not.
- The finish and the cancel run in linear time; the system's `completionCurve` shapes them, which the port does not apply.
- Cancelling shows the animator's animation run backwards from a paused layer; an animator that animates something other than the layer properties of views (a
  label's text, for one) is not put back by it.
- A transition that has been finished is completed a moment after the animator completes, so `animationEnded:` comes after it.
