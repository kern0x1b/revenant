# The size and look of `UISwitch` on iOS 6

A `UISwitch` on iOS 6 is 79 by 27 points and draws the round iOS 6 switch with "ON" and "OFF" in it. From iOS 7 to iOS 18 it is
51 by 31 points and flat. An application written for the later switch lays out around 51 points and runs into the wider one. The
backports draw the later switch on iOS 6, at its size.

## What was seen

Telegram 13.0.0 on an iPhone 4S, iOS 6.1.3, the Debug menu, measured with tprobe's `tprobe.ui` (2026-11-12, by the Telegram session):
all 16 switches on the screen (`Display.SwitchNodeView`, a subclass of `UISwitch`) have bounds `{0, 0, 79, 27}`, and `sizeThatFits:`
of `{1000, 1000}` answers `{79, 27}`. `ItemListSwitchItem` places the switch from the size it reports (`sizeToFit`, then
`x = width - rightInset - switchWidth - 15`), but limits the title's width to `width - leftInset - rightInset - 64`, room for a 51-point
switch and its margin. In the 288-point card the switch starts at x 194 and the titles may run to x 224, so "Recording: respect syst…",
"Use Modern Video Mes…", "Crash on memory press…" and "Remove Sensitive Data" end under the switch, 30 points deep (79 - 51 + 2).

## The switch the backports draw

The model is the switch of iOS 13 to 18, measured on this Mac with a Mac Catalyst probe linked with `-platform_version mac-catalyst 17.0
17.0`: UIKit gives a program built against an SDK older than 26 the switch from before iOS 26, which is the one Telegram 13 lays out
for (its `SwitchNode` answers 51 by 31 below iOS 26, and 63 by 28 from iOS 26). The probe read the switch's layers, its animations
and the private getters of `UISwitchModernVisualElement`, and rendered every state to a bitmap. What it measured:

- Size: `initWithFrame:` with any size, `setFrame:` and `sizeThatFits:` of any size give 51 by 31, keeping the origin. `intrinsicContentSize`
  is 49 by 31 and `alignmentRectInsets` is `{0, 0, 0, 2}` (2 points on the right).
- Track: a capsule of radius 15.5. Off it is `rgba(120, 120, 128, 0.16)` in the light appearance (`#E9E9EA` over white); on it is
  `onTintColor`, by default the light system green `rgb(52, 199, 89)`. `tintColor` is kept but does not colour the track: a blue
  `tintColor` left the off track grey. Catalyst's own default for `onTintColor` is the Mac accent colour, so the green is the
  phone's value of `systemGreenColor`, resolved by the same probe with a phone trait collection.
- Knob: a 27-point circle, 2 points inside the track, in a 43 by 43 image that carries its shadow: black at 12%, blurred 5.75 points
  and moved 2.5 points down (the image's alpha, fitted to the system's knob image within 1 of 255 at 19 sampled pixels). On the screen
  no shadow falls outside the track's capsule: the rendered switch is white there. Pressed, the knob is 7 points wider (34), and its
  centre moves 3.5 points to the middle. `thumbTintColor` fills it.
- Change of value: the knob springs to its new place (mass 1, stiffness 438.649, damping 31.416, 0.488 s); the track's colour comes in as
  a wipe, a 510-point strip of the on colour, opaque for the first 51 points and fading linearly to clear 51 points before its end, that
  springs from x -459 to 0 (on: stiffness 85.377, damping 18.48, 1.0 s; off: stiffness 246.74, damping 31.416, 0.588 s) inside the
  track. When it stops, the track takes the plain colour and the strip is hidden.
- Disabled: everything is drawn at half opacity, as one group.
- Touch: a touch presses the knob. Without a drag, the end of the touch toggles the switch. A drag flips what the switch shows when the
  finger has moved half the switch's width (25.5 points, measured: 25.0 does not flip, 25.5 does) towards the other side, and counts again
  from there; when the touch ends, the switch keeps what it shows. `UIControlEventValueChanged` is sent when the value changed by touch,
  never by `setOn:animated:`.
- `onImage` and `offImage` are kept and not drawn.

The probe called the pan handler (`_handlePanWithGestureLocationInBounds:horizontalTranslation:gestureState:resetPanTranslationBlock:`)
with chosen translations and locations: the flip depends on the translation only. The 10-point movement before a touch counts as a
drag is the pan gesture's own slop and was not measured. iOS 7 to 12 drew another switch of the same size: a white track with a grey
border of `tintColor`, which `onTintColor` filled from the knob outwards; that one is not drawn.

