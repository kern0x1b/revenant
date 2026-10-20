# APActivationPayload and the payload of an NSUserActivity, iOS 14

An App Clip is a small application Apple lets an author cut out of a larger one, launched by a
physical invocation: an NFC tag or a visual code the camera reads. The system, not the application,
decides to launch one; it passes what it knows about the invocation — the link that was scanned, and
where the device physically was — to the application as an `APActivationPayload` inside the
`NSUserActivity` the launch carries, and the application confirms the place with
`confirmAcquiredInRegion:completionHandler:`.

## What the devices this port runs on are

iOS 6.1.3 has no App Clips. Measured: the armv7 shared cache of iOS 6.1.3 has no `AppClip.framework`
and no App Clip service; there is no App Clip binary, no registered App Clip URL, no NFC tag
invocation (the release has no NFC radio of its own for it), and no service that can confirm where an
invocation happened. Nothing on the release can put a payload into an `NSUserActivity`.

So no payload is ever made. The class is carried anyway, because an application that is an App Clip
names it and a strong reference to a class that is not there stops the application at launch — and
because the surface is where the honest answer belongs.

## What the port answers

- `URL` is `nil`, always. A payload of this release was made by nothing, so it holds no link. An
  application that reads it learns the invocation did not happen here, which is the truth.
- `confirmAcquiredInRegion:completionHandler:` calls the handler once with `NO` and an `NSError` in
  `APActivationPayloadErrorDomain` with code `APActivationPayloadErrorCodeDisallowed` (1), on the
  thread that asked, before the call returns. A nil region is answered the same way — the release
  cannot confirm any place, so there is nothing to distinguish — and a nil handler is allowed.
- `+supportsSecureCoding` is `YES`, `-encodeWithCoder:` writes nothing and `-initWithCoder:` gives an
  empty payload: there is no field of a payload of this release to archive, so an archive of one
  restores what it always was. `-copyWithZone:` is the receiver, the payload being immutable.
- `NSUserActivity.appClipActivationPayload` is `nil` on every activity, including one the application
  made itself and one restored from an archive. The `NSUserActivity` of this release is the one
  Foundation's own backport carries (`registry/Foundation/base.json`, status `inert`: it holds what
  it is given and is never advertised, indexed or continued), so this category is on a class of this
  package and attaches to it.
- `APActivationPayloadErrorDomain` is `APActivationPayloadErrorDomain`, the text AppClip itself
  gives it, read from the arm64e shared cache of iOS 18.0 with `tools/corpus/cache-value.lua`.

`APActivationPayloadErrorCodeDisallowed` is the framework's own code for this case: the header says
the request "fails with `disallowed` if the source of the invocation isn't an NFC tag or a visual
code". On this release the source can never be one, so the code is the documented answer and not an
invented one. The description says the same in this port's words: "The App Clip invocation did not
come from an NFC tag or a visual code."

## What was measured, and what was not

Measured: the state of the release (the 6.1.3 armv7 cache, above), the text of the error domain (the
18.0 arm64e cache), the shape of the class (the headers of the SDK 16.4).

Not measured: the behaviour of Apple's own `APActivationPayload`. AppClip does not exist on macOS
and cannot be measured on a host, and no release this port runs has it. The thread and the moment of
the completion handler therefore follow the same rule the other carried seams of this package use —
the answer is known without a system call, so the handler is called on the thread that asked, before
the call returns — and that choice is written down here rather than presented as a measurement.
