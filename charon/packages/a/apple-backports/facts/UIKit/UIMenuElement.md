# UIMenuElement, iOS 13.0

Introduced in iOS 13.0: the base class of the things a menu holds. It has a title and an
image and nothing else; `UIAction`, `UIMenu` and `UIDeferredMenuElement` are its three kinds.
The class is carried because an application that names it - to type an array of elements,
or to test a child with `-isKindOfClass:` - would otherwise stop at launch.

Source: the host's own UIKit under Mac Catalyst (macOS 27.0), asked each question below and
held against the backport by `tests/backports/host/uikit2` (the `menus` group), and the
header of SDK 16.4. The device test is `tests/backports/device/menus.m`.

## What the port does as UIKit does

- `title` is a copy of the string it was made with, `image` the object it was made with; both may be nil.
- `subtitle` (15.0) is nil until set, and is a copy of the string it is given; nil clears it. Measured on the host's own
  UIMenuElement, and checked in both directions by `tests/backports/host/menu-selection`.
- The class adopts `NSCopying` and `NSSecureCoding`; a copy of the bare class is the object itself.
  The three kinds copy as their own facts say.
- Archiving writes `title` and `image` when they are set, and `preferredDisplayMode`, which the
  host's own unarchiver insists on finding. An archive the port writes is read by the host's UIKit
  and one the host writes is read by the port; both directions are in the differential test.
- The three kinds descend from it directly, as they do on the host.

## What the port does not carry

- The image visibility and highlight members that came after iOS 15 are not there:
  `respondsToSelector:` says no, and the device test asserts it. They belong to later releases.
- The private display keys the host writes into an archive (`internalIdentifier`,
  `accessibilityIdentifier`, the display preferences and the element sizes) are neither written nor read.
