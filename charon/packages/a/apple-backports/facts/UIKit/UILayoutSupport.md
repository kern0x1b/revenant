# UIViewController.topLayoutGuide and bottomLayoutGuide, iOS 7

Introduced in iOS 7.0: the layout guides of a view controller that mark the part of its view the status bar, a navigation bar and a tab bar or toolbar cover, as
objects of `UILayoutSupport` (a `length` and, from iOS 9, the three anchors) that are items of constraints. iOS 11 deprecated them for the safe area layout guide.

Source: the host's own UIKit under Mac Catalyst (`host/layoutsupport/run.sh`): a controller in a window answers both guides, the same object each time, distinct, conforming to
`UILayoutSupport`, of length zero, with the three anchors, and a view constrained to the bottom of the top guide and the top of the bottom guide fills the view.
`device/layoutsupport.m` repeats them and then puts a controller with a full screen layout under a translucent navigation bar and over a translucent toolbar: the top guide
is the status bar and the bar (64 on the 4S and the iPad 2), the bottom guide the toolbar (44), and a view between them fits between the bars.

## How the port does it

Each guide is a `UILayoutGuide` of a subclass that answers `length`, in the controller's view: full width, its top at the top of the view and its bottom at the top of the safe area
layout guide (the top guide), and its bottom at the bottom of the view with its top at the bottom of the safe area layout guide (the bottom guide). The guide is therefore as
tall as the top or bottom safe area inset, wherever the bars are; `length` reads the inset, so it is right when asked before a layout as well as after. The guides are made when they are first
asked for, which loads the controller's view.

## The safe area under a navigation bar

The safe area the guides are built on took a bar into the top inset only when the bar touched the top edge of the view, which a navigation bar below the status bar does not: the
status bar counts, and the bar under it did not, so a controller under a translucent navigation bar had a top inset of 20 where iOS 11 has 64. A bar now counts when it begins
where the status bar ends. That changes `safeAreaInsets` and `safeAreaLayoutGuide` of such a controller from 20 to 64 (a scroll view's adjusted inset follows).
