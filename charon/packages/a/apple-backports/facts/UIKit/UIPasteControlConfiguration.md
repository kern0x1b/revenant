# UIPasteControlConfiguration, iOS 16.0

Introduced in iOS 16.0: the look of a paste control (`UIPasteControl`): what its button shows (an icon, a label, or both, and where the
icon sits), its corners, and its two colours. A configuration is a value that the control reads when it is made; the control itself is not
here (see below).

Declarations: the generator's rows for SDK 16.4 (`corpus/sdk-16.4-declared.json`) and `spec/UIKit/declarations.tsv` (`ios=16.0` on the class).
The class is `NSObject` and conforms to `NSSecureCoding`; the header marks no `-init` unavailable.

Source: the host's own UIKit under Mac Catalyst (macOS 27.0.1), measured by `tests/backports/host/paste-config`, which compiles the port
source beside the host's class in one process and prints the same checks for both.

## As UIKit does

- The defaults, from the runtime `-init`: `displayMode` 0 (`UIPasteControlDisplayModeIconAndLabel`), `cornerStyle` 2
  (`UIButtonConfigurationCornerStyleMedium`), `cornerRadius` 0, `imagePlacement` 2 (`NSDirectionalRectEdgeLeading`), and nil colours.
- Each property is stored as set: an integer, a corner style, a radius, a placement and two colours. Setting a colour to nil clears it.
- The class supports secure coding. An archive made with `NSKeyedArchiver` decodes, through `NSKeyedUnarchiver`, to an object of the same
  class with the same six values: the enum values, the radius, and the colours (a nil colour stays nil).

## What the port does

- `UIKit/UIPasteControlConfiguration.m`: `-init` sets the two non-zero defaults (the cornerStyle and the placement) and leaves the rest at the
  ivars' zero values. The six properties are readwrite, as the header says, with the ivars the class holds.
- `+supportsSecureCoding` answers YES. `-encodeWithCoder:` writes each property under its own name (the integers as integers, the radius as a
  double, the colours as objects); `-initWithCoder:` reads them back. The archive keys are the port's own; they are read only by this class, so
  they need not match the host's archive bytes, which the host differential does not compare.

## What is not measured

- The archive bytes themselves: the differential checks the round trip, not the layout of the archive.
- The colours are compared by `isEqual:` after a round trip, so a colour's colour space and components are not compared beyond equality.

## Owed: the control

- `UIPasteControl` (`initWithConfiguration:`, `configuration`, `target`) stays absent in `registry/UIKit/ios15-16.json`. It is a `UIControl`
  whose target is a `UIPasteConfigurationSupporting`, per the header; drawing it needs the button configuration's appearance machinery the
  port does not carry, and nothing in the port could show the configuration this page covers.

## Caveats

- **device-unverified.** The port has not run on the iPhone 4S or the iPad 2. The class is plain Objective-C state and the archive, so the host
  run is its oracle; the control that shows the configuration is not present on any target.
