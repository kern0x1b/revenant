# GCMouse and GCMouseInput, iOS 14

Corpus ranks 7-10, 3 applications, 2 owners: `GCMouse.mouseInput`, `GCMouseInput.middleButton`,
`.mouseMovedHandler`, `.scroll`. An external mouse is peripheral the owner may attach over
Bluetooth, not hardware absent from the phone - the 4S and iPad 2 both have Bluetooth - so this is
the same capability-honest device-template verdict the whole GameController peripheral cluster
got (coordination verdict, 2026-09-22): the class exists, the profile is real, and the only
undetected fact is a physical mouse actually being connected.

## What was there before this pass

`GCMouse.m` declared `@dynamic mouseInput, handlerQueue, vendorName, productCategory;` with no
implementation anywhere - a live instance calling `.mouseInput` would have raised an unrecognized
selector. `GCMouseInput` (in `GCDeviceClasses14.m`) was the same: `@dynamic mouseMovedHandler,
scroll, leftButton, rightButton, middleButton, auxiliaryButtons;`, nowhere implemented. Neither
crashed in practice only because `+[GCMouse mice]` and `+[GCMouse current]` always answered
empty/nil, so no application ever obtained a live instance to call the dynamic properties on - but
the moment either factory method got a real answer, or an application called `-init` directly, the
crash was live.

## What this pass does

`GCMouse` now has a real designated initializer: it builds a real `GCMouseInput`
(`-[GCMouseInput init]`, the same spec-driven `-initWithCharonSpecs:` pipeline
`GCPhysicalInputProfile14.m` already gives `GCController`'s own profiles) and attaches it via
`charon_setDevice:`. `handlerQueue` defaults to the main queue and is a real stored property;
`vendorName` answers `"Mouse"`, `productCategory` the real `GCProductCategoryMouse` constant
(`GCConstants15.m`).

`GCMouseInput`'s `leftButton`/`rightButton`/`middleButton` are real `GCControllerButtonInput`
elements, and `scroll` a real `GCDeviceCursor` - both built through a new `mouseSpecs` table
(`CharonGCTables.m`) and a new `"cursor"` element kind added to
`-[GCPhysicalInputProfile initWithCharonSpecs:]`'s dispatch (`GCDeviceCursor` is itself a
`GCControllerDirectionPad` subclass, so the existing dpad axis/button linking logic picks it up
without further change). `mouseMovedHandler` is a real, copied, settable block property.
`auxiliaryButtons` answers `nil` - the header already allows this for a mouse with none, and this
port has no real mouse to measure a count for.

## What differs from the release

`+[GCMouse mice]` still answers an empty array and `+[GCMouse current]` still answers `nil`: no
Bluetooth HID mouse pairing or connection detection is built. This is the genuine, named boundary
- whether iOS 6.1.3's Bluetooth stack recognizes a paired HID mouse at all is a real, unmeasured
device question, distinct from and larger than making the object model itself crash-safe and real,
which this pass does. `mouseMovedHandler` is real and safe to set but is never called, for the same
reason: there is no live pointer-delta source to call it with. `GCDeviceCursor`'s axis range is
reported the same normalized `[-1, 1]` a dpad uses, not the width/height-scaled range the header
describes for a cursor - a real, stated simplification, not a silent one.
