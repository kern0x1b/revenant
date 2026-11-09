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
source folder, so the attribute and the `@implementation` need not be in one file. The attribute also gives the compiled
class the SDK's name for its `_OBJC_CLASS_$_` and `_OBJC_METACLASS_$_` symbols, so the library exports the class under
that name and not under the port's own. `lowered_exports_test.lua` asks the same scan, `classes_implemented_in`, which
classes the sources implement, so it counts such a class under the SDK's name too; it runs in `tools/prepush.lua`.

## An enum type is lowered with its cases

A case that `src/` implements is an `enum` line, and Swift sees the case only if the enum type itself is nameable too.
The type of an Objective-C error enum such as `WKError`, `CKError` or `CNError` carries the availability of the
release that introduced it, so a case that is lowered while its type is not still fails with "'WKError' is only
available in iOS 8.0 or newer". The `enum_type` lines of `lowered-members.txt` name the enum types that have a lowered case, and the lowering
removes the availability that follows the closing brace of such a typedef and nothing of its cases: a case that
`src/` does not implement keeps its own availability, or takes the one of the enclosing `API_AVAILABLE_BEGIN` region,
which the lowering writes onto the case before it takes the typedef out of the region. A typedef with no availability
after its brace is left alone.

## A case that names a lowered case is lowered with it

`PHImageContentModeDefault` is declared as `PHImageContentModeAspectFit`, so it is the same value, and Telegram writes
`contentMode: .default` for it. The lowering read each case's own availability and gave `Default` the enclosing region's
iOS 8, because `src/` never writes the word `Default`. `enumerator_alias` reads an initializer that is only the name of
another case of the same enum, and the lowering repeats until no case remains that names a lowered case, so `Default`
loses its availability with `AspectFit` and a case that names nothing lowered keeps its own. `lowering_test.lua` checks
both directions on the Photos header and compiles a probe that uses all three modes at iOS 6.0.

## A class that a macro implements

`UITextInputTraits11.m` gives `UITextField`, `UITextView` and `UISearchBar` the same traits through one macro that wraps
`@implementation CLASS (RevenantTextInputTraits11)`. The scan is line based and does not run the preprocessor, so it
read the macro's body as an implementation of a class named `CLASS` and recorded no member for the three real classes:
`smartQuotesType`, `smartDashesType`, `smartInsertDeleteType` and `textContentType` kept their iOS 11 and iOS 10
availability. `expanded_class_macros` finds a `#define` whose body holds `@implementation` followed by its own parameter,
drops the definition, and replaces each line that is only a use of that macro with the body, so the members belong to the
class each use names. A macro whose body has no implementation of its parameter is left alone.

## A synthesize list implements every property it names

`@synthesize a, b, c;` implements three properties, and the scan recorded only the first. `PHAssetResourceCreationOptions`
had `originalFilename` in the list and `uniformTypeIdentifier` and `shouldMoveFile` missing, so Telegram's
`options.shouldMoveFile = true` stopped at "only available in iOS 9.0". Each name of the list is a member now, with or
without `= ivar`. A property that the SDK declares with its own availability needs a `@synthesize` or an accessor in `src/`
to be a member at all: relying on the compiler's automatic synthesis leaves it out, which is why `PHFetchOptions` names
`includeAssetSourceTypes` and `fetchLimit`, the two iOS 9 members of its header, in a list.

## A protocol is backed through the classes that conform to it

A protocol's members are lowered when a class that `src/` implements conforms to the protocol and implements the member.
`protocol_status` reads the conformance from the `@interface` declarations of the SDK headers and of `src/`, through the
superclasses of the class and the parent protocols of each protocol, so `UITextField` conforms to `UITextInputTraits`
through the protocol it adopts and not only by the line that names it. Such a protocol is a candidate even when no file
of `src/` names it. `UIMenuBuilder`, `UITextInputTraits` and `UIViewControllerPreviewing` are backed this way. A member
is lowered when a conforming class implements it and either the protocol is one that `src/` names (adopts, uses as a
type or defines) or the SDK marks the member later than the floor; a member that an earlier release already declares is
not touched through a protocol that `src/` never names.

## A protocol that the signature of an implemented member names is lowered with it

The lowering already followed the typedefs that the signature of a lowered statement names, and a typedef whose
availability is later than the floor is lowered with it. A protocol was left out. `CNChangeHistoryEvent` is implemented
in `src/`, its `acceptEventVisitor:` is lowered, and the parameter is `id<CNChangeHistoryEventVisitor>`, a protocol the
SDK marks iOS 13. Telegram's `ContactsHelper` header declares a function over that parameter, and the module did not
build: "only available on iOS 13.0 or newer". An annotated protocol, by its own macro or through an availability region,
that a lowered statement names is now lowered with it, and the methods of such a protocol keep their own availability,
so a protocol that is named does not make its unimplemented methods callable. `signature_types` runs the same pass over
header texts, and `lowering_test.lua` probes it without the SDK. The change added 154 protocols to
`frameworks/Backports/tools/lowered-members.txt` (the message of its commit says 127; 154 is the count).

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

