# UNPushNotificationTrigger

Introduced in iOS 10.0. The trigger of a notification that came from a server, and
carried on iOS 6 as the marker the centre puts in the request it builds for a push.

Sources: the UserNotifications headers of the iPhoneOS 16.4 SDK the port is
compiled against, of the 26.2 SDK the registry is read from and of the macOS SDK the
host differential compiles against, all three for the API; UIKit of the armv7 cache of
iOS 4.3 for what the release carries; the name index for `application:didReceiveRemoteNotification:`;
and the host differential of `tests/backports/host/usernotifications`, run against the
system's own UserNotifications.

## What it is

```objc
API_AVAILABLE(macos(10.14), ios(10.0), watchos(3.0), tvos(10.0))
@interface UNPushNotificationTrigger : UNNotificationTrigger
@end
```

**No SDK this port is compiled against declares a member on it.** Not the iPhoneOS
16.4 SDK, not the 26.2 SDK the registry is read from, not the macOS SDK the host
differential builds against - the same three lines in all three headers. It is a marker,
and a caller learns a notification was pushed by asking whether its request's trigger is
of this class, then reads the identifier, the body, the badge, the sound and the payload
out of the request's content.

`first-rung.lua UNPushNotificationTrigger` answers `10.0.1`, the rung it arrived at
with the framework.

## What the release of iOS 6 has instead

iOS 6 has no UserNotifications framework and no daemon: `application:didReceiveRemoteNotification:`
first appears at **3.0**, and `UIApplication` of the armv7 cache of iPhone OS 4.3 carries
`registerForRemoteNotificationTypes:`, `enabledRemoteNotificationTypes` and
`unregisterForRemoteNotifications` beside `scheduleLocalNotification:` and its four
siblings - the whole of what iOS 6 does with a notification, local or remote.

So the registry's former reason, "remote notifications of iOS 6 reach the application
delegate and not this center, so no request ever carries a push trigger", was a claim
about **the port** and not about the release: it named the port's own wiring as the
absence. The center now hooks that delegate method, so the request a push is delivered
as does carry the trigger.

## The class, and what the host differential measured about it

The class is one factory and nothing else:

```objc
@implementation UNPushNotificationTrigger
+ (instancetype)charon_pushTrigger
{
    return [[self alloc] initCharonWithRepeats:NO];
}
@end
```

`-init` is `NS_UNAVAILABLE` on `UNNotificationTrigger`, which is why the factory exists
and why it is declared in `CharonUserNotifications.h`. `repeats` is NO: a pushed
notification is not a schedule the application asked for. Everything else - `repeats`,
`initWithCoder:`, `encodeWithCoder:`, `isEqual:`, `hash`, `copyWithZone:` - is
`UNNotificationTrigger`'s and is carried there.

The host differential asks the port and the framework the same question, with the port's
classes renamed so both stand in one process. Its verdict on this class, run on this
machine:

```
$ BUILD=<scratch> sh tests/backports/host/usernotifications/run.sh
note: this framework's UNPushNotificationTrigger declares _initWithContentAvailable:mutableContent:
      description encodeWithCoder: hash initWithCoder: isContentAvailable isEqual: isMutableContent
6069 checks, 0 failures
```

Three things in that note are worth stating rather than glossing:

- the class this framework ships implements `description`, `hash`, `isEqual:`,
  `initWithCoder:` and `encodeWithCoder:` **itself**, rather than inheriting them from
  `UNNotificationTrigger`. The port's marker inherits them, and the check is the strict
  direction - the port's class must add nothing over its base, which is what the headers
  say it may do - so the difference is reported, not asserted away.
- `_initWithContentAvailable:mutableContent:`, `isContentAvailable` and
  `isMutableContent` are implemented by the class and declared by **no** header of any
  of the three SDKs. They are not API, they are not in the registry, and the port does
  not carry them.
- the framework will not hand a `UNPushNotificationTrigger` over: only a request that
  arrived from a server carries one, so the differential compares the shape of the two
  classes and asks the port's own trigger what it answers - that it is a push trigger,
  that it does not repeat, that it survives an archive round trip and that its copy
  equals it.

## The request a push becomes

`charon_push_request` in `UNUserNotificationCenter.m` reads the payload the release hands
the delegate: the alert fields are under `aps`, and whatever the server sent beside them
is the notification's own data, so `content.userInfo` is the whole payload.

| `aps` | the content |
|---|---|
| `alert` as a string, or `alert.body` | `body` |
| `alert.title`, `alert.subtitle` | `title`, `subtitle` |
| `badge` | `badge` |
| `category`, `thread-id` | `categoryIdentifier`, `threadIdentifier` |
| `sound`, a string | `defaultSound` for `"default"`, `soundNamed:` for anything else |
| the rest of the payload | `userInfo` |

A `sound` that is a dictionary is read for its name only: `critical`, `volume` and the
rest describe an alert a release of this age has no way to play, and `UILocalNotification`
carries no field that would hold them.

**The identifier is this port's own choice and not Apple's.** iOS 10's system makes the
identifier of a request the application never added, and nothing in iOS 6 names it;
nothing on this machine measures what iOS 10 makes. The port uses the release's own
`[[NSUUID UUID] UUIDString]` - `NSUUID` first appears at **6.0**, and 6.1.3 carries
`UUID` and `UUIDString` - so the identifier is unique per delivery and derived from the
release rather than invented here. A caller must not read it as an APNS field: there is
none.

## The application delegate's own implementation

The hook leaves it in place and calls it after the center's, because a pushed
notification belongs to the application as much as to the center. The local hook, which
was measured earlier, returns before the original for a notification the center
scheduled - there the notification is the center's - and a push is never one.

Only `application:didReceiveRemoteNotification:` is hooked. Its
`:fetchCompletionHandler:` variant arrived in 7.0 and a release of this age never calls
it, so hooking the one the release has is the whole of what it can answer.

## What is not measured

The delivery itself: it needs a server to send a push from, and a device with an APNS
token, and neither is on this bench. What is measured is the shape of the class against
the framework's own, the payload-to-content mapping against the fields APNS documents and
that `CKNotifications8.m` already reads out of a CloudKit push, and the release's
substrate for the push arriving at all.

## `release-split`

```
$ .agent-work/plan-and-analysis/d5-un-r10/compile.sh "$PWD/packages/a/apple-backports" \
      UIKit/UNPushNotificationTrigger10.m <objects> 6.0
$ xmake l tools/release-split.lua <objects> <report> "$SDK"
release-split: clean, every object file's symbols first-appear in one release
UNPushNotificationTrigger10.o  _OBJC_CLASS_$_UNPushNotificationTrigger      10.0.1
UNPushNotificationTrigger10.o  _OBJC_METACLASS_$_UNPushNotificationTrigger 10.0.1
```

One object, one release, and the object's whole API is the marker - which is the whole of
iOS 10.0's `UNPushNotificationTrigger`.