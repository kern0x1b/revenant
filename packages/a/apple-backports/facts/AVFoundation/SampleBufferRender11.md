# The two 11.0 sample-buffer render classes, carried

`AVSampleBufferAudioRenderer`, `AVSampleBufferRenderSynchronizer` and the protocol
`AVQueuedSampleBufferRendering`, all of them `absent` on 6.1.3 and all three now carried by the port's own
objects. Four objects, one release each:

| object | release | what it carries |
| --- | --- | --- |
| `AVFoundation/AVSampleBufferRenderSynchronizer11.m` | 11.0 | the class, and the eleven 11.0 members of the two classes and the protocol |
| `AVFoundation/AVSampleBufferAudioRenderer11.m` | 11.0 | the renderer, on an AudioQueue |
| `AVFoundation/AVSampleBufferRenderSynchronizer12.m` | 12.0 | `-currentTime` |
| `AVFoundation/AVSampleBufferRenderSynchronizer14.m` | 14.5 | `-setRate:time:atHostTime:` |

`AVFoundation/CharonAVSampleBufferRender.h` is the private header the three of them share: the one method
the synchronizer says to a renderer when its rate changes, and the synchronizer's own seams.

## The correction, and it is in the renderer's queue

The row said `AVSampleBufferAudioRenderer` was a wall, and the wall was the queue: "of the 43 exports
matching `AudioQueue` the three time members all READ a time, so a queue that can only play from now cannot
honour a timestamp." **That is false, and the coordinator's reading was right.** Measured:

    xmake l tools/image-exports.lua 6.1.3 armv7 AudioToolbox.framework/AudioToolbox AudioQueue

337 exports, 43 matching, and among them **`_AudioQueueEnqueueBufferWithParameters`**, whose tenth argument
is the time to play the buffer at (AudioQueue.h:1189, and the note at :1181: "If you specify the time using
the mSampleTime field of the AudioTimeStamp structure, the sample time is relative to the time the queue
started"). So the timestamp never travels on the buffer - which is why `AudioQueueBuffer` has no time field
and `AudioStreamPacketDescription` has none either - it is an argument of the enqueue. The mapping from a
`CMTime` on the synchronizer's clock to that queue-relative sample time is read off the queue at the instant
of the call:

- `_AudioQueueGetCurrentTime` answers the queue's sample time and the host time of that instant together;
- the synchronizer's clock answers its own time, and its rate;
- the frames between two times follow from the format's sample rate and the clock's rate.

Every one of those symbols is in the same 43, and so are the ten the renderer uses:
`_AudioQueueNewOutput`, `_AudioQueueAllocateBuffer`, `_AudioQueueEnqueueBufferWithParameters`,
`_AudioQueueReset`, `_AudioQueueStart`, `_AudioQueueStop`, `_AudioQueueGetCurrentTime`,
`_AudioQueueFreeBuffer`, `_AudioQueueSetParameter`, `_AudioQueueDispose`.

The synchronizer's half of the correction was already right and is re-measured here: the plain
`_CMTimebaseCreate` is **0** in 6.1.3's CoreMedia (1819 exports, 62 matching `Timebase`) while
`_CMTimebaseCreateWithMasterClock` and `_CMClockGetHostTimeClock` are both there, so the two-step
`CMTimebaseCreateWithMasterClock(kCFAllocatorDefault, CMClockGetHostTimeClock(), &timebase)` is the call.
Also there, and used: `_CMTimebaseSetTime`, `_CMTimebaseGetTime`, `_CMTimebaseSetRate`,
`_CMTimebaseGetRate`, `_CMTimebaseSetRateAndAnchorTime`, `_CMTimebaseSetMasterTimebase`,
`_CMTimebaseSetMasterClock`, `_CMTimebaseGetMasterTimebase`, and the dispatch-source timer pair
`_CMTimebaseAddTimerDispatchSource`, `_CMTimebaseSetTimerDispatchSourceNextFireTime`,
`_CMTimebaseRemoveTimerDispatchSource`. The private pre-4.0 `_FigTimebase*` spellings are in the same trie
and are not used.

## What the oracle answered, and how it was reached

`tests/backports/host/avf-samplerender11` is one source compiled twice: once against this Mac's own
AVFoundation - the ORACLE, from which every expectation in the join is read - and once with `-I standin`
and the port's four objects linked in unmodified, against a stand-in release shaped like 6.1.3 (which
carries none of the three names). **103 rows, 97 of them answered the same by both halves, five allowed
differences, zero rows one side answers alone, zero unexplained.**

