# UserNotifications delegate on iOS 6

The UserNotifications backport calls the app's `UNUserNotificationCenterDelegate` for a local notification, as iOS 10 does.
The calls are in `frameworks/Backports/src/UserNotifications/UNUserNotificationCenter.m` (`revenant_deliverRequest:state:`).

## Which call

- A notification that fires while the application is active calls `userNotificationCenter:willPresentNotification:withCompletionHandler:`.
  The completion handler receives `UNNotificationPresentationOptions`, and the backport applies what iOS 6 can show.
- A notification that is opened from the notification centre, or that launches the application, calls
  `userNotificationCenter:didReceiveNotificationResponse:withCompletionHandler:` with the default action identifier.
- A remote notification that arrives while the application is active goes through the same path, with its payload as the request.

## What the options do on iOS 6

| Option | iOS 6 behaviour |
|---|---|
| `UNNotificationPresentationOptionBadge` | sets the application icon's badge to the content's badge |
| `UNNotificationPresentationOptionSound` | plays through AudioServices the named file of the main bundle when the content names one that loads. For the default sound it plays `/System/Library/Audio/UISounds/sms-received1.caf` where that file exists. Otherwise it only vibrates. Whether the system file exists on the device was not checked |
| `UNNotificationPresentationOptionAlert` | accepted and nothing is drawn: iOS 6 has no banner for a notification while the application is in front. This is logged once |
| `UNNotificationPresentationOptionNone` | nothing |

The iOS 10 options `UNNotificationPresentationOptionList` and `UNNotificationPresentationOptionBanner` are not in iOS 6's
SDK, and are ignored when a delegate passes them.

## Default delegate

When the app sets no delegate, or its delegate does not implement the method, the backport uses
`RevenantUserNotificationDefaultDelegate`, a class in the same file that adopts the protocol. Its
`willPresent` completes with no options, so nothing is presented while the application is in front, as iOS 10 does
with no delegate method. Its `didReceiveNotificationResponse` completes at once. Because the class adopts the protocol and
implements those two methods, `toolchain/modules/apple/lowered.lua` (`protocol_status`) lowers the protocol's members for
an iOS 6 target, and with them the `UNNotificationPresentationOptions` typedef.

## Checks

Nothing has been run on a device. The delegate calls and the sound path compile only with the iOS 6 lowered headers, and
the macOS test does not compile this file, since it needs UIKit.
