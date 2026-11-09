# QR codes through AVCaptureMetadataOutput on iOS 6

The iOS 6 AVFoundation class AVCaptureMetadataOutput exists, so the backport overlays it rather than replacing it.

Measured in the iOS 6.0 shared cache (`.cache/dyld/6.0/classes_armv7.json`, read from the inventory): AVCaptureMetadataOutput
has availableMetadataObjectTypes, metadataObjectTypes, setMetadataObjectTypes:, metadataObjectsDelegate,
metadataObjectsCallbackQueue and setMetadataObjectsDelegate:queue:. It has no rectOfInterest. AVMetadataObject has type,
bounds, time and duration, and AVMetadataFaceObject is the only AVMetadataObject subclass named in the cache; there is no
AVMetadataMachineReadableCodeObject class. AVCaptureVideoDataOutput has setSampleBufferDelegate:queue:, videoSettings,
availableVideoCVPixelFormatTypes and alwaysDiscardsLateVideoFrames, and AVCaptureSession has addOutput:, removeOutput:,
canAddOutput:, beginConfiguration and commitConfiguration.

Not measured on a device: that the release reports only the face type from availableMetadataObjectTypes, which is what
Apple's iOS 6 documentation describes. The backport adds the QR type to that list and passes the other types to the native
output.

The backport swaps the implementations of availableMetadataObjectTypes, metadataObjectTypes, setMetadataObjectTypes:,
setMetadataObjectsDelegate:queue:, addOutput: and removeOutput:, with `method_setImplementation` at `+load`
(`frameworks/Backports/src/AVFoundation/AVCaptureMetadataOutput+MachineReadableCode7.m`). Each replacement calls the
implementation it replaced. This is the only mechanism available: the class is a system class on iOS 6, so a link-time
backport cannot override its existing methods. The crutch is entry C46 in `docs/reference/backports/crutches.md`.

Guard: when the app requests no QR type, the type setter and getter forward to the native implementations with the arrays
the app passed, the delegate setter forwards and then finds nothing to start, and addOutput:/removeOutput: forward and
keep a weak session reference. No internal output is added. The one visible difference while QR is not requested is that
availableMetadataObjectTypes lists QR on iOS 6, which is the point of the overlay. The probe checks the two halves on the
device: a face request leaves one output in the session, and a QR request adds one.

While the release lacks QR, the output has a delegate and it is in a session, the session gets one internal
AVCaptureVideoDataOutput in NV12 (full range when the release offers it), with late frames discarded. Each frame's luma plane
goes through revenant_qr_decode_region, limited to rectOfInterest, and each code is delivered as an
AVMetadataMachineReadableCodeObject on the delegate's callback queue. The delegate gets an empty array once when the codes
leave the frame. The internal output is removed when the metadata output loses its session, its delegate or the QR type.

A code's bytes are converted to UTF-8 from the charset its ECI declares. The metadata path registers the converter at load
(`frameworks/Backports/src/AVFoundation/RevenantQRECI.c`, `revenant_qr_install_default_converter`), which maps the ECI to an
IANA charset name and resolves it with CoreFoundation's `CFStringConvertIANACharSetNameToEncoding`. A code whose bytes do
not decode in the charset it declares is not delivered, and the engine flags it; the drop is logged on the first occurrence
and every hundredth. The engine never guesses: with no converter registered, a non-UTF-8 ECI code is flagged the same way.

Coordinates follow the iOS 7 convention as read: corners and bounds are normalized to the frame as the video data output
delivers it, which is the sensor's landscape frame, and rectOfInterest is in the same space. A preview layer must convert
them with its own transform; transformedMetadataObjectForMetadataObject: is not backported for QR objects.

Not measured yet, to measure on the iPhone 4S (`frameworks/Backports/tests/qr_metadata`, the BackportsQRMetadataProbe target):
whether the release lets a session take a second video data output alongside the app's own, whether the NV12 full-range
format is offered, the frame rate and the decode time per frame on the A5, whether the corner coordinates line up with the
preview, and how the release's native face detection behaves when only QR is requested.

# AVPlayer volume and mute, and AVAssetTrack minFrameDuration on iOS 6

`AVPlayer.volume` and `AVPlayer.isMuted` are iOS 7 members and `AVAssetTrack.minFrameDuration` is an iOS 7 member. Telegram's MediaEditor
(`MediaEditorPlayerView`, `MediaEditorComposer`, `MediaEditorValues`) calls all three without a `#available` check, so they are implemented, not
guarded. The lowering drops the availability of a name that `frameworks/Backports/tools/lowered-members.txt` lists, and that file is generated from
the `@implementation` blocks of `frameworks/Backports/src`.

## What the iPhone 4S (iOS 6.1.3) has

Measured on the device (2026-11-08, `frameworks/Backports/tests/AVFoundation/player_volume_test.m` and `track_frame_duration_test.m` run there):

