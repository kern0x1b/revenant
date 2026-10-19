# UIView.anchorPoint, iOS 16.0

The view's own spelling of its layer's anchor point, the point of the bounds that `center` is measured to and that transforms turn
about. `UIKit/UIView+AnchorPoint16.m` reads and writes `self.layer.anchorPoint`, which the release's `CALayer` carries, so the view
and its layer never disagree; setting it keeps the layer's position, and so the view's `center`, and moves the frame, as setting it
on the layer always did. That UIKit 16 does nothing beyond the forward - no layout pass, no change to `center` - is read from the
header's comment on `center` ("relative to anchorPoint"), not measured.

Ladder by `objc.inventory` (`.agent-work/plan-and-analysis/b1314-flips/ladder-leaf-anchor-key.log`, `center` as the positive control and
an invented selector as the negative one): `anchorPoint` and `setAnchorPoint:` are not in `UIView`'s methods in 6.1.3 or 12.0 and are in
16.0 and 18.0. There is no 13-15 cache, so `introduced` stays the header's 16.0. Run on a device: the last section.

## On a device, iOS 6.1.3

On an iPad 2 of iOS 6.1.3 (2026-09-23), a process of the band's own (`.agent-work/runs/b1314-live/main.m`, output `run4-all.txt` beside it) loaded the gate's `libUIKitBackports.dylib` and checked the getter and setter against the layer, and that the center stays and the frame moves; all as described.
