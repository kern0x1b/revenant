# UIMenuSystem, and the menu builder that is not carried, iOS 13.0

Introduced in iOS 13.0: the object an application asks to rebuild or revalidate its menus - the menu bar of Mac Catalyst and the shortcut
list of a hardware keyboard - and the builder (`UIMenuBuilder`) it edits them with, given to `-buildMenuWithBuilder:` of a responder.

Source: the host's own UIKit under Mac Catalyst (macOS 27.0), held against the backport by `tests/backports/host/uikit2`
(the `menus` group), and the header of SDK 16.4.

## What the port does

- `+mainSystem` and `+contextSystem` answer one shared object each, always the same, and they are two objects. The host's are
  instances of two private subclasses; the port's are both `UIMenuSystem`.
- `-setNeedsRebuild` and `-setNeedsRevalidate` are **inert**. iOS 6 has no menu bar and no key command menus to rebuild or check,
  so each says once in the system log - `UIMenuSystem: iOS 6.1.3 has no menu bar and no key command menus...` - and returns.
  Each has its own line, printed the first time it is called.

## What is not there, and why

- `UIMenuBuilder` and `-[UIResponder buildMenuWithBuilder:]` are **not carried**. The builder is handed to the responder chain when
  the system builds the main menu, which never happens here. An application that overrides the method is never called, and
  nothing is lost that could have been shown. The protocol's own members (`menuForIdentifier:`, `replaceMenuForIdentifier:withMenu:`,
  `insertChildMenu:atStartOfMenuForIdentifier:` and the rest, and `system`) go with it.
