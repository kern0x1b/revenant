# AVCaptureDevice.activeVideoMinFrameDuration / activeVideoMaxFrameDuration, iOS 7

Introduced in iOS 7 as the device-level replacement for `AVCaptureConnection.videoMinFrameDuration`/
`videoMaxFrameDuration`, deprecated the same release. Corpus rank 5, 3 of 3 applications: the
camera is real hardware the iPhone 4S and iPad 2 already have, so this is not a wall.

## What the device already has

The selector list of iOS 6.1.3's own AVFoundation carries `activeFormat` and
`videoSupportedFrameRateRanges` - `AVCaptureDeviceFormat` and `AVFrameRateRange` are already real,
present, and readable on this release, ahead of their public iOS 7.0 documentation. The deprecated
`AVCaptureConnection.videoMinFrameDuration`/`videoMaxFrameDuration` (`isVideoMinFrameDurationSupported`/
`isVideoMaxFrameDurationSupported` alongside them) are also on the selector list and have been
since iOS 5.0. The real hardware knob this property front-ends already exists; only the
device-level accessor pair is missing.

## What the port does

`activeVideoMinFrameDuration`/`activeVideoMaxFrameDuration` are stored per device. Setting either
without the configuration lock raises `NSGenericException` with 7.0's text ("activeVideoMinFrameDuration
cannot be set without first successfully gaining exclusive ownership of the device using
-lockForConfiguration:"), read as 7.0 reads it: `-[AVCaptureDevice isLockedForConfiguration]`, a method
6.1.3 has and its own setters ask (`CaptureZoomAudioSession.md`). A device tracks the sessions its input
has been added to (`AVFoundation/CharonAVCapture.m`, shared with the zoom: `AVCaptureSession`'s
`addInput:`, `addOutput:` and `commitConfiguration` wrapped with `method_setImplementation`, and
`AVCaptureSessionDidStartRunningNotification`; `CaptureZoomAudioSession.md` says why each); on each of them, every video
connection of every tracked session gets the device's stored duration written onto its own
(real, present) `videoMinFrameDuration`/`videoMaxFrameDuration`, guarded by
`isVideoMinFrameDurationSupported`/`isVideoMaxFrameDurationSupported`. Reading the property
without ever setting it computes the header's own documented default: the shortest
`minFrameDuration` (for min) or longest `maxFrameDuration` (for max) across the active format's
`videoSupportedFrameRateRanges`.

## What differs from the release

The real `AVCaptureDevice` applies a set duration immediately, watches for automatic resets (format
change, session interruption) and is key-value observable for both. This port only reapplies a
stored duration at the four hook points above - a session already running, with its connections
already formed and no configuration change afterward, does not see a value set outside a
`lockForConfiguration:`/`commitConfiguration:` pair take effect until the next of those calls.
Automatic resets to the format's default on the conditions the header lists (format change, other
session interruption reasons) are not detected or mirrored; the stored value keeps applying
until the application changes it itself. Not exercised against a running capture session on
device this pass; the header contract and the underlying `AVCaptureConnection` properties are
measured, the end-to-end frame-rate change is not.
