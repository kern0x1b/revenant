# UIGraphicsImageRendererContext

Introduced in iOS 10.0. Adds one thing to the base context: the image drawn so
far.

Source: UIKit of the armv7s cache of iOS 10.3.4.

| member | behaviour |
|---|---|
| `-currentImage` | `CGBitmapContextCreateImage` of the context; `nil` if that fails. Otherwise `+[UIImage imageWithCGImage:scale:orientation:]` with the format's `-_contextScale`, or **1** when that is 0, and `UIImageOrientationUp`. The CGImage is released afterwards. |

The scale is guarded twice: `-_contextScale` already answers the main screen's
scale when the format's own is 0, and `-currentImage` still falls back to 1 if
what it gets is 0. Both are kept.

`-currentImage` may be called as often as a drawing block likes, and each call
makes a new image of the bitmap as it stands.
