# The swipe actions of a table, iOS 8 and iOS 11

`tableView:editActionsForRowAtIndexPath:` (iOS 8, an array of `UITableViewRowAction`) and
`tableView:leadingSwipeActionsConfigurationForRowAtIndexPath:` /
`tableView:trailingSwipeActionsConfigurationForRowAtIndexPath:` (iOS 11, a `UISwipeActionsConfiguration` of
`UIContextualAction`) are what an application answers to say which buttons a swipe on a row shows.

Source: **there is no oracle for the interaction**. The host's UIKit under Mac Catalyst draws no swipe buttons, so the
values (`UITableViewRowAction`, `UIContextualAction`, `UISwipeActionsConfiguration`) are held against it and the behaviour
below is the port's own, checked by `tests/backports/device/swipeui.m` on an iPhone 4S and an iPad 2 running 6.1.3 with
real touches: the test sends digitizer events to the HID event system, so UIKit's own gesture recognizers see a finger. The fraction that makes a full swipe and the duration are set from what the system's swipe looks like and are not measured; the look of a
button is (see the next section).

## What is carried

- The port puts one pan recognizer and one tap recognizer on a table when its delegate is set (`setDelegate:` is
  replaced on `UITableView`, calling the release's own first), on a release whose UIKit lacks `UITableViewRowAction` or
  `UISwipeActionsConfiguration` - the check is that the class comes from the port's library. A release that has the class
  has the behaviour, and the port does nothing there.
- The pan begins for a drag that is more horizontal than vertical, on a row that exists, when the table is not editing, the
  data source does not refuse `canEditRowAtIndexPath:` and `editingStyleForRowAtIndexPath:` is not none, and the delegate
  answers a message for the side of the drag: to the left the trailing configuration, or the row actions; to the right the
  leading configuration. Anything else is left to the release, whose own swipe to delete goes on working.
- The row slides: its content view and accessory move by the drag, and the buttons are laid out in a view behind them at
  the edge, each as wide as it is at rest times the fraction of the way open. The first action is at the edge, and the
  others follow it inward.
- A button is as wide as its title plus 15 points each side and at least 74; its colour is the action's background colour
  (grey for a normal action and red for a destructive one, as the values give); a contextual action's image is drawn
  above the title.
- Letting go opens the row for a drag over half the buttons' width or a flick towards the edge, and closes it otherwise. An
  open row is dragged closed the same way. Only one row is open at a time.
- A tap on a button runs its handler: a row action's with the action and the index path, a contextual action's with the
  action, the button as the source view, and a completion block that closes the row. A row action's row closes after the
  handler returns.
- A drag across more than 65% of the table's width runs the first action when a row action is the source or the
  configuration's `performsFirstActionWithFullSwipe` is YES; otherwise the row stops at its buttons.
- A tap anywhere but on a button closes the open row and is swallowed: nothing is selected. A scroll of the table closes it.
- The delegate is told `willBeginEditingRowAtIndexPath:` when a row starts to open and `didEndEditingRowAtIndexPath:` when
  it has closed.

## When the table changes under an open row

An open row is closed at once, without animation, and the delegate is told `didEndEditingRowAtIndexPath:`, when:

- the table enters editing mode (`setEditing:YES`), and while it is editing no swipe begins;
- the table is reloaded, or rows or sections are inserted, deleted, reloaded or moved;
- the table's width changes, as a rotation makes it change;
- the row is no longer the cell of its index path, which is what a row that scrolled away and was reused looks like.

Each is checked on the devices by `tests/backports/device/swipeui.m`, with a swipe that still opens a row afterwards.

## What is not carried

`backgroundEffect` of a row action, the slide out of a row after a destructive action, the haptics, and right to left layouts
are not carried. An open row is closed by a scroll of the table or a tap, never held open across them.

## The look of a button

A button is drawn as the iOS 6 delete button is, from the release's own button read off an iPad 2 (768 x 1024, scale 1) by
`tests/backports/device/swipelook.m`: a real swipe on a plain table shows the release's button, and the pixels of the screen
are read. The measured button is a rounded rectangle 33 points high and 63 wide for the title "Delete", 6 points in from the
right edge of the row and centred in its 44 point row, made of 33 rows: a dark top edge (91, 52, 54), one row of highlight
(199, 111, 116), fifteen rows of gradient from (237, 130, 136) to (200, 54, 64), fifteen rows of flat red (189, 20, 33) and a
darker bottom edge (147, 16, 26); the sides are (139, 69, 74) fading to (122, 13, 22) at the half; the corner radius is about
4.5 points; the title is bold 14 point white, 40 points wide, with a black shadow at half strength one point up.

The port draws that in a context, so it is sharp at every scale: the destructive style gets exactly those colours, and any
other background colour gets a button of the same shape and brightness steps made from its hue and saturation (lower half
80% of the brightness, the gradient from a paler tone to 90%, edges at 50 to 60%). A pressed button is 25% darker. A button
is at least 63 points wide and as wide as its title and 11.5 points of padding on both sides; the buttons of a row are 6
points apart, the one at the edge 6 points from it, and each is as tall as the release's 33 points however tall the row is
(a shorter row leaves 2 points above and below). The full-swipe growth stretches the first button.

`swipelook.m` puts the release's own delete button and this one on the same screen, takes both as pixels, and holds the
gloss of the port's, from the first gradient row to the last flat one, to the release's within a channel difference of 24
(it is 8 on the iPad 2).

## The button on an iPhone

The release's delete button is not the same on an iPhone: read off an iPhone 4S (scale 2, 640 x 960) by the same test it is as
high (33 points) and as wide (63 points for "Delete") but a lighter red, in half points: 2 rows of dark top edge (44, 28, 28), 1 of
highlight (205, 128, 131), 31 of gradient from (246, 152, 156) to (214, 74, 78), 30 of flat red (207, 43, 45) and 2 of darker
bottom edge (114, 24, 25); the sides go from (107, 59, 61) to (95, 20, 21). The iPad 2's is deeper (flat 189, 20, 33). The port
draws the iPhone's on an iPhone (by `userInterfaceIdiom`) and the iPad's on an iPad. Colours other than the destructive red are
made from the same steps on either.

## Table view controllers

A `UITableViewController` answers `-tableView:willBeginEditingRowAtIndexPath:` and `-tableView:didEndEditingRowAtIndexPath:`
itself, and its answer puts the table in editing mode, which shows the minus controls and closes the swipe. The port no longer
sends those two messages to a delegate whose implementation is the one of `UITableViewController`; a subclass that overrides
them is sent them as before.
