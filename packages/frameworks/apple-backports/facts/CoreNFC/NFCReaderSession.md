# NFCReaderSession and NFCNDEFReaderSession, iOS 11.0

Introduced in iOS 11.0: the session an application opens to read a tag. What an
application asks before it opens one is whether the device can read tags at all,
`+readingAvailable`, and that is what is carried.

Source, and what was measured: the SDK 16.4 header `NFCReaderSession.h`
declares `+readingAvailable` as available from iOS 11.0, and its text says YES
if the device supports NFC tag reading. The host's CoreNFC through Mac Catalyst
answers NO for it on both classes, and gives `NFCErrorDomain` the value
`NFCError`; there `NFCNDEFReaderSession` is a subclass of `NFCReaderSession`.

**The release caches were read, and the previous statement here was wrong.** It
said CoreNFC is in no shared cache this package holds. It is.

**The command.** From the repository root, with no xmake project and no gate:

```
REVENANT_ROOT="$PWD" xmake l tools/corpus/cache-census.lua NFC
```

`tools/corpus/cache-census.lua` reads each named release's cache with
`modules/apple/objc.lua`'s `inventory`, prints the images, classes and protocols
it carries that name the prefix, and prints a control in the same run: if no
rung read found a name, it prints `CONTROL FAILED` and the run certifies
nothing. Its output, in full, the three defaults being the two releases this
package deploys on and the first rung that carries CoreNFC. The two long lines
are cut here at their class and protocol names:

```
6.1.3     $HOME/.revenant/dyld/6.1.3/dyld_shared_cache_armv7
         images 524, of which naming NFC 0
         classes 11378, of which NFC* 0
         protocols 1171, of which NFC* 0
4.3       $HOME/.revenant/dyld/4.3/dyld_shared_cache_armv7
         images 354, of which naming NFC 0
         classes 7187, of which NFC* 0
         protocols 564, of which NFC* 0
11.0      $HOME/.revenant/dyld/11.0/dyld_shared_cache_arm64
         images 1258, of which naming NFC 1
         classes 52768, of which NFC* 34 (NFCError NFCHardwareManager ... NFCurrency)
         protocols 8954, of which NFC* 11 (NFCHardwareManagerCallbacks ... NFContactlessUICCSessionInterface)
control: 45 name(s) beginning NFC found in this run, so a zero on another rung
is the release's and not the reader's
```

The 34 and the 11 are the control, and they are what makes the two zeros mean
anything: the same reader, the same run, the same prefix. `objc-inventory.lua`
answers the same question for one cache at a time and is the tool behind it.

| held cache | what it carries of CoreNFC |
| --- | --- |
| **6.1.3 armv7** (deployment) | 0 of 524 images name NFC; 0 of 11378 classes and 0 of 1171 protocols begin with `NFC` |
| **4.3 armv7** (deployment) | 0 of 354 images; 0 of 7187 classes and 0 of 564 protocols |
| 11.0 arm64 | 1 of 1258 images is `CoreNFC.framework`, **34** `NFC*` classes and 11 `NFC*` protocols |
| 16.0 arm64e | as 11.0, and the two delegate protocols among them |

Every count in the table is a line of the command above.

**The second reader, and what it corrects.** A class-prefix census reads class
and protocol metadata, so the natural question is whether a *different* reader
agrees. `tools/corpus/cache-census.lua --selectors` asks through the other one -
`modules/apple/objc.lua`'s `known_selectors`, which reads the selector table, a
different part of the image:

```
REVENANT_ROOT="$PWD" xmake l tools/corpus/cache-census.lua --selectors \
  -readingAvailable -beginSession -invalidateSession -isReady -alertMessage \
  -sessionQueue -initWithDelegate:queue:invalidateAfterFirstRead: -ndefMessagePayload
```

Its output, in full, each release preceded by its selector count and four
controls - three every release registers and one none does:

