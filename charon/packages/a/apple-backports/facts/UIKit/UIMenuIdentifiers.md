# The menu identifiers, iOS 13.0 and 14.0

`UIMenuApplication` to `UIMenuWindow` and the rest are the standard identifiers of the menu bar's menus
(`UIMenuFile`, `UIMenuEdit`, `UIMenuSpelling`, ...), 43 from iOS 13.0 and `UIMenuOpen` and `UIMenuOpenRecent` from 14.0.
Each is a string, and the port carries the same string.

Source: read out of the host's own UIKit under Mac Catalyst (macOS 27.0) by asking each symbol; `tests/backports/host/uikit2`
(the `menus` group) compares all 45 with the backport's, and `tests/backports/device/menus.m` holds the same table against
the device, and that each comes from `libUIKitBackports.dylib`.

- All are `com.apple.menu.<name>`, the name in lower case with hyphens (`UIMenuNewScene` is `com.apple.menu.new-item`,
  `UIMenuUndoRedo` is `com.apple.menu.undo-redo`), except `UIMenuSpeech`, which is `com.apple.command.speech`.
- `UIMenuSidebar` (15.0) is `com.apple.menu.sidebar` and `UIMenuDocument` (16.0) is `com.apple.menu.document`, each in an object of
  its own release (`UIKit/UIMenuIdentifiers15.m`, `UIMenuIdentifiers16.m`). Both strings were read from UIKitCore's exports in the 16.0
  cache (`tools/corpus/cache-value.lua` on the 16.0 cache, with `UIMenuFile` and `UIMenuRoot` read the same way
  as controls), not from the host; neither is exported in 12.0 (`tools/corpus/cache-value.lua` on the 12.0 cache), and with no 13-15 cache the headers' 15.0 and 16.0
  stand.

Nothing on this release builds a menu from them: the identifiers exist so that an application that keys its menus by them
- to name a menu it makes, or to look for one in a builder - links.

## On a device, iOS 6.1.3

On an iPad 2 of iOS 6.1.3 (2026-09-23), a process of the band's own (`.agent-work/runs/b1314-live/main.m`, output `run4-all.txt` beside it) loaded the gate's `libUIKitBackports.dylib` and checked `UIMenuSidebar` and `UIMenuDocument` read through the library's exports: the strings above.
