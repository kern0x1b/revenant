# UNUserNotificationCenter

Introduced in iOS 10.0. The center an application schedules its notifications
through, carried on iOS 6 as a facade over the scheduler the release already
has.

Sources: UserNotifications and UserNotificationsServer of the armv7s cache of
iOS 10.3.4; UIKit, BulletinBoard and SpringBoard of iOS 6.0 and of an iPhone4,1
running 6.1.3.

## On iOS 10 it is a client of a daemon

`UserNotifications.framework` holds the API - `UNUserNotificationCenter`,
`UNNotificationRequest`, the triggers, the content, the settings - and talks over
XPC (`UNUserNotificationServiceConnection`, `UNUserNotificationService`) to a
second framework, `UserNotificationsServer`, which is where the work happens:
`UNSNotificationRepository`, `UNSPendingNotificationRepository`,
`UNSNotificationSchedulingService`, `UNSNotificationSettingsService`,
`UNSLocationMonitor`, `UNSUserNotificationServer`.

That daemon does not exist on iOS 6 and cannot be written for it. **But it does
not have to be.** Everything the daemon does for local notifications - keeping
the pending list, firing on a date, repeating on a calendar, delivering to the
notification centre, badging, sounding - SpringBoard already does on iOS 6,
through `-[UIApplication scheduleLocalNotification:]`. So the port is not a
daemon; it is a facade over the scheduler iOS 6 already has.

## What iOS 6 gives it

`UILocalNotification` is a class cluster; the real class is
`UIConcreteLocalNotification`, and it carries more than the iOS 6 header admits:

| member | note |
|---|---|
| `fireDate`, `timeZone` | the public pair |
| `repeatInterval` | an `NSCalendarUnit`, not an arbitrary interval |
| `repeatCalendar` | the calendar the repeat is counted in |
| `totalRepeatCount`, `remainingRepeatCount` | a **finite** number of repeats, which iOS 10's own API cannot express |
| `alertBody`, `alertAction`, `alertLaunchImage`, `hasAction` | the alert |
| `soundName`, `soundType` | the sound |
| `applicationIconBadgeNumber` | the badge |
| `userInfo` | free-form, and the only place a port can keep an identifier |
| `fireNotificationsWhenAppRunning` | shows the alert even in the foreground |
| `allowSnooze`, `snoozedNotificationName`, `firedNotificationName` | snoozing |
| `isSystemAlert`, `hideAlertTitle`, `customLockSliderLabel`, `interruptAudioAndLockDevice`, `resumeApplicationInBackground`, `showsAlarmStatusBarItem` | private |

SpringBoard refuses the private ones to an unentitled app - its own string is
`Ignoring UILocalNotification property change as '%@' entitlement is re...` - so
a port may not lean on them.

`UIApplication` gives `-scheduleLocalNotification:`, `-cancelLocalNotification:`,
`-cancelAllLocalNotifications`, `-scheduledLocalNotifications`,
`-presentLocalNotificationNow:`, `-registerForRemoteNotificationTypes:`,
`-enabledRemoteNotificationTypes` and `-unregisterForRemoteNotifications`.

## What the center does

| iOS 10 | on iOS 6 |
|---|---|
| `+currentNotificationCenter` | one center for the process. |
| `delegate` | weak. Setting it hooks `-application:didReceiveLocalNotification:` of the application delegate's class, once; a notification scheduled through the center goes to the center's delegate, any other to the application delegate as before. |
| `-requestAuthorizationWithOptions:completionHandler:` | local notifications need no permission on iOS 6 and the release never asks, so the answer is granted. Badge, sound and alert are recorded under `org.charon.apple-backports.UIUserNotificationTypes`, the key the iOS 8 `UIUserNotificationSettings` of this package records its types under - the bits are the same - so the two APIs agree. |
| `-getNotificationSettingsWithCompletionHandler:` | not determined until authorization was asked for; after it, authorized, and each of badge, sound and alert enabled if it was asked for and disabled if not, the notification centre and the lock screen following the alert, the alert style a banner, CarPlay not supported. **These are what the application asked for, not what the user set**: iOS 6 tells an application nothing of its notification settings - they live in BulletinBoard, which answers no application here (see below). |
| `-addNotificationRequest:withCompletionHandler:` | the request becomes a `UILocalNotification`, any pending one of the same identifier is cancelled, and it is scheduled; one with no trigger is presented at once. A request with no content is refused with `UNErrorDomain` 1401. |
| `-getPendingNotificationRequestsWithCompletionHandler:` | the release's scheduled notifications that carry a request, the requests read back from them whole. |
| `-removePendingNotificationRequestsWithIdentifiers:`, `-removeAllPendingNotificationRequests` | cancel those - only those: `-cancelAllLocalNotifications` would take notifications the application scheduled itself as well. |
| `supportsContentExtensions` | NO: iOS 6 runs no extensions. |

