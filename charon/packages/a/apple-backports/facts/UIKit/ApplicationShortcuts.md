# Application shortcut items and the shortcut bar over the keyboard, iOS 9

Source: the host's own UIKit, recorded for the defaults, the copies and the archive, and held against the port by the checks
of `tests/backports/device/uikit2.m`.

## Shortcut items

`UIApplicationShortcutItem` is made with a type and a localized title, and with a subtitle, an icon and a dictionary; it
answers what it was made with, copies to another item, and `mutableCopy`s to a `UIMutableApplicationShortcutItem`, whose
setters change the fields, and whose copy is an immutable item. The icon is made from a system type or a template image name.
`UIApplication.shortcutItems` keeps the array it is given, and `nil` at first. The key `UIApplicationLaunchOptionsShortcutItemKey`
is carried and never present in the launch options.

A quick action needs a pressure-sensitive screen, which the devices this port runs on do not have, and a home screen that
shows the items, which iOS 6 does not have; nothing shows a shortcut item and nothing performs one, so the classes and the
property are `inert`, and `application:performActionForShortcutItem:completionHandler:` is never sent.

## The bar over the keyboard

`UIBarButtonItemGroup` keeps its items and its representative item, is archived, and says it is not displaying its
representative item; each item knows its group. `UITextInputAssistantItem` keeps two arrays of groups and whether the system
may hide the shortcuts, which it may; `UIResponder.inputAssistantItem` answers one item of its own for every responder.
iOS 6 has no such bar, so nothing is shown and both are `inert`. The first time an application puts a group that is not
empty into `leadingBarButtonGroups` or `trailingBarButtonGroups` the port says so once in the log, since an item kept and
never drawn is the kind of inaction an application has no other way of noticing; an empty array says nothing, because
clearing the groups asks for nothing to be drawn.

## `targetContentIdentifier`, iOS 13

`UIApplicationShortcutItem.targetContentIdentifier` is what a scene activation condition matches a shortcut against. It is
readonly on the item and writable on `UIMutableApplicationShortcutItem`, nil until set, and a set is **copied** (a mutable
string given is copied, so a change to it afterwards does not reach the item), as the header says and the host does. Nil
clears it. A copy of a mutable item is an item and keeps the identifier; a mutable copy keeps it too; copying an item returns
the item itself. Measured by `tests/backports/host/shortcut-item` (11 checks, the port and the host print the same values; the
three controls fail): the port's classes answer as the host's do, with the CharonPort prefix stripped from their names.
