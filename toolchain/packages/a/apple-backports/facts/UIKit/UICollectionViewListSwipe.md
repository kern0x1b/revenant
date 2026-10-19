# Swipe actions of a list: the providers, iOS 14.0

`UICollectionLayoutListConfiguration.leadingSwipeActionsConfigurationProvider` and `trailingSwipeActionsConfigurationProvider`, with `UIContextualAction` and `UISwipeActionsConfiguration`, on the rows of a list.

Source: the header of SDK 16.4 and the swipe of the table view the package already carries (`UITableView+SwipeActions.m`), whose buttons and gestures the list reuses (`CharonSwipeViews.m`). The host's UIKit under Mac Catalyst draws no swipe on a row, so there is no oracle for the pixels; the touch behaviour is checked on an iPhone 4S by `tests/backports/device/lists.m` with real touches.

## What the port does

- A horizontal drag that begins on a list cell asks the provider of the side it moves towards: left asks the trailing provider, right the leading one; the layout the cell belongs to gives the configuration (a section made by `sectionWithListConfiguration:layoutEnvironment:` remembers its own, so a layout built from a section provider works). The provider is asked with the item's index path, and answers nil or no actions to leave the row alone.
- The content of the row and its accessories slide, the buttons appear behind them from the edge, each with its title, its image and its background colour (the style gives one where none was set: grey for normal, red for destructive), the first action at the edge. A drag past half the buttons, or a fast one, opens and holds; less closes.
- A tap on a button runs the action's handler with the action, the button as the source view and a completion block; the row closes when the block is called, whatever it is given. With `performsFirstActionWithFullSwipe` (the default) a drag across most of the row runs the first action.
- A tap elsewhere, a scroll, a reload and a batch update close the row that is open. A list in editing does not swipe.

## What the port does not do

- The completion block's answer is not used: the host removes a row whose destructive action completed with YES only if the application removes the item, and the port leaves that to the application as well.
- The buttons are the port's own, not the host's: 74 points wide at least, 15 points of padding, a 15 point title.
