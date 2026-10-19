# UIControl.toolTip and UIControl.toolTipInteraction, iOS 15.0

Introduced in iOS 15.0: a control's tool tip. Setting `toolTip` gives the control a tool-tip interaction (`UIToolTipInteraction`,
see its facts) that shows the string while a pointer rests on the control. `toolTipInteraction` is the control's default one.

Declarations: the SDK 16.4 header (`UIControl.h`, lines 141 to 144) and `spec/UIKit/declarations.tsv` (`ios=15.0`). The properties are
unavailable on watchOS and tvOS.

Source: the host's own UIKit under Mac Catalyst (macOS 27.0.1), measured by `tests/backports/host/control-tooltip`, which runs the
host's control and the port's category in two processes and requires the same 26 lines from both. The 6.1.3 cache holds neither name
(`tools/corpus/objc-inventory.lua`).

## As UIKit does (measured)

- `toolTip` is nil on a fresh control, and `toolTipInteraction` is nil too: no interaction exists until a tool tip is set.
- Setting a tool tip creates a `UIToolTipInteraction`, adds it to the control's `interactions` (count 1), makes the control its view, and
  gives it the tool tip as its default tip. It is enabled.
- A later tool tip reuses that interaction: the same object, with its default tip changed.
- The tool tip is kept by reference. The copy the header's `copy` attribute suggests is not made: the object read back is the object
  given, and a later change to a mutable string shows through both `toolTip` and the interaction's default tip.
- Setting nil clears `toolTip`, removes the interaction from the control, and makes the control's `toolTipInteraction` nil. The removed
  interaction has no view and keeps the default tip it had.
- The next non-nil tool tip creates a new interaction; the old one is not revived.
- An empty string is a tool tip: it is kept, and an interaction is created with it as the default.

## What the port does

- `UIKit/UIControl+ToolTip15.m` keeps both as associated objects on the control: the tool tip retained, the interaction retained. The
  setter does what the list above describes, through `addInteraction:` and `removeInteraction:`, which the port's `UIView+Interactions.m`
  supplies for a device whose UIKit has no interaction list.
- The port's interaction is `UIKit/UIToolTipInteraction.m`, which the tool-tip facts describe.

## Caveats

- **device-unverified.** The port has not run on the iPhone 4S or the iPad 2. Neither has a pointer, so the tip is never shown on
  them; the state, the attach and the detach are what the port does, and they are the host's.
- The differential runs the host's control and the port's category in separate processes, because the category is on the host's
  `UIControl` and would replace its methods in one process.
