# AVSampleBufferDisplayLayer: the class iOS 6 already has

iOS 6.0 and 6.1.3 carry a class named `AVSampleBufferDisplayLayer` in `/System/Library/Frameworks/AVFoundation.framework`.
Backports used to define a class of that name too (`src/AVFoundation/AVSampleBufferDisplayLayer8.m`), so a process that
loaded both printed `objc: Class AVSampleBufferDisplayLayer is implemented in both AVFoundation.framework and
libAVFoundationBackports` (seen on the iPhone 4S in every run of Telegram13 pass137), and which of the two
`objc_getClass` answers was not defined by the runtime. `docs/explanation/backports/shadowed-classes.md` states the rule
for a class the device exports: it never gets a proxy; the members a later SDK added live on the real class.

## What the system class is

Read from the iOS 6.0 and 6.1.3 shared-cache inventories (`.cache/dyld/6.0/classes_armv7.json` and
`.cache/dyld/6.1.3/classes_armv7.json`, identical for this class) and from the `6.1` branch of
`nst/iOS-Runtime-Headers` (`Frameworks/AVFoundation.framework/AVSampleBufferDisplayLayer.h`, generated from iOS 6.1; the
branch `master` is a later release and is not evidence for 6.1.3: it has `status`, `error` and `setRenderSynchronizer:`).
The two sources agree member for member.

- Superclass `CALayer`. One instance variable, `_sampleBufferDisplayLayerInternal`, an `AVSampleBufferDisplayLayerInternal`
  with `aboveHighWaterLevel`, `contentLayer`, `controlTimebaseSetByUser`, `hasEnqueuedSamples`, `isRequestingMediaData`,
  `mediaDataRequester`, `presentationSize`, `serialQueue`, `videoGravity` and a `struct OpaqueFigVideoQueue *videoQueue`.
  The variables show a Fig video queue and a content layer of the private class
  `AVSampleBufferDisplayLayerContentLayer`; what the queue accepts and draws is not in the inventory (see below).
- Instance methods: `controlTimebase`, `setControlTimebase:`, `enqueueSampleBuffer:`, `flush`, `flushAndRemoveImage`,
  `isReadyForMoreMediaData`, `requestMediaDataWhenReadyOnQueue:usingBlock:`, `stopRequestingMediaData`, `videoGravity`,
  `setVideoGravity:`, `init`, `dealloc`, `finalize`, `setBounds:`, `addAnimation:forKey:` and the private
  `_addAnimationsForContentLayer:size:gravity:`, `_createVideoQueue`, `_refreshAboveHighWaterLevel`,
  `_setControlTimebase:`, `_updatePresentationSize:`. The release's header lists no conformance to
  `AVQueuedSampleBufferRendering`.

## Against the SDK

| SDK member | iOS 6.1.3 |
| --- | --- |
| `controlTimebase`, `setControlTimebase:`, `videoGravity`, `setVideoGravity:` | present |
| `enqueueSampleBuffer:`, `flush`, `flushAndRemoveImage`, `isReadyForMoreMediaData`, `requestMediaDataWhenReadyOnQueue:usingBlock:`, `stopRequestingMediaData` | present |
| `status`, `error` (iOS 8) | absent |
| `isReadyForDisplay`, `requiresFlushToResumeDecoding`, `outputObscuredDueToInsufficientExternalProtection`, `preventsCapture`, `preventsDisplaySleepDuringVideoPlayback`, `sampleBufferRenderer`, `hasSufficientMediaDataForReliablePlaybackStart` (later SDKs) | absent |

So the system class has the whole queue API of iOS 8 except the status pair, and the earlier Backports class duplicated all of it.

## Measured on the emulator (iPhone4,1 6.1.3, one app, both classes loaded)

`tests/runtime/cases/avfoundation_system_display_layer.m` ran in the emulator with the Backports library loaded. The
runtime printed `Class AVSampleBufferDisplayLayer is implemented in both AVFoundation and libAVFoundationBackports`
and the app saw:

- two classes registered under the name; `objc_getClass` and `[AVSampleBufferDisplayLayer alloc]` answer the system's,
  from `/System/Library/Frameworks/AVFoundation.framework/AVFoundation`: superclass `CALayer`, instance size 52, one
  instance variable `_sampleBufferDisplayLayerInternal` at offset 48;
- the class the Backports library exported under that name was another one: instance size 104 with sixteen instance
  variables of its own (`_displaySource`, `_requestBlock`, `_pending`, ...). No code could allocate it by name, so none of
  its methods ever ran on a layer an app made;
- the system class's method list held `status`, `error`, `timebase`, `isReadyForDisplay`, `sampleBufferRenderer` and the
  other members the system lacks: the skeleton's stand-ins, registered on the system class because it did not answer
  them. A call to `-[AVSampleBufferDisplayLayer status]` printed `not implemented: -[AVSampleBufferDisplayLayer status]`
  and aborted the process (signal 6). `respondsToSelector:` answered yes.

So with the second class, an app got a class that crashed on `status` and `error`, and the 645-line renderer was dead
code. It was the cause of the process aborts the case was written to explain.

## What Backports does now

`src/AVFoundation/AVSampleBufferDisplayLayer8.m` defines no class. It is a category on the system class, as
`AVCaptureMetadataOutput` is, which adds what the SDK declares and the system class lacks:

