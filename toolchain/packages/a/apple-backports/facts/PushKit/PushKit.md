# PushKit, iOS 8

`PKPushRegistry`, `PKPushCredentials`, `PKPushPayload` and `PKPushTypeVoIP` (plus
`PKPushTypeComplication` and `PKPushTypeFileProvider`, carried alongside it so an application
naming either symbol does not LOAD-FAIL) are what an application uses to place and take VoIP
calls without a persistent network connection. Per the coordination rule, the only genuine wall
here is Apple's own service issuing a VoIP-flagged token; everything else is carried.

## What the device has

iOS 6.1.3 predates PushKit by two major releases and has no `PKPushRegistry`-shaped registration
surface at all. What it does have, already carried by this project's own
`UIApplication+UserNotificationSettings.m` (`libUIKitBackports.dylib`): `apsd`, the release's own
push daemon, hands a real device token to `-[UIApplication registerForRemoteNotificationTypes:]`,
exercised on an iPhone 4S and an iPad 2 through `tests/backports/device/uikit2.m`. The catch, also
already recorded there: iOS 6's `apsd` protocol ties every token to a nonzero
`UIRemoteNotificationType` bitmask (`Badge`/`Sound`/`Alert`); asking with none of those bits set
gets nothing back, and there is no fourth, silent, no-prompt bit the way later releases eventually
grew one for background/content-available delivery. PushKit's own contract is the opposite: a
`PKPushRegistry` never shows the user anything, and its whole purpose is a token for pushes the OS
delivers without asking permission first.

## What the port does

`PKPushRegistry` is real: `initWithQueue:`, `delegate`, `desiredPushTypes` and
`pushTokenForType:` all behave as the header describes. Setting `desiredPushTypes` to a set
containing `PKPushTypeVoIP` does two things: it delivers a cached token immediately if this
process already holds one (a plist-backed cache under `NSUserDefaults`, the same convention
`UIApplication+UserNotificationSettings.m` already uses for its own registered-types record), and
it re-asks `apsd` for a token by replaying `-registerForRemoteNotificationTypes:` with whatever
`UIUserNotificationType` bits the application already holds from a **prior, separate** call to
`-registerUserNotificationSettings:` - never bits this port invents on the application's behalf,
since that would show the user a permission prompt they never asked PushKit to show. When
`apsd` calls the application delegate back with a token, this port hears it too: the first time
`-[UIApplication setDelegate:]` names a delegate class, `CharonPushBridge` chains its own
implementation onto that class's `-application:didRegisterForRemoteNotificationsWithDeviceToken:`
(calling the application's own implementation first, if it has one, then broadcasting the token to
every live `PKPushRegistry` whose `desiredPushTypes` wants it) - the same
`class_replaceMethod`/`imp_implementationWithBlock` chaining `UIApplication+KeyCommands.m` already
uses elsewhere in this project for a method that may or may not be overridden by the application.
`PKPushCredentials` and `PKPushPayload` are ordinary real objects, independent of how a credential
was obtained.

## What is the wall, and what proves it

A `PKPushRegistry` set up with no prior `-registerUserNotificationSettings:` call - the common
case for an application that wants a *silent* VoIP-only token, exactly what PushKit exists to
provide - never receives one on this release. This is not a refusal to try: the selector that
would have to deliver it, `-[UIApplication registerForRemoteNotificationTypes:]`, is called with
the only types `apsd`'s iOS 6.1.3 protocol accepts, and with `UIRemoteNotificationTypeNone` it
answers nothing, confirmed by the existing `UIApplication+UserNotificationSettings.m`/
`facts/UIKit/UIApplicationNotificationRegistration.md` measurement against real hardware. Forcing
some nonzero type bit here instead, to manufacture a token, would put up the "would like to send
you notifications" alert as a side effect of a PushKit call the application never asked to show
UI for - a silent behavioural difference from the real class, which is worse than the honest gap
this port leaves: a registry that never calls back. An application already showing that prompt for
its own reasons (a chat application that also wants ordinary push, say) still gets a genuine
Apple-issued VoIP token for free once it does.

## What differs from the release

Incoming push delivery is not wired: `-pushRegistry:didReceiveIncomingPushWithPayload:forType:`
and its `withCompletionHandler:` successor are never called, and `PKPushPayload` exists only so
the class symbol resolves for a delegate whose method signatures name it. This is a second, real
gap, distinct from the token wall above: apsd on iOS 6.1.3 never wakes a suspended or
not-running application for any push at all, VoIP included, so there is no path by which this
port could observe an incoming push outside the small window the application is already running
in the foreground or the background modes iOS 6 already grants it - and forwarding only that
narrow, unreliable subset under PushKit's name would be a misleading partial implementation of the
one behaviour (reliable wake-on-push) the framework is built around. Left undone rather than faked.

`PKPushTypeVoIP`, `PKPushTypeComplication` and `PKPushTypeFileProvider` are carried as their own
constant names (`"PKPushTypeVoIP"` etc.), the form Apple's own documentation and headers have used
for every `PKPushType` since iOS 8; an attempt to read their literal bytes out of the iOS 12.0 and
iOS 16.0 arm64 shared caches with `modules/apple/dyld.lua`'s `pointer_at` (chain-resolving a
`CFConstantString`'s `bytes` field, at offset 16 of the struct, `length` at offset 24 - the earlier
attempt in this same session mis-read offset 8, the `flags` field, as the bytes pointer) kept
landing outside every mapping in both caches, for reasons not run down further. Recorded as
unmeasured rather than presented as extracted.