### `UTType` is bridged to the Objective-C class

The SDK's `UniformTypeIdentifiers.apinotes` names the Objective-C class `UTType` `UTTypeReference` in Swift and gives it
`SwiftBridge: UTType`, so a header's `NSArray<UTType *>` or `UTType *` is imported as `[UTType]` or `UTType` of the
struct, and Swift hands it to Objective-C only through the struct's `_ObjectiveCBridgeable` conformance. The overlay's
struct had none. swift-frontend 6.4 did not diagnose that: with the class in view, IR generation of a call to
`UIDocumentPickerViewController(forOpeningContentTypes:asCopy:)` crashed in clang's `ARMABIInfo::computeInfo` while it
expanded the signature `(Array<UTType>, ObjCBool, ...)`, which is the exit 11 of Telegram's
`LegacyICloudFilePicker.swift:71` in `LegacyMediaPickerUI`. Without the class in view, which is the case of a file that
imports only the overlay, the initialiser was not imported at all and the call failed with "incorrect argument label".

`frameworks/Backports/src/UniformTypeIdentifiers/Bridging.swift` adds the conformance over `UTTypeReference`, which is the
Backports' own `UTType` class (`src/UIKit/UTType.m`), and the overlay is built with `-import-underlying-module` as the
`SceneKit`, `Vision` and `CoreML` modules are, so a consumer that imports the module sees the class and the
`UIDocumentPickerViewController`, `UIDocumentBrowserViewController` and `contentTypesForRecentDocuments` declarations of the
lowered headers. The reference is made with `+typeWithIdentifier:`, which returns `nil` for the empty identifier only, so
`UTType(importedAs: "")`, the one struct without a reference, stops at the `!` of the bridge. The dylib overlay
`swiftUniformTypeIdentifiers` is built the same way, because it compiles the same folder. `Bridging.swift` is not in the
host test `uti_test.lua`, which compiles the other four files without the Objective-C class.

The class is defined by `libUIKitBackports.dylib`, so the dylib overlay now refers to `_OBJC_CLASS_$_UTType` and must bind it
at link time, as `swiftNetwork` binds the TLS entry points: `src/Swift/uti_stub.lua` lists the class and the overlay passes
`stub = "uti_stub"`, which generates a `libUIKitBackports.tbd` carrying the install name
`/usr/lib/revenant/org.revenant.backports/libUIKitBackports.dylib`. Without the stub the link of
`libswiftUniformTypeIdentifiers.dylib` stopped at the undefined class. The `UIKitBackports` target checks after it is built
that it exports `_OBJC_CLASS_$_UTType`, as the `TLSBackports` target checks its stub symbols, so a rename of the class stops
that build and not a consumer's link. A port that links `libswiftUniformTypeIdentifiers.dylib` therefore loads
`libUIKitBackports.dylib` with it, which the Backports package `org.revenant.backports` carries in the folder of that install name.

Checked: the real Bazel parameters of `LegacyMediaPickerUI` replayed through `swiftc` end in the crash (signal 11) with the
module as it was, and in exit 0 with this one, with the seven objects written. `uti_swift_test.lua` compiles a file made of the picker's two
initialisers, the browser's initialiser and `contentTypesForRecentDocuments` to an object against the lowered SDK at armv7
iOS 6.0, and compiles the same file against a module built without `Bridging.swift`, which must stop with `Array<UTType>`
in the log (it stops in the getter). Of the SDK's `SwiftBridge` classes this is the only one whose Swift side an overlay of
ours declares: Foundation's come from the runtime's overlay, and `INMediaDestination`, `INShortcut` and the `PencilKit`
classes have no struct here. The object of `swiftUniformTypeIdentifiers` linked with the generated stub as an armv7 dylib
with `ld`: the class binds to `libUIKitBackports`, and the same link without the stub leaves it to a dynamic lookup. Not
run: the bridge on a device or in the emulator, since no image is booted here.

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

`swift_target` also gives every static target `-module-link-name <target name>`. The flag is what makes a program that
imports the module link the archive: the importing object records `-l<name>` as an autolink entry, and `ld` takes the
archive from the `-L` folder. The nine static targets that wrote the flag by hand had it, and `createml`, which builds
`TabularData`, `CoreML`, `CreateMLComponents` and `CreateML`, did not. A Telegram object that imported `CoreML` therefore
carried `-framework CoreML` (from `-import-underlying-module`) and no `-lCoreML`, `libCoreML.a` was never opened, and the
armv7 link of the app stopped with one undefined symbol, `static (extension in CoreML):__C.MLModel.load(contentsOf:configuration:completionHandler:)`
from `libImageObjectSeparation.a`. The archive defined it all along: no CoreML runtime was missing, the engine in
`src/CoreML` (`RevenantML*.c`) is the one that serves the call. The `linkname` test of `swift_backports_tests` fails for a
static target of the component whose `swift.flags` do not name it.

