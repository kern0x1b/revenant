# The members of UIImage that iOS 13 added

Introduced in iOS 13: `imageWithTintColor:` and its rendering mode form, the baseline members, `configuration` and
`imageWithConfiguration:`, `+imageNamed:inBundle:withConfiguration:`, and five system images.

Source: the host's own UIKit under Mac Catalyst (macOS 27.0), run in a process of its own, and held against the backport by the
`images13` group of `tests/backports/host/uikit2`, which draws the results and compares their bytes; `uirest.m` on a device.

## Tinting

`-imageWithTintColor:` answers a copy of the same size and scale that draws in the colour wherever the image is opaque, at the
opacity the colour and the image give together: the port fills the size with the colour and draws the image over it with the
destination-in blend mode, and the pixels drawn are byte for byte the host's for opaque, half transparent, clear and white colours.
The rendering mode is the automatic one, not the original; `-imageWithTintColor:renderingMode:` gives the mode asked for. A nil colour
answers a copy. The capture insets and the resizing mode, the alignment insets, the baseline and the configuration are kept; an image
with no bitmap answers a copy.

## Baseline

`hasBaseline` is NO and `baselineOffsetFromBottom` 0 until `-imageWithBaselineOffsetFromBottom:` makes a copy that has one;
`-imageWithoutBaseline` makes a copy that has none, and neither changes the image it was sent to. A tint keeps the baseline.

## Configuration

`configuration` is the configuration the image was given, or one that holds the image's scale as a trait, printed
`traits=(DisplayScale = 2)`; the host's also holds the traits of the environment, which the port has no environment to give.
`-imageWithConfiguration:` of a symbol configuration is `imageByApplyingSymbolConfiguration:` of the symbols batch, and of another
configuration a copy that holds it. `symbolImage` is `isSymbolImage` of that batch, always NO, since the port draws no symbol.

## Images of a bundle

`+imageNamed:inBundle:withConfiguration:` answers `imageNamed:` for the main bundle, and for another finds `name.png`, or the name as
it is given with its extension, at the screen's scale with `@2x` first, and nil when there is none; the configuration is applied. The
host answers the same for the four names of the test.

## The five system images

`+checkmarkImage`, `+strokedCheckmarkImage`, `+addImage`, `+removeImage` and `+actionsImage` are SF Symbols on the host
(`checkmark.circle.fill`, `checkmark.circle.platter`, `plus.circle.fill`, `minus.circle.fill`, `ellipsis.circle.fill`), of 20 by 20
points. The release has no symbols, so the port draws its own: a disc with the glyph knocked out of it, or a ring for the stroked
check, as template images of 20 points, one image for each call. They are not symbol images, and they are not the symbols' shapes.
