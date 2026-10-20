# Messages on a release with no Messages

`MSMessage`, `MSMessageLayout`, `MSMessageTemplateLayout` and `MSSession` are the classes an
application hands its message data to, and they arrived in iOS 10 with the iMessage extension point.
iOS 6.1.3 has none of it: the release's armv7 6.1.3 cache carries no Messages.framework surface, and
its own `MFMessageComposeViewController` - measured with `objc.binary_inventory` - has `-body`,
`-setBody:`, `-recipients`, `-setRecipients:`, `-messageComposeDelegate` and nothing else. It cannot
send an MMS, has no session, and has no transcript to draw an interactive bubble in.

So nothing here can be *sent*. What can be real is everything the objects *are*, and that is most of
their surface, because four of these classes are value objects: a message is a bag of values the
sender set and the receiver reads.

## The line this draws

The delivery this belongs to also had to decide what to do with ten members it had first written as
"kept and read back, never acted on" (`COORDINATION.md` §2's silent fake). The line it drew, and this
file is written on it, is:

- **A member whose promise is "the value I was given" is implemented.** A message's `URL`, `summaryText`,
  `shouldExpire`, `accessibilityLabel`, `layout`, a layout's captions, its image and its media URL: for
  these, keeping the value and answering it back *is* the contract. They also copy and archive, so
  they survive a round trip.
- **A member whose promise is "the system did something" needs the release's machinery.** The compose
  sheet's subject field, the attachment affordance, the one-time-code completion, the widget's display
  modes: without a subject field, an attachment row, a Messages code detector or a panel, there is no
  honest answer, so those members are not carried at all (`absent`, the port's own arrangement, 589
  absent methods and 727 absent properties of the same shape).

## The three members that are not values

**`isPending` answers YES, and that is derived, not stored.** The header defines it as a message that
has not been sent. Nothing in the port sends one - a message leaves through
`-[MSConversation insertMessage:completionHandler:]`, and there is no conversation, no iMessage service
and no Messages extension host here - so a message the port holds is unsent, and `isPending` is the
true answer. There is no flag and no reader waiting for it.

**`error` answers nil, for the same reason.** The header promises the error that occurred *while
sending*. No send was attempted, so no error occurred. An application that reads `error` to find out
whether a send failed is reading the truth, and the truth is that the message is still pending - which
is what `isPending` says in the same breath.

**`senderParticipantIdentifier` is this device's own identifier.** The header says the value is scoped
to the current device and is different on all devices in the conversation. So it is one `NSUUID`,
generated the first time it is asked for and kept in `NSUserDefaults`: stable across launches, and a
different value on every other device by construction. The release exports `NSUUID` (measured in the
same cache), so the value is a real object and not a stand-in. It is an identifier of the port, and
the file says so - Apple's is scoped to the device in the same way, and nothing here claims to be an
identity Apple's service assigned.

## `MSSession` is its identity, so a copy is itself

`MSSession` has no properties and no methods in the header. Its whole contract is that two messages
sharing a session are one exchange - which means `-copyWithZone:` must answer *the receiver*. A
`[self class] allocWithZone:` copy would be a different session, and would quietly break the one thing
a session exists for. It is equal only to itself, hashed by address, and archived and unarchived
through `NSSecureCoding`.

## `MFMessageComposeViewController.message`

The row that was open in the MessageUI delivery is now closed, because the class it needs is carried.
It is a value property by Apple's own abstract ("This property sets the initial interactive message"),
so it is copied in and copied out, and reading it before anything was set answers a fresh `MSMessage`
holding the body the release's composer already has rather than nil. What the release cannot do is
make that message *interactive*: there is no iMessage, no interactive bubble and no URL payload here,
and the release's own composer has no notion of a message at all. The message's session, URL, layout
and captions travel with it and are never drawn - the same truth `+canSendSubject` and
`+canSendAttachments` already report, for the same measured reason.

## Not measured against a host

There is no Messages.framework on the host and no differential for any of this; the classes are
iOS-only. `MSMessageLayout`'s and `UIImage`'s own behaviour - the copying and equality of a value
object - is the port's, and the port's `UIVisualEffect`/`UIAction` host differentials cover that
machinery rather than these classes. The device call test, which would archive a message, copy a
layout and read every member back, has not been run: see the delivery.
