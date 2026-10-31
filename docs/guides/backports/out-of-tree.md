# Out-of-tree apps: choosing the Backports an app links

An app built outside the checkout takes the Backports from the package `revenant@backports`. The package holds the
libraries named in its `libraries` config, and every library those use. Name the libraries the app links, and nothing
else:

```lua
add_requires("revenant@backports", {configs = {libraries = "UIKitBackports,UserNotificationsUIBackports"}})

target("App")
    add_packages("backports")
```

- The names are the targets in `frameworks/Backports/tools/library_list.lua`. The library for user notifications is
  `UserNotificationsUIBackports`, not `UserNotificationsBackports`.
- A selected library brings the libraries it uses, through its entries ending in `Backports`. `UIKitBackports`
  brings `GraphicsBackports` and `CoreGraphicsBackports`, and with them `FoundationBackports`.
- The package requires exactly the packages those libraries use, and no others. `frameworks/Backports/tools/subset.lua`
  derives them from the library table, so a library that adds a dependency adds its requirement too. `UIKitBackports`
  requires `box2d` and `apple-compat`; `UserNotificationsUIBackports` with `UIKitBackports` requires the same two.
- The symbols an app uses decide the library. The `QuartzCore` constants `kCACornerCurve*` are in `UIKitBackports`
  (`frameworks/Backports/src/UIKit/CALayer+CornerCurve.m`), so an app that uses them selects `UIKitBackports`. The
  `ImageIO` framework is held by `GraphicsBackports`, which `UIKitBackports` brings with it.
- `add_packages("backports")` binds the app to the libraries at link, by ordinal; the bindings are described in
  [the backports loading explanation](../../explanation/backports-loading.md).

The `apple-ios` include adds `revenant@backports` on its own, with the default `FoundationBackports`, unless
`REVENANT_BACKPORTS_LIBRARIES` is set. Checked with a throwaway app configured for `iphoneos` (armv7) on this change:
with the app's requirement declared after the include, and again before it, the project recorded one backports
instance, and its wrapper build produced the seven dylibs of the `UIKitBackports` closure (`UIKitBackports`,
`GraphicsBackports`, `CoreGraphicsBackports`, `IOSurfaceBackports`, `FoundationBackports`, `CoreFoundationBackports`,
`SystemBackports`). The app's `libraries` therefore takes effect, and the default is not built as a second copy. That
is what the configure showed; the app itself was not run.

## Check the selection without a device

The subset rules are a host test, which needs no iOS SDK:

    ./xmakew test -P . 'subset/*'

It checks the libraries and packages that `UIKitBackports` alone selects, the same two for `UserNotificationsUIBackports`
with `UIKitBackports`, the target that `CloudKitBackports` alone needs, the full table's package list, and that an unknown
library name is refused. It does not install the packages or build the libraries.