The earlier reading of this page - "measured, this machine cannot answer the 11.0 questions ... the class
that is there has 51 own instance methods ... The 11.0 names the port must carry - `-renderSampleBuffer:`,
`-renderingAlgorithm`, `-currentTime`, `-isRendering`, `-isRenderingForwards`, `-finishRendering` - are not
among them" - was wrong in a way worth naming, because it is the difference between a class that cannot be
carried and one that can. Those six names **are not in the 16.4 header for this class at all**: they belong
to `AVSampleBufferVideoRenderer` (14.0) and to the protocol of a later release. Every member the 16.4
header *does* declare for `AVSampleBufferAudioRenderer` is present in this Mac's class, and so is every one
for the synchronizer. Measured over `class_copyMethodList` on 2026-10-03: 51 own instance methods and 3 own
class methods on the renderer (superclass `NSObject`, instance size 16), 39 own instance methods and 2 own
class methods on the synchronizer, and the shared surface is
`-init`, `-timebase`, `-status`, `-error`, `-volume`/`-setVolume:`, `-isMuted`/`-setMuted:`,
`-audioTimePitchAlgorithm`/`-setAudioTimePitchAlgorithm:`, `-enqueueSampleBuffer:`, `-flush`,
`-flushFromSourceTime:completionHandler:`, `-isReadyForMoreMediaData`,
`-requestMediaDataWhenReadyOnQueue:usingBlock:`, `-stopRequestingMediaData`,
`-hasSufficientMediaDataForReliablePlaybackStart` on the renderer, and `-timebase`, `-rate`/`-setRate:`,
`-currentTime`, `-setRate:time:`, `-setRate:time:atHostTime:`, `-renderers`, `-addRenderer:`,
`-removeRenderer:atTime:completionHandler:`, `-addPeriodicTimeObserverForInterval:queue:usingBlock:`,
`-addBoundaryTimeObserverForTimes:queue:usingBlock:`, `-removeTimeObserver:` on the synchronizer. The two
halves differ in how a renderer is attached (macOS spells it `-setRenderSynchronizer:error:`) and in the
construction: macOS has a runtime class factory `+sampleBufferAudioRenderer` that no header here declares,
and both builds therefore construct with `-init`, which is what the 16.4 header and this Mac's header
between them leave as the way in.

The other two claims of that reading, corrected the same way:

- "the release's own `AVSampleBufferDisplayLayer` ... which the port carries in
  `AVFoundation/AVSampleBufferDisplayLayer8.m`" - there is no such file, and none is needed: the display
  layer is on 6.1.3 itself (first held rung 6.0), so the release carries it.
- "the 11.0 declarations are in the 26.2 iOS SDK the port compiles against" - the port compiles against
  the 16.4 iOS SDK, and there is no 26.2 SDK on this machine.

### The synchronizer, measured