```
== 4.3  $HOME/.revenant/dyld/4.3/dyld_shared_cache_armv7
   selectors the cache registers: 70062
   control  -isEqual:                     known
   control  -description                  known
   control  -initWithFrame:               known
   control  -revenantNoSuchSelectorAnywhere:  unknown, as it must be
   ask      -readingAvailable             absent
   ask      -beginSession                 absent
   ask      -invalidateSession            known
   ask      -isReady                      known
   ask      -alertMessage                 absent
   ask      -sessionQueue                 absent
   ask      -initWithDelegate:queue:invalidateAfterFirstRead:  absent
   ask      -ndefMessagePayload           absent
== 6.1.3  $HOME/.revenant/dyld/6.1.3/dyld_shared_cache_armv7
   selectors the cache registers: 113981
   control  -isEqual:                     known
   control  -description                  known
   control  -initWithFrame:               known
   control  -revenantNoSuchSelectorAnywhere:  unknown, as it must be
   ask      -readingAvailable             absent
   ask      -beginSession                 absent
   ask      -invalidateSession            absent
   ask      -isReady                      known
   ask      -alertMessage                 absent
   ask      -sessionQueue                 absent
   ask      -initWithDelegate:queue:invalidateAfterFirstRead:  absent
   ask      -ndefMessagePayload           absent
== 11.0  $HOME/.revenant/dyld/11.0/dyld_shared_cache_arm64
   selectors the cache registers: 487244
   control  -isEqual:                     known
   control  -description                  known
   control  -initWithFrame:               known
   control  -revenantNoSuchSelectorAnywhere:  unknown, as it must be
   ask      -readingAvailable             known
   ask      -beginSession                 known
   ask      -invalidateSession            known
   ask      -isReady                      known
   ask      -alertMessage                 known
   ask      -sessionQueue                 known
   ask      -initWithDelegate:queue:invalidateAfterFirstRead:  known
   ask      -ndefMessagePayload           absent
```

**This reader cannot decide these rows, and the reason is the point.**
`-invalidateSession` is registered in 4.3 and `-isReady` in both deployment
releases, where CoreNFC is not: they belong to other classes, and a selector
carries no owner. A bare selector match is therefore not evidence that a
release carries a name, and `-invalidateSession` answering "known" at 4.3 says
nothing about `NFCReaderSession.invalidateSession`. The class-scoped census is
what decides, because the row is about a member of a named class; the two
readers agreeing on `-readingAvailable` and on the initializer is a second
reader confirming it where a selector *is* specific, and this one says so where
it is not rather than being quoted. `-ndefMessagePayload` is absent from all
three, 11.0 included, and is first held at 16.0.

12.0's arm64 cache carries no CoreNFC either, which is that cache's own state
and not this port's; `tools/cache-index/first-rung.lua` reads the same rungs and
the same answer (`NFCReaderSession` at 11.0, 16.0, 18.0 and at no other held
rung), by a different reader again - the whole symbol table rather than the
Objective-C metadata - which is why the two agree. The command, and its control:

```
xmake l tools/cache-index/first-rung.lua --self-test          # 8 of 8, the checks that mean the rest
xmake l tools/cache-index/first-rung.lua --rungs NFCReaderSession
xmake l tools/cache-index/first-rung.lua _NFCISO15693TagResponseErrorKey
```

The last two print `NFCReaderSession  11.0,16.0,18.0` and
`_NFCISO15693TagResponseErrorKey  11.0`. A C symbol needs its leading
underscore: the bare name answers `NONE` at every rung, which is the tool being
literal about a name no image holds under it.

16.0 and 18.0 are held as **arm64e** and at no other architecture, 11.0 and 12.0
as arm64; the census picks each release's architecture through
`dyld.held_ladder` and prints the cache it read, so the split is visible in the
output rather than something to remember.

The two delegate protocols, `NFCReaderSessionDelegate` and
`NFCNDEFReaderSessionDelegate`, are a second fact the caches give and the headers
do not: **neither is a protocol in 11.0's or 12.0's cache**, where
`NFCReaderSession` and `NFCTag` are both class and protocol, and both first
appear as protocols in 16.0's arm64e cache. `NFCReaderSession` is the name of a
class *and* of a protocol in 11.0 and 16.0. Read with

```
REVENANT_ROOT="$PWD" xmake l tools/corpus/objc-inventory.lua \
    "$HOME/.revenant/dyld/11.0/dyld_shared_cache_arm64" \
  | grep -E '^(class|protocol)[[:space:]]+(NFCReaderSession|NFCNDEFReaderSession|NFCReaderSessionDelegate|NFCNDEFReaderSessionDelegate)[[:space:]]'
```

which prints three lines and no fourth, the absence being the result:

```
class	NFCNDEFReaderSession
class	NFCReaderSession
protocol	NFCReaderSession
```

Neither delegate appears as a `protocol` line: the SDK header declares both, and
11.0's own binary carries no metadata for either.

## What is carried

