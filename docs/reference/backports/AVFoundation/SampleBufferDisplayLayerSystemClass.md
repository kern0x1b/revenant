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

What this does not give: the system reports no failure on iOS 6, so `status` never becomes `Failed` and `error` stays nil;
`isReadyForDisplay` turns on at the enqueue, not when the frame's timestamp is reached; and a frame the Fig queue cannot
draw is not drawn. The CPU conversion of `420v` and `420f` frames that the earlier class had (commit `cee944be1`, with
the matrix table and the case that checked each channel) was removed with the class; whether the system queue needs it is
the open question below.

`tests/runtime/cases/avfoundation_display_layer.m` checks the state machine on the system class, `tests/avfoundation_test.lua`
checks that the Backports objects define no class of the name and none of the system's own members.

## Not yet measured

Whether the system Fig queue draws an uncompressed `32BGRA`, `420v` or `420f` frame. The case prints, for each, how many
layers in the layer's tree hold `contents` after the enqueue; the emulator may not say (no hardware queue), and then the
answer comes from the iPhone 4S. If the system does not draw them, a pixel path for uncompressed frames returns, as a
wrapper of `enqueueSampleBuffer:` that sets the layer's own `contents`, from the code of `cee944be1`.
