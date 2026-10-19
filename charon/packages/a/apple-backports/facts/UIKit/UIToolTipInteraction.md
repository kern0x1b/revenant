# UIToolTipInteraction and UIToolTipInteractionDelegate, iOS 15.0

Introduced in iOS 15.0: an interaction an app adds to a view to show a tool tip while a pointer rests on it. The app gives the tip as a string
(`defaultToolTip`), or the delegate answers for a point with a `UIToolTipConfiguration` (`facts/UIKit/UIToolTipConfiguration.md`). The class
conforms to `UIInteraction` and is attached with `addInteraction:` like the other interactions.

Declarations: the generator's rows for SDK 16.4 (`corpus/sdk-16.4-declared.json`) and `spec/UIKit/declarations.tsv` (`ios=15.0`). The header
marks both unavailable on watchOS and tvOS. The delegate has one optional method, `toolTipInteraction:configurationAtPoint:`.

Source: the host's own UIKit under Mac Catalyst (macOS 27.0.1), measured by `tests/backports/host/tooltip-interaction`, which compiles the port
source beside the host's class in one process and prints the same checks for both.

## As UIKit does

- A new interaction is enabled, holds no default tip, has no delegate, and has no view.
- `initWithDefaultToolTip:` keeps the string it is given, as the same object (a mutable string changed afterwards shows the change). The header
  says the property is `copy`; the host does not copy it, and the port does not either.
- `setDefaultToolTip:` keeps the object given in the same way, and a nil clears it.
- Adding the interaction to a view makes that view its `view`; adding it to another view moves it and leaves the first view with none;
  adding it to a view that already holds it keeps one. Removing it clears `view`.
- `setEnabled:` and `isEnabled` read back what was set.
- The delegate is held weakly and reads back as set.
- The interaction has no `setView:` and no `copyWithZone:`: the view is set only by the view that holds the interaction.

## What the port does

- `UIKit/UIToolTipInteraction.m`: the class holds the enabled flag, the default tip, the delegate (weak) and the view (weak). `init` and
  `initWithDefaultToolTip:` set enabled to YES. The view moves the interaction through `willMoveToView:` and `didMoveToView:`, which the port's
  view category (`UIKit/UIView+Interactions.m`) calls on add and remove; the interaction keeps the view it is given.
- The class declares `<UIInteraction>` through its header, so `UIInteraction` answers on the class.
- The delegate protocol is kept in the image by a function the object keeps (`__attribute__((used))`) that returns `@protocol(...)`. Measured on
  the armv7 object of `UIToolTipInteraction.m` compiled for 6.1.3 against the 16.4 SDK: `nm -m` places
  `__OBJC_LABEL_PROTOCOL_$_UIToolTipInteractionDelegate` in `__DATA,__objc_protolist`, so `NSProtocolFromString` answers the name in the port's
  image. A type reference alone (`id<UIToolTipInteractionDelegate>` in a property) emits nothing, which is why the function is there.

## The pointer

The tip is shown when a pointer rests on the view, and the system then asks the delegate `toolTipInteraction:configurationAtPoint:` for the
configuration at that point. The 4S under 6.1.3 has no pointer, so the system never asks, and the port never asks either: nothing in the port
calls the delegate or draws a tip. The attach, the detach, the enabled flag, the default tip and the delegate are the state an app reads and
sets, and they are the whole of what runs on that device. That the release asks for nothing on a device with no pointer follows from the header
(the request is made for a pointer's hover); it is not measured on a device.

## Named differences

- None measured in the differential. The host's class has no hidden setters for the view or copy behaviour (`setView:` and `copyWithZone:` are
  absent on both sides).

## Caveats

- **device-unverified.** The port has not run on the iPhone 4S or the iPad 2. The class is plain Objective-C state; the host run is its oracle
  for everything but the pointer, which neither side measures without a pointer.
- The host differential runs without a window. Attaching to a view in a window is the same call; the port's view category is the one that
  runs on the device, and the differential exercises the host's view, which makes the same calls on the interaction.
- The delegate's tip configuration (`toolTipInteraction:configurationAtPoint:`) is not called on either side in the differential, since
  neither side has a pointer to hover; `UIToolTipConfiguration` is measured on its own (`facts/UIKit/UIToolTipConfiguration.md`).
