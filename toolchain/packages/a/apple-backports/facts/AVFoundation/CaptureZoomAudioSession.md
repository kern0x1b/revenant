# AVCaptureDevice zoom and AVCaptureSession's application audio session, iOS 7.0

Ranks 47, 48 and 49 of `coordination/corpus/band-frameworks.tsv`, all `CRASH-ON-USE` (session and
telegram send `videoZoomFactor`, `videoMaxZoomFactor` and `usesApplicationAudioSession`). The armv7
cache ladder first carries every member here at 7.0. The registry had them all `absent` because "it
arrived in iOS 7", the reason `COORDINATION.md` section 2 forbids; retracted.

## Zoom: what 6.1.3 has, measured and read

`objc.inventory` of 6.1.3 finds no zoom selector on `AVCaptureDevice`, `AVCaptureDeviceFormat` or the
concrete device class; the scale and crop is `AVCaptureConnection`'s `videoScaleAndCropFactor` of iOS 5.
Read from 6.1.3's AVFoundation (armv7 cache, `-[AVCaptureConnection initCommonStorage]` and its
`observeValueForKeyPath:...`): `videoMaxScaleAndCropFactor` is set from the device's
`LiveSourceOptions.Capture.Width` and `.Height` as `min(width, height) * 0.0625`, a crop of no less than
16 pixels on the short side. On an iPad 2 (`tests/backports/device/zoom7.m`), capturing 640x480, it is 30
on a still image connection, 480 / 16; a video data connection answers 1 and refuses 2 with
`NSInvalidArgumentException`, and so does a movie file output's connection (1). The preview layer masks
its bounds and draws the video in a sublayer of its own (it sets `masksToBounds` in `-initWithSession:`
and centres the sublayer in `-layoutSublayers`), and sets no `sublayerTransform` of its own.

