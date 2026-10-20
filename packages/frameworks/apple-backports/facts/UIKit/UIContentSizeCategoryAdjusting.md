# adjustsFontForContentSizeCategory, iOS 10

Introduced in iOS 10.0 on `UILabel`, `UITextField` and `UITextView` through the
`UIContentSizeCategoryAdjusting` protocol: a view whose font came from `+preferredFontForTextStyle:` or from
`UIFontMetrics` re-reads it when the user changes the text size.

Source: the release. iOS 6 has no Dynamic Type: there is no `UIApplication.preferredContentSizeCategory`, no
`UIContentSizeCategoryDidChangeNotification` posted by anything, and no setting in Settings that would move the
category. This package's own `UIContentSizeCategory` answers the default category and nothing ever changes it -
which `facts/UIKit/UIContentSizeCategory.md` records.

## Why the flag is inert and not carried

The flag is kept and read back on all three views, and the font is left exactly as the application set it. It is
`inert` because the phenomenon it reacts to does not exist: there is no category change to adjust for, so a view
that says it adjusts and one that says it does not behave identically, now and for the life of the process. That
is not the port declining to do work - there is no work. The first time an application turns the flag on, the port
says so once in the log.

The three views are made to conform to `UIContentSizeCategoryAdjusting` as well, so `-conformsToProtocol:` answers
what the property makes true rather than leaving an application to discover the accessor by trying it.

What would change this: nothing short of a Dynamic Type setting on the device. Were the package ever to post a
category change of its own, the flag would have to start re-reading the font, and the entry would become
`implemented`.

## What the device run reached

`device/focuscontentsize.m` on an emulated iOS 6.0 (iPhone3,1, 10A403) passes eighteen checks: the protocol is
registered in the process, all three classes answer both accessors out of `libUIKitBackports.dylib`, and all three
say they adopt `UIContentSizeCategoryAdjusting`.

The per-instance behaviour - the flag kept, the font left alone - is **not** exercised there, and the reason is the
release, not the port: in a process with no application, iOS 6 cannot construct a `UITextField` or a `UILabel` at
all. A plain `UIView` is made without trouble, and so is a `UIProgressView`, but the text-bearing controls trap
with `SIGILL` inside CoreFoundation before their initializer returns. Holding the flag on live instances needs an
application, and that is where it belongs when one is written.
