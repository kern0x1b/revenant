# UIPointerAccessory and the accessories of UIPointerStyle, iOS 15

`UIPointerAccessory` (iOS 15) is a shape drawn beside the pointer, at a position given by `UIPointerAccessoryPosition` (an offset and an
angle, with the constants and `UIPointerAccessoryPositionMake`). `UIPointerStyle.accessories` (iOS 15) is the array of them a style
shows. Up to four are supported by the system; the port does not draw them.

## What the port stores

- `+accessoryWithShape:position:` copies the shape, as the host does; the shape is not the object given, and the position is the one
  given.
- `orientationMatchesAngle` is NO for a custom accessory and keeps the value set.
- A copy keeps the shape and the position, but **not** the orientation, which is NO in the copy. The host's copy does the same.
- `UIPointerStyle.accessories` is nil by default. The array is copied on set, so a change to the array given afterwards does not reach
  the style; the accessories inside are the same objects. A copy of the style keeps the accessories.
- Equality of styles does not compare the accessories: this was not measured, and the port keeps equality as it was.

Measured by `tests/backports/host/pointer-accessory` (42 checks; the port's classes and the host's print the same values, and the nine
controls fail). The port's class is what the test builds in the port's build, with the RevenantPort prefix stripped from the names.

The pointer itself is not drawn with the accessories, and nothing on the port's pointer is placed relative to an accessory. The
`+[UIPointerStyle systemPointerStyle]` class method is a separate row and is not built here.

Source: the host's own UIKit under Mac Catalyst, and the header of SDK 16.4 (`UIPointerAccessory.h`, `UIPointerStyle.h`), iOS 15.0.

## The arrow

`+arrowAccessoryWithPosition:` (iOS 15) is the system's arrow. Measured in the host:

- Its class is `UIPointerAccessory`, and its shape is a `UIPointerShape` holding a path: 11 elements (a move, six curves and lines, and a
  close), with bounds from the origin of about 8.54 by 8.77 points. The path is the same at every position, so two arrows' shapes compare equal and
  are not the same object. The port builds the same path from the host's elements, at full precision, in `revenant_arrowPath()`.
- The position is the one given. The orientation is **YES**: the header says a system vended accessory's orientation varies, and the arrow's is
  YES where a custom accessory's is NO. A copy of the arrow has NO, as a copy of a custom one does, and setting the orientation NO keeps NO.
- It is not a rounded rectangle: the arrow's shape does not equal one.

The port stores the arrow and does not draw it. The `tests/backports/host/pointer-accessory` differential holds the path element by element, the
position, the orientation, the shape's equality and the copy; its five arrow controls fail (the orientation NO, the path open, the shape rounded,
the position dropped, one control point moved).
