# The camera and microphone authorization, iOS 7.0

iOS 7.0 gave the camera and the microphone a permission of their own, and added to
`AVCaptureDevice` the two class methods an application asks it with:
`+authorizationStatusForMediaType:` and `+requestAccessForMediaType:completionHandler:`.

Source: AVFoundation of the arm64 shared cache of iOS 12.0 -
`+[AVCaptureDevice authorizationStatusForMediaType:]` at `0x186f6376c`,
`+requestAccessForMediaType:completionHandler:` at `0x186f63900`, the strings of
`_AVMediaTypeAudio` (`soun`) and `_AVMediaTypeVideo` (`vide`), and
`_MCFeatureCameraAllowed` of ManagedConfiguration (`allowCamera`). An iPad 2 running 6.1.3
for what ManagedConfiguration answers there.

## What it is

For the audio type the method reads the microphone entry of the privacy service. For the video
type it asks ManagedConfiguration first: when the setting `allowCamera` comes back as 2 the
answer is restricted, and otherwise it reads the camera entry of the privacy service. The result
is one of not determined, restricted, denied and authorized. A media type that is neither audio nor
video raises an `NSInvalidArgumentException` whose reason is the receiver and the selector with the
sentence `The passed media type '...' is not supported`. The request takes the same steps and hands
the handler a `BOOL`.

## Where iOS 6 differs

iOS 6 asks nobody for the camera or the microphone: an application captures with no prompt and no
entry in Settings for either. So the microphone is authorized, and the camera is authorized unless the
restriction of iOS 6 that switches the camera off says otherwise. The release has ManagedConfiguration
and the same `MCFeatureCameraAllowed` (`allowCamera`), and the iPad 2 answered 1 for it with the camera
not restricted; the restricted answer, 2, is what iOS 12 tests for, and it was not exercised, because
switching the camera off is a setting of the device that a test does not change. The status is never
not determined or denied, and the request never shows a prompt: the handler is called once, off the
main thread, with YES when the status is authorized and NO when it is restricted. The queue the
handler runs on in iOS 12 was not read.

The exception text is written the way iOS 12 writes it; the plus that names a class method in the
reason was taken from the receiver being the class.