The reader sessions are carried as CoreNFC makes them on a device with no radio. Every line below is a line of
`tests/backports/host/nfc-session`, which asks the host (Catalyst's CoreNFC) and the port's classes the same questions and
diffs the answers; the host is held to `expected.txt`.

- `+readingAvailable` answers **NO** on `NFCReaderSession`, `NFCNDEFReaderSession` and `NFCISO15693ReaderSession`, which
  inherit it.
- **A session can be made.** Its initializers answer by the delegate they are given, not by the device:
  - `-[NFCNDEFReaderSession initWithDelegate:queue:invalidateAfterFirstRead:]` answers an object for a delegate that
    implements `readerSession:didDetectNDEFs:`, and **nil** for a nil delegate or one without it. A delegate with only
    `readerSession:didInvalidateWithError:` gets nil.
  - `-[NFCISO15693ReaderSession initWithDelegate:queue:]` answers an object for a delegate that implements
    `readerSessionDidBecomeActive:`, and nil otherwise.
- `-isReady` answers **NO**. There is no `-ready` selector, and there is no `-setDelegate:`.
- `alertMessage` is nil until it is set, and the setter keeps a copy that the getter answers back.
- `delegate` is held weakly: it answers the delegate the session was made with, and nil once that delegate is released.
- `sessionQueue` answers the queue the session was made with. A nil queue gets a serial queue of the session's own,
  which is non-nil.
- `-beginSession` calls the delegate's `readerSession:didInvalidateWithError:` with **NFCError code 1**
  (`NFCReaderErrorUnsupportedFeature`), on the session's queue, after the run loop turns, once per begin.
- `-invalidateSession` after a begin calls the delegate again with the same error. Before a begin it ends the session:
  a begin that follows calls nothing, and nothing is ever called on that session.
- **A begun session is kept until its callback is made.** A session the application drops at once after the begin still
  calls back. The port's block holds the session for the same reason.
- `NFCErrorDomain` is `NFCError`, and `NFCISO15693TagResponseErrorKey` is the string `ISO15693TagResponseErrorCode`.
- The two delegate protocols, `NFCReaderSessionDelegate` and `NFCNDEFReaderSessionDelegate`, are declared by the header
  the generator writes (`RevenantCoreNFCProtocols.h`) from the SDK 16.4 bodies in `spec/CoreNFC/protocols.tsv`, through the
  CoreNFC rows of `spec/protocol-headers.tsv`. Their required and optional selectors are the host's
  (`tests/backports/host/nfc-protocols`, which diffs the two lists).

## What this file said before, and what was wrong

The earlier version of this section said the initializers always answer nil, that a session cannot be begun, and that
the members were absent because a stub would answer for a radio that does not exist. The measurement was made with a
delegate that did not implement the callback the initializer checks, so it got nil for a reason that has nothing to do
with the radio. Measured with the delegates that a session takes, the host answers an object, and the members answer what
the list above says. The earlier claim that the rows are absent is withdrawn: they are implemented as that list states.

The probe's first measurement that a begun session is not kept alive was also wrong for the same reason: the session it
measured was nil. Measured with a session that exists, a begun session calls back after the application lets go of it.

## The tag protocols, and the activity's message

- **NFCTag and NFCISO15693Tag** (protocols) are declared by the generated header, with the SDK 16.4 members. Their
  required selectors are the host's (`tests/backports/host/nfc-protocols`, which lists both protocols on each side). The
  header also needs the three enumerations the members name (`NFCTagType`, `NFCISO15693RequestFlag`,
  `NFCISO15693ResponseFlag`), the `NFCNDEFStatus` enumeration and the `NFCNDEFTag` protocol that `NFCISO15693Tag`
  inherits from; those are rows of the same table and are not registry rows of their own. The three members the
  snapshot writes with a bare `API_AVAILABLE` are replaced by the SDK's declarations.
  No class of the port is a tag, because no session on this device delivers one, so no class conforms to these
  protocols. The rows are the protocol objects.
- **NSUserActivity.ndefMessagePayload** is a read-only category in the CoreNFC library
  (`CoreNFC/NSUserActivity+CoreNFC.m`). The host's value for an activity no tag launched is measured
  (`tests/backports/host/nfc-activity`): one record of the empty type-name format, with no type, identifier or
  payload, a message of length 3, and a new message on every read, whatever the activity's type and user info.
  The header declares the property read-only; the host also answers `-setNdefMessagePayload:`, which the header does
  not declare, and the port does not carry it.

## The probes, and how to run them

```
sh tests/backports/host/nfc-session/run.sh     # PASS golden, PASS alike, PLANT
sh tests/backports/host/nfc-protocols/run.sh   # PASS golden, PASS alike, PLANT
```

Both print their plant: a session whose unsupported-feature error is NFCReaderErrorRadioDisabled (14), and a protocol
header with `didDetectTags:` removed from `NFCReaderSessionDelegate`. Each diff must be non-empty.

Everything here is measured on Catalyst. The device's CoreNFC is not on this machine and no device has been asked, so the
device behaviour of a session that is never ready is the host's answer, not a device's.
