# UIColorWell and UIColorPickerViewController, iOS 14.0

Introduced in iOS 14.0: a control that shows a color and lets a person choose another, and the picker view controller it presents.
iOS 6 has neither. The port carries both; the picker is **a small grid of colors**, not the system's picker.

Source: the host's own UIKit under Mac Catalyst (macOS 27.0), held against the backport by `tests/backports/host/uikit2` (the `colors`
group), and the header of SDK 16.4. A Mac Catalyst tool never completes a presentation, so presenting and dismissing are held to the device test.

## UIColorWell, as UIKit does

- `supportsAlpha` starts YES, `title` and `selectedColor` nil; the well is enabled and not hidden, a zero-frame view made with `-init`. Its
  `selectedColor` is kept as set, nil included; the system stores the title without copying it, and so does the port.
- Setting a value never sends `UIControlEventValueChanged`; only a choice in the picker does.
- The `supportsEyedropper` and `maximumLinearExposure` of iOS 26 are not answered.

## What the port does

- The well draws a round ring and a swatch of the selected color (white when there is none) with two layers, and is 44 points square for
  `-sizeThatFits:` and `intrinsicContentSize`. The host, a Mac, answers 48 by 24.
- A touch that ends inside the well presents a `UIColorPickerViewController` over the top of the well's view controller, with the well's
  color, alpha setting and title; the well is its delegate, sets `selectedColor` on every choice and sends `UIControlEventValueChanged`. A well outside a
  view controller presents nothing and says so once in the log.

## UIColorPickerViewController, as UIKit does

- `-init` makes a picker with `selectedColor` black, `supportsAlpha` YES, no delegate and `modalPresentationStyle` form sheet. The delegate is weak.
  `selectedColor` is null-resettable in effect: nil is ignored and the color before stays. `-initWithNibName:bundle:` and `-initWithCoder:` make the
  same picker (the host's leave `supportsAlpha` NO, and the port does not follow).
- The delegate's `-colorPickerViewControllerDidFinish:` is sent when Done is tapped, after the picker has gone; a picker that is not presented sends it at once.
  `-colorPickerViewController:didSelectColor:continuously:` (iOS 15) is sent for every choice, continuously while a finger moves; a delegate that only has
  `-colorPickerViewControllerDidSelectColor:` (iOS 14) hears it once, when the finger lifts.
  Registry correction, 2026-09-23: `ios15-16.json` listed the iOS 15 message `absent`, "never sent", while
  `charon_pickColor:continuously:` in `UIKit/UIColorPickerViewController.m` sends it; the row is now `implemented`.
- The `supportsEyedropper` and `maximumLinearExposure` of iOS 26 are not answered.

## What the picker is

- A navigation bar with the title (the controller's, or "Colors") and Done, a grid of 12 columns by 10 rows - greys on top, then tints, the pure hues in the
  middle row and shades - a swatch of the selected color and, when `supportsAlpha` is YES, an alpha slider. Touching the grid chooses a swatch, keeping the alpha;
  moving the slider changes the alpha. No sliders, spectrum, eyedropper, saved colors or hex entry.
