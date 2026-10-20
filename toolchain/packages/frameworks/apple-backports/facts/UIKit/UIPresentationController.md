# UIPresentationController, iOS 8.0

Introduced in iOS 8.0: the object that owns a view controller's presentation - the container
view, the frame of the presented view, the adaptive style - and the class an application
subclasses for a custom presentation (`UIModalPresentationCustom` with a transitioning
delegate that answers a subclass).

Source: the host's own UIKit under Mac Catalyst, in an application with a window, asked for
each answer below and held against the backport by `tests/backports/host/presentation/run.sh`,
sixteen records that the app `tests/backports/device/presentation.m` compares on a device
running 6.1.3.

## The class

- The superclass is NSObject and the class adopts `UIContentContainer`.
- `-initWithPresentedViewController:presentingViewController:` keeps both; a nil presenting
  controller is accepted.
- The presentation style is the presented controller's `modalPresentationStyle`, whatever it
  is - 0 to 5, 7 and -1 all come back as they were set.
- `shouldPresentInFullscreen` is YES and `shouldRemovePresentersView` NO for every style, and
  both adaptive styles are `UIModalPresentationNone` (-1), for every style and every trait
  collection. A subclass overrides them.
- `containerView` is nil until a presentation has begun; `presentedView` is the presented
  controller's view; the frame of the presented view is empty without a container.
- `-sizeForChildContentContainer:withParentContainerSize:` answers the parent size.
- The delegate and `overrideTraitCollection` are plain properties, both nil at first. The delegate adopts
  `UIAdaptivePresentationControllerDelegate`; its members are the application's to implement. No presentation adapts in the
  port, so the adaptive ones are never sent; the sheet sends the four about a dismissal by drag or tap
  (`UISheetPresentationController.md`).
- The six transition hooks do nothing, and a subclass that overrides them and calls `super`
  is called in the order it is asked.

## What the port does

The release presents a view controller itself - a full screen, a page sheet or a form sheet - and has no presentation controller.
For a presentation in the style `UIModalPresentationCustom` (4), `OverFullScreen` (5) or `OverCurrentContext` (6), the port asks the
presented controller's `transitioningDelegate` for `-presentationControllerForPresentedViewController:presentingViewController:sourceViewController:`,
and when it answers a `UIPresentationController` the presentation is that object's, as on iOS 8. A custom style whose
delegate answers none, or that has no delegate, gets a plain `UIPresentationController`, as UIKit makes one
(`-_presentViewController:withAnimationController:completion:` 0x1891a8fe0 in UIKitCore of 16.0, after
`-_customPresentationControllerForPresentedController:` 0x1890dafa0 answers nil; the host's is that class, recorded as the
"bare" case). Otherwise the release presents as it always has (a style that is not its own is its full screen one). What is different from the system's is written below;
everything else was recorded from the host by `tests/backports/host/custompresentation/run.sh` (five variants: a
presentation that keeps the presenter's view and animates, one that removes it, one without an animator, one that says
`shouldPresentInFullscreen` and one with no transitioning delegate) and is held on the iPad 2 by `tests/backports/device/custompresentation.m` (53 checks).

- `containerView` is a view on the window that the port makes, the same for the presentation and the dismissal, and is nil before
  the presentation begins and after the dismissal ends. It stays while the controller is presented, and it holds what the
  presentation controller adds to it (a dimming view, for one) and the presented view. Its `layoutSubviews` sends
  `containerViewWillLayoutSubviews` and `containerViewDidLayoutSubviews`.
- The order of a presentation is: the delegate is asked for the presentation controller, `presentationTransitionWillBegin`,
  `viewWillDisappear:` of the presenting controller (only when `shouldRemovePresentersView` is YES) and `viewWillAppear:` of the
  presented one, `animateTransition:` of the animator (when the delegate answers one), `completeTransition:`,
  `presentationTransitionDidEnd:`, `viewDidAppear:` of the presented controller and `viewDidDisappear:` of the presenting one, the
  completion handler and `animationEnded:`. A dismissal is `dismissalTransitionWillBegin`, `viewWillDisappear:` of the presented
  controller (and `viewWillAppear:` of the presenting one when it was removed), the animator, `completeTransition:`,
  `dismissalTransitionDidEnd:`, `viewDidAppear:` (when removed) and `viewDidDisappear:`, the completion handler and
  `animationEnded:`. With no animator there is no animation at all and no `animationEnded:`, as on the host.
- The context of the animator: the presented view goes in `viewForKey:` of the to controller and it is not in the container yet;
  the presenting view is the from view only when `shouldRemovePresentersView` is YES (it is in the container then), else `nil`; `presentationStyle`
  is the style of the presented controller; the final frame of the presented controller is
  `frameOfPresentedViewInContainerView` (the container's bounds by default, which is also what the class answers once it has a container).
  `shouldPresentInFullscreen` is asked and changes nothing the port shows.
- While the controller is presented `presentedViewController.presentationController` is that object and
  `presentationStyle` answers the style; the presented view is at `frameOfPresentedViewInContainerView` in the container, and
  the presenting view stays in the window under it unless it is to be removed.
- The presenting view keeps the frame the release gave it, which on iOS 6 is the application frame for a root view (under the status
  bar, 0 20 320 460 on the iPad 2's phone-sized window), not the window's bounds: it goes into the container at that place on the
  screen when it is to be removed, and after a dismissal it is where the release's own dismissal put it. That dismissal frames the
  presenting view for its controller again (it sets its bounds and origin in
  `-[UIWindowController transition:fromViewController:toViewController:target:didEndSelector:]`, and does so even when the view was
  moved while it was out of the window) and puts it where the presented view was, in the container; the port moves it from there to
  the window at the same place before the container goes. Measured on the iPad 2 (6.1.3) with the root view's frame changes and their
  call stacks; before this the port put it at the window's bounds, under the status bar, after every dismissal and during a
  presentation that removes it.

Not carried: a presentation controller for any other style (the release's own presentation is kept, and
`presentationController` answers nil for it), adaptive presentation (`adaptivePresentationStyle` is kept and never acts), and the trait
and content-size messages, which nothing sends. A `presentedView` that is not the presented controller's view is used as the view in the
container, but its content is the subclass's to build.
