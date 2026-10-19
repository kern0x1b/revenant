# UIContextualAction and UISwipeActionsConfiguration, iOS 11.0

Introduced in iOS 11.0: the value an application returns from
`-tableView:leadingSwipeActionsConfigurationForRowAtIndexPath:` and
`-tableView:trailingSwipeActionsConfigurationForRowAtIndexPath:` to say which buttons a
swipe on a row shows - an action with a style, a title, an image, a background colour and
a handler, and a configuration that holds them in order and says whether a full swipe
performs the first.

Source: the host's own UIKit under Mac Catalyst, asked for each answer below and held
against the backport by `tests/backports/host/swipeactions/run.sh`, twenty-five checks, and
an iPad 2 running 6.1.3 through `tests/backports/device/tail11.m`. iOS 12.0's UIKit was
searched for the strings only.

## The action

- `+contextualActionWithStyle:title:handler:` keeps the style, the title and the handler;
  the title is copied, and so is the handler, and a nil title or handler is accepted.
- The background colour is made from the style: the grey 0.78, 0.78, 0.8 for the normal
  style and the system red for the destructive one, and a style that is neither has none.
  Setting a colour to nil puts the style's colour back - a style that has none gets none.
  A colour is copied on the way in.
- An action made by `-init` has style 0, no title, no handler and **no** background colour,
  and setting one to nil gives it the normal style's grey.
- The image is kept as it is, not copied: the host answers the object it was given.
- The class adopts nothing: it does not answer to `-copyWithZone:` and is not archived.
  The style and the handler have no setters.

## The configuration

- `+configurationWithActions:` keeps the array it is given **as it is**, the same object,
  not a copy: an object added to a mutable array afterwards is in the configuration's
  actions. The property says `copy` and does not do it. Nil gives nil, and so does a
  configuration made by `-init`; an element that is no action is accepted.
- `performsFirstActionWithFullSwipe` is YES for a configuration made either way and can be
  set.
- The class adopts nothing and has no setter for the actions.

## What the port answers, and what iOS 6 does with them

The port keeps every answer above, and the red is the one this package gives
`+systemRedColor`, the system red of iOS 7, as it is for `UITableViewRowAction`; the host's
own red is that of its release. What it cannot do is show a button: the table of this
release asks its delegate for a delete confirmation and for nothing else, so the two
delegate methods are never sent - a swipe on a row shows the release's own delete button
when the delegate lets the row be deleted, and nothing when it does not - and no handler
is ever called by a swipe. The classes are carried so that a program that builds and
returns them links and runs; the delegate methods are `ignored` for that reason, which
is the quiet failure the registry entry names.
