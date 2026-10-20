# Behavioral styles, iOS 15.0 and 16.0

`behavioralStyle` and `preferredBehavioralStyle` of `UIButton` and `UISlider` (15.0) and of `UINavigationBar` (16.0), and the bar's
`currentNSToolbarSection` (16.0). A behavioral style says whether a control draws and behaves as an iOS control (pad) or as a Mac one
(mac); `UIBehavioralStyle.h` of SDK 16.4 calls pad "a style and set of behaviors best for iOS/iPadOS applications" and says
`behavioralStyle` always answers a resolved style, never automatic.

## What the port does (`UIKit/UIBehavioralStyle.m`)

- `behavioralStyle` answers pad for all three. The mac style exists only for a Mac Catalyst application; a phone or tablet of the
  release has only the iOS controls, so pad is the answer such a device gives, not a placeholder.
- `preferredBehavioralStyle` keeps what was asked, automatic until set, and changes nothing: asking for mac on a phone or tablet
  resolves to pad, as it does on the system's iPhone and iPad.
- `currentNSToolbarSection` answers none: the bar's contents are placed in an `NSToolbar` only in a Mac window, and the release has
  no toolbar of that kind.

That the system on an iPhone answers pad for a control whose preferred style is mac is read from the header's two comments, not
measured on a device of iOS 15 or later. Ladder by `objc.inventory` (`.agent-work/plan-and-analysis/b1314-flips/ladder-rest.log`, an
invented selector as the negative control): none of these members is in 6.1.3 or 12.0, and all are in 16.0 and 18.0. There is no
13-15 cache, so `introduced` stays the headers' 15.0 and 16.0. Run on a device: the last section.

## On a device, iOS 6.1.3

On an iPad 2 of iOS 6.1.3 (2026-09-23), a process of the band's own (`.agent-work/runs/b1314-live/main.m`, output `run4-all.txt` beside it) loaded the gate's `libUIKitBackports.dylib` and checked pad for a button, a slider and a bar, a mac preference kept and still pad, automatic until set, and no NSToolbar section; all as described.
