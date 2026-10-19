# Opening a URL with options, iOS 10

Source: UIKitCore of iOS 12.0 arm64 (`-[UIApplication openURL:options:completionHandler:]` at `0x1acac802c`, the
block it runs at `0x1acac825c` and the block that reports back at `0x1acac8198`) and UIKit of iOS 10.0.1 armv7s
(`0x200ff04c`), read instruction by instruction; and iOS 6.0 and 6.1.3 on the emulator, an iPhone 4S and an iPad
2, through `tests/backports/device/uikit2.m`.

## What the newest release does

The call returns at once. It retains the URL, the options and the handler, and hands the rest to a global queue
of user-initiated quality of service, where three things are decided in order:

1. The application is asked `_shouldAttemptOpenURL:`. If it declines, the handler is told NO.
2. The value of the option `UIApplicationOpenURLOptionUniversalLinksOnly` is read with `valueForKey:`, and it counts
   only if it is an `NSNumber` whose `boolValue` is YES: a string `@"YES"` is not that. When it counts, the URL goes to
   `LSAppLink` alone, which opens it only if an application claims it as a universal link, and the handler is told
   what that answered.
3. Otherwise the URL goes to the workspace, `LSApplicationWorkspace`, which opens it whatever application claims it,
   waiting for the open to finish, and the handler is told whether it did.

The handler is optional. When there is one it is called once, whichever of the three ways ended it, from a block
dispatched to the main queue, so it runs later than the call and on the main thread.

## What the backport does

The handler is called once, later, on the main thread, and with nothing to call the call is still made. The
decision follows the same order with what iOS 6 has:

- a nil URL, or one no application claims, goes to `-openURL:` of the release, which answers NO on iOS 6.0
  and 6.1.3, and the handler is told NO;
- the option counts only when it is an `NSNumber` that is YES, as above. iOS 6 has no universal links, so when it
  counts nothing is opened and the handler is told NO, with one line in the log saying why;
- otherwise `-openURL:` of the release opens it and the handler is told what that answered.

The open itself is made on the calling thread rather than on a global queue, since `-openURL:` of the release
hands the URL to SpringBoard and comes back either way.

`UIApplicationOpenURLOptionUniversalLinksOnly` is the string of its own name, read from the host's UIKit.
