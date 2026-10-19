# UIPointerStyle, UIPointerShape and the pointer effects, iOS 13.4

Introduced in iOS 13.4: what the pointer becomes over a region - a content effect on a view's preview, a shape, or nothing at all.
iOS 6 has no pointer to change, so these are values that compare, copy and describe themselves as the host's do and are never used.

Source: the host's own UIKit under Mac Catalyst (macOS 27.0), held against the backport by `tests/backports/host/uikit2` (the
`pointer` group): descriptions, equality over every pair of 19 shapes, 12 styles and 7 effects, copies, the hashes that are determined
by the values, and the header of SDK 16.4.

## UIPointerShape

- `+shapeWithRoundedRect:` has no corner radius of its own - it takes the system's - and is **not equal** to `+shapeWithRoundedRect:cornerRadius:`
  with any radius, zero included; `-init` is the shape of the empty rectangle with a radius of zero.
- `+shapeWithPath:` keeps a **copy** of the path (a later change to the caller's path does not reach it) and accepts nil; two shapes are equal
  when their paths are (`CGPathEqualToPath`). `+beamWithPreferredLength:axis:` is a beam along the vertical axis unless the axis is exactly
  horizontal; an axis of both or of neither is a vertical beam and equal to one.
- `-copy` is another object with a copy of the path. `-hash` is the exclusive or of the four rectangle values (as signed integers), the radius
  and 8 for a rounded rectangle; the length exclusive or 16 (vertical) or 17 (horizontal) for a beam. The hash of a path shape is
  the port's own - the bounds of the path - since the host's cannot be told from its path's.
- `-description` is `<UIPointerShape: 0x...; rect = (x y; w h)`, `; cornerRadius = r` for a radius that is neither unset nor zero, `>`;
  `; path = <UIBezierPath: 0x...>` for a path (nil is `0x0`); `; beamLength = 10 (vertical)` for a beam.

## UIPointerEffect and its subclasses

- `+effectWithPreview:` makes an instance of the class it is sent to, with the preview it is given, as it is (nil is accepted); the base
  class does not choose a subclass, whatever the preview's view is. `UIPointerHighlightEffect` and `UIPointerLiftEffect` add nothing.
- `-isEqual:` is YES for an object that is of the receiver's class or below, with an equal preview: a base effect equals a hover effect over the
  same preview and not the other way round. The hash is the preview's; nil gives 0. `-copy` keeps the preview. `-description` is
  `<UIPointerHoverEffect: 0x...>`.
- `UIPointerHoverEffect` starts with `preferredTintMode` overlay, `prefersShadow` NO and `prefersScaledContent` YES; any tint mode value is
  kept. Its equality and its hash (the preview's, exclusive or the mode, the shadow and the scaling flags) include the three settings.

## UIPointerStyle

- `+styleWithEffect:shape:`, `+styleWithShape:constrainedAxes:` (axes kept as given) and `+hiddenPointerStyle` (a new object each time)
  accept nil arguments and keep the effect and shape as they are; `-copy` copies both.
- Two styles are equal when their kind (effect, shape or hidden), axes, effect and shape are; `-description` is
  `<UIPointerStyle: 0x...; type = content effect>`, `type = shape` or `type = hidden`.
- `accessories` arrived in iOS 15 and is not answered.

## Where they differ

- The host's `UIPointerStyle` descends from `UIHoverStyle` of iOS 17; the port's from `NSObject`. `-hash` of a style is the port's own combination.
- `-effectWithPreview:` and the shapes keep what iOS 6 can keep: the preview is a `UITargetedPreview` of the port.

## `accessories`, iOS 15

`UIPointerStyle.accessories` is nil by default and holds a copy of the array given. The accessories are their own class; see
`UIPointerAccessory.md`, which carries the shape, the position and the orientation of each. Measured by `tests/backports/host/pointer-accessory`.
