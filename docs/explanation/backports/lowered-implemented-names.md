# What the lowering takes as implemented

The lowering removes the availability of an SDK declaration only for a name that Backports implement, so a name that
is missing from `frameworks/Backports/tools/lowered-members.txt` keeps its SDK availability and a use of it fails to
compile at the iOS 6 floor, however well `src/` implements it.

A C function or global that `src/` implements is written `BACKPORT_IMPL(name)`. `toolchain/modules/apple/lowered.lua`
reads that marker in every `.m`, `.mm` and `.c` file: a name followed by `(` is a function, any other is a global. The
marker is the contract, so the shape of the definition does not matter. The older line scan, which reads a definition
by how its line begins, still runs for what is not marked (the C functions of `IOSurfaceCPU.m`), and it misses four
shapes: a definition that starts with `__attribute__`, a global that is typed without `const`, a global with a
multi-line initialiser, and a function defined between `@implementation` and `@end`. The marked names that it missed
were `CMTimebaseCopySource` and `CMTimebaseCreateWithSourceClock`, `VTMultiPassStorageCreate`, `Close` and
`GetTypeID`, `SRErrorDomain`, `VNVisionVersionNumber`, `GCInputDirectionPad`, `SCNMatrix4Identity`,
`kVTHDRPerFrameMetadataGenerationHDRFormatType_DolbyVision` and the eight `AVCaptureReactionType` constants. Telegram's
`MediaPlayerAudioRenderer.swift` failed on the first of them with "'CMTimebaseCopySource' is only available in iOS 9.0
or newer".

`lowered_members_test.lua` fails for any marked name that is not in the list, and `lowering_test.lua` compiles a probe
of the names above at armv7 iOS 6.0 against the lowered headers with `-Werror=unguarded-availability`.

A class whose source gives it the run-time name of an SDK class, `__attribute__((objc_runtime_name("AVCapturePhotoOutput")))`
on an `@interface` of the port's own, is recorded under the SDK's name, since the headers declare the SDK's class and the
lowering looks the class up by that name. The scan reads the attribute in every `.m`, `.mm` and `.h` of the framework's
source folder, so the attribute and the `@implementation` need not be in one file.

## An enum type is lowered with its cases

A case that `src/` implements is an `enum` line, and Swift sees the case only if the enum type itself is nameable too.
The type of an Objective-C error enum such as `WKError`, `CKError` or `CNError` carries the availability of the
release that introduced it, so a case that is lowered while its type is not still fails with "'WKError' is only
available in iOS 8.0 or newer". The `enum_type` lines of `lowered-members.txt` name the enum types that have a lowered case, and the lowering
removes the availability that follows the closing brace of such a typedef and nothing of its cases: a case that
`src/` does not implement keeps its own availability, or takes the one of the enclosing `API_AVAILABLE_BEGIN` region,
which the lowering writes onto the case before it takes the typedef out of the region. A typedef with no availability
after its brace is left alone.

## Swift names that only the SDK's interface declares

The Swift overlays that the port builds from the open-source sources lack what the SDK's own overlay added later. Two
of those gaps are closed from the SDK instead of by hand. The `Notification.Name` members of AVFoundation
(`AVCaptureSessionRuntimeError`, `AVPlayerItemDidPlayToEndTime`, `AVCaptureDeviceSubjectAreaDidChange` and the others)
are declared only in the SDK's `AVFoundation.swiftinterface`, in the extensions of `Foundation.NSNotification.Name`,
and the `swift-runtime` package copies those extensions into the AVFoundation overlay as the SDK has them, so a new SDK
brings its new names without a change here. The `attachments` of `CMSampleBuffer`, `CMBlockBuffer` and `CVBuffer`
(`CMAttachmentBearerProtocol`) are written in `toolchain/src/swift-runtime/overlay/CoreMedia/CMAttachmentBearer.swift`
over `CMSetAttachment`, `CMGetAttachment`, `CMCopyDictionaryOfAttachments` and their relatives, which CoreMedia has had
since iOS 4: `propagated` and `nonPropagated` are the two modes of `CMCopyDictionaryOfAttachments`, which returns only
the attachments of the mode it is asked for.

## Swift overlays are modules the consumer must import

Some names have no Objective-C or C answer, and their Swift side is a module of its own. The `UniformTypeIdentifiers`
overlay declares the `UTType` struct and its 140 constants, and the `IOSurface` overlay declares `IOSurface` as an alias
of `IOSurfaceRef`. At armv7 the SDK has no Swift interface for either framework, so a Swift compile that does not have
the overlay on its search path sees the Objective-C class `UTType`, which Swift names `UTTypeReference` and which has no
`jpeg`, `rtf` or `utf8PlainText`, and the Objective-C class `IOSurface`, which is an iOS 11 class.

A consumer builds the targets `UniformTypeIdentifiers` and `IOSurface` of the `Swift` component, as it builds
`AppIntents`, and passes their module folders with `-I`. Checked against the lowered SDK at armv7 iOS 6.0: without the
modules, `UTType.utf8PlainText` fails with "type 'UTType' has no member" and `IOSurface` with "only available in iOS
11.0"; with them, a file made of the lines that Telegram's Pasteboard, DrawingUI, LegacyMediaPickerUI,
ShareExtensionContext, SaveToCameraRoll and MetalEngine sources use typechecks without a change to those lines. That is
a check of the lines, not a build of the targets.
