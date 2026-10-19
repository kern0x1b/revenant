# The tint colour of a view, iOS 7

Source: the host's own UIKit, measured beside the backport, and the `tint` group of
`tests/backports/host/uikit2/run.sh`, which holds the two to the same answers.

## What is inherited and what is told

A view with no colour of its own answers its superview's, all the way up. Setting a colour on a view
reaches every view below it that has none of its own and stops at one that has: that view keeps its
colour and is not told about the change. Clearing a colour - setting nil - puts the view back to
inheriting. `-tintColorDidChange` is sent to every view the change reaches, once, and to none of the
others.

`tintAdjustmentMode` is `Automatic` on a fresh view and answers `Normal` where nothing above it is
dimmed. Setting it to `Dimmed` reaches the views below the same way a colour does, and does not reach the
superview. While a view is dimmed its tint colour is the dimmed one; when the dimming stops the colour
comes back unchanged, because dimming is not stored - it is applied to whatever colour is inherited.

## What dimming does to a colour

The dimmed colour is the colour converted to grey and made four fifths as opaque. The conversion is not a
formula of our own: it is what CoreGraphics does when the colour is matched to the device's grey colour
space, which is why red comes out at 0.509, green at 0.863 and blue at 0.273 rather than at the 0.299,
0.587 and 0.114 of a luma weighting. Below iOS 9 there is no
`CGColorCreateCopyByMatchingToColorSpace`, so the backport asks for the same conversion the way the
release can: it fills one pixel of a device-grey bitmap with the colour and reads the byte. The
difference from the system's answer is that byte's rounding - at most 1/255, and the test holds it to
that. The alpha is multiplied by 0.8: an opaque colour dims to 0.8, a colour at 0.5 to 0.4.

On iOS 6 the same pixel gives other greys, because the CoreGraphics of that release does no colour
management between device spaces: it matches a device colour to device grey by a luma weighting, and red,
green and blue come out at 77, 150 and 28 of 255. The backport asks the release's CoreGraphics and so
dims to those; the later answer would need the colour management iOS 6 does not have, and a formula of
our own in its place would only be a guess at it. Measured in the device test on iOS 6.0 in the emulator,
where the alpha of 0.8 and 0.4 holds as it does on the later release.

## The colour a view answers when nothing sets one

It is the system blue, `(0, 122/255, 1)`, and the number is read from UIKit: `122/255` is a `double`
literal in the UIKitCore of iOS 12.0 arm64 at `0x1ad730c78`, in the same constant pool as the other
components of [the system colours](UIColorSystemColors.md), and the pair `(122, 255)` is carried whole by
VectorKit of that release. The host is no help here - under Mac Catalyst both the default tint and
`+systemBlueColor` answer the Mac's accent colour, `(0, 0.533, 1)` on the machine this was measured on -
and iOS 7's own UIKit carries the number in neither float nor double form, so it builds the colour rather
than storing it. That is why the later release is the one read.
