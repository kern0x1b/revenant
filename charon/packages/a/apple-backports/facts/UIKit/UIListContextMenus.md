# Context menus on tables and collection views, iOS 13 and 14

Introduced in iOS 13: the delegate methods `tableView:contextMenuConfigurationForRowAtIndexPath:point:` and
`collectionView:contextMenuConfigurationForItemAtIndexPath:point:` with their preview and multiple selection companions; iOS 13.2
and 14 added the will display and will end methods and the `contextMenuInteraction` of the views.

Source: the header of SDK 26 and the context menu interaction of `UIContextMenuInteraction.md`; the behaviour is the port's own, held
by the `listmenus` group of `tests/backports/host/uikit2` and by `uirest.m` on a device.

## What the port does

A table or collection view whose delegate answers the configuration method gets a `UIContextMenuInteraction` of the port when the
delegate is set: the setter of the release's two classes is wrapped and checks the delegate. `contextMenuInteraction` answers that
interaction, made on the first ask when the delegate wanted none, so it is never nil. The interaction's delegate is an object of the
port that asks the view for the row or item under the point of the long press - `indexPathForRowAtPoint:` or
`indexPathForItemAtPoint:` - and asks the application's delegate for the configuration, giving it the index path and the point. No row
and no delegate method are no question and no menu. The configuration's menu is shown as the action sheet of the interaction, and
its display and end are told to the delegate as `willDisplayContextMenuWithConfiguration:animator:` and
`willEndContextMenuInteractionWithConfiguration:animator:`, with an animator that runs added animations at once.

## What is not there

The preview delegate methods - highlighting, dismissing and the commit of a preview - are never sent: the sheet has no preview to
morph, dismiss to or commit. The three multiple selection methods are never sent, since iOS 6 has no two finger selection gesture.
`collectionView:canEditItemAtIndexPath:` and the two index title methods of the data source are never sent either, the collection view
of the release having no editing state to ask about and no index bar.
