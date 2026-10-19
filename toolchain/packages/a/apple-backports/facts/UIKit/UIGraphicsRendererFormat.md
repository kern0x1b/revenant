# UIGraphicsRendererFormat

Introduced in iOS 10.0. What a renderer is to draw into, and the bounds it covers.

Source: UIKit of the armv7s cache of iOS 10.3.4.

| member | behaviour |
|---|---|
| `+defaultFormat` | a plain `[[self alloc] init]`. Its bounds are `CGRectZero`. |
| `-bounds` | read only from outside; the renderer sets it on its own copy. |
| `-copyWithZone:` | `[[[self class] allocWithZone:zone] init]`, then the bounds are carried over. The class is asked for, so a subclass copies as itself. |

`+preferredFormat` and `+formatForTraitCollection:` arrived in iOS 11 and are not
part of this backport.

## The bounds

The format the application hands to a renderer does not carry the bounds: the
renderer copies the format and writes the bounds it was made with into that copy.
`-[UIGraphicsRenderer format]` therefore answers a format whose bounds are the
renderer's, while the one the application kept still has whatever it had. Charon
does this through a private `-_setBounds:`, since the property is read only.