Checked on armv7 iOS 6.0 against the lowered SDK: an object that imports `CoreML` lists no `-lCoreML` before the change to
`swift_target` and lists it after. Telegram's own `libImageObjectSeparation.a`, linked with ld64 as a dylib together with
the rebuilt `libVision.a`, the Swift runtime, libSystem and the CoreML and Vision Backports dylibs, leaves 57 distinct
undefined symbols without `-lCoreML` and 56 with it. The one that goes is
`MLModel.load(contentsOf:configuration:completionHandler:)`; the others are symbols of Telegram's other modules and
`___isPlatformVersionAtLeast`, which `libapple-compat.a` supplies in the app link and this ad hoc link did not carry.
`libCoreML.a` alone links against the runtime, libSystem and `libCoreMLBackports.dylib` with nothing undefined, and all 18
static targets of the component build after the change. The archive of an app compiled before the change keeps its
objects without the entry, so the importing module is compiled again against the new `CoreML.swiftmodule` to autolink.
Not run: the app's own link (the Telegram build), a device, or a model.

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

The overlay's Swift methods are matched to implemented selectors by the name the overlay gives them. `swift_base` guesses
the name from the selector; `SWIFT_OVERLAY_NAMES` names the seven `Calendar` methods that the guess misses
(`dateComponents(in:from:)`, `nextDate(after:matching:matchingPolicy:...)` and the others), and `lowered_by` also reads
`public mutating func`. The match is by name, so an overload that shares a lowered name takes the lowering with it, and
that is wrong when its signature names a type that is still gated: `dateIntervalOfWeekend(containing:)` and
`nextWeekend(startingAfter:direction:)` return a `DateInterval`, which is iOS 10, and lost their gate with the iOS 8
overloads of the same name, so the runtime stopped building at "'DateInterval' is only available in iOS 10.0 or newer".
A method whose signature names `DateInterval` is not lowered unless `DateInterval` is implemented
(`names_unlowered_type`; `lowering_test.lua` has the three weekend overloads and fails without it). The unit test sees only the
samples it holds, so a build of the runtime from source is what confirms a change to this lowering.

## A declaration whose availability is behind a preprocessor conditional

Two shapes of the SDK's own headers kept an implemented member's availability, and each failed a Telegram line that the
backport covered.

- `@property (nonatomic) BOOL automaticallyWaitsToMinimizeStalling`, then `#if AVF_DEPLOYING_TO_2022_RELEASES_AND_LATER`,
  `NS_SWIFT_NONISOLATED`, `#endif`, then `API_AVAILABLE(...)` (`AVPlayer`). `property_name` named the property after the last identifier of the
  declaration, and the conditional's lines put the macro there, so the property was recorded under the wrong name, lost no
  availability, and its neighbour was lowered by mistake. `property_name` drops the directive lines first.
- `@property (nonatomic, readonly) CMTime minFrameDuration`, then `#if __swift__`, `API_UNAVAILABLE(visionos);`, `#else`,
  `API_AVAILABLE(ios(7.0), ...);`, `#endif` (`AVAssetTrack.minFrameDuration`). The declaration was taken to end at the first
  `;`, inside the `#if` branch, so the `API_AVAILABLE` of the `#else` branch stayed. `declaration_end` reads on to the
  `#endif` that closes a conditional opened inside the declaration. It is used for the members of an `@interface` and an
  `@protocol` in `lowering_of`; `device_members_in` still ends at the first `;`.

`lowering_test.lua` has a sample of each (`SampleGated`, `SampleBranched`) and fails without the fix. Checked on the
SDK: of the 3988 headers the second change alters one, `AVAssetTrack.h`, by one line.

A member that a class implements is lowered where that class declares it. A subclass that declares it again keeps its
own availability: `AVCompositionTrack (SynchronousTrackInterface)` redeclares `minFrameDuration` for Swift, and Swift
resolved `compositionTrack.minFrameDuration` to the redeclaration, "only available in iOS 7.0 or newer", although
`AVAssetTrack` had the member. A class that redeclares a member needs an `@implementation` of its own for it
(`AVAssetTrackFrameDuration7.m` has one for `AVCompositionTrack`, which is a real implementation and not a forwarder:
a composition track has no samples of its own to read). The SDK headers hold one more case, `AVMutableMovieTrack`,
which Telegram does not use.

