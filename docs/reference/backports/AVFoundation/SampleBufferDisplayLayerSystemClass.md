# AVSampleBufferDisplayLayer: the class iOS 6 already has

iOS 6.0 and 6.1.3 carry a class named `AVSampleBufferDisplayLayer` in `/System/Library/Frameworks/AVFoundation.framework`.
Backports also defines a class of that name (`src/AVFoundation/AVSampleBufferDisplayLayer8.m`), so a process that loads
both prints `objc: Class AVSampleBufferDisplayLayer is implemented in both AVFoundation.framework and
libAVFoundationBackports` (seen on the iPhone 4S in every run of Telegram13 pass137), and which of the two
`objc_getClass` answers is not defined by the runtime. `docs/explanation/backports/shadowed-classes.md` states the rule
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

So the system class has the whole queue API of iOS 8 except the status pair, and the Backports class duplicates all of it.

## To measure

The inventories name members, not behaviour. `tests/runtime/cases/avfoundation_system_display_layer.m` prints, for the class
`objc_getClass` names and for the one the Backports library exports, the image, superclass, instance size, instance
variables and method list, and what each does with a 64 by 64 `32BGRA`, `420v` and `420f` sample enqueued with
`DisplayImmediately`: `isReadyForMoreMediaData` before and after, how many layers in its tree hold `contents`, and `status`.
It checks that the Backports image defines no class of the name, that `objc_getClass` answers the system's, and that the
class answers every member of the SDK. Results are not in this page yet: the emulator run is waiting for the shared
store, and the phone measurement goes through the Telegram session's 4S.