7.0's `-[AVCaptureFigVideoDevice setVideoZoomFactor:]` and `rampToVideoZoomFactor:withRate:` check the
factor against 1 and `activeFormat.videoMaxZoomFactor` (`NSRangeException`, "videoZoomFactor out of
range"), then `[self isLockedForConfiguration]` (`NSGenericException`, "You must call lockForConfiguration
and successfully obtain the configuration lock before modifying zoom factor"). `-isLockedForConfiguration`
is a method of 6.1.3's `AVCaptureDevice` too, the lock count above 0, and 6.1.3's own setters ask it
(`setFocusMode:` raises `NSGenericException`, "... before setting focusMode", when it answers NO): the port
reads the lock the way the release and 7.0 do.

## Zoom: what the port does

The header: "Applies a centered crop for all image outputs, scaling as necessary to maintain output
dimensions."

- `AVCaptureDeviceFormat.videoMaxZoomFactor` is `min(width, height) * 0.0625` of the format, at least 1:
  the release's own limit for its scale and crop, so the still connection can follow the zoom to its end
  (on the iPad at 640x480 the active format's maximum and the still connection's are both 30).
  `videoZoomFactorUpscaleThreshold` is 1: the crop is of the format's own frames, so any factor scales up.
- `videoZoomFactor` is kept on the device. Setting it, and `rampToVideoZoomFactor:withRate:`, check as
  7.0 does, in its order and with its texts; outside a running session 6.1.3 has no active format, and the
  range is then 1 to 1. Setting it cancels a ramp. It is key-value observable.
- The factor goes to every session an input of the device is in, when it changes and whenever a session
  gains an input, an output or a preview layer, starts running or commits a configuration: a connection
  that scales and crops itself (the still image output's) is given it as `videoScaleAndCropFactor`, up to
  its own maximum; a preview layer of the session is given it as its `sublayerTransform`, so its video is
  scaled inside the bounds it masks, and its `captureDevicePointOfInterestForPoint:` and
  `pointForCaptureDevicePointOfInterest:` are taken through the zoom around the layer's centre; the buffers
  a video data output hands its delegate are cropped to the centre `1/factor` of each plane and scaled back
  to their size with vImage (32BGRA and both bi-planar 4:2:0 formats, the ones the output delivers), with
  the timing and attachments of the frame; the application's delegate is kept behind a proxy of the
  port's (see "What is replaced, and why").
- `rampToVideoZoomFactor:withRate:` moves the factor by `pow(2, |rate| * time)` towards the target, sixty
  steps a second on the main queue, and ends there; a rate of 0 ends the ramp. `rampingVideoZoom` is YES
  while it runs and is observable. `cancelVideoZoomRamp` needs the lock, as the header says, and stops the
  ramp where it is.
- Differs: a movie file output of 6.1.3 cannot scale or crop (its connection's maximum is 1), and records
  the whole frame; an application that records with a video data output and an asset writer gets the
  zoomed frames. A format the video data output delivers that is not one of the three is passed on whole,
  said once in the log. The metadata object rectangles of the preview layer are the release's.
- Measured on an iPad 2 running 6.1.3 with the zoom built into a daemon (`tests/backports/device/zoom7.m`).

## What is replaced, and why

The zoom acts where 6.1.3 gives it no public signal or hook; each case, and the public path taken where there
is one (read from 6.1.3's AVFoundation in the armv7 cache):

- `-[AVCaptureDevice isLockedForConfiguration]` is not in any public header. It is a method of the release's own
  `AVCaptureDevice` in the class lists of 5.1.1, 6.0, 6.1 and 6.1.3 (the configuration lock count above 0), every
  public setter of 6.1.3's camera device asks it before anything else is done (`setFocusMode:`,
  `setFocusPointOfInterest:`, `setExposureMode:`, `setExposurePointOfInterest:`, `setWhiteBalanceMode:`,
  `setFlashMode:`, `setTorchMode:`, `setTorchModeOnWithLevel:error:`, `setSubjectAreaChangeMonitoringEnabled:`,
  `setAutomaticallyEnablesLowLightBoostWhenAvailable:`: supported first, then the lock, then the release's own
  private setter; none compares the value first), and 7.0's zoom and frame duration setters ask it. The only public
  reading of the lock is to call one of those setters and catch the exception, which changes the device when the
  lock is held; the port asks the method instead, a documented exception.
- `-[AVCaptureSession startRunning]` is not replaced: `AVCaptureSessionDidStartRunningNotification` (4.0) says it.
- `-[AVCaptureSession addInput:]`, `-addOutput:` and `-commitConfiguration` are wrapped, calling the release's
  first (`CharonAVCapture.m`): 6.x posts nothing for them, and `inputs` and `outputs` are not observable (6.1.3's
  `addInput:` and `addOutput:` send no `willChangeValueForKey:`). A device's sessions are learnt from
  `addInput:`, and each of them reapplies the zoom and the frame durations to the connections it made.
- `-[AVCaptureVideoPreviewLayer setSession:]` is wrapped (`-initWithSession:` calls it): a session does not list its
  preview layers, and nothing public says a layer was given one.
- `-[AVCaptureVideoDataOutput setSampleBufferDelegate:queue:]` is wrapped: the delegate is the only public way the
  frames reach the application, so the crop has to stand in front of it. The release is given a proxy of the port's
  own that forwards every message to the application's delegate (its class, equality, hash, description and what
  it answers are the delegate's) except the one that carries a frame; `sampleBufferDelegate` answers the proxy,
  since the release reads the delegate through that getter for each frame
  (`-[AVCaptureVideoDataOutput _AVCaptureVideoDataOutput_VideoDataBecameReady]`). Differs: the pointer is not the
  application's.
- `-[AVCaptureVideoPreviewLayer captureDevicePointOfInterestForPoint:]` and `-pointForCaptureDevicePointOfInterest:`
  are wrapped: they are the release's conversions, which know nothing of the sublayer transform the zoom sets, and
  an application has no other public way to convert.

## The application's audio session: what 6.1.3 does, measured

A daemon on the same iPad set its audio session to `AVAudioSessionCategoryPlayback` with
`MixWithOthers` and made it active - a category that cannot record - then ran a capture session with
the microphone and an audio data output: the buffers arrived, and before, during and after the
capture the application's category, options and mode were unchanged, with no interruption. The
capture session records through an audio session of its own and leaves the application's alone.

- `usesApplicationAudioSession` and `automaticallyConfiguresApplicationAudioSession` answer `NO`,
  which is what 6.1.3 does.
- Setting either to `YES` cannot be honoured: the release has no way to record through the
  application's session. The property keeps answering `NO`, so an application that reads it back
  sees the truth, and the log says so the first time.
- Measured with the category in the same daemon: a new capture session answers `NO` for both, and
  still does after both are set to `YES`.
- Not measured: what the private session does to audio the application itself plays while a
  capture runs (the daemon played nothing).
