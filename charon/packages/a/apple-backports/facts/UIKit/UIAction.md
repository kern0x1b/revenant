# UIAction, iOS 13.0 and 14.0

Introduced in iOS 13.0: one choice in a menu - a title, an image, an identifier, a handler
- and in 14.0 the factory that needs no title and the `sender`. The port makes it a real
value object, and the only thing that ever runs its handler is the port's own context menu
(`UIContextMenuInteraction.md`), since iOS 6 has no menu, button or bar item that takes an action.

Source: the host's own UIKit under Mac Catalyst (macOS 27.0), held against the backport by
`tests/backports/host/uikit2` (the `menus` group).

## As UIKit does

- `+actionWithTitle:image:identifier:handler:` copies the title, keeps the image and the handler,
  and makes the identifier `com.apple.action.dynamic.` and a UUID when it is given none. An empty
  string is an identifier of its own and is kept. A nil title or handler is accepted.
- `+actionWithHandler:` (14.0) is the same with an empty title, no image and a generated identifier.
- `discoverabilityTitle`, `attributes` and `state` start nil, 0 and off, and can be set. `title` and
  `image` can be set as well; the title is copied, the image kept.
- `-copy` is another object with the same title, image, identifier, discoverability title,
  attributes, state and handler, and changing the copy leaves the original alone.
- Two actions are equal when their identifiers are, whatever their titles, images, attributes and
  state, and only if both are actions; `-hash` is the identifier's hash, and an action never equals a
  menu with the same identifier.
- `-description` is `<UIAction: 0x...; title = T; image = <UIImage: 0x...>; attributes = (Disabled|Destructive)>`:
  the title when it is not empty, the image when there is one, the attributes when there are any,
  named `Disabled`, `Destructive`, `Hidden` and `KeepsMenuPresented`; the identifier, the state and the
  discoverability title are not printed.
- Archiving writes `title`, `identifier`, `discoverabilityTitle`, `image`, `attributes` and `states`, the
  last two only when they are not zero, plus `preferredDisplayMode`; the handler is not archived, and an action
  read back has none.

## Where the port departs

- `sender` (14.0) is nil, as on the host for an action nobody has sent. While the handler runs for a choice
  made in the context menu of this port it is the view the interaction belongs to; the host's is the control
  or bar item the action was sent from, and no such thing exists here. The value is not read from the host: it
  is the nearest honest sender a view-attached menu has.
- `UIMenuLeaf` (16.0), which the header makes `UIAction` adopt, is carried with its members: `UIMenuLeaf.md`.