The completion handlers run on a serial queue of the center's own, never the
main thread, as iOS 10's do; the delegate is told on the main thread.

## What a bundle that never asked reads

`-getNotificationSettingsWithCompletionHandler:` does not prompt. A bundle that has never asked for authorization reads not determined, with the
per-setting values below. They are measured in a bundled Mac Catalyst application, `tests/backports/host/notification-settings`, which never
requests authorization (16 checks: the port's `UNNotificationSettings` and the host's print the same values, and the six planted controls fail).

| member | a fresh bundle reads |
| --- | --- |
| `authorizationStatus` | not determined (0) |
| `soundSetting`, `badgeSetting`, `alertSetting`, `carPlaySetting` | not supported (0) |
| `notificationCenterSetting`, `lockScreenSetting` | enabled (2) |
| `alertStyle` | banner (1) |
| `showPreviewsSetting` | when authenticated (1) |
| `criticalAlertSetting`, `announcementSetting`, `timeSensitiveSetting`, `scheduledDeliverySetting`, `directMessagesSetting` | not supported (0) |
| `providesAppNotificationSettings` | NO |

The Catalyst build of that harness is not the product's build. Mac Catalyst does not have `UNLocationNotificationTrigger` (the SDK marks it
unavailable), so the harness compiles copies of the port's sources, made in its build directory, in which the location-trigger check is written
`NSClassFromString(@"UNLocationNotificationTrigger")`: the same answer where the class exists. The port's `UNLocationNotificationTrigger10.m` is
not compiled, since it does not build on Mac Catalyst either; in its place the harness compiles `tests/backports/host/notification-settings/app/region-monitor-stub.m`,
a stand-in `CharonRegionMonitor` that answers as an empty monitor. The settings never reach it: the centre reaches the monitor only for a location
request or for the pending list, and this check asks for neither. The product source keeps the class literal.

The seven members the later releases add are answered with these values. An authorized bundle keeps the same values for them: their authorized
values are not measured, so none is claimed. The authorized values of the first members are the ones the table in the previous section gives.

## Triggers, and what the release can repeat

A time interval trigger fires at now plus its interval. A calendar trigger
fires at its next date (see `UNNotificationTrigger.md`), in its calendar's zone,
so it keeps to the wall clock when the device's zone changes; one with no next
date is refused with `UNErrorDomain` 1400, `UNErrorCodeNotificationInvalidNoDate`.

iOS 6 repeats a local notification by one calendar unit from its first date.
Where that is the same series the trigger describes, it is used:

- a time interval of exactly a minute, an hour, a day or a week, counted in
  Greenwich time so that a change of clocks does not bend it;
- a calendar trigger whose highest unit is the second, minute, hour or weekday
  alone - every minute, hour, day or week;
- a day of the month up to the 28th, every month;
- a month and a day, other than the 29th of February, every year.

Any other repeat - 90 seconds, the 31st of every month, the second Tuesday - is
refused with `NSCocoaErrorDomain` `NSFeatureUnsupportedError` and a reason that
says so, rather than scheduled to fire on dates it does not describe.

## Arriving

- **In front.** The release calls the application delegate; the center makes a
  `UNNotification` of the request, dated when it arrived, and asks its
  delegate's `-userNotificationCenter:willPresentNotification:withCompletionHandler:`.
  Of the options it answers, the badge is set; iOS 6 shows nothing and plays
  nothing for a notification that arrives in front, so alert and sound change
  nothing, and the first time they are asked for the log says so.
- **Opened from the notification.** The release calls the application delegate
  with the application inactive, or launches it with the notification in its
  launch options; the center hands its delegate a response with
  `UNNotificationDefaultActionIdentifier`.
- **Dismissed.** iOS 6 does not tell an application, so no dismissal is ever
  reported.

