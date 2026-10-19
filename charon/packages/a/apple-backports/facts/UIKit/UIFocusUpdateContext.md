# UIFocusUpdateContext, iOS 9

Introduced in iOS 9.0 as the context of one focus move: the focus engine makes one for each move and hands it to
`shouldUpdateFocusInContext:` and `didUpdateFocusInContext:withAnimationCoordinator:`. It is an `NSObject`. The SDK 16.4
header is the contract: `previouslyFocusedItem` and `nextFocusedItem` (10.0, `id<UIFocusItem>`, readonly, weak),
`focusHeading` (9.0, `UIFocusHeading`, readonly), and, in the `UIKitAdditions` category, `previouslyFocusedView` and
`nextFocusedView` (9.0, `UIView *`, readonly, weak).

The release has no focus engine, so no system code makes a context. The classes are carried so that an application
which links them loads, and so that the answers an application can reach are the host's.

## Defaults, measured on the host

A probe on Mac Catalyst:

- the superclass is `NSObject`; the class conforms to neither `NSCoding` nor `NSCopying`, and answers no `initWithCoder:`;
- `[[UIFocusUpdateContext alloc] init]` and `[UIFocusUpdateContext new]` raise `NSInternalInconsistencyException` with the
  reason `Invalid parameter not satisfying: focusSystem`. The reason is the one `NSParameterAssert` writes for a nil
  focus system, and the exception's user info carries the `NSAssertFile` and `NSAssertLine` keys;
- `[UIFocusUpdateContext alloc]` without init answers an object. Each of the five public properties answers nil, or 0
  for `focusHeading`. These answers are the host's, so the release gives the same.

The port's init asserts on a nil focus system with the same macro, so its exception has the host's name, reason and user
info keys. Its five getters answer nil and `UIFocusHeadingNone`.

## What is not carried

The focus engine never runs on iOS 6, so no context is ever filled in: the properties of every context are the zero
ones. The host has more properties on this class (its focus map, focus movement, focus guide and similar), none of them
in the SDK header, and the port does not carry them.

## Device

Not run on a device. The differential in `tests/backports/host/uikit-focuscontext/` compares the port with the host's
answers on every line that the header names.
