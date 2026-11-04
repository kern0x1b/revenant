# UserNotifications attachments on iOS 6

`UNNotificationAttachment`, the `UNNotificationAttachmentOptions*` keys and the `UNErrorCodeAttachment*` codes are iOS 10
API. Swift code (expo-notifications among them) sees them lowered for an iOS 6 target: they are in
`frameworks/Backports/tools/lowered-members.txt`, and their Objective-C implementations are in
`frameworks/Backports/src/UserNotifications/UNNotificationAttachment.m`. The lowering is generated from the source tree
and the SDK by `frameworks/Backports/tools/lowered_members.lua`. The presentation options typedef is the exception, see
below.

## What the class does

`+attachmentWithIdentifier:URL:options:error:` checks the URL and the type, then keeps the identifier, the URL and the type.

- The URL must be a file URL that names a readable regular file. A remote URL, a missing file, a directory or an
  unreadable file is refused with `UNErrorCodeAttachmentInvalidURL`.
- The type is the `UNNotificationAttachmentOptionsTypeHintKey` value when it is a non-empty string. Otherwise it comes
  from the file's extension, case-insensitively, through a fixed table: JPEG, PNG, GIF, MP3, M4A, WAV, AIFF, CAF, MP4,
  M4V and QuickTime movies. An extension outside the table, without a hint, is refused with
  `UNErrorCodeAttachmentUnrecognizedType`.
- The file's content is not read. The type is decided from its name, so a file that is named as a PNG but is not one is
  accepted.
- The file is not copied into a data store, and its size is not checked against a limit. The attachment keeps the URL
  it was given.
- The `UNNotificationAttachmentOptions*` keys other than the type hint are accepted and not used.
- The class supports `NSSecureCoding` and `NSCopying`; the copy is the same object, as for `UNNotificationRequest`.

## What iOS 6 does not do

iOS 6 has no notification attachments. A notification scheduled with an attachment is delivered without it: the
attachment is validated when it is made, and nothing shows it. The thumbnail and clipping options have no effect.

## Open: the presentation options typedef

`UNNotificationPresentationOptions` is not lowered yet, so Swift still sees the SDK's iOS 10 typedef. The generator
lowers a typedef only when a lowered declaration uses it. Its one user is the delegate method
`userNotificationCenter:willPresentNotification:withCompletionHandler:`, and a protocol member is lowered only when a
backport class adopts the protocol and implements that member (`toolchain/modules/apple/lowered.lua`, `protocol_status`,
`docs/explanation/backports-gaps.md`, the open row about `UIDocumentPickerDelegate`). Nothing in the backport does, so
the typedef stays out of `lowered-members.txt`. Two ways to close it: lower the delegate members the backport calls
(a rule change in `toolchain/modules/apple/lowered.lua`, which touches every protocol), or give the backport a class that
adopts `UNUserNotificationCenterDelegate` with real behaviour. Neither is done here.

## Checks

`frameworks/Backports/tests/UserNotifications/attachment.m` runs the class against the cases above and a secure-coding
round trip, and `user_notifications_test.lua` requires its `attachment ok` line. The backport's output for the existing
UserNotifications cases matches the host's. Nothing has been run on a device.
