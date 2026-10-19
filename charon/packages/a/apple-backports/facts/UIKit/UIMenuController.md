# UIMenuController, the members of iOS 13.0

Introduced in iOS 13.0: `-showMenuFromView:rect:`, `-hideMenuFromView:` and `-hideMenu`, which replace the three calls of the old
interface - `-setTargetRect:inView:`, `-setMenuVisible:` and `-setMenuVisible:animated:` - that iOS 13 deprecated. iOS 6 has the
menu controller, so these are written on top of it as a category.

Source: the header of SDK 16.4 for the names and the deprecation replacements. The host's own menu controller never showed its menu in
the windowed test application (`menuVisible` stayed NO), so its behaviour could not be measured; the test
(`tests/backports/host/uikit2`, the `menucontroller` group) asserts the calls the port makes to the old interface instead, by replacing
the two methods it calls.

## What the port does

- `-showMenuFromView:rect:` is `-setTargetRect:inView:` with the rect and the view, then `-setMenuVisible:YES animated:YES`.
  The animated flag is the one the header names for the replacement.
- `-hideMenu` is `-setMenuVisible:NO animated:YES`.
- `-hideMenuFromView:` is the same. On iOS 13 the menu is hidden only if it is shown from that view; this release's controller keeps no
  way to read the view back, so the port hides the menu whichever view it is shown from. An application that hides a menu it did not
  show is rare; one that hides its own is served.