| Member | Answer |
| --- | --- |
| `status`, `error` | `Unknown` and nil at first; `Rendering` after a frame is enqueued; `Unknown` and nil after `flush` and `flushAndRemoveImage`; `Failed` is never reached |
| `isReadyForDisplay`, `hasSufficientMediaDataForReliablePlaybackStart` | yes after a frame that is not `DoNotDisplay` is enqueued, no after a flush |
| `requiresFlushToResumeDecoding` | yes only when `status` is `Failed`, so never |
| `outputObscuredDueToInsufficientExternalProtection` | no |
| `preventsCapture`, `preventsDisplaySleepDuringVideoPlayback` and their setters | what was set, kept for each layer |
| `timebase` | the layer's control timebase; when it has none, a timebase on the host clock is made, kept by the layer's state and given to the system through `setControlTimebase:` |
| `sampleBufferRenderer` | nil |

The state of each layer is an associated object. The three system methods that change it, `enqueueSampleBuffer:`, `flush`
and `flushAndRemoveImage`, are wrapped at `+load` with `method_setImplementation`, call the system's first, and then
change the state and post the key-value notifications for `status` and `readyForDisplay`. Everything else, the Fig queue,
`isReadyForMoreMediaData`, `requestMediaDataWhenReadyOnQueue:usingBlock:`, `controlTimebase` and `videoGravity`, is the
system's own.

The wrapped `enqueueSampleBuffer:` also draws what the system queue does not (measured on the iPhone 4S, below): a frame
that holds an uncompressed image buffer (`32BGRA`, `32ARGB`, `420v`, `420f`) and is not `DoNotDisplay` is converted on the
CPU (the matrix table and the ranges of `cee944be1`; `YCbCrMatrix` 601 or 709, 709 when absent, anything else is not
drawn) and becomes the layer's own `contents`, with `contentsGravity` from `videoGravity`. It is shown at once when the
frame is `DisplayImmediately`, has no timestamp or the layer has no control timebase, and otherwise when its timestamp is
reached on the control timebase (a dispatch after the wait divided by the rate). `flush` cancels the frames not yet
shown and keeps the image on the layer; `flushAndRemoveImage` cancels them and removes the image. Compressed frames
(H.264) are left to the system queue alone.

What this does not give: the system reports no failure on iOS 6, so `status` never becomes `Failed` and `error` stays nil;
`isReadyForDisplay` turns on at the enqueue, not when the frame's timestamp is reached; a frame is not dropped when a
later one is due too (each is shown in turn); a timebase with rate 0 never shows a frame whose time is ahead, and a rate
change does not move the frames already waiting; and the conversion runs on the thread that enqueues.

`tests/runtime/cases/avfoundation_display_layer.m` checks the state machine on the system class, `tests/avfoundation_test.lua`
checks that the Backports objects define no class of the name and none of the system's own members.

## Measured on the iPhone 4S (iPhone4,1, 6.1.3, 2026-11-21)

The runtime app of this checkout ran on the phone from a scratch folder, with `DYLD_LIBRARY_PATH` pointing at this
build's libraries, and only the case `avfoundation_system_display_layer`. Positive pass; the negative control fails on
its three checks as it should. Numbers, identical for `32BGRA`, `420v` and `420f` (64x64, `DisplayImmediately`):

- `isReadyForMoreMediaData` is 1 before and after the enqueue; the system's `enqueueSampleBuffer:` raises nothing.
- Layers with `contents` in the layer's tree: 0, as on the emulator, and `renderInContext:` into a 64x64 bitmap draws 0
  pixels.
- The tree is `AVSampleBufferDisplayLayer` > `AVSampleBufferDisplayLayerContentLayer` > `CALayerHost`. The host holds a
  non-zero context id (a different one for each layer and format). The queue creates a remote Core Animation context
  and the video is composited by the render server, so a layer's `contents` and `renderInContext:` can never show the
  frame: the in-process numbers do not say whether it is drawn.
- The syslog during the runs holds no line from mediaserverd or the Fig queue about the frames.

### Does the queue draw them? The screen says no

The in-process numbers cannot say, so the screen was read. `AVFDrawProbe` (`tests/device_probe/avfoundation_draw_main.m`,
a device app, bundle id `space.kern0x1b.backports.avfdrawprobe`) puts known-colour 80x80 frames into layers of the
system class beside a plain magenta view and a black reference, and `UIGetScreenImage` (what `revenant-shot` calls)
was read for the middle 40x40 points of each block, with the probe the front application. The image was compared by a
program, not by eye, and deleted on the Mac and the phone after the comparison. Mean red/green/blue of each block:

| Block | Expected | System queue alone | With the Backports wrapper |
| --- | --- | --- | --- |
| `32BGRA` red | 255/0/0 | 0/0/0 | 255/0/0 |
| `420v` green (601) | 0/255/0 | 0/0/0 | 0/255/1 |
| `420f` blue (601) | 0/0/255 | 0/0/0 | 0/0/254 |
| `32BGRA` red, control timebase, frame time now | 255/0/0 | 0/0/0 | 255/0/0 |
| H.264 green (compressed, from `VTCompressionSession` on the Mac) | 0/255/0 | 20/255/9 | 20/255/9 |
| plain magenta view (control) | 255/0/255 | 255/0/255 | 255/0/255 |
| black reference | 0/0/0 | 0/0/0 | 0/0/0 |

The H.264 row shows the capture sees what the system queue draws, so the black rows are the queue's, not the
capture's: the iOS 6.1.3 video queue accepts uncompressed frames (ready, no error, no log line) and draws nothing for
them. The wrapper's rows are the layer's own `contents` and match to within one level.

The release of a layer after its pool (emulator, 2026-11-21): a layer that was never touched, one whose `status` was
read and one that made a `timebase` are all released by the end of the run loop spin, 1 of 1 each; five cases of the
selection passed.
