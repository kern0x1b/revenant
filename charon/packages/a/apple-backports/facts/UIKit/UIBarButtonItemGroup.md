# UIBarButtonItemGroup's iOS 16 properties

`UIBarButtonItemGroup` (iOS 11) holds bar button items and a representative item that a bar shows instead when it has no room. iOS 16
added three properties, which the header ties to the group's presentation in a bar: `alwaysAvailable`, `menuRepresentation` and
`hidden` (`isHidden`).

## What the port stores

- `alwaysAvailable` is NO by default and keeps the value set. It is a flag on the group, independent of the items.
- `menuRepresentation` is nil by default. A menu is **copied** on set, as the header says, so a change to the menu afterwards does
  not reach the group; nil clears it.
- `hidden` is NO by default and keeps the value set; `isHidden` reads it.

Each is independent of the others and of the items: setting one changes nothing else, and the items are kept as they were.

The port's bars do not present a group differently for these values: they are stored, and the group is shown as it always was.
Measured by `tests/backports/host/bar-group` (13 checks, the host's group and the port's print the same values; the three controls
fail). The host's presentation of a hidden or always-available group in a bar was not measured, since the port's bars do not show
groups.

Source: the host's own UIKit under Mac Catalyst, and the header of SDK 16.4 (`UIBarButtonItemGroup.h`, the three properties at
lines 45 to 51, iOS 16.0).
