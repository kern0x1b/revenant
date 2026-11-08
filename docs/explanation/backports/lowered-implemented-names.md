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

## SceneKit, Vision and CoreML have a module too

`SceneKit`, `Vision` and `CoreML` (with `TabularData`, `CreateMLComponents` and `CreateML`, which its Swift side needs) are
Swift modules of the same kind, and their names are the SDK frameworks' names. The SDK has a `*.swiftmodule` folder for each
at armv7, so a module that carries the name must be compiled with `-Xfrontend -import-underlying-module`, and its sources
do not import it; the targets in `frameworks/Backports/src/Swift/xmake.lua` pass the flag. A consumer builds the targets
`SceneKit`, `Vision` and `CoreML` of the `Swift` component, passes their module folders with `-I`, and adds them to the
modules it links. `AuthenticationServices` is a dylib overlay, `swiftAuthenticationServices`, taken from the
`revenant@authenticationservices` package, and it carries the SDK framework's name too, so it passes the flag as well: its
module holds only `ASCredentialUpdater`, and without the flag it replaced the SDK's module for every file that imports
`AuthenticationServices`, so Telegram's `PasskeysScreen.swift` found no `ASAuthorizationController`, `ASAuthorization`,
`ASPresentationAnchor` or `ASAuthorizationPlatformPublicKeyCredentialProvider`. What each carries is in
`docs/reference/backports/SceneKit/README.md`, `Vision/README.md`, `CoreML/README.md` and
`AuthenticationServices/CredentialUpdater.md`.

Every Swift target of the `Swift` component is made by one function of `frameworks/Backports/src/Swift/xmake.lua`,
`swift_target`, which sets the kind, the swift rule, the optimisation and `swift.cxx_interop` to `off`, and the flag for the
underlying module is one list, `UNDERLYING`, that the framework overlays, the CoreML module and the dylib overlay all
take. The `CoreML` target had been written beside the others without the `off`, so its module was built with C++
interoperability, and a program that imports it without the interoperability (every Telegram module) stopped with "module
'CoreML' was built with C++ interoperability enabled, but current compilation does not enable C++ interoperability".

## A name the device already exports is lowered, not backported

A backport of a name the release already has would replace the release's own, so the first question for a name is whether
iOS 6.0 exports it. Two lists answer it, and neither needs source in `src/`:

- A class member that the release implements and the SDK marks later is in `frameworks/Backports/tools/device-members.txt`,
  which `frameworks/Backports/tools/device_members.lua` writes from the release's dyld inventory. The writer read only
  `API_AVAILABLE` and `__IPHONE_x_y`, so it missed members marked with the older `NS_AVAILABLE(10_10, 8_0)` and
  `NS_AVAILABLE_IOS(8_0)`. Reading them adds six: `-[CIImage imageByApplyingOrientation:]`,
  `-[CIImage imageTransformForOrientation:]`, `-[CIImage initWithCGImageSource:index:options:]`,
  `-[EKEvent occurrenceDate]` and `-[MKDirectionsRequest setSource:]` and `setDestination:`. `lowered_device_macros_test.lua`
  checks both forms. The first two had been written again by the CIImage backport, which replaced the release's own.
- A C function has no inventory entry, so a record in `MEMBERS` of `toolchain/modules/apple/lowered.lua` names the exact
  header text to change. `CGPathCreateWithRoundedRect` and `CGPathAddRoundedRect` are there: measured in the iOS 6.0 and
  6.1.3 shared caches, CoreGraphics exports `_CGPathCreateWithRoundedRect` and `_CGPathAddRoundedRect`, although the SDK
  marks both iOS 7.

## The runtime's Swift overlays are built against the lowered headers

`swift-runtime` builds its Swift overlays from two checkouts, and lowers the Swift text of some of them
(`lower_swift_overlay_folder` in `toolchain/modules/apple/lowered.lua`): Foundation, and AVFoundation, where the overlay
carried `@available(iOS 7.0` on `AVMetadataMachineReadableCodeObject.corners`, which Backports implement.

CoreGraphics was the overlay built against the SDK's own headers, so its `CGMutablePath.addRoundedRect(in:cornerWidth:cornerHeight:transform:)`
carried `@available(iOS 7.0)` from a patch, and every program that called it at iOS 6 met "only available in iOS 7.0 or
newer" (Telegram's `WalletCardTextures.swift`). It is built against the lowered headers now, the patch carries no
`@available`, and the guard row `_CGPathAddRoundedRect` of `apple.runtime_guards` is gone, because the import is strong
and the release's CoreGraphics exports the symbol. Checked: the patched sources compile against the lowered SDK at armv7
iOS 6.0, and against the SDK's own headers the same sources fail with "'__addRoundedRect(transform:rect:cornerWidth:cornerHeight:)'
is only available in iOS 7.0 or newer".

The lowering also took the `@end` at the front of a doc comment's `@endcode` for the end of an `@interface` or `@protocol`,
so the members after the first doc-commented one kept their availability (`MLModel`'s compile call was one).
`block_end_of` ends a block only at the word `@end` (`lowered_doc_comment_test.lua`).
