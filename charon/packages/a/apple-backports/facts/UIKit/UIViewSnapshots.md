# UIView snapshots and drawViewHierarchyInRect, iOS 7

Source: the host's own UIKit, under Mac Catalyst, in an application with a window - the newest release makes a snapshot
only for a view it can put in a scene - asked every answer below and held against the backport by the `snapshots`
group of `tests/backports/host/uikit2/run.sh`, which builds the group into an application bundle and runs it; and iOS 6.0
and 6.1.3 on the emulator, an iPhone 4S and an iPad 2, through `tests/backports/device/uikit2.m`, which reads the
pixels of the snapshot back. UIKit of iOS 10.0.1 armv7s (`-[UIView snapshotViewAfterScreenUpdates:]` at `0x20159727`)
was read for what the methods hand to the private machinery: a `_UIReplicantView`, and for the deferred case a
pending snapshot that is taken after the animation transaction commits.

## The snapshot

`-resizableSnapshotViewFromRect:afterScreenUpdates:withCapInsets:` always answers a view, never nil: for a rect outside the
view, for `CGRectNull`, for a rect of no width, for a view of no size, for a hidden view and for a view outside a window.
Its frame is `{0, 0}` and the size of the rect - a rect that runs partly outside the view is not clipped, and
`CGRectNull` and a negative size make zero - its bounds are the same, it has no subviews, accepts touches, and has no
autoresizing. The image is the layer's contents, at the screen's scale: `contentsScale` is the scale, also for a view of no
size, and `contentsGravity` is resize. The newest release's snapshot is a view of a private class; the port's is a private view class of its own.

`-snapshotViewAfterScreenUpdates:` is the same for the view's bounds and no insets. With no insets `contentsCenter` is
the whole image, `{0, 0, 1, 1}`. With any inset it stretches the middle in a rule of pixels that the newest release
follows and the port copies, and that has two odd parts. On each axis, with `p` the rect's origin, `b` and `a` the
insets before and after and `L` the size, all in pixels (points times the scale), the centre starts at `(p + b + 1) / L` and
is `(L - b - a - 2) / L` long - a pixel in from each side - except that an axis on which the rect starts at 0 and
both insets are 0 is `0` and `1`; the origin `p` is added into the start, so a rect that does not begin at
the view's corner puts the middle beyond the image. When the length would be under 0.04 pixel, it is 0.04 pixel long and starts
0.02 pixel earlier. These are all held against the host by every one of the seven rects and six sets of insets the group asks.

The snapshot shows the view as the host draws it: the view and its subviews, at the view's alpha. The port's
pixels are checked on the device; the host's cannot be read back, since the newest release keeps the image on the
server and the picture is empty when it is drawn, so the agreement with the host on the pixels is the agreement of
`drawViewHierarchyInRect:`, below, which both draw from the same source.

## afterScreenUpdates

`afterScreenUpdates:YES` asks for what the screen is about to show, changes made in the current transaction included; the
newest release takes the snapshot when the transaction commits. The port cannot defer: with YES it lays the view out
and flushes the transaction and takes the picture at once, so a change made in the same animation block and not yet
committed is not in it, which the newest release would have shown.

## drawViewHierarchyInRect

`-drawViewHierarchyInRect:afterScreenUpdates:` draws the view, its subviews and its alpha into the current graphics context,
scaled from the view's bounds into the rect - a rect of half the size draws the view at half the size. It answers no
when there is no graphics context, and no for a view that is not in a window; a view of no size answers yes wherever it is.
A hidden view and a view of no alpha answer yes and draw nothing; a view whose superview is hidden is drawn by the port as hidden too, which was not asked of the host. The view's own transform is
not part of the picture, its position is not either, and the picture of a view the size of the rect fills it.

The port draws from the layer with `renderInContext:`, which is what the release has: content that only the newest
render pass can draw - a blurred effect view - is not in it.
