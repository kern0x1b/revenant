# Menus on controls, bar button items and segmented controls, iOS 14

Introduced in iOS 14: `UIButton.menu`, `UIControl.showsMenuAsPrimaryAction`, `contextMenuInteractionEnabled`, the delegate methods a
control answers for its context menu interaction, `UIBarButtonItem` with a primary action or a menu, and the segmented control made
of actions.

Source: the host's own UIKit under Mac Catalyst (macOS 27.0), run in a process of its own, and held against the backport by the
`controlmenus` group of `tests/backports/host/uikit2` (32 lines of answers compared); `tests/backports/device/uirest.m` for the
sheets on a device.

## Buttons

`UIButton.menu` is a copy of the menu (equal to it, not the same object). Setting one enables the control's context menu interaction,
whose delegate is the button, and clearing it disables it; `contextMenuInteractionEnabled` and `contextMenuInteraction` follow, the
interaction being nil while the control has none. `showsMenuAsPrimaryAction` is kept whether or not there is a menu. The button's
configuration answer is one whose action provider gives the current menu, and a control that is not a button answers nil, as the host
does. A long press shows the menu as the action sheet of the context menu interaction; with `showsMenuAsPrimaryAction` a touch up
inside shows it as well, where the host shows it on touch down, which a sheet cannot do: it would appear and be dismissed with the
finger. The preview and dismissing preview answer nil, the will display and will end methods do nothing, and the attachment point is
the origin, since a sheet is not attached to anything.

The host refuses `contextMenuInteractionEnabled = YES` on a switch, a slider or a text field, which the port allows; a control of a
subclass that answers the delegate's configuration shows a menu.

## Bar button items

An item made with a primary action has the action's title, and its image when there is one; a system item takes neither. `primaryAction`
is a copy of the action. `menu` is a copy of the menu. Setting an action later gives the item its title and image too, and removing it
leaves them. Changing the title afterwards does not change the action's. What the item does when tapped is the port's: it takes the
item's `target` and `action`, so those answer the port's while the item has an action or a menu (the host leaves them nil), and
tapping runs the action with the item as its sender, or shows the menu as an action sheet on the key window with a hidden view as
the source.

An item given a menu while it already has an action of the application's own keeps that target and action, and a tap sends it:
UIKit shows such an item's menu on a long press, and an item of the release is not a view the port can give one, so the menu is kept and
not shown - as with an item that has both a primary action and a menu. Before 2026-09-23 the port took the target and action over
for the menu here too, and the application's action was lost without a word.

The space items `+fixedSpaceItemOfWidth:` and `+flexibleSpaceItem` are system items of those kinds.

## Bar button items, iOS 16

`-initWithPrimaryAction:menu:` and `-initWithBarButtonSystemItem:primaryAction:menu:` are the iOS 14 initialisers with the action, and
then the menu set (`UIKit/UIBarButtonItem+Menu16.m`). `-initWithTitle:image:target:action:menu:` is a plain item with the title, the
target and the action, the image when there is one, and then the menu; with no action a tap shows the menu, with one the rule above
holds. The three are composed from what the port already carries, not held against the host - Catalyst is not on this machine - and not
measured on a device. Ladder, by `objc.inventory` with `initWithBarButtonSystemItem:menu:` as the positive control and an invented
selector as the negative one: none of the three is in `UIBarButtonItem`'s methods in 6.1.3 or 12.0, all three are in 16.0 and 18.0; with
no 13-15 cache that bounds them to 12.0-16.0, and `introduced` stays the header's 16.0.

## Segmented controls

`-initWithFrame:actions:` inserts a segment for each action with none selected: the action's image if it has one, else its title, as
the host does. The actions are kept by a copy, so `actionForSegmentAtIndex:` answers an equal action and not the same one; plain
segments have none and an index out of range answers nil. `segmentIndexForActionIdentifier:` answers the index or `NSNotFound`. Two
segments with one identifier raise "Attempting to set the action of segment at index 1 with an action whose identifier is the same as
the segment at index 0 (action=...). Identifiers are required to be unique." The actions follow their segments when segments are
inserted or removed by title or image - the port wraps the four methods of the release to keep them in step - and the segmented
control performs the selected segment's action when its value changes.

The host does not run the action when the value change is sent by hand; the port does, since the release's control has no other
way to tell.

## On a device, iOS 6.1.3

On an iPad 2 of iOS 6.1.3 (2026-09-23), a process of the band's own (`.agent-work/runs/b1314-live/main.m`, output `run4-all.txt` beside it) loaded the gate's `libUIKitBackports.dylib` and checked the three `UIBarButtonItem` initialisers of the last round: the title, image, target, action and menu one keeps the application's target and action with the menu (a copy - the property is `copy`), and the two primary-action ones keep the action and the menu. What a tap on such an item does was not run: a process has no window to tap in.
