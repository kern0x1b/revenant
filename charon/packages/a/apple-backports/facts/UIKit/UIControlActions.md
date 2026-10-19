# Actions on a control, iOS 14

Introduced in iOS 14: `UIAction` handlers on a `UIControl` - `addAction:forControlEvents:`, `removeAction:forControlEvents:`,
`removeActionForIdentifier:forControlEvents:`, `enumerateEventHandlers:`, `sendAction:` and the initialisers with a primary action.

Source: the host's own UIKit under Mac Catalyst (macOS 27.0), run in a process of its own before the port's code is loaded, and held
against the backport by the `controlactions` group of `tests/backports/host/uikit2`; `tests/backports/device/uirest.m` for a device.

## What the host does

- An action is one entry per identifier. Adding one whose identifier is already there removes the first entry and appends the second
  with the union of the events, so an action added for touch up inside and again for touch down is one entry of both events at the end
  of the list. Removing by an action or by an identifier is by the identifier, so an equal action of another object removes the
  first; taking one event away leaves the entry with the others, and none left removes it.
- A nil action raises `NSInternalInconsistencyException`, "Attempt to set nil action with event mask:00000040"; no events raise "Attempt
  to set action '<UIAction ...>' with no event mask set".
- `enumerateEventHandlers:` lists everything in the order it was added: target and action pairs with their selector and the events
  they were added for as one mask, and actions with their events. `allTargets` does not contain the actions.
- The handler runs with the control as the action's sender, on each of its events, in the order added among the targets too.
- `removeTarget:nil action:NULL forControlEvents:` on all events removes the actions with the targets.
- `-initWithFrame:primaryAction:` adds the action for `UIControlEventPrimaryActionTriggered`; a button also gets the action's title
  and image.

## How the port does it

An entry is an object that holds the action and its events, and a proxy target registered on the control with `addTarget:action:` for
the events, so the control's own machinery sends it. Whether an entry is still there is asked of the control each time, by whether
its proxy is still a target for the events, so `removeTarget:...` needs no hook. The primary action event is registered for itself
and for the event that triggers it on this release, which sends none: touch up inside for a button, value changed for a switch, a
slider, a stepper, a segmented control, a page control and a date picker, editing did end on exit for a text field, and for a plain
control nothing, as in the host. Sending the event by hand fires it too.

`enumerateEventHandlers:` lists the target and action pairs first, found from `allTargets` and `actionsForTarget:forControlEvent:`
one event bit at a time, then the actions in order; the release does not say in which order pairs and actions were added, so the two
kinds do not interleave, and the tests sort the rows. The host's UIKit sends the primary action event itself after touch up inside
and after value changed, so on the host the port's proxy, registered for both, runs twice for one touch; on iOS 6, which sends only
the one, it runs once - the test collapses repeats.

## `UIControlEventPrimaryActionTriggered` itself

The event is iOS 9's and the release never sends it; a target added for it by `addTarget:action:forControlEvents:` is not run by the
release, and the port does not change that (the host runs it after touch up inside).

## Buttons

`+buttonWithType:primaryAction:` and `-initWithFrame:primaryAction:` give the button the action's title and image and add the action.
`+systemButtonWithPrimaryAction:` and `+systemButtonWithImage:target:action:` use `UIButtonTypeSystem`, which on this release is the
rounded rect type. `UIButton.role` is kept and the first role other than normal says so once in the log. The preferred symbol
configuration for an image in a state is kept and read back, with the normal state's for `currentPreferredSymbolConfiguration`; there
are no symbols to configure.
