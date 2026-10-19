# Display P3 colors, iOS 10, and why they are not carried

Introduced in iOS 10.0: `+[UIColor colorWithDisplayP3Red:green:blue:alpha:]` and `-[UIColor initWithDisplayP3Red:green:blue:alpha:]`.

Source: UIKit of the armv7s cache of iOS 10.3.4, read for what the two methods make.

The class method allocates and initializes with the instance method; the instance method lets go of `self` and answers an
object of a private subclass, `UIDisplayP3Color`, that holds the four components in the Display P3 color space. That class
has its own `-CGColor`, `-getRed:green:blue:alpha:`, `-getHue:saturation:brightness:alpha:`, `-getWhite:alpha:`, `-set`,
`-setFill`, `-setStroke`, `-isEqual:` and `-hash`, and converts its components between color spaces with CoreGraphics's
`CGColorTransformConvertColorComponents`.

iOS 6 has no Display P3 color space; the named spaces it can make are generic RGB, gray and CMYK, and its `UIColor` holds
device RGB in 0 to 1. A color made from sRGB values would answer other components from `-getRed:...` than the release
does, and other pixels than a P3 color drawn on a display that shows it, so it would be a different color under the
same name. Not carried: `respondsToSelector:` answers NO.
