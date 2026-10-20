# AVPlayerLooper (iOS 10.0)

The class and its iOS 10 members, built by `AVFoundation/AVPlayerLooper10.m` (runtime name `AVPlayerLooper`), and
measured against the host's own AVPlayerLooper by `tests/backports/host/avf-player-looper`.

## What the release has, and what it does not

- 6.1.3 exports no `_OBJC_CLASS_$_AVPlayerLooper`, and neither does 4.3: the class is absent, so a strong reference
  to it would stop the application at load.
- The substrate is here: 6.1.3's AVQueuePlayer carries `items`, `insertItem:afterItem:`, `removeItem:`,
  `removeAllItems` and `initWithItems:`, and `AVPlayerItemDidPlayToEndTimeNotification` (exported as
  `_AVPlayerItemDidPlayToEndTimeNotification` from 4.0). A looper is a queue manager over those.

## The surface

From the generator's IR, `spec/AVFoundation/declarations.tsv` (the SDK 26.2 rendering, the lines for
`interface c:objc(cs)AVPlayerLooper` and its members, all `ios=10.0`):

- `+playerLooperWithPlayer:templateItem:` and `+playerLooperWithPlayer:templateItem:timeRange:`
- `-initWithPlayer:templateItem:timeRange:`
- `-disableLooping`
- readonly `status` (AVPlayerLooperStatus), `error`, `loopCount` (NSInteger), `loopingPlayerItems` (NSArray)
- `-initWithPlayer:templateItem:timeRange:existingItemsOrdering:` is `ios=17.0` and is **not built**. It is an iOS 17
  ordering option, not an iOS 10 member, and nothing in this file answers it.

Correction to `facts/AVFoundation/AVFoundation10.md`, which named four members a port would need rows for:
`-initWithPlayer:queueItems:`, `player`, `queueItems` and `disableLooping`. Those names are not the release's. The
rows that match the IR are the ones in `registry/AVFoundation/ios10playerlooper.json`.

Status values: 0 Unknown, 1 Ready, 2 Failed, 3 Cancelled (the IR's `AVPlayerLooperStatus` enumeration).

## What the host measured

Probe: `tests/backports/host/avf-player-looper/probe.m`, a one-second, 10-frame, 16x16 H.264 movie made by the
host's AVAssetWriter. Every value below is read from the host's AVPlayerLooper; the port's answers are the same
on every compared row (62 of 62, `run.sh`).

- **Nothing is queued when the looper is made**: `status` 0, `loopCount` 0, `loopingPlayerItems` empty, the queue
  empty, `error` nil. The first copy is queued after the factory returns, on a later turn of the run loop.
- **The template is never queued**: the copies are new items on the template's asset (`loopingPlayerItems` share its
  asset, and the template is in neither the queue nor the looping list).
- **The loop starts when a copy is ready, not the template** (a template that is only made, or whose asset has loaded
  its keys, stays Unknown: an AVPlayerItem becomes ready only once it is in a player).
- **Queue size**: with a time range the looper keeps about ten seconds of loop material queued. Measured at ready:
  range 1.0 s gives 10 items, 0.5 s gives 20, 0.25 s gives 40, 0.1 s gives 100. The port uses
  `ceil(10 / loop length)`.
- **Default range** (no time range): 3 items when the looper is made before the asset's `duration` key has loaded,
  and 10 items (1.0 s) when the key was loaded first. So the loop length is read once, when the looper is made,
  from the asset's duration once the `duration` key is loaded; otherwise 3 copies, and that count is not revisited.
  A `duration` that is only synchronously estimated does not count (the host answers 3 for it).
- **Loops**: after 1.5 s of a 1.0 s loop, `loopCount` is 1, `status` 1, and 3 items are queued; the queue is
  topped back up as each copy ends. With a 0.5 s range, `loopCount` is 2 at 1.25 s, and 20 items stay queued.
- **disableLooping**: `status` becomes 3 (Cancelled) at once; every queued copy but the one playing is removed; no
  copy is added. The playing copy still counts when it ends (after 2.5 s more, `loopCount` is 2 and the queue is
  empty).
- **Range copies**: their `forwardPlaybackEndTime` is valid and equals the range end (0.5 s gives 50/100); the
  default copies' is invalid.
- **Range start**: a range from 0.5 s of length 0.5 s loops the second half of the movie. The host's `loopCount` is
  1, 2, 3 at 0.75, 1.25 and 1.75 s (two runs, the same). The samples sit between the boundaries (0.5 s apart from
  the start of playback). A sample at exactly 1.5 s is on a boundary and answered differently by the two sides
  in one run, so the probe does not use it.
- **A template that cannot be played**: `status` 2 (Failed), `error` set, nothing queued.

## What the port does, and what it does not

The rules above are the port's, in `AVPlayerLooper10.m`. The port does not copy the template's own settings (its audio
mix, video composition, and so on): a copy is a new AVPlayerItem on the template's asset with the range's end and
start applied. The host's copies were not checked for those settings, so the port claims none of them: a template
with an audio mix or a video composition loops here without it. That is a gap, not a measured equality.

## Caveats

- **Host-measured, not device-measured.** The host is macOS. The iPhone 4S run has not been done, so the rows say
  device-unverified in the report. A device run would show whether 6.1.3's AVQueuePlayer keeps the same queue.
- The default-range count depends on a timing fact (whether the duration key has loaded when the looper is made).
  The port reproduces the host's rule, not a mechanism that was read from Apple's code.