## What the backports do

`UISwitch+Appearance7.m` defines `RevenantSwitch`, a `UIControl` subclass with no instance variables, and on a system older than iOS 7
its `+load` puts every method of it on `UISwitch` (`class_replaceMethod`): `init`, `initWithFrame:`, `initWithCoder:`, `encodeWithCoder:`,
`setFrame:`, `sizeThatFits:`, `intrinsicContentSize`, `_intrinsicSizeWithinSize:`, `alignmentRectInsets`, `isOn`, `setOn:`,
`setOn:animated:`, the colour and image accessors, `setEnabled:`, `setAlpha:` and the four `UIControl` tracking methods. A call to `super`
in them goes to `UIControl`, so the iOS 6 switch's own view (`_UISwitchInternalView`) and its pan and tap recognisers are never made, and
the methods of UISwitch that are not replaced find no internal view and do nothing. The state is one associated object.

The switch draws with layers, never with `drawRect:` (Telegram's `SwitchNodeView` gives its layer a class whose `setNeedsDisplay` does
nothing): a grey capsule, a capsule for the on colour that holds the strip, and the knob, whose image stretches at its middle column when
pressed. The knob has two images, for the off and the on place, each with its shadow cut to the track's capsule at that place, so the
track needs no mask for it. The white knob images and the green strip are made once per process; a switch with its own `thumbTintColor`
or `onTintColor` makes its own. The springs are `CASpringAnimation`s of the backports, which iOS 6 runs as keyframes. A static switch has no masked layer and no
shadow pass: the strip and the track's mask exist only while the colour moves, and the shadow is in the image.

The archive keys are the iOS 6 ones (`UISwitchOn`, `UISwitchOnTintColor`, `UISwitchTintColor`, `UISwitchThumbTintColor`, `UISwitchOnImage`,
`UISwitchOffImage`, read from the strings of the 6.1.3 UIKit), so a switch from a nib or storyboard keeps its value and colours.
`RevenantSwitchGeometry.c` holds the numbers above and the touch decision, and draws the two images.

## Scope: who is affected

The replacement lives in `libUIKitBackports.dylib` and runs in every process that loads it on a system older than iOS 7: every application
built with the Revenant toolchain that links the backports, on any phone that has the package. Stock iOS 6 applications (Settings,
SpringBoard, Mail, Safari, Phone, Messages) do not load the library and keep the iOS 6 switch. On iOS 7 and later nothing is replaced.

What an application built for iOS 6 sees: a switch 28 points narrower and 4 points taller than it laid out for, in the later look. One that
drew custom `onImage` and `offImage` into the switch (iOS 6 drew them) no longer sees them. One that reached into the switch's subviews
finds none, and one that set `tintColor` for the off track sees the grey track. Accessibility keeps the iOS 6 answers of `UISwitch`, which
read `isOn`: it was not run with VoiceOver.

## Where it is not claimed

- The model is UIKit's switch on Mac Catalyst built for SDK 17, not a phone with iOS 13 to 18: no such phone was at hand. Its sizes,
  springs, the strip and the knob image are the same code as the phone's; its colours were resolved for the phone idiom and the light
  appearance.
- The 10-point slop before a drag, and a touch that ends outside the switch without a drag (it leaves the value), are decisions, not
  measurements.
- While the knob is pressed or moving, its shadow is cut to the track at its resting place, not where it is.
- The look on the phone was not compared pixel by pixel with a later iOS. On the Mac, the same source built for Catalyst, rendered at 2x
  beside UIKit's switch in the light appearance, matched within 6 of 255 in every channel off and disabled off; on, on in red and yellow,
  and disabled on, it differs only at about 30 pixels of the knob's edge on its diagonals (up to 28, and 34 on red), where UIKit's knob
  is anti-aliased with less coverage.

## Tests

`frameworks/Backports/tests/UIKit/switch_geometry_test.m` (host, target `UIKitBackports_switch_geometry_test`) checks
`RevenantSwitchGeometry.c` against the probe's numbers: the size, the knob's bounds and places off, on and pressed, the strip's frames and
its ramp, the strip image at 2x, the knob image's alpha at the system's values (edges, shadow beside, above and under), the cut of its
shadow to the track off and on, and the touch decision: a tap toggles, a small move is a tap, a drag flips at half the width and counts again
from the flip, a drag ends where it shows. 68 checks, and the negative run fails.
