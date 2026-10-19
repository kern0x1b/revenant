# UIPreviewAction and UIPreviewActionGroup, iOS 9.0

Introduced in iOS 9.0: what a view controller returns from `-previewActionItems` to say which
buttons the sheet under a peek shows - an action with a title, a style and a handler, and a
group that holds several under one title. Deprecated in iOS 13.0 for `UIContextMenuInteraction`.

Source: the host's own UIKit under Mac Catalyst, asked for each answer below and held against
the backport by `tests/backports/host/previewaction/run.sh`, which records thirteen answers
that the app `tests/backports/device/previewaction.m` compares on a device running 6.1.3.

## The action

- `+actionWithTitle:style:handler:` keeps the style, the title and the handler; the title is
  copied, and so is the handler, and a nil title or handler is accepted. A nil handler reads
  back as nil.
- The handler is called with the action and the view controller it is given; the property
  answers the block itself.
- `-copy` is another object with the same title, style and handler.
- An action made by `-init` has no title, no handler and style 0.
- The superclass is NSObject. The class adopts `UIPreviewActionItem` and `NSCopying`, and is
  not archived.
- `style` is not in the header; UIKit's class answers it and so does the port's.

## The group

- `+actionGroupWithTitle:style:actions:` keeps the title and the style, and **copies** the
  array: an action added to a mutable array afterwards is not in the group. The actions
  themselves are shared, not copied. A nil title and nil actions are accepted, and the group
  then has no title and no actions.
- `-copy` is another object with the same title, style and actions.
- `actions` is not in the header; UIKit's class answers it and so does the port's.

## The view controller

- `-previewActionItems` answers an empty array when the controller does not override it.

## What the port answers, and what iOS 6 does with them

The release has no peek and no pop, so nothing asks a controller for its actions and nothing
calls a handler. An application that builds the items and returns them from
`-previewActionItems` links and runs; the items are values.
