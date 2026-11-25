# The background color of a `UIPopoverController` on iOS 6

`-[UIPopoverController backgroundColor]` is iOS 7. An application that asks first, `respondsToSelector:@selector(setBackgroundColor:)`,
got YES from the stub the skeleton had registered and aborted on the call: `not implemented: -[UIPopoverController
setBackgroundColor:]`.

## What the backports do

`UIPopoverController+BackgroundColor7.m` keeps the color and, for it, sets `popoverBackgroundViewClass` (iOS 5) to a background view
of its own: a rounded body of radius 7 and an arrow 37 wide and 13 high, filled with the color
(`RevenantPopoverArrow.c` computes the shape). The class is made once per color, because UIKit takes a class and gives the view no
way back to its popover. `nil` puts back the system background. An application that has set a `popoverBackgroundViewClass` of its
own keeps it; the color is then only stored.

## What differs from iOS 7

- The color is drawn when a popover is next presented. A popover already on screen keeps the background it was presented with.
- `popoverBackgroundViewClass` reads back the class the backports made, not `nil`.
- The radius and the arrow's size are chosen, not measured on a later system.
- `UIPopoverPresentationController.backgroundColor` (iOS 8) is stored and still not drawn.

## Tests

`frameworks/Backports/tests/UIKit/popover_arrow_test.m` (host, target `UIKitBackports_popover_arrow_test`) checks the shape for each
arrow direction; the negative run fails. `frameworks/Backports/tests/runtime/cases/popover_controller_background_color.m` runs on
the iOS 6.1.3 userland of an iPhone in the emulator, where a popover cannot be initialised: it sends the members to an allocated
`UIPopoverController`, so UIKit's own setter takes the class, and lays out the background view itself. Before this change the run
aborted on the stub. How the popover looks on an iPad has not been seen.
