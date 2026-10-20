# NSString drawing with attributes, iOS 7

iOS 7 moved the measuring and drawing of a string onto attributes: `-sizeWithAttributes:`, `-boundingRectWithSize:options:attributes:context:`,
`-drawAtPoint:withAttributes:`, `-drawInRect:withAttributes:` and `-drawWithRect:options:attributes:context:`, in place of the font-and-mode
methods of iOS 2 to 6 that iOS 7 deprecated.

Source: the host's own UIKit, recorded by `host/stringdrawing` for every case of `device/stringdrawing-cases.m` and read back on the
iPad 2 by `device/stringdrawing.m`: three fonts and paragraph styles, six strings, the size, the box with no options, with the
line-fragment origin, with the font leading and at a width that wraps, the inked area of each of the three draw methods and the context
(101 records). The attributed string of the release already measures and draws these ways, so the methods make an attributed string of
the text and ask it.

## What the port does as the system does

`sizeWithAttributes:` is the box of the text on its lines, unbounded, so a newline counts and an empty string is one line high; a box asked
for with no options is one line and has its origin above the baseline, as the system's has; the line-fragment origin puts the origin at
zero and wraps to the width; the font leading adds the leading; the three draw methods draw where the system draws.

The release has a `-drawInRect:withAttributes:` of its own, which does not return when it is given the attributes of iOS 7: the library
puts its own in its place when it loads, and it draws as `-drawWithRect:options:attributes:context:` with the line-fragment origin does.
An empty string measures as one line high, as the system's does; the release's attributed string forgets the font of an empty text, so
the height is that of a space in the same attributes, with no width.

## What differs

The fonts of the two releases measure alike to within two points, so a width or a height is not the host's to the digit, and the ink of a
drawn string to within four. The default font of a string with no attributes is Helvetica 12 on the release, and the host's is
larger.
