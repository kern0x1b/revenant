# Intents on iOS 6: the data model, and the Swift module

iOS 6 has no Intents framework. A Siri extension is never launched there, but Telegram's `IntentsExtensionLib`,
`NotificationServiceExtensionLib` and the app itself build against the Intents API, and the notification service builds an
`INSendMessageIntent` and keeps an image in it. The backport carries the value objects, the responses and the resolution results
that code names, so that it links, runs and behaves as the SDK describes. Nothing here talks to Siri.

## What is implemented

| File (`frameworks/Backports/src/Intents/`) | Classes |
| --- | --- |
| `RevenantIntentsResponse.m` | `INIntentResponse` with `userActivity`, and its subclasses `INSendMessageIntentResponse` (`sentMessages`), `INSearchForMessagesIntentResponse` (`messages`), `INSetMessageAttributeIntentResponse`, `INSearchCallHistoryIntentResponse` (`callRecords`) and `INStartCallIntentResponse`, each with `code`, `initWithCode:userActivity:`, secure coding, copying and a description that names the code |
| `RevenantIntentsMessages100.m` | `INSearchForMessagesIntent` (the nine-argument designated initializer, the speakable group name form, the deprecated group name form, the conditional operators and the derived group names) and `INSetMessageAttributeIntent` |
| `RevenantIntentsCalls110.m` | `INCallRecord` (the nine-argument designated initializer, the number of calls form, the six-argument form, the deprecated `caller:` forms that store the caller as the only participant) and `INSearchCallHistoryIntent` (the five-argument designated initializer, the deprecated call type form that maps one call type to its option, and the derived `callType`) |
| `RevenantIntentsResults100.m` | `INPersonResolutionResult`, `INSendMessageRecipientResolutionResult`, `INStartCallContactResolutionResult`, `INStringResolutionResult`, `INMessageAttributeResolutionResult`, `INMessageAttributeOptionsResolutionResult`, `INCallDestinationTypeResolutionResult`, `INCallRecordTypeResolutionResult` and `INCallRecordTypeOptionsResolutionResult`, each with `success`, `disambiguation`, `confirmationRequired`, `needsValue`, `notRequired` and `unsupported` constructors, and the unsupported reasons of the recipient and contact results |

The enumerators of the response codes, `INMessageAttribute`, `INMessageAttributeOptions`, `INConditionalOperator`,
`INCallRecordType`, `INCallRecordTypeOptions` and the unsupported reasons are named in these files, so the lowering takes them as implemented.

Coding, copying, equality and hash go through `coding/RevenantCoding.m`, which walks the instance variables of the class and its
superclasses. `revenant_intents_equal` and `revenant_intents_hash` compare only the instance variables of the class that asks, so
`INIntent`'s per-instance identifier does not make two equal intents differ. Copying keeps a mutable instance variable mutable:
before, the copy of an intent that held images got an immutable image table and `setImage:forParameterNamed:` on the copy raised.
`NSUserActivity` is on the by-name list of classes secure decoding accepts, as iOS 6 has no such class.

## The Swift module

The SDK's Swift overlay of Intents is not shipped for armv7, so `INSendMessageIntent.setImage(_:forParameterNamed:)` with a key
path, `INParameter(keyPath:)`, the `INCallRecord` initializers with `Double?` and `Bool?`, and `INSearchCallHistoryIntent`'s `unseen`
are missing from an armv7 build (Telegram's `NotificationService.swift:611` and `IntentMessages.swift:215`).
`src/Intents/Intents.swift` is the backport's overlay for them, built with `-import-underlying-module`: the `_INIntentSetImageKeyPath`
and `INIntentSetImageKeyPath` protocols, adopted by `INIntent`, over the refined `__setImage` and `__image`; the `INParameter`
key path initializer, which turns the key path into its KVC string; the `INCallRecord` initializers and accessors; and the
`INSearchCallHistoryIntent` initializer and `unseen`. A consumer builds the `Intents` target of the `Swift` component, puts its module folder on
`-I` and links `libIntents.a`; for Telegram that is one more name in `SWIFT_MODULES` of `telegram-build/tools/bazel-overlay.lua`.

## Checked

- `frameworks/Backports/tests/framework_overlay_test.lua` builds the module for armv7 iOS 6.0 against the lowered SDK, typechecks
  `frameworks/Backports/tests/Intents/overlay.swift` (Telegram's call patterns, with no availability guard), and checks that the
  same file fails without the module (`has no member 'setImage'`).
- `tests/Intents/calls_test.m` compares `INCallRecord` with the macOS class over every initializer, secure coding, copying and
  equality: 77 checks, run directly with clang because the xmake host group is not configurable in a private cache without the
  host packages. The other classes are `API_UNAVAILABLE(macos)` or use types that are, so they cannot be compared there.
- `tests/device_probe/intents_main.m` (`IntentsProbe`) runs 54 checks of the responses, the two message intents, the call
  record and call history intent, the image table and the resolution results on an iPhone 4S, iOS 6.1.3: all pass. It links the
  Intents sources and the generated skeleton directly, without `libFoundationBackports`, so `NSDateInterval` is absent in it and
  the secure-decoding class list it builds stops after `NSDateComponents`; no class under test decodes anything after that.
- Telegram's real swiftc arguments for `IntentsExtensionLib`, `NotificationServiceExtensionLib`, `GalleryUI`, `TelegramIntents`,
  `TelegramCallsUI` and `ShareExtensionContext`, replayed with `-typecheck` against the lowered SDK of this tree and the module
  above, report no error.

## Reasoned, not measured

The description strings (`code=success`, `reason=noValidHandle`) are this backport's, not Apple's. The mapping of one
`INCallRecordType` to its option and back follows the names of the two enumerations. The default operator of a search intent is
`INConditionalOperatorAll`, the first enumerator. None of this was compared with an iOS 10 or later device.

## Not implemented

`INDateComponentsRange`, `INRecurrenceRule`, `INMessageReaction`, `INSticker` and `INRideDriver` are implemented only where a
source file of this tree names them (a category of `INDateComponentsRange` and one of `INRideDriver`); their other
initializers and members come from the generated skeleton and stop with `not implemented` when called, as an unimplemented
initializer of `INSendMessageIntent` did in the probe. A search intent cannot be built with a date range on the device.
Telegram builds none; the probe passes `nil` for the range.
