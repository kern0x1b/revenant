# UNNotificationContent, UNNotificationSound, UNNotificationRequest, UNNotification, UNNotificationResponse

Introduced in iOS 10.0. What a notification says, and the request, the delivery
and the answer that carry it.

Source: UserNotifications of the armv7s cache of iOS 10.3.4 for the checks and
the descriptions, and the host's own UserNotifications, asked side by side with
the port, for every value.

## Content

A fresh content has no title, subtitle, body, badge or sound; an empty
`userInfo` and `attachments`; and an empty string for `categoryIdentifier`,
`threadIdentifier` and `launchImageName`. Set to nil, those three read back as
empty strings, `attachments` as an empty array, and the rest as nil.

`-copy` of a content answers the content itself; of a mutable content, a new
immutable one. `-mutableCopy` answers a mutable one. Two contents are equal
when every value is, whatever their mutability, and hash alike then.

Archived under `title`, `subtitle`, `body`, `badge`, `sound`, `launchImageName`,
`userInfo`, `attachments`, `categoryIdentifier` and `threadIdentifier`, the
names the system uses; its archives read back into the port and the other way.

The SDK declares members of later releases on these classes -
`summaryArgument`, `summaryArgumentCount` (iOS 12), `targetContentIdentifier`
(13), `interruptionLevel`, `relevanceScore` (15) and `filterCriteria` (16). They
are kept as the release keeps them, measured by `tests/backports/host/notification-content`
(30 checks, the host's classes and the port's print the same values; the five planted
controls fail):

- A fresh content has the summary argument `""`, a count of 0, no target content
  identifier, the interruption level 1 (active), a relevance of 0 and no filter criteria.
- The summary argument and the target content identifier are copied on set, the filter
  criteria too, and nil is kept as nil for each; the count is kept as set.
- The interruption level is kept as set (passive 0, active 1, time-sensitive 2, critical 3).
- The relevance is kept within [0, 1]: a value above one reads as one, and one below zero
  as zero.
- Equality compares all six, so a content that differs in any one of them is not equal to
  the original; the copies carry all six, and the archive does too.

The archive keeps the six under keys of the port's own, which are not the system's key
names: a release's archive of them is not read back, and the port's is not read by the
release, as with the rest of the archive's keys.

## What iOS 6 shows of it

A local notification of iOS 6 has a body, a sound, a badge and a launch image,
and nothing else. Of the content:

- `body`, `badge`, `sound` and `launchImageName` reach the release: the alert
  body, the badge number, the sound - `UILocalNotificationDefaultSoundName` for
  the default one - and the launch image.
- `userInfo` reaches it too, merged with the archived request under the key
  `org.charon.apple-backports.UNNotificationRequest`, so an application that
  also reads the notification through `UIApplication` sees its own keys.
- `title` and `subtitle` are **kept and not shown**. They stay with the request -
  archived, handed back by the pending requests and to the delegate - and the
  one place that would hand the title to the release is behind a single switch,
  `CharonReleaseShowsTitles`, off for iOS 6, whose local notifications have no
  title (it arrived in iOS 8.2). The first request that carries either says so
  in the log. Folding the title into the body would change the text the user
  reads, and nothing in any release does that, so it is not done.
- `categoryIdentifier` and `threadIdentifier` are kept and change nothing:
  iOS 6 has no categories, actions or threads. The first request that carries
  one says so in the log. The category set an application registers is kept
  (see `UNUserNotificationCenter.md`), and no action is ever shown.
- `attachments` stays empty in practice: `UNNotificationAttachment` is not
  there, so there is nothing to attach.

## Sound

`+defaultSound` and `+soundNamed:`. Two sounds are equal when both are the
default or both name the same file; the default sound is not equal to a named
one. Archived as `toneFileName`.

## Request

`+requestWithIdentifier:content:trigger:` asserts `identifier != nil` -
`NSInternalInconsistencyException`,
`Invalid parameter not satisfying: identifier != nil`. A nil content is taken
here and refused when the request is added. The identifier, the content and the
trigger are copied; two requests are equal when all three are. Archived as
`identifier`, `content` and `trigger`.

## Notification and response

`UNNotification` is a request and the date it arrived; `UNNotificationResponse`
a notification and an action identifier. Both are made by the center with
`+notificationWithRequest:date:` and `+responseWithNotification:actionIdentifier:`,
the names 10.3.4 gives them. The only action identifier iOS 6 can answer is
`UNNotificationDefaultActionIdentifier`, `com.apple.UNNotificationDefaultActionIdentifier`:
there are no actions, and a notification dismissed is never reported, so
`UNNotificationDismissActionIdentifier` is carried as a constant and never sent.

## Describing

`<%@: %p; identifier: %@, content: %@, trigger: %@>`,
`<%@: %p; date: %@, request: %@>` and `<%@: %p; actionIdentifier: %@, notification: %@>`,
as 10.3.4 writes them. A content is described by the public part of the 10.3.4
text - title, subtitle, body, category, launch image, thread, attachments,
badge and sound - since the rest names private values it does not carry.
