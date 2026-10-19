# UIEditMenuInteraction, iOS 16

`UIEditMenuInteraction` (iOS 16) is the interaction that shows an edit menu over a view for a configuration an application gives it, and asks
its delegate for the menu, the target rectangle and the animation of the dismissal. The port carries it as an **inert** interaction, the same
policy the other interactions with nothing to react to follow (`facts/UIKit/UIInertInteractions.md`): the class is made, added to a view and
removed like any other interaction, keeps its delegate weakly, and never calls back. Presenting, dismissing and updating a menu do nothing, and
say so once in the log.

Source: the host's own UIKit under Mac Catalyst (macOS 27), measured by `tests/backports/host/edit-menu`: a bundled application with the iPad
idiom (`UIDeviceFamily` 2), a window made key, and a view in it. 14 checks compared line for line with the port's classes, and three planted
controls fail (the location answered as zero, the delegate held strongly, the view not kept). The configuration the interaction takes is
`UIEditMenuConfiguration`, which has its own facts (`facts/UIKit/UIEditMenuConfiguration.md`).

## What the host does, measured

- `initWithDelegate:` keeps the delegate, and the delegate is weak: after the application lets go of it, `delegate` reads nil.
- Before it is added the interaction's `view` is nil; `addInteraction:` makes the view the one it was added to, and `removeInteraction:` makes it nil.
- The host's own UIKit adds **three private interactions** to the view when one of ours is added (`_UIEditMenuBridgedContextMenuInteraction`,
  `_UIClickPresentationInteraction` and `_UIClickPresentationFeedbackGenerator`), and removing ours leaves one of them behind. These are the host's
  machinery for presenting the menu. The counts are recorded in `host-only` evidence beside the checks and are not compared: the port has no such
  machinery, and the view holds only the interaction the application added.
- `locationInView:` answers `{CGFLOAT_MAX, CGFLOAT_MAX}` on both axes while no menu is shown, with the view given or nil.
- `presentEditMenuWithConfiguration:` does not reach the delegate here. In the measured application the scene reads foreground active (the
  `UISceneActivationStateForegroundActive` value, 0), its window is key and the view is in it, and the presentation is made one second after
  launch, into a settled window. The delegate's `menuForConfiguration:`, `targetRectForConfiguration:` and `willDismissMenuForConfiguration:`
  are never called, and no menu's location is reported. The host's answer in this environment is therefore that no menu is presented
  programmatically; what a device shows is not measured.

## What the port does

- Keeps the delegate weakly, reads it back, and answers `view` through the attachment `UIView+Interactions.m` makes.
- `locationInView:` answers `CGFLOAT_MAX` on both axes, the host's answer while no menu is shown.
- `presentEditMenuWithConfiguration:`, `dismissMenu`, `reloadVisibleMenu` and `updateVisibleMenuPositionAnimated:` do nothing, and the
  presentation says once in the log that it shows no menu.
- The delegate's three callbacks are never made. The animator protocol is declared by the SDK and has no object here to be handed to.

## Not built

- The menu itself, its position, and the delegate's callbacks, which the host does not make in the measured environment. A device with a
  real presentation would be the place to measure them; until then the port does not claim them.
- The host's three private interactions, which are the host's own machinery.
