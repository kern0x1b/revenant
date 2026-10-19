# UIAlertController and UIAlertAction, iOS 8

Source: the host's own UIKit, under Mac Catalyst, asked for every answer below and held against the backport by
`tests/backports/host/alert/run.sh` (121 checks, the system and the backport built the same way and compared);
and iOS 6.0 and 6.1.3 on the emulator, an iPhone 4S and an iPad 2, through `tests/backports/device/alert.m`, which
presents the alerts and sheets on the device.

## An action

An action is a title, a style and a handler. The factory makes one that is enabled; a plain `-init` makes one with no
title, the default style and enabled. A nil title stays nil - the newest release asks for one only on a pad. The
class is `NSCopying`, and a copy is a different object with the same title, style, enabled flag and handler, and whether it
equals the original is what the system answers; enabling the copy leaves the original as it was.

## A controller

A controller keeps its title, message and preferred style, and a plain `-init` has the same style as the system's.
It has no actions and no text fields at first - the arrays are there, empty - and no preferred action. `title` and
`message` are settable, and a message set to nil reads nil.

Actions are added in order and kept in it, by identity; `-actions` answers a snapshot, so an action added later is
not in an array read earlier. The rules the newest release enforces are enforced the same way, by the same
exception:

- a second cancel action raises, and so does a copy of the cancel action, which is a second one;
- the same default action added twice is accepted, and stands twice in the list;
- adding nil raises;
- a preferred action that is not one of the actions raises, and leaves the preferred action nil; a copy of a member is not a
  member and raises; a member is accepted and kept, and nil clears it again.

Text fields are added by a handler that the controller calls at once, before the method returns, with the field, and
what the handler set on it is what the field holds afterwards; the field listed is the field the handler was given.
An action sheet raises when asked for one. A second field is accepted. A third one is accepted by the newest release, and the port raises
`NSInternalInconsistencyException` for it: the two fields of a login alert are all a `UIAlertView` holds.

An alert has no popover presentation controller. An action sheet on a pad has exactly one, the same object every time,
which keeps the source view and the source rectangle it is given and allows every arrow direction.

## What iOS 6 shows

iOS 6 has no `UIAlertController`, so the controller builds the native view the release has and takes over as its delegate:

- an alert is a `UIAlertView` with the title and message, the cancel action first and the other actions after it in
  the order they were added; a nil action title is shown empty. It has a cancel index only when there is a cancel
  action, and starts the others at zero when there is none. A message changed afterwards reaches the view;
- an action sheet is a `UIActionSheet` in the order added with the cancel action last, the first destructive action as
  its destructive button, and the title and message joined by a line break in the title - the message alone when there
  is no title, and no title when both are empty;
- no text field gives the default alert style; one plain field gives a plain text input, one secure field a secure
  one, and two fields the login and password input, with the placeholder, text, keyboard type, secure flag and target
  actions the handlers set carried to the native fields, and what is typed copied back to the fields the controller lists,
  with the change notification posted for them;
- an action is run once, when the view is dismissed with its index, and only if it is enabled; a disabled action runs
  nothing, an index of -1 runs nothing, and a view that has been dismissed already runs no handler again;
- the first other button of an alert is disabled while its action is, and enabled when there is no other button.

## `severity`, iOS 16.0

`UIKit/UIAlertController+Severity16.m` keeps the value set, default until then, and nothing reads it. The header of SDK 16.4 has the
two values and no comment; a critical alert is drawn differently only in the Mac idiom (the reason on the old registry row, not read
from a Mac here), so on a phone or tablet a kept value that changes nothing is what the system does. `objc.inventory`
(`.agent-work/plan-and-analysis/b1314-flips/ladder-rest.log`): getter and setter are not in 6.1.3 or 12.0 and are in 16.0 and 18.0; no
13-15 cache, so `introduced` stays the header's 16.0. Run on a device: the last section.

## On a device, iOS 6.1.3

On an iPad 2 of iOS 6.1.3 (2026-09-23), a process of the band's own (`.agent-work/runs/b1314-live/main.m`, output `run4-all.txt` beside it) loaded the gate's `libUIKitBackports.dylib` and checked `severity` default until set and kept; as described.
