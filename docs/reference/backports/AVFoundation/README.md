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