## Actions and categories

`UNNotificationAction`, `UNTextInputNotificationAction`, `UNNotificationCategory`,
`UNTextInputNotificationResponse` and `UNNotificationServiceExtension` are
present because applications link them by name. The values are real: identifier,
title, options, the text-input fields, secure coding, equality and hash as
10.3.4 makes them, and the descriptions in its format. Nothing shows an action,
since iOS 6 local notifications have none.

Measured: `tests/backports/host/usernotifications` asks `UNNotificationAction`,
`UNTextInputNotificationAction` and `UNNotificationCategory` of the port and of
the host's own UserNotifications side by side (6069 checks, 0 failures). Not yet
measured, and so still `inert`: `UNTextInputNotificationResponse` (no differential
asks a response of either side) and `UNNotificationServiceExtension` (nothing calls
it). The two category methods stay `inert` too: the set is stored, but no banner
draws what it names.

- `-setNotificationCategories:` archives the set into the application's defaults
  and logs once for a non-empty set; an empty set removes the entry.
- `-getNotificationCategoriesWithCompletionHandler:` unarchives the set and
  completes on the center's queue.
- The factory methods of later releases (`icon:`, `hiddenPreviewsBodyPlaceholder`,
  `categorySummaryFormat`) are not there, so `respondsToSelector:` says NO.
- The service extension's default hands the request's content on unchanged and
  its expiry callback does nothing.

## How it is held

On an iPhone4,1 running 6.1.3, an application launched by SpringBoard asks for
authorization, reads the settings before and after, adds a request and adds it
again under the same identifier, reads the pending request back whole, reads
what iOS 6 was given - the body, the badge, the sound, the user info and the
date, and no title - has repeats taken and refused, removes by identifier and
all at once while a notification it scheduled itself survives, and waits for a
notification to arrive in front: the delegate hears of it on the main thread,
as the request it was added as, and the badge it asks for is set. A request
with no trigger arrives at once. 36 checks, no failures.

The notification opened from outside, and the one that launches the
application, need a hand on the screen, so they are read off the release -
`-application:didReceiveLocalNotification:` with the application inactive,
and `UIApplicationLaunchOptionsLocalNotificationKey` - and not measured.

## BulletinBoard, and why the delivered notifications are not there

iOS 6 has the whole notification backend as a framework: `BBBulletin`,
`BBBulletinRequest`, `BBObserver`, `BBServer`, `BBSectionInfo`, `BBSound`,
`BBAction`, `BBButton`, `BBSettingsGateway`. Two pieces would answer exactly what
the mapping table leaves open:

- `BBObserver` - `-requestListBulletinsForSectionID:`, `-clearBulletins:inSection:`,
  `-clearSection:` - is what `getDeliveredNotifications` and
  `removeDeliveredNotifications` would ride on.
- `BBSectionInfo` carries `alertType`, `showsInNotificationCenter`,
  `showsInLockScreen`, `showsMessagePreview`, `pushSettings`, `enabled`,
  `notificationCenterLimit` - which is nearly field for field what
  `UNNotificationSettings` reports.

The services are vended by SpringBoard as `com.apple.bulletinboard.settings`,
`.observer`, `.utilities` and `.systemstate`, and SpringBoard carries a plist
naming those same four strings as the entitlements it requires.

Measured on the iPhone4,1: a process that dlopens BulletinBoard gets the classes
and can construct `BBSettingsGateway` and `BBObserver`, but every call comes back
empty and the log says `Unexpected error on BBServer connection ... XPCObjectsErrorDomain Code=2`.
That happened as root, as `mobile`, and with all four entitlements applied by
`ldid`. SpringBoard's own failure string for this path is
`Unable to get entitlements for client task`, which suggests it validates through
`SecTaskCopyValueForEntitlement` and does not accept an `ldid` pseudo-signature.
It is not a bootstrap namespace problem: other SpringBoard services answer this
same SSH session.

So: whether a properly installed application can reach BulletinBoard on this
jailbreak is **not established**. Until it is, the delivered-notification methods
are not there rather than answer emptily, and the settings report what the
application asked for, which is all the release lets it know.
Proving it needs code running inside an application SpringBoard launched. The
device check of this center is one, but it has not asked BulletinBoard yet.

## The same absence, read out of the caches (2026-10-01)