| question | this Mac's own class | this port |
| --- | --- | --- |
| `-timebase` at `-init` | non-nil; the clock reads `0/1` | same |
| `-rate` at `-init` | 0.0 | same |
| `-currentTime` at `-init` | `0/1` | same |
| `-renderers` at `-init` | empty | same |
| `-setRate:` 1.0 / 0.0 / 2.0 / 1.0 | 1.000 / 0.000 / 2.000 / 1.000 (read after a settle) | same |
| `-setRate: -1.0` | raises `NSInvalidArgumentException` | same |
| `-setRate: 1.0 time: 600/1` | `-currentTime` reads `600000011125/1000000000` | same bucket |
| `-setRate: 1.0 time: kCMTimeInvalid` | the time is left alone | same |
| the clock frozen at rate 0, moving at 1, twice as fast at 2 | yes / yes / within 100 ms of twice the host clock's advance | same |
| `-addPeriodicTimeObserverForInterval: 100 ms` | at least three calls in 420 ms, the first within 200 ms of registration, times 100 ms apart to within 20 ms, the time is the clock's own | same |
| `-removeTimeObserver:` | no further calls; a second removal of the same token is accepted and does nothing; anything that is not a token raises | same |
| `-addBoundaryTimeObserverForTimes:` ahead / past / empty | fires / does **not** fire / raises | same |
| `-addRenderer:` twice | raises | same |
| `-addRenderer:` a second renderer | accepted | same |
| `-removeRenderer:atTime:` 120 ms ahead | the handler does not run before the time, runs within 300 ms, answers YES, and the list is one shorter | same |
| `-removeRenderer:` never added | the handler answers NO | same |
| the renderer's clock after the add | a different object from the synchronizer's, reading the same time; after a removal, a rate of 0 at a time of 0 | same |
| `-setRate:time:atHostTime:` with the host time in the past | the time is the named time plus what the rate has run since then (101.1051 at the first read, 101.6221 six steps later) | same |
| `-setRate:time:atHostTime:` with the host time in the future | the clock **holds** the named time until that host time and then runs at the rate (200.0000 at 900 ms, 200.0463 at 1000 ms) - **not** the "immediately start running from an earlier time" the header's paragraph describes | same |
| an invalid time, or an invalid host time | the other input applies at once, and the rate is applied even while the clock is held | same |

### The renderer, measured

