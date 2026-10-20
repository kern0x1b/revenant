# The deferred start of iOS 26: 13 rows, one object, four owners

`AVFoundation/AVCaptureDeferredStart26.m` carries the eleven code rows - eight properties and three methods -
over the three classes the feature belongs to, and the registry
`registry/AVFoundation/deferredstart26.json` carries thirteen with the protocol row and its two methods.
Header: `RevenantAVCaptureDeferredStart26.h`, transcribed from the SDK 26.2 (`AVCaptureSession.h:670-725`,
`AVCaptureOutputBase.h:117-131`, `AVCaptureVideoPreviewLayer.h:262-278`).

**The protocol is not declared in that header.** `AVCaptureSessionDeferredStartDelegate` is in
`RevenantAVFoundationProtocols.h`, transcribed from the SDK 26.2 by `tools/transcribe-protocols.py@52253c0650`, and the
protocol row in the registry is what makes the generated protocol source emit it into every band - without the
row a conformance looks present in the source while the runtime has no protocol object to add it to (the trap
`facts/UIKit/UIKit16Absence.md` records). The regeneration, its command and its line counts are in the delivery
message and on the shared-file notice in QUEUE.md.

## What deferred start is, and why this release has none of it

"Deferred Start is a feature that allows you to control, on a per-output basis, whether output objects start when
or after the session is started. The session defers starting an output when its
`AVCaptureOutput/deferredStartEnabled` property is set to `true`, and starts it after the session is started."
(`AVCaptureSession.h:671`). It is a startup-latency feature: the session holds an output's resources back so an
application can put its interface up first.

6.1.3's capture session has no member of any kind for it - measured, tools/corpus/objc-inventory.lua over the
6.1.3 armv7 cache: its `AVCaptureSession` owns none of these selectors and no deferred-start member at all. So
this object is four categories on three classes the release already carries, and every answer is the header's
own answer for a release that cannot defer anything.

## Every refusal the port raises is Apple's own measured string, character for character

```
-[AVCaptureSession setDeferredStartDelegate:deferredStartDelegateCallbackQueue:]
  *** -[AVCaptureSession setDeferredStartDelegate:deferredStartDelegateCallbackQueue:] Deferred start not supported
-[AVCaptureSession runDeferredStartWhenNeeded]
  *** -[AVCaptureSession runDeferredStartWhenNeeded] Deferred start not supported
```

and the exception is `NSObjectInaccessibleException`, which is what "this platform has no deferred start" is and
what the controls family raises for the same shape of absence (facts/AVFoundation/CaptureControls.md). The host
raises both with the same text and the same class, so the port's are the same strings with nothing swapped.

**The order was measured, and it is why the header's NULL-queue rule is not implemented.** The host raises the
same refusal for a delegate with a real dispatch queue exactly as it does for one with a NULL queue, so "If
`deferredStartDelegate` is not `NULL`, the session throws an exception if `deferredStartDelegateCallbackQueue` is
`nil`" (`:719`) is never reached on a release that cannot defer anything. The port does not add a second error
for a case Apple never reaches - the decision `CaptureControls.md` records for the controls family's own
NULL-queue rule.

## "LINKED ON OR AFTER iOS 26" IS A PROPERTY OF THE APPLICATION, and the port READS it

Three of the header's sentences are written with that condition - the session's default (`:685`) and the output's
default (`AVCaptureOutputBase.h:129`) - and the preview layer's has **no** version clause at all (`:271`). An
earlier version of this object read the condition as TRUE in one place and FALSE in another, which the
coordinator's ruling called the wrong answer twice over: the condition is a fact about the application, and every
band of this repository links against SDK 16.4.

So it is read, once, from the only place it is written down: the `sdk` field of the main executable's own load
command (`LC_VERSION_MIN_IPHONEOS`, or `LC_BUILD_VERSION` for the platform the image was linked for), through
`packages/frameworks/apple-backports/RevenantProgramSDK.h`. That read was a file-static in
`UIKit/UIViewController+AutomaticPresentation.m`, which is not reusable - a static in one object cannot be called
from another - so it became a header of `static inline` functions and the UIKit caller includes it, which is the
arrangement `RevenantValueStore.h` and `RevenantSayOnce.h` already use and for the same reason: two libraries that
include it each get their own copy and neither needs an exported symbol, which this package's registry does not
allow.