The section above measures BulletinBoard on the device. That measurement cannot be
re-run from a bench, so the half of it that can is here, with the control in the same
reading: the dump of 7187 classes in the armv7 cache of iPhone OS 4.3, the low band
end.

```
$ python3 -c "import json; c=json.load(open('$HOME/.charon/dyld/4.3/classes_armv7.json'))['classes']; \
    print('\n'.join(sorted(m for m in c['UIApplication']['instance'] \
        if any(k in m.lower() for k in ('notification','remote','badge')))))"
applicationIconBadgeNumber
cancelAllLocalNotifications
cancelLocalNotification:
enabledRemoteNotificationTypes
presentLocalNotificationNow:
registerForRemoteNotificationTypes:
scheduleLocalNotification:
scheduledLocalNotifications
unregisterForRemoteNotifications
```

Eight members, and they are the whole of what `UIApplication` does with a notification:
schedule one, cancel one, cancel all, read what is **scheduled**, present one now, and
the three of the remote pair. **There is no member that reads what has already been
delivered**, and `-cancelAllLocalNotifications` cancels the scheduled ones, which is
what the port's own `-removeAllPendingNotificationRequests` had to be careful about
earlier in this page.

The control for that negative is in the same dump: 7187 classes came out of it, and
`UIApplication` and `UIConcreteLocalNotification` are two of them, so the reader finds
the class it is looking in. The three delivered-notification selectors themselves are
absent from every release before they existed - `first-rung.lua
getDeliveredNotificationsWithCompletionHandler: removeAllDeliveredNotifications
removeDeliveredNotificationsWithIdentifiers:` answers `10.0.1` for each - and
`$HOME/.charon/dyld/6.1.3/selectors_armv7.txt` holds 113981 selectors and none of them
is one of those three (0 matches for each, `rg -c -x`).

For the attachment, the same dump carries the concrete class a `UILocalNotification` is
actually one:

```
$ python3 -c "import json; c=json.load(open('$HOME/.charon/dyld/4.3/classes_armv7.json'))['classes']; \
    print(len(c['UIConcreteLocalNotification']['instance'])); \
    print(', '.join(c['UIConcreteLocalNotification']['instance']))"
47
clearNonSystemProperties, compareFireDates:, copyWithZone:, _addCalendarUnits:toDateComponents:,
_setUserInfoData:, alertAction, alertBody, alertLaunchImage, allowSnooze,
applicationIconBadgeNumber, customLockSliderLabel, dealloc, description, encodeWithCoder:, fireDate,
fireNotificationsWhenAppRunning, hasAction, hash, hideAlertTitle, init, initWithCoder:,
interruptAudioAndLockDevice, isEqual:, isValid, nextFireDateAfterDate:localTimeZone:,
nextFireDateForLastFireDate:, repeatCalendar, repeatInterval, resumeApplicationInBackground,
setAlertAction:, setAlertBody:, setAlertLaunchImage:, setAllowSnooze:,
setApplicationIconBadgeNumber:, setCustomLockSliderLabel:, setFireDate:,
setFireNotificationsWhenAppRunning:, setHasAction:, setHideAlertTitle:,
setInterruptAudioAndLockDevice:, setRepeatCalendar:, setRepeatInterval:,
setResumeApplicationInBackground:, setShowAlarmStatusBarItem:, setSoundName:,
setSoundNameIsARingtone:, setTimeZone:, setUserInfo:, showAlarmStatusBarItem, soundName,
soundNameIsARingtone, timeZone, userInfo
```

Forty-seven members, and **not one of them renders an image, a sound or a film into the
notification**: the alert is `alertBody`, `alertAction`, `alertLaunchImage` and
`hasAction`, the sound is `soundName` and `soundNameIsARingtone`, the badge is
`applicationIconBadgeNumber`, and the rest are the date, the repeat, snoozing, the lock
slider, the audio interrupt and the system-alert flags SpringBoard refuses to an
unentitled application. `alertLaunchImage` is a **launch** image - the picture the
application's own icon is replaced with while it starts - not a picture in the
notification, and setting it is what this port's own `-charon_local_notification` does
with `content.launchImageName`.

So both absences rest on a reading a reader can repeat, and `UNNotificationAttachment`
and the three delivered-notification methods keep their status: what the release has
does not answer those four names.
