# UIKeyCommand wantsPriorityOverSystemBehavior, allowsAutomaticLocalization and allowsAutomaticMirroring, iOS 15

Source: the SDK 16.4 header of `UIKeyCommand.h`, and iOS 6.0 on the emulator and iOS 6.1.3 on an iPad 2 and an iPhone 4S, through
`tests/backports/device/ios1516.m`. The three accessors were not disassembled: the header states what each means, and what the
newest release does with them is decided by its keyboard and shortcut system, which iOS 6 does not have.

## What the header says

- `wantsPriorityOverSystemBehavior` (default NO): the command takes priority over a system key shortcut that uses the same keys.
- `allowsAutomaticLocalization` (default YES): the command's input is mapped to the keyboard layout in use, so that a shortcut
  made for one layout is reached on another.
- `allowsAutomaticMirroring` (default YES): the command's input is mirrored for a right to left layout direction.

## What the port does

iOS 6 sends an application the keys of a hardware keyboard, and the system's own shortcuts are handled before it sees them, so
there is no shortcut to take priority over; and it maps no key by layout or direction. The three properties are kept and
answered back with the defaults the header names, and are inert: an application that sets `wantsPriorityOverSystemBehavior` to YES
is told once, in the log, that the priority is not applied. The other two say nothing when set, since NO, the value they may be
set to, is what iOS 6 does; what an application that leaves them YES expects, a shortcut that follows the layout, is not done.

## What was measured

A key command made on the emulated iOS 6.0, the iPad 2 and the iPhone 4S starts with the priority NO and the other two YES, keeps
each one set independently, and the log line appears once, the first time the priority is set to YES.
