# Registering for notifications on an application, iOS 8

Source: UIKitCore of iOS 12.0 arm64, `-[UIApplication registerUserNotificationSettings:]` at `0x1acade2a0`,
`-currentUserNotificationSettings` at `0x1acade73c`, `-registerForRemoteNotifications` at `0x1acade838` and
`-isRegisteredForRemoteNotifications` at `0x1acadea48`, read instruction by instruction; and iOS 6.0 and 6.1.3 on
the emulator, an iPhone 4S and an iPad 2, through `tests/backports/device/uikit2.m`.

## What the newest release does

The four methods are façades over UserNotifications, the daemon that holds the user's answer:

- `-registerUserNotificationSettings:` gives the categories of the settings to the notification center, asks it to
  authorize the types, and when it has answered reads the settings and categories the center holds back into a
  `UIUserNotificationSettings`, and on the main queue tells the delegate `-application:didRegisterUserNotificationSettings:`
  if it answers that selector. What the delegate hears is what the user granted, not what was asked for.
- `-currentUserNotificationSettings` is the center's current settings, with its categories, turned into a
  `UIUserNotificationSettings`.
- `-registerForRemoteNotifications` sets a delegate on the remote notification registrar and asks it for a token; a
  failure reaches the application delegate on the main queue as
  `-application:didFailToRegisterForRemoteNotificationsWithError:` when it answers that selector, and a success
  is reported back the same way.
- `-isRegisteredForRemoteNotifications` is the registrar's `allowsRemoteNotifications`.

## What the backport does with what iOS 6 has

iOS 6 has no daemon of settings and no question to the user per type: an application asks for the types of
`registerForRemoteNotificationTypes:` and the release answers with the ones the user has left on in Settings.
So the port keeps what an application asked for and reports it back:

- `-registerUserNotificationSettings:` keeps the badge, sound and alert bits of the types, in the application's
  defaults, and calls `-registerForRemoteNotificationTypes:` again when the application had registered for remote
  notifications. The delegate is told once, on the main queue, with `currentUserNotificationSettings` - the types it
  asked for, since iOS 6 grants what it is asked for - and with no categories, since iOS 6 shows no actions on a
  notification. When categories were given, a line in the log says they are not registered.
- `-currentUserNotificationSettings` is those types with no categories.
- `-registerForRemoteNotifications` registers with those types. With none registered it does not ask the release:
  it tells the delegate `-application:didFailToRegisterForRemoteNotificationsWithError:` on the main queue, with
  an error in `NSCocoaErrorDomain` that says to call `-registerUserNotificationSettings:` first. The newest release
  has no such condition, and needs none: iOS 6 hands out a token by a set of types.
- `-isRegisteredForRemoteNotifications` is whether the release reports any remote notification type enabled.

Where the answers differ from the newest release, all of it follows from the release having no per-application
authorization: the settings the delegate hears are the types asked for and not what a user granted, and the
categories are never kept.
