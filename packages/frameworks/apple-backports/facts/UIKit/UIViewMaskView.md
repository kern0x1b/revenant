# UIView maskView and performWithoutAnimation, iOS 8 and iOS 7

Source: the host's own UIKit, under Mac Catalyst, asked for each answer below and held against the backport by
`tests/backports/host/uikit2/run.sh` (the `viewmisc` group); and iOS 6.0 and 6.1.3 on the emulator, an iPhone 4S and an
iPad 2, through `tests/backports/device/uikit2.m`.

## maskView

`maskView` is nil until it is set and answers the view it was given. Setting a view makes its layer the mask of the
view's layer, so the alpha of the mask view decides what shows; setting nil, or another view, takes the old mask off the
layer and leaves that view without a superview. Setting the view that is already the mask does nothing at all. A view
that is its own mask raises `NSInvalidArgumentException` (`Can't add self as subview`). A view given as the mask that
is a subview elsewhere is taken out of its superview first. The mask view is not one of the view's `subviews`, and it does
not follow the view's size: its frame stays as it was set.

The host also answers the view as the mask's `superview`; iOS 6 has no private list of the kind, so the port keeps the mask
view with no superview.

## performWithoutAnimation

`+performWithoutAnimation:` runs the block at once, with `+areAnimationsEnabled` NO inside it, and puts the setting
back to what it was before - after a call made while animations were already off they are still off. A nil block
crashes the newest release, and the port does not defend against it either. A block that raises leaves the animations off in
the newest release; the port does the same, since it restores the setting only after the block returns.
