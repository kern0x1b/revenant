# UITargetedPreview, iOS 13.0

Introduced in iOS 13.0: a view, the parameters to draw it with and the target to draw it at. The interaction delegates of later releases (drag and drop,
context menus) hand it back; on iOS 6 none is ever drawn.

Source: the host's own UIKit under Mac Catalyst (macOS 27.0), held against the backport by `tests/backports/host/uikit2` (the `menus` group).

## As UIKit does

- `-initWithView:parameters:target:` keeps all three as they are - the parameters are the same object, not a copy. A nil view, parameters or target
  raises `NSInternalInconsistencyException`, `Invalid parameter not satisfying: view != nil` (or `parameters != nil`, `target != nil`), in that order.
- `-initWithView:parameters:` needs the view to be in a window and makes the target from the view's superview, `center` and `transform`;
  a view outside a window (nil included) raises `This UITargetedPreview initializer requires that the view is in a window, but it is not. Either fix that,
  or use the other initializer that takes a target with an explicit container. (view: <UIView: 0x...>)`, and a view with no superview raises the target's own
  error. A nil `parameters` raises `Invalid parameter not satisfying: parameters != nil`.
- `-initWithView:` is the same with default parameters whose background is **clear**, not the system background a bare `UIPreviewParameters` has.
- `size` is the size of the view's bounds - unscaled by its transform.
- `-retargetedPreviewWithTarget:` is a preview with the same view and parameters and the new target; nil raises `Invalid parameter not satisfying: newTarget != nil`.
- The object copies to itself.
- `-description` is `<UITargetedPreview: 0x...; view = <UIView: 0x...>; parameters = <UIPreviewParameters: 0x...>; target = <UIPreviewTarget: 0x...>>`.

## Where the port differs

The host's `-isEqual:` answers NO even for the object itself; the port keeps identity.
