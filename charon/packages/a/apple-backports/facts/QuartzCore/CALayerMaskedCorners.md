# CALayer.maskedCorners, iOS 11

Introduced in iOS 11: `CACornerMask` picks which of a layer's four corners `cornerRadius` rounds
- `kCALayerMinXMinYCorner`, `kCALayerMaxXMinYCorner`, `kCALayerMinXMaxYCorner`,
`kCALayerMaxXMaxYCorner` - and `CALayer.maskedCorners` holds the set, all four by default. It is
the corpus's most frequent crash-exposure row: every one of the four applications that call it
would otherwise send an unrecognized selector to a real, present class.

Source: the header of iOS 16.4 for the four bit values, their default and the property's shape;
`CACornerMask` and `UIRectCorner` (iOS 2.0's own `UIBezierPath` corner-rounding option set) share
their four bit positions in the same order, confirmed by reading both enums.

## What the port does

iOS 6's `CALayer` rounds all four corners together whenever `cornerRadius` and `masksToBounds`
are set; there is no per-corner selection. A layer whose `maskedCorners` is set to fewer than all
four gets a `CAShapeLayer` mask of a rect rounded on exactly the selected corners -
`[UIBezierPath bezierPathWithRoundedRect:byRoundingCorners:cornerRadii:]` over the mask bits cast
straight to `UIRectCorner` - kept in step with the layer's bounds, radius, `masksToBounds` and its
own mask the same way `CALayer.cornerCurve` (`facts/QuartzCore/CALayerCornerCurve.md`) keeps its
continuous-curve mask in step, hooking the same four selectors
(`setCornerRadius:`/`setMasksToBounds:`/`setBounds:`/`layoutSublayers`) with an independent
`class_replaceMethod`/`imp_implementationWithBlock` chain. A layer masked to all four corners (the
default), one that does not clip to its bounds, or one that already carries a mask of its own, is
left untouched, exactly as `cornerCurve` leaves such a layer untouched.

## What differs from the release

The two features are not coordinated. Each only claims `layer.mask` when it is empty or already
its own shape layer, so whichever of `setCornerCurve:` or `setMaskedCorners:` was called more
recently on a given layer keeps the mask, and the other stays inert - set but not drawn - until it
is set again itself. The real `CALayer` draws a masked-corners layer with whichever curve
`cornerCurve` names on the corners that are selected; this port never combines the two shapes in
one mask. Applications that use `maskedCorners` on its own, without also setting `cornerCurve` to
continuous, see no difference at all.
