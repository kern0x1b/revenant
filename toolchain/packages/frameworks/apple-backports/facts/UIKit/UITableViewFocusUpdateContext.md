# UITableViewFocusUpdateContext, iOS 9

Introduced in iOS 9.0 as the focus update context of a table view. It is a `UIFocusUpdateContext`. The SDK 16.4 header is
the contract: `previouslyFocusedIndexPath` and `nextFocusedIndexPath` (9.0, `NSIndexPath *`, readonly, strong), declared
on the class itself.

## Defaults, measured on the host

A probe on Mac Catalyst:

- the superclass is `UIFocusUpdateContext`;
- `[[UITableViewFocusUpdateContext alloc] init]` and `+new` raise the superclass's `NSInternalInconsistencyException`,
  reason `Invalid parameter not satisfying: focusSystem`;
- `[UITableViewFocusUpdateContext alloc]` without init answers an object whose two index paths are nil.

The port has no init of its own, so it inherits the superclass's, and its two getters answer nil.

## What is not carried

No focus engine makes a table view focus context on iOS 6, so the index paths of every context are nil. The host's own
properties of this class, which the SDK header does not name, are not carried.

## Device

Not run on a device.