| question | this Mac's own class | this port |
| --- | --- | --- |
| `-init` | status `0`, error nil, `-isReadyForMoreMediaData` YES, a `-timebase` of its own, volume 1.000, `-isMuted` NO, `audioTimePitchAlgorithm` `TimeDomain` | same |
| `-setVolume: 0.25 / 2.0 / -1.0` | 0.250 / **above 1.0** / **below 0.0** - stored, not clamped | same |
| `-setMuted: YES / NO` | YES / NO | same |
| `audioTimePitchAlgorithm` set to `AVAudioTimePitchSpectral` | reads back `Spectral` | same |
| `-flush` on a renderer holding no media | status stays `0`, ready YES, error nil | same |
| `-flushFromSourceTime:` past / future / `kCMTimeInvalid` on a renderer holding no media | YES / YES / not refused | same |
| `-requestMediaDataWhenReadyOnQueue:` then `-stopRequestingMediaData` | the block runs, then no more calls | same |
| a rate change on a renderer holding no media | the clock follows the rate, **no** flushed-automatically notification, status stays `0`, error nil | same |
| `-isReadyForMoreMediaData` after the first enqueue, and after nine | NO / NO | same |
| status and error after media | `1` (Rendering) and nil, because Apple's own decode layer sits above the output device and this machine has none | `2` (Failed) with an `AVFoundationErrorDomain` error, and the ALLOWANCES below say why |
| `-enqueueSampleBuffer: NULL` | raises | raises (not in the join: this Mac's class answers nothing usable afterwards - see below) |

## What this machine cannot answer, and what was measured instead

**There is no audio device on this machine**, and that is a measurement rather than an impression:

    AudioObjectGetPropertyDataSize(kAudioObjectSystemObject, kAudioHardwarePropertyDevices)
    -> 'who?' (CoreAudio's hardware-not-running)

and with no device behind it, of the queue calls above:

| call | on this machine |
| --- | --- |
| `AudioQueueNewOutput` | **0** - the queue is made |
| `AudioQueueAllocateBuffer` | 0 |
| `AudioQueueStart(NULL)` | 0 |
| `AudioQueueGetCurrentTime` | **-66678 (0xFFFEFB8A)**, with no valid time in the `AudioTimeStamp` |
| `AudioQueueEnqueueBufferWithParameters` | 0, and `outActualStartTime` is meaningless (4661570860979585024) |
| `AudioQueueReset` | 0 |
| `AudioQueueSetParameter(kAudioQueueParam_Volume, 0.5f)` | 0 |

So the one call a timestamp needs - the queue's own time, which comes from the device's clock - cannot
answer here, and a renderer that cannot place a buffer at its timestamp answers
`AVQueuedSampleBufferRenderingStatusFailed` with an `AVFoundationErrorDomain` error rather than a status
that claims to be rendering. Those five rows are the check's ALLOWANCES, each carrying that measurement.
**The sound itself was not measured, and cannot be on this machine**: the brief's two routes are an
AudioQueue input tap (there is no input device either) and the queue's own time against the PTS (the queue
has no device clock here). What *is* measured is that the renderer holds what it was given until the queue
can take it, and that it stops answering `-isReadyForMoreMediaData` YES while it holds any - which is the
property's own meaning, and is the release's own bound, because the bound is
`AudioQueueAllocateBuffer` refusing, not a buffer count this file chooses.

**Three questions were dropped from the join because this Mac cannot answer them at all.** On a renderer
that has been given media and has never played it, this Mac's own `AVSampleBufferAudioRenderer` **aborts** -
measured, SIGABRT with empty stderr - on `-flush`, on a rate change, on `-enqueueSampleBuffer: NULL`, and on
release; and its `-isReadyForMoreMediaData` never comes back (still NO after eight enqueues, while
`-hasSufficientMediaDataForReliablePlaybackStart` is YES from the first). So:

- the flush rows and the rate-change rows are asked of renderers that hold **no** media, which is askable;
- the with-media flush is not asked at all, and what the port answers for it is in the row's reason;
- `-enqueueSampleBuffer: NULL` is implemented (it raises, as the host's does) but is not a join row,
  because a raise on this machine is followed by an abort and the answers after it are not answers.

One more answer of the host that shaped the code and is worth recording: **a rate change is applied through
a barrier**, so a `-rate` read in the same breath as `-setRate:` can answer the rate from before the change -
measured, four back-to-back `-setRate:` calls for 1, 0, 2 and 1 read 1.000, 0.000, 0.000 and 1.000 on one
run and 1.000, 0.000, 2.000 and 1.000 on another. The port applies the change in the call, and the check
asks the settled question rather than a row that changes from run to run.

## The five allowed differences, in one place

| row | host | port | why |
| --- | --- | --- | --- |
| `renderer: status after the first enqueue` | 1 | 2 | no audio device here, so the queue has no clock: see above |
| `renderer: error after the first enqueue is nil` | YES | NO | the same |
| `renderer: status after nine enqueues` | 1 | 2 | the same |
| `renderer: error after nine enqueues is nil` | YES | NO | the same |
| `renderer: status after a buffer with no frames` | 1 | 2 | the same |

plus one more, which is not a media row: `attached: the renderer's clock reads the synchronizer's clock as
its master` answers NO here and YES in the port. The port slaves the renderer's own `CMTimebase` to the
synchronizer's, which is what "Adds a renderer to begin operating with the synchronizer's timebase" asks
for; this Mac's own synchronizer answers `NULL` from `CMTimebaseGetMasterTimebase` for both clocks and keeps
them in step by propagating the rate instead (its own private method is `-_updateRateFromTimebase`, measured
in the method list above). The two clocks read the same time either way, which is the row beside it.

## What the port does not carry, and why, member by member

| member | release | why not |
| --- | --- | --- |
| `-[AVSampleBufferRenderSynchronizer delaysRateChangeUntilHasSufficientMediaData]` | 14.5 | it asks the renderer below, and that level is not measurable here |
| `AVSampleBufferAudioRenderer.hasSufficientMediaDataForReliablePlaybackStart` | 14.5 | the header states no preroll level, and this Mac answers YES from the first buffer on a machine where nothing plays any of them - so the level cannot be read from the oracle either |
| `AVSampleBufferAudioRenderer.allowedAudioSpatializationFormats` | 15.0 | the value "will attempt to spatialize" the media and 6.1.3's AVFAudio carries nothing to spatialize with; the header also says the property is not observable, so any answer would be a value with no behaviour behind it |
| `AVSampleBufferAudioRenderer.audioOutputDeviceUniqueID` | 11.0 on macOS | the 16.4 header declares it `API_UNAVAILABLE(ios, tvos, watchos, visionos)`, so there is no iOS member to carry and no row for it |

Two things the members above would need and the release does not have, named here because they are the
reason the port's answers are what they are:

- **Only linear PCM is played, and compressed audio is refused with a reason.** The header says this class
  "can decompress and play compressed or uncompressed audio", and the port does not decompress: what the
  queue is given has to be laid out as audio by the release's own
  `-CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer`, which is linear PCM, so a buffer whose format
  is anything else is refused and the renderer answers `AVQueuedSampleBufferRenderingStatusFailed` with an
  `AVFoundationErrorDomain` error naming the format it was given. A decoder this port could use and could
  measure is not one this machine or this release has on the table: `AudioConverterNew` and
  `_AudioConverterFillComplexBuffer` are both exported by 6.1.3's AudioToolbox (measured, 12 exports
  matching `AudioConverter`), but there is no device here to play the result through and no measured answer
  for what a 6.1.3 decode costs, so a decoder on this path would be code nothing here could verify. What was
  measured instead is the refusal above, and the two rows that carry it are
  `AVSampleBufferAudioRenderer.status` and `.error`.
- **`audioTimePitchAlgorithm` has no effect on the audio this port renders.** The release has no time-pitch
  unit (`tools/corpus/objc-inventory.lua` over the armv7 caches of 6.1.3 and 4.3 lists no such class in
  AVFAudio), so a rate other than 1.0 is honoured by the mapping alone: the queue plays at the rate the
  format names and the media is heard faster or slower with its pitch following. The header's own words for
  the rate are "play at the natural rate of the media", which is what the mapping is.
- **The synchronizer's clock runs on the host time clock, not on an audio device clock.** The header says
  "By default, this timebase will be driven by the clock of an added AVSampleBufferAudioRenderer", and
  CoreMedia on 6.1.3 exports eight `CMClock` symbols (`_CMClockConvertHostTimeToSystemUnits`,
  `_CMClockGetAnchorTime`, `_CMClockGetHostTimeClock`, `_CMClockGetTime`, `_CMClockGetTypeID`,
  `_CMClockInvalidate`, `_CMClockMakeHostTimeFromSystemUnits`, `_CMClockMightDrift`) and **none of them
  makes a clock from an audio device**, so there is no public mechanism for it on this release.

One more thing a client on this port should know, and it is a gap rather than a choice: the rate-change
notification `AVSampleBufferRenderSynchronizerRateDidChangeNotification` is a 12.0 constant (the port
carries it, in `AVFoundationConstants120.m`) and nothing posts it, because the setter that would post it is
an 11.0 member and the bands do not link upward - an 11.0 object cannot reference a 12.0 symbol. The
renderer side of the same family is not affected: `AVSampleBufferAudioRendererWasFlushedAutomaticallyNotification`
is an 11.0 constant (in `AVFoundationConstants110.m`) and the renderer posts it when a rate change really
discards media it was holding.

## What a run on 6.1.3 hardware has to prove, so the next band does not have to guess

The one measurement this machine cannot make is the audible path, and it is the only thing left open for
these two classes. It needs a package on a device that has audio hardware - the fleet's iPhone 4S or iPad 2,
which are the ones with iOS 6.1.3 - and it needs the canon built from the branch that carries these four
objects. Nothing here has to be re-derived first; these are the calls and the questions, in the order a run
would meet them.

**1. Does the queue get a device clock?** The whole mapping rests on `_AudioQueueGetCurrentTime` answering a
valid `AudioTimeStamp` (`mFlags & kAudioTimeStampSampleTimeValid`), which it cannot do here
(measured: -66678, empty flags). On the device it must answer 0, and `mSampleTime` must advance by about
`mSampleRate` per second while the rate is 1.0. That single answer is what turns "cannot be measured here"
into "measured".

**2. Does a buffer actually play at the time its presentation timestamp names?** The mapping is
`start.mSampleTime = anchor.mSampleTime + llround(seconds(pts - CMTimebaseGetTime(timebase)) * format.mSampleRate / rate)`.
Two ways to see it, both with the release's own calls and neither needing the port to expose anything:

- `AudioQueueEnqueueBufferWithParameters`'s `outActualStartTime`, compared with the `inStartTime` asked for.
  The queue reports when it will really play the buffer, in the queue's own timeline; if it agrees with what
  the port asked, the port's number was a time the queue could place.
- the buffer callback's own `mAudioDataByteSize` against the format: a buffer that plays is a buffer the
  callback returns, and its return is the queue's word that the audio went out rather than being dropped.

**3. Does the audio that comes out carry the media that went in?** The routes the brief names: an
`AudioQueue` **input tap** on the device, recording what the speaker played, or the queue's own current time
against the PTS. A 1 kHz sine at 44.1 kHz is what `tests/backports/host/avf-samplerender11/samplerender.m`
already generates, so the same fixture answers here: the recorded frequency is the tone's, and at a
synchronizer rate of 2.0 the spacing of the buffers is halved with the pitch following it, which is what this
port's mapping does and what no time-pitch unit on the release could change.

**4. What the three questions this machine refused become.** The with-media flush, a rate change on a
renderer that holds media, and `-isReadyForMoreMediaData` coming back YES are the three rows the differential
had to ask of an *unfed* renderer here because this Mac's own class ABORTS on them (measured, SIGABRT). On a
device with a device clock the port's renderer holds none of those aborts, and those rows can be asked of a
fed renderer - which is the whole point of the run.

**5. What it does not have to re-measure.** The synchronizer needs no device: its clock, its rate, its
anchored form, both observers and the renderer list are all answered on this Mac and all agree with this
Mac's own class (107 rows, 98 of them identical). A device run is for the audio path and nothing else.

**Where the run would go in the check:** the four "absent:" rows and the five media rows are the ones that
change shape, and a run that closes this should be the check's host half replaced by the device - a new
`avf-samplerender11-device` case rather than an edit of this one, so the row set that is green on this Mac
stays green on it.

## clang synthesises the properties the rows say are absent, and how that was found

**The coordinator's gate caught this on my branch: "listed as absent, but what is built answers it" for
`AVSampleBufferAudioRenderer.allowedAudioSpatializationFormats` and
`AVSampleBufferRenderSynchronizer.delaysRateChangeUntilHasSufficientMediaData`.** Measured then, on my own
objects at the package's flags, `nm -a` over `AVSampleBufferAudioRenderer11.o` and
`AVSampleBufferRenderSynchronizer11.o` carried, at **both** `-target armv7-apple-ios6.0` and
`-target armv7-apple-ios4.3`:

| auto-synthesised member | where the SDK declares it | the row says |
| --- | --- | --- |
| `-allowedAudioSpatializationFormats`, `-setAllowedAudioSpatializationFormats:`, `_allowedAudioSpatializationFormats` | `AVSampleBufferAudioRenderer.h:88`, `API_AVAILABLE(ios(15.0))` | `absent` |
| `-delaysRateChangeUntilHasSufficientMediaData`, `-setDelaysRateChangeUntilHasSufficientMediaData:`, `_delaysRateChangeUntilHasSufficientMediaData` | `AVSampleBufferRenderSynchronizer.h:117`, `API_AVAILABLE(ios(14.5))` | `absent` |
| `-audioOutputDeviceUniqueID`, `-setAudioOutputDeviceUniqueID:`, `_audioOutputDeviceUniqueID` | `AVSampleBufferAudioRenderer.h:41`, `API_UNAVAILABLE(ios)` | no iOS row at all |

**Why it happened, measured rather than guessed: it is plain auto-synthesis and availability is not part of
it.** clang gives an ivar and a pair of accessors to every property **the `@interface` the `@implementation`
answers** declares and the implementation does not mention - no inheritance consulted, no `API_AVAILABLE`
consulted, and nothing different at the 4.3 band's target, which is the point: the same members appear at
both, so this was never a question of what the band is. The protocol's own
`hasSufficientMediaDataForReliablePlaybackStart` is **not** synthesised (measured: no accessor of that name in
any of the four objects, and `-Wobjc-protocol-property-synthesis` says so at compile time), because a
property a *protocol* declares is not auto-synthesised.

**Why this series' own verification missed it, which is the part worth keeping:**

- `-fsyntax-only` emits no code, so it cannot show auto-synthesis **at all**. That was the whole of my
  verification of these objects and it was the wrong instrument: `check_registry` reads the built library, and
  a synthesised accessor exists only in the object file. The check that catches it is `nm -a` (or
  `strings -a`) over the object, at each band target.
- `-Werror=objc-missing-property-synthesis`, which the package passes, is the warning for the **opposite**
  condition: a property that is *not* synthesised, which is what happens under
  `-fno-objc-default-synthesize-properties`. It cannot fire for a property that was synthesised silently.
- `-Wincomplete-implementation` **did** fire, for the two *methods* another release's object carries
  (`-currentTime` at 12.0, `-setRate:time:atHostTime:` at 14.5), and it cannot fire for a property: the
  synthesised accessors satisfy the declaration, so from the compiler's point of view nothing is missing.

**The fix** is main's idiom (`FileProvider/FileProvider11.m`, NSFileProviderDomain): `@dynamic` for each of
the three, in the object that declares the class, with the reason beside it. `@dynamic` leaves
`respondsToSelector:` answering NO, which is the truth - a synthesised accessor is a name the port claims and
does not carry. Measured after the fix, at both targets: no accessor and no ivar of any of the three names in
any of the four objects.

**And the check holds it.** Four rows in `avf-samplerender11` ask each build what it answers for those three
plus the protocol's preroll property: this Mac's own classes answer YES to all four (their surface is a later
one) and the port answers NO, so each is an ALLOWANCE **carrying the value the port is required to answer**,
not only a reason. The join checks every row against the value it requires rather than against the host's
value, which is what lets a mutation break an allowance: the `nodynamic` mutation removes one `@dynamic`, the
port answers YES, the join prints `WRONG ALLOWED` and goes red, and the directionality step reports
`broke-a-required-answer=1`. The stand-in header now declares those three properties as well, because the
16.4 SDK does - without them the check could not have asked the question at all.

## The twelve mutations, and what each one is for

Every mutation changes a line the join reads, turns an answer that was **required** - the host's own, or the
value an ALLOWANCE names - into one that is not, and has a control that runs the unmutated source through the
same path. `rate`, `raterenderers`, `detachclock`, `periodicinterval`, `removeobserver`, `addtwice`,
`boundarypast`, `emptytimes`, `flushstatus`, `readiness`, `volume`, `nodynamic`.

Two things the check found in the port's own code while it was being written, both fixed and both recorded
because a row that only agrees because the code is wrong is worse than no row:

- the drain handed a buffer to the queue and dropped it from the pending list even when the enqueue had
  failed, so `-isReadyForMoreMediaData` answered YES while the renderer was still holding media (the
  readiness rows flagged it);
- a `CMTimebase` slaved to another follows its master's **timeline** and keeps its own rate and time, so
  slaving alone did not make a renderer's clock read the synchronizer's *time* (the
  "reads the synchronizer's new time" row flagged it: the port answered 0.2 where the host answers 5.2032).
  Both the rate and the time are propagated on every change now.

And one thing in the port's own code that deliberately has no mutation: the two lines in `-addRenderer:`
that slave the clock and set its rate. Every rate or time change after that propagates the same two things
to every attached renderer, so removing them changes nothing this check can see, and the only row that reads
the master relationship is the row the two halves deliberately differ on.

## Reproducing

    xmake l tools/image-exports.lua 6.1.3 armv7 AudioToolbox.framework/AudioToolbox AudioQueue
    xmake l tools/image-exports.lua 6.1.3 armv7 CoreMedia.framework/CoreMedia Timebase
    xmake l tools/image-exports.lua 6.1.3 armv7 CoreMedia.framework/CoreMedia CMClock
    xmake l tools/image-exports.lua 6.1.3 armv7 CoreMedia.framework/CoreMedia CMSampleBufferGetAudio
    xmake l tools/cache-index/first-rung.lua _OBJC_CLASS_\$_AVSampleBufferAudioRenderer \
        _OBJC_CLASS_\$_AVSampleBufferRenderSynchronizer _OBJC_PROTOCOL_\$_AVQueuedSampleBufferRendering
    sh tests/backports/host/avf-samplerender11/run.sh

The host table is `class_copyMethodList` and the run above over the macOS SDK's own
`AVSampleBufferAudioRenderer` and `AVSampleBufferRenderSynchronizer`; the numbers in this page (51 and 39 own
instance methods, superclass `NSObject`, instance size 16, the queue and CoreAudio answers) are from that
and from the runs above, on 2026-10-03.