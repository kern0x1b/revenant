# UIGraphicsImageRendererFormat

Introduced in iOS 10.0. The scale, the opacity and the colour range of the bitmap
an image renderer draws into.

Source: UIKit of the armv7s cache of iOS 10.3.4.

| member | behaviour |
|---|---|
| `-init` | `[super init]`, then the scale is `[UIScreen mainScreen].scale`. |
| `+defaultFormat` | `[super defaultFormat]`, then `prefersExtendedRange` from whether the device supports deep colour, `opaque` to `NO`, and the scale to the main screen's. |
| `-_contextScale` | private; the scale, or the main screen's when the scale is 0. |
| `-copyWithZone:` | `[super copyWithZone:]`, then scale, opacity and range are carried over. |

`-setPrefersExtendedRange:` also clears the private override colour space, the
override bits per component and the grayscale flag. Charon carries none of those
three: nothing on iOS 6 sets them, they are in no header, and the plain path is
the only one reachable.

`+formatForTraitCollection:` and `-preferredRange` arrived in iOS 11 and 12 and
are not part of this backport.

## Deep colour on this hardware

`+defaultFormat` asks `-[UIDevice _supportsDeepColor]`. No device that runs
armv7 has a wide colour display - it arrived with the iPhone 7 - so the answer on
an iPhone 4S or an iPad 2 is always no, and `prefersExtendedRange` is always
`NO`. Charon answers `NO` outright rather than asking a method iOS 6 does not
have. This is the real behaviour of the real implementation on this hardware, not
a simplification: on a device without deep colour the same branch is taken.
