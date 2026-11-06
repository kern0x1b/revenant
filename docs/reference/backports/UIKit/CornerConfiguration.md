# `UICornerConfiguration` and `UICornerRadius` on iOS 6

`UICornerConfiguration` is the per-corner description of a view's shape that `UIView.cornerConfiguration` takes, and
`UICornerRadius` is the radius of one corner: fixed, or concentric with the nearest rounded ancestor. The backport
supplies both classes, `UIView.cornerConfiguration` and `-[UIView effectiveRadiusForCorner:]` on iOS 6, and leaves the
system classes in charge where they exist.

## Source

| File | Contents |
| --- | --- |
| `frameworks/Backports/src/UIKit/UICornerConfiguration.m` | the two classes, the factories, the concentric rule and the view's property |
| `frameworks/Backports/src/UIKit/RevenantCornerPath.h`, `.c` | the radius fitting and the rounded path with four different radii |
| `frameworks/Backports/src/UIKit/RevenantUICorner.h` | the declarations of the two classes where the SDK has none |
| `toolchain/src/swift-runtime/overlay/UIKit/UIKitRevenant.swift` | the Swift spelling: `UICornerRadius`, `UICornerConfiguration` and the factories |
| `frameworks/Backports/tests/UIKit/corner_path_test.m` | the host test of the geometry against an analytic oracle |

**The overlay and the class symbol.** The headers the overlay is built against carry no release mark for these two classes
(the backport lowers it), so the Swift code may name their types. It may not name the `UICornerRadius` class as the
receiver of a message: Swift would then emit a strong reference to `_OBJC_CLASS_$_UICornerRadius`, which iOS 6's UIKit
does not export, and the overlay library would not load. The overlay creates its radii through three functions in
`RevenantUIKitOverlayShims.h` that look the class up with `NSClassFromString`. The factories of
`UICornerConfiguration` are messages to `self` in a static method and need no symbol. A program that does not link the
backports and builds a radius stops with a message that says so.

## The factories

Every factory of the SDK's `UICornerConfiguration` exists, with the SDK's Swift names:

| Swift | What it describes |
| --- | --- |
| `corners(radius:)` | one radius for the four corners |
| `corners(topLeftRadius:topRightRadius:bottomLeftRadius:bottomRightRadius:)` | one radius per corner; `nil` is a square corner |
| `capsule()`, `capsule(maximumRadius:)` | half of the shorter side, capped by the maximum |
| `uniformCorners(radius:)` | four corners that always share one radius |
| `uniformEdges(topRadius:bottomRadius:)`, `uniformEdges(leftRadius:rightRadius:)` | the two corners of an edge share a radius |
| `uniformTopRadius(_:bottomLeftRadius:bottomRightRadius:)` and the bottom, left and right forms | one edge's corners share a radius, the other two are free |

A *uniform* group takes the largest of the radii it contains, so a concentric radius that is smaller at one of the
group's corners than at another gives the group the larger value.

`UICornerRadius.fixed(_:)` is a number of points. `UICornerRadius.containerConcentric(minimum:)` follows the nearest
ancestor that is rounded at the same corner:

```
radius = max(outer − max(across, down), minimum)
```

where `outer` is the ancestor's effective radius at that corner, and `across` and `down` are the distances of the view's
corner from the ancestor's two edges that meet there. With no rounded ancestor the radius is the minimum (`0` when none
is given). An ancestor counts as rounded when it has a `cornerConfiguration`, or a `layer.cornerRadius` whose
`maskedCorners` include the corner.

## Drawing

`-[UIView setCornerConfiguration:]` stores a copy of the configuration and applies it to the layer:

- When the four effective radii are equal, the view's `layer.cornerRadius` is set to the radius. Nothing else changes.
- When they differ, the view's layer gets a `CAShapeLayer` mask whose path has the four radii
  (`RevenantCornerPathCreate`). The mask clips the content, which `maskedCorners` alone does not do for different radii.
- A radius that does not fit is shrunk the way CSS shrinks `border-radius`: one factor, the smallest ratio of a side to
  the sum of the two radii on it, scales all four. A capsule on a 100 × 50 view has radius `25`, not `50`.

The result is applied again when the layer's bounds change, which is when a size-dependent radius (capsule, concentric)
has to follow. `effectiveRadiusForCorner:` answers with the same computation, so it agrees with what is drawn. With no
configuration set the getter answers `corners(radius: .fixed(0))`.

## What is not the same

- A view whose `layer.mask` was set by someone else keeps that mask and gets no per-corner shape. A single radius still
  goes through `cornerRadius`.
- A concentric radius is computed from the ancestors at the time of the layout of the view itself. It is not updated
  when only the ancestor's size changes, nor when the view moves to another superview without a size change.
- `effectiveRadiusForCorner:` with a set of corners answers the largest of their radii.

## Test

`corner_path_test.m` compares the path's inside and outside against the analytic shape (a point is inside when it is
within the rectangle and outside every corner's cut-away quarter circle), with a band of `0.02` around the arcs for the
Bézier approximation. It checks the fitting invariants (after fitting, the tightest side holds the sum of its two radii
exactly), zero-sized rectangles, and that equal radii give the path of `CGPathCreateWithRoundedRect`. In `--negative`
mode it uses the radii before fitting and must fail.
