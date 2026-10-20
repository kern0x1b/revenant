# UIToolTipConfiguration, iOS 15.0

Introduced in iOS 15.0: the text and the region of a tool tip. A configuration holds the string a tool tip shows and the rectangle it
annotates; a tool tip interaction (`UIToolTipInteraction`, still absent in `registry/UIKit/ios15-16.json`) asks its delegate for one at a
point under the pointer. The configuration is a value: nothing in the port shows a tool tip, since the port has no pointer.

Declarations: the generator's rows for SDK 16.4 (`corpus/sdk-16.4-declared.json`) and `spec/UIKit/declarations.tsv` (`ios=15.0` on the class,
`-init` and `+new` marked unavailable in the header).

Source: the host's own UIKit under Mac Catalyst (macOS 27.0.1), measured by `tests/backports/host/tooltip-config`, which compiles the port
source beside the host's class in one process and prints the same checks for both.

## As UIKit does

- `+configurationWithToolTip:` applies the string to the whole view: the configuration's `sourceRect` is `CGRectNull`.
- `+configurationWithToolTip:inRect:` keeps the rectangle as given, including `CGRectZero`, which is not the same as the whole view.
- The string is copied: a mutable string changed after the factory call does not change the configuration's `toolTip`, and the copy is
  immutable.
- A nil string gives an object with a nil `toolTip`.
- The runtime `-init` answers a configuration with a nil `toolTip` and a zero `sourceRect`.

## What the port does

- `UIKit/UIToolTipConfiguration.m`: both factories build the configuration through `revenant_initWithToolTip:inRect:`, which copies the string and
  keeps the rectangle. The whole-view factory passes `CGRectNull`, as the header names it. The runtime `-init` answers the zero state through the
  ivars' zero values.
- `toolTip` and `sourceRect` are the header's readonly properties, and the port's getters answer the stored values.

## A named divergence, not a gap

- **The host has hidden setters.** `setToolTip:` and `setSourceRect:` are answered by the host's class although the header declares both
  properties readonly, and each stores the value it is given (the host's `toolTip` reads back `Changed` after a set, its `sourceRect` reads back
  the rectangle set). The port has no such setters, as the header says, and the release's own behaviour is not carried. No public header declares these setters, so only an app that calls them by name (undocumented
  API) would notice the port's absence. The divergence is asserted
  by `tests/backports/host/tooltip-config/run.sh`: if the host stops storing the set, that run fails so the port can be revisited.

## What is not measured

- `+new` is declared unavailable. The runtime answer is `NSObject`'s `+new`, which calls `init`; the `init` answer is measured, the `+new` path
  is not separately measured.
- The tool tip the system shows, and where, is not measured: the host run only reads the configuration back, since no pointer is present.

## Caveats

- **device-unverified.** The port has not run on the iPhone 4S or the iPad 2. The class is plain Objective-C state, so the host run is its
  oracle.