- `AVPlayer` has the private `_volume` and `_setVolume:`. Calling them changes the volume of the whole device, the one the hardware buttons set (the
  measurement moved the device's volume and the probe put it back). The backport does not use them: an app that mutes its player would mute the phone.
- `AVPlayerItem` has the private `volumeAdjustment` and `setVolumeAdjustment:` (in the shared caches of 6.0 and 6.1.3 alike; the item's `kFigPlaybackItemProperty_Volume`).
  A gain set that way applies to that item only, as a linear factor: on the phone's microphone a factor of 0.5, 0.25 and 0.1 reads the same as an audio mix
  with that volume (within 0.4 dB), 0 reads the ambient level, 2 reads louder than 1, and the factor multiplies with the gain of an audio mix. It changes
  while the item plays. An audio tap (`MTAudioProcessingTap`) sees the sound before either gain.
- `AVAssetTrack` has no `minFrameDuration` and `AVAssetTrack.asset` is a weak reference, so a track does not keep its asset alive.
- `AVAssetReader` with a track output and `outputSettings:nil` hands out the compressed samples with their durations.

## Volume and mute

`frameworks/Backports/src/AVFoundation/AVPlayerVolume7.m` keeps the player's volume and mute state in an associated object, so `volume` reads back as
set (clamped to 0 to 1, default 1) and `isMuted` is independent of it. The gain applied is 0 while muted and the volume otherwise. It reaches the sound as
the `volumeAdjustment` of each item the player holds: the item's own value at the time the player first touched it, times the gain.

- The app's audio mix is never replaced, scaled or read, and no track has to be loaded: the gain is set at once, on items whose tracks have not loaded too.
- The gain is applied when the volume or mute changes, when `replaceCurrentItemWithPlayerItem:` runs, and on a queue player when an item is inserted, to every
  item the player holds. At full volume the item gets its own value back and the record is dropped.
- `+load` replaces `replaceCurrentItemWithPlayerItem:` on `AVPlayer` and `insertItem:afterItem:`, `removeItem:`, `removeAllItems` and
  `advanceToNextItem` on `AVQueuePlayer` (`class_replaceMethod` with a block that calls the original first; the crutch is C52). A removed item gets its own value back, and a player
  that is released gives back every item that is left, so an item that outlives a muted player is not left muted.

Limits, reasoned: an item that the app takes out of one player and puts into another is given its own value on removal and takes the new player's gain on
insertion; the player's rate and `AVAudioSession` are untouched.

Checked: host 14 of 14 and device 14 of 14 (`player_volume_test.m`, the claims above in the order of the file); the host run's `--negative` mode fails. On the
host the test supplies `volumeAdjustment` itself, because macOS has no such member. The sound was measured on the phone with `PlayerSignalProbe` (a tone from the
speaker read by the phone's microphone): the backport's volume and mute change the level as the numbers in C52 show.

## minFrameDuration

`frameworks/Backports/src/AVFoundation/AVAssetTrackFrameDuration7.m` returns the shortest sample duration of a visual track, read once with a passthrough
`AVAssetReader` over the whole track and cached on the track. A track with no samples, a non-visual track, a reader that does not complete and a track
whose asset is gone give `kCMTimeInvalid`, an invalid time that a caller testing validity or taking the reciprocal reads as unknown. The first call reads every sample of the
track once (compressed, not decoded, and with `alwaysCopiesSampleData` off so the reader does not copy each sample) and the answer is kept, so the cost is one
pass over the track; C53 records it. Measured on the iPhone 4S: a 30 s clip of 900 frames took 0.29 s at 0.7 MB, 0.57 s at 14.3 MB and 0.88 s at
42.9 MB. The system keeps no stored value to read instead (no such property in the FigTrack lists of 6.0 and 6.1.3, no reachable sample cursor), and `samplePresentationTimeForTrackTime:`
returns the time it is given and so cannot step along the samples (measured, about 300 microseconds a call).

A composition track has no samples of its own, and the SDK redeclares the property on `AVCompositionTrack` for Swift (`AVCompositionTrack
(SynchronousTrackInterface)`), which is the declaration Telegram's `MediaEditorVideoExport.frameRate(for:)` and `MediaEditor.swift` resolve to. The same file
gives `AVCompositionTrack` its own `minFrameDuration`: the shortest of the source tracks of the track's non-empty segments, each source track read
as above from a new `AVURLAsset` of the segment's `sourceURL` and `sourceTrackID`, and each scaled by the segment's time mapping (the target duration over the
source duration, so a clip stretched to twice its length has twice the shortest frame). An empty segment adds nothing, a track that is not video gives
`kCMTimeInvalid`, and the answer is not kept, because a mutable composition changes. The lowering needs the class named: a member that a class implements is
lowered where that class declares it, not where a subclass declares it again (`docs/explanation/backports/lowered-implemented-names.md`).

A track is visual when its media type is video or it has the visual characteristic. The characteristic alone is not enough: measured on the iPhone 4S,
`hasMediaCharacteristic:AVMediaCharacteristicVisual` is NO for a composition video track, which has no format description, and the first device run gave an
invalid time for it.

Checked: a 320 by 240 clip written with unequal frame durations (the shortest a sixtieth of a second) gives the sixtieth, twice the same value, and the
reciprocal exceeds the average frame rate; a composition track that plays the clip gives the sixtieth, an empty segment after it changes nothing, the clip
stretched to twice its length gives a thirtieth, and an audio composition track gives an invalid time. Host 9 of 9 (the `--negative` mode fails 7) and device
9 of 9 (targets `TrackFrameDurationTest` and `FrameDurationProbe`). The test does not cover a track whose frames are all the same length, a variable-rate H.264 asset longer than a few seconds, a
track of an asset on the network, or a segment whose source file has moved.

Not measured: the time of the first call on a clip longer than 30 s on the A5.
