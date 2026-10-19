# UIMenu, iOS 13.0 and 14.0

Introduced in iOS 13.0: a titled group of menu elements, which nests. `+menuWithChildren:`
(14.0) makes one with nothing but its children. The port keeps the value and shows it only through
`UIContextMenuInteraction` (see its facts), as a sheet of buttons.

Source: the host's own UIKit under Mac Catalyst (macOS 27.0), held against the backport by
`tests/backports/host/uikit2` (the `menus` group) and `tests/backports/host/menu-selection`, which holds the port's
selection, size and subtitle against the host's own menus.

## As UIKit does

- `+menuWithTitle:image:identifier:options:children:` copies the title and the children array, keeps the image and
  the options, and makes the identifier `com.apple.menu.dynamic.` and a UUID when it is given none. `+menuWithTitle:children:`
  and `+menuWithChildren:` (title empty, not nil) are the same with the defaults. A nil title stays nil, and nil children
  are an empty array.
- A child that is not a `UIMenuElement` raises `NSInvalidArgumentException` - the host's message names a private
  selector, the port's names the same one - from every entry point that takes children.
- `-menuByReplacingChildren:` is a menu with the same title, image, identifier and options and the given children, kept as they
  are, not copied; nil keeps the children the menu has.
- `-copy` copies every child, so a copy's children are other objects that are equal to the originals.
- `preferredElementSize` (16.0) is -1 until set, which the host's menu also answers for a menu nothing has sized; a value is kept as
  given, including one the enum does not name (7 reads back 7). A copy and `-menuByReplacingChildren:` keep it.
- `selectedElements` (15.0) is the elements whose state is on, in the menu and in its sub-menus, in the order they appear; a mixed
  element is not selected, and a menu with none answers an empty array.
- `subtitle` (15.0) is a copy of what it was given, and a copy and `-menuByReplacingChildren:` keep it.
- Two menus are equal when their identifiers are; a menu never equals an action with the same identifier.
- `-description` is `<UIMenu: 0x...; title = M; identifier = com.m; image = <UIImage: 0x...>; options = (Inline|Destructive); children = <NSArray: 0x...>>`,
  the title when not empty, the identifier always, the image and the options when set, the children always. The options are named `Inline`,
  `Destructive` and `SingleSelection`.
- Archiving writes `title`, `identifier`, `options`, `children` and `image`, plus the element size keys the host's unarchiver reads.

## Where the port differs

- A menu the host has decoded prints `currentSelection = <NSArray>` after the options; the port never does.
- `selectedElements` walks the menu's children and its sub-menus only. A deferred element among the children is not asked for its
  elements, so none of them is counted; the host's answer for a deferred element is not measured.
- Archiving writes `preferredElementSize` as the value the menu holds, under the key the host's unarchiver reads; the host's own
  archive of the same value is not compared, so that key's bytes are the port's own choice.
