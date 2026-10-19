# UIPreviewTarget, iOS 13.0

Introduced in iOS 13.0: where a preview should come from or go to - a container view, a centre in it and a transform.

Source: the host's own UIKit under Mac Catalyst (macOS 27.0), held against the backport by `tests/backports/host/uikit2` (the `menus` group).

## As UIKit does

- `-initWithContainer:center:` is the same with the identity transform. All three properties are read-only.
- A nil container raises `NSInternalInconsistencyException`, `The preview target must have a valid container.`; a container that is not in a window (a
  window itself is in one) raises the same exception, `UIPreviewTarget requires that the container view is in a window, but it is not. (container: <UIView: 0x...>)`.
- The object copies to itself and adopts `NSCopying` only.
- Two targets are equal when their containers are the same view and their centres and transforms are the same.
- `-description` is `<UIPreviewTarget: 0x...; container = <UIView: 0x...>; center = (5 6)>`, with `; transform = [a, b, c, d, tx, ty]` when the transform is not
  the identity; the numbers are printed with `%g`.

## Where the port differs

The host's `-hash` of two equal targets differs; the port's agrees, as `NSObject` asks of it.
