# UserNotificationsUI on a release with no extension host

The notification content extension arrived in iOS 10 and runs in a process the *system* starts. iOS
6.1.3 has no app extensions at all: there is no extension host, no `pluginkit`, and nothing makes an
`NSExtensionContext` for an extension. That wall is already recorded for the class itself -
`registry/Foundation/ios8extensioncontext.json` has `NSExtensionContext` as `inert`, "the release has
no app extensions, so there is no host to hand a request back to", with
`facts/Foundation/NSExtensionContext.md` behind it. These five members answer as the class they are
added to does, and the difference is which half of each one is the extension's own and which is a
message to the host.

**The extension's own half, implemented.** `notificationActions` is the array the extension wants
offered for the notification; it is copied in, copied out, and an extension that set none reads an
empty array rather than nil. `mediaPlayingStarted` and `mediaPlayingPaused` record the state of the
extension's own media on the context, so a host that existed would see it.

**The message-to-the-host half, not carried at all.** `performNotificationDefaultAction`,
`dismissNotificationContentExtension`, `mediaPlayingStarted` and `mediaPlayingPaused` are registry
entries with status `absent`, and the port carries no code for any of them. Each needs something this
release does not have - a delivered notification to act on, a presented content extension to dismiss,
and a system that takes playback controls in a notification and plays a sound with it. Carrying them
would mean storing a media state or an action list that nothing can act on, which is the silent fake
COORDINATION.md §2 forbids; `mediaPlayingStarted` keeping a flag that no reader ever asks for was
precisely that. Not carrying them is the port's own answer for a member of a class the release cannot
honour: the accessor is not declared, `respondsToSelector:` answers NO, and an unchecked call is a
crash the application must avoid.

## The protocol, and why it is `absent` rather than `implemented`

`UNNotificationContentExtension` is a protocol, and its seven members are all implemented by the
*application's* view controller: `didReceiveNotification:`, the response form with its completion
handler, `mediaPlay`, `mediaPause`, and the three answers about the play/pause button the extension
places in its own view. Nothing in the port sends any of them and nothing in the port reads any of
them, so there is no class of ours that could conform.

The port's own convention for exactly this is `registry/UIKit/ios13menus.json`: "the protocol is not
a wall: it is owed alongside the delegate property it types, even though the release does not yet
send its messages" - and there a class of ours does conform, so the protocol is emitted and the
messages have somewhere to go. Here nothing does, and the same convention's other half applies
(`registry/MediaPlayer/absent_MediaPlayer.json`): the protocol is not carried, and the reason says
why.

An application that writes `@interface MyContent : UIViewController <UNNotificationContentExtension>`
gets the protocol emitted in its own translation unit, with the class's own implementations on it -
which is the whole of what the protocol is for. That was measured while working this out: a
translation unit that only names a protocol in a variable's type emits a *label* for it and no
protocol object, while one whose class declares the conformance emits the protocol itself
(`__OBJC_PROTOCOL_$_PKPushRegistryDelegate` in the object file, against
`__OBJC_LABEL_PROTOCOL_$_PKPushRegistryDelegate` alone for the naming case). So an application that
conforms is fine, and the backports gain nothing by carrying a second, disconnected protocol object
with the same name - a `conformsToProtocol:` across the two would compare different pointers and
answer NO.

## Not measured against a host

`UNNotificationContentExtension` is iOS 10 and the host has no such protocol; the additions to
`NSExtensionContext` are additions to a class the port implements itself, whose own differential is
`tests/backports/host/tail2` and whose device probe is `tests/backports/device/tail2.m` - neither
touches these five, and no new one was written for them. They are `NSExtensionContext` members and
they were checked by the full gate (which builds and links them for both band ends) and by the
emulator call test, listed in the delivery.