The harness holds both branches, because one binary can only answer one: it links the probe twice, once with this
host's SDK field and once with `-Wl,-platform_version,macos,11.0,16.4`, and each probe prints the field it was
linked with (a `CONTROL` line, read back through the port's own helper) so the link is a measurement and not a
claim. Then:

- **`AVCaptureSession.automaticallyRunsDeferredStart` moves with the link** (NO at 16.4, YES at 27.0), because
  the condition is the only thing behind it.
- **`AVCaptureOutput.deferredStartEnabled` does not move, and must not**: its sentence also needs
  `deferredStartSupported`, which is NO for every output on this port, so "and false otherwise" answers NO in
  either reading.
- **`AVCaptureVideoPreviewLayer.deferredStartEnabled` does not move**, because its sentence names no version.

The plant `linkread` asks the read about version 4.0 - which every band passes - so the session's row answers YES
where the link says NO, and both the two-build check and the table comparison see it.

### The count in that line was wrong for four runs, and it was my fault

The line above used to end "and the other **0** answers are the same in both", while the check was comparing all
108. The count came from `grep -c '^ANSWER' "$build/answers26"` and that file holds the comparison's working
form - `api<TAB>host<TAB>port`, the leading `ANSWER` field already dropped - so the pattern could never match and
the count was zero on every run. I read that as a formatting slip, wrote **103** into this page by hand, and
reported it to the coordinator as "the other 103 answers are the same in both": a number no run printed.

Three things are different now, and the first is the one that matters:

1. **The check refuses to be vacuous.** It fails when it compared fewer answers than the 26 build's table holds,
   when any answer had no row in the other build, or when the one row the header makes depend on the link alone
   did not move. Measured on a scratch copy of the run with the pre-26 build's ANSWER rows removed and its
   CONTROL lines kept - the one shape the control checks cannot see:
   `FAIL: the two linked probes were compared over 0 of the 108 answers the table holds (108 of them had no row in
   the other build), so this check would pass without comparing anything - a vacuous check is not a check`
2. **The count is measured in the loop** rather than grepped out of a file that does not carry the field.
3. **The red control turns it red by the guard**, which is what the coordinator asked to see:
   `AVFCAPSMUTANT=linkread` -> `FAIL: no row moved between the two linked probes, so the port's
   linked-on-or-after read is not following the binary it is in` (with the comparison at version 4.0 both builds
   answer YES, so nothing moves - and a check that only counted differences would have passed).

## Three rows where the port follows the header and the host does not, each with both columns

| case | host | port | the sentence |
| --- | --- | --- | --- |
| `automaticallyRunsDeferredStart` | 0 | **NO** | "By default, for apps that are linked on or after iOS 26, this value is `true`" (`:685`), and **the condition is read from the main executable's own load command** - see the section below. Every band of this repository links against SDK 16.4, so the band answer is the pre-26 one, NO. The host's 0 is macOS's own default, not this rule's |
| `setAutomaticallyRunsDeferredStart: false` | **returns** | raises NSInvalidArgumentException | "If `manualDeferredStartSupported` is `false`, setting this property value to `false` results in the session throwing an `NSInvalidArgumentException`" (`:686`), and the flag is NO |
| `setDeferredStartEnabled: true` on a preview layer | **returns**, and the getter then reads 1 | raises NSInvalidArgumentException | "If `deferredStartSupported` is `false`, setting this property value to `true` results in the session throwing an `NSInvalidArgumentException`" (`AVCaptureVideoPreviewLayer.h:275`), and the flag is NO |

The third is measured on the host's own layer: it reports `deferredStartSupported` NO and accepts YES anyway.
Each of the three is the call the coordinator accepted for the locked-frame-duration setter - the port follows
the header where the header is explicit and the host does not, and the row carries both columns.

One more difference is a class name and nothing else: `-setDeferredStartEnabled:` on an **output** refuses on
the host with `*** -[AVCaptureVideoDataOutput setDeferredStartEnabled:] Not supported by this device`, and the
port raises the same tail with its own `AVCaptureOutput`, which is the class the header declares the property on
(Apple's text names its concrete subclass).

## The four owners, and the two read-only members that follow from the refusals

`deferredStartDelegate` and `deferredStartDelegateCallbackQueue` answer nil on both sides, because nothing can
be set: a setter that refuses every value has no last accepted one, so nothing is stored and there is no
associated object in this object at all. `manualDeferredStartSupported`, `AVCaptureOutput.deferredStartSupported`
and `AVCaptureVideoPreviewLayer.deferredStartSupported` answer NO on both sides - the release's session has no
deferred start for any of them to take part in - and the two `deferredStartEnabled` flags answer NO by each
header's own documented default.

## Checks

```
sh tests/backports/host/avf-capabilities/run.sh   exit 0
  ok  two probes, linked against [27.0] and [16.4]: 1 row(s) whose only condition is the link
      moves with it, 2 of the 2 rows the header pins through a term this port answers NO stayed at
      NO, and all 108 answers were compared - none fewer than the 108 the table holds
  ok  66 members are answered by both sides, or by the port alone where the table says the host has none
  ok  103 answers are the ones expectations.tsv names, the host's and the port's columns both
  ok  AVCaptureSession.deferredStartDelegate after every refused set - host and port both nil, which is what
      the three refusals mean for the two read-only members
AVFCAPSMUTANT=deferred  ok  the mutation was noticed: 1 of 103 table answers, 0 of 8
AVFCAPSMUTANT=linkread  ok  the mutation was noticed: 1 of 103 table answers, 0 of 8
CONTROL=1 with each of the ten plants  ok  the control is clean
```

Ten plants, all noticed:
`capabilities` (3 of 103), `multichannel` (4 of 103), `rectsupport` (1 of 103), `cinematic` (6 of 103),
`syncmin` (2 of 103), `smudge` (1 of 103), `deferred` (1 of 103 - a session that supports a deferred start by
hand, which is what `-setAutomaticallyRunsDeferredStart:`'s refusal is tied to), `linkread` (1 of 103 - the linked-on-or-after read asked about version 4.0, which every band passes).

### Two more harness defects this family found

1. **A protocol body is an owner too.** The member generator only recognised `@interface X (Category)` lines as
   owners, so every line inside `@protocol X <NSObject>` was skipped - and the two deferred-start delegate methods
   are declared there, in a header the run was reading. The run reported them as undeclared while holding the
   file that declares them.
2. **Declarations must be visible to every registry file, not only to their own pair.** The generator read one
   header and its own registry file per pair, so the protocol header's declarations (the last pair) did not
   exist yet when the deferred-start rows (the pair before) were read. It is two loops now: every header first,
   then every registry file.