### Not fixed: a word that only a comment contains

`lowering_of` lowers the statement around every occurrence of an implemented C function or global, and it counts an
occurrence inside a comment. A header comment that names one of them lowers the declaration beside it although nothing
implements that declaration. Measured on the SDK: skipping comment occurrences changes 140 headers by 324 lines, all of
them declarations that regain their availability, among them `AVAudioSession.secondaryAudioShouldBeSilencedHint`
(iOS 8), `MKDirections.Request.requestsAlternateRoutes` (iOS 7), `AVCaptureInput.Port.sourceDevicePosition` and
`sourceDeviceType` (iOS 13), `UITableView.fillerRowHeight` and `selfSizingInvalidation`, `CIContext.workingFormat` and the
`AVError` codes after `AVErrorFailedToParse`. Telegram 13.0.0 uses three of them without a guard:
`ManagedAudioSession.swift:623` (`secondaryAudioShouldBeSilencedHint`), `LocationUtils.swift:154` (`requestsAlternateRoutes`)
and the `RTCAudioSession.mm` line that reads the same hint. `requestsAlternateRoutes` is implemented now
(`MKDirectionsRequest7.m`), so that line no longer depends on the comment. The other two compile today only because the
lowering removed an availability that nothing implements, and would be a compile error after the change (reasoned: on an iOS 6 device the
selector is not there, so the call would raise "unrecognized selector" if it ran; no device run). The change is
therefore not made here: it needs those three names implemented or guarded first.

## A framework's own availability macro

The lowering removes an availability annotation by recognising the macro: a name that holds `AVAILABLE`, or a `DEPRECATED`
macro that names a release later than the device's. MediaPlayer annotates with neither, `MP_API(ios(7.1), tvos(7.1),
macos(10.12.2), watchos(5.0))`, which `MediaPlayerDefines.h` defines as `__API_AVAILABLE(__VA_ARGS__) _MP_VISIBLE`. The
class, member and enum-type lines of `lowered-members.txt` named `MPRemoteCommandCenter`, `MPRemoteCommand`,
`MPRemoteCommandEvent`, `MPChangePlaybackPositionCommandEvent` and the status codes, but no header changed, because the
annotation was never seen as one: Telegram's `MediaManager.swift` stopped at "'MPRemoteCommandCenter' is only available in iOS
7.1 or newer" (nine errors) although the command center is implemented. Only `MP_DEPRECATED`, which the deprecation rule
catches, was ever lowered in that framework, so the same gap held for `MPNowPlayingInfoCenter.playbackState` and the
`MPMediaItem` members.

`region_markers(sdk)` now also reads every function-like macro that an SDK header defines as a wrapper of
`API_AVAILABLE(__VA_ARGS__)` or `__API_AVAILABLE(__VA_ARGS__)`, whatever its name, and keeps the names in
`markers.annotations`. `lowering_of`, the typedef scan and the protocol scan take that set, and `lowered_types` reads the
markers of the SDK as the overlay build does, so the types that a lowered signature names are found through the macro too.
On the 26.2 SDK the set holds 15 names (`MP_API`, `CK_SWIFT_AVAILABILITY`, `CT_AVAILABLE`, `CX_CLASS_AVAILABLE`,
`FPUI_AVAILABLE`, `MTR_AVAILABLE`, the AVKit, ML Compute and Metal Performance Shaders wrappers); the two that lack
`AVAILABLE` are `MP_API` and `CK_SWIFT_AVAILABILITY`, and `CK_SWIFT_AVAILABILITY` changes no header, because no implemented
CloudKit name is annotated with it.

Measured on the 26.2 SDK: `lowered-members.txt` gains 13 lines (`MPErrorCode` as an enum type, `MPMediaPlayback` as a
protocol and eleven MediaPlayer types, among them `MPRemoteCommandHandlerStatus`, `MPSeekCommandEventType` and
`MPNowPlayingPlaybackState`), and the overlay maps 18 more MediaPlayer headers and changes `MPVolumeView.h`. No other header
of the 1992 that the overlay mapped before differs. The real Bazel parameters of Telegram's `TelegramUI` module, replayed
through `swiftc -typecheck` with the overlay built for the SDK path of that build, end with the nine `MPRemoteCommand*` errors
gone and nothing new. A replay whose overlay is built for a different SDK path maps nothing, because the overlay names the
SDK's headers by their path, and then fails earlier, at the first module that imports a header whose class is gated.

`lowering_test.lua` checks that `MP_API` is in the annotation set, that a class and a member that Backports implement lose
the macro and an unimplemented neighbour keeps it, that the lowering without the set does not see it, and it compiles a probe
of the remote command center at armv7 iOS 6.0 against the lowered headers.
