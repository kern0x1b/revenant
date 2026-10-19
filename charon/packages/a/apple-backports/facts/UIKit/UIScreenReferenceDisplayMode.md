# UIScreen reference display mode and EDR headroom, iOS 16.0

`referenceDisplayModeStatus`, `UIScreenReferenceDisplayModeStatusDidChangeNotification`, `currentEDRHeadroom` and
`potentialEDRHeadroom`. A reference display mode is the colour-accurate mode some iPad Pro screens have; EDR headroom is the ratio of
the brightest white a screen can show to its SDR white (SDK 16.4 `UIScreen.h`).

## What the port does (`UIKit/UIScreen+Reference16.m`)

- `referenceDisplayModeStatus` answers not supported, the first value of the enumeration, whose comment is "reference display modes are
  not supported on this display". The screens of the iPhone 4S and iPad 2 have no such mode.
- `UIScreenReferenceDisplayModeStatusDidChangeNotification` is exported, with the value `UIScreenReferenceDisplayModeStatusDidChangeNotification`
  read from UIKitCore's export of the 16.0 cache (`tools/corpus/cache-value.lua` on the 16.0 cache, with
  `UIScreenDidConnectNotification` read the same way as the control). It is never posted: a status that cannot change has nothing to
  announce, and an observer simply never hears it.
- `currentEDRHeadroom` and `potentialEDRHeadroom` answer 1: those screens show nothing brighter than SDR white, so the brightest white is
  SDR white and the ratio is one. That 1, rather than 0, is the system's answer on a screen without EDR follows from the header's
  definition of headroom as a ratio; it was not read from a device of iOS 16.

Ladder: by `objc.inventory` (`ladder-rest.log`), the three getters are not in `UIScreen`'s methods in 6.1.3 or 12.0 and are in 16.0 and
18.0; the notification is not exported by UIKitCore in 12.0 (`tools/corpus/cache-value.lua` on the 12.0 cache, `UIApplicationOpenSettingsURLString` found there as the
control) and is in 16.0. There is no 13-15 cache, so `introduced` stays the header's 16.0. Run on a device: the last section.

## On a device, iOS 6.1.3

On an iPad 2 of iOS 6.1.3 (2026-09-23), a process of the band's own (`.agent-work/runs/b1314-live/main.m`, output `run4-all.txt` beside it) loaded the gate's `libUIKitBackports.dylib` and checked headroom 1 and 1 and the status not supported on the main screen, and the notification's string; as described.
