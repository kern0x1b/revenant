# The large members still open for Telegram

What the demand map (`docs/guides/backports/demand.md`) still reports as missing. The Metal and WebKit sections are
checked against the sources of this revision: each claim names the file it comes from, and a claim that was not
checked is not made. The AuthenticationServices section is unchanged from the earlier revision and has not been
re-checked. Each entry says what exists, what is missing, and what has to be decided before anyone starts.

## Metal

What exists, from `frameworks/Backports/src/Metal` (84 files):

- The device is OpenGL ES 2.0. `RevenantMetalDevice.m` creates its own `EAGLContext` with `kEAGLRenderingAPIOpenGLES2`.
  Buffers, textures, pipelines, encoders, the queue and drawables are GL objects (`RevenantMetal*.m`, 2,743 lines).
  `RevenantMetalPipeline.m` compiles and links GL shaders, and `RevenantMetalDrawable.m` reads the color renderbuffer.
- `MTLCreateSystemDefaultDevice` is implemented (`MTLCreateSystemDefaultDevice8.m`). Its declaration is lowered to
  iOS 6.0 by the derived lowering, and `frameworks/Backports/tests/lowering_test.lua` compiles a call to it at iOS 6.0
  with unguarded availability as errors.
- Compute dispatch runs only kernels that the app carries as `air2cpu` C code. `MTLComputePipeline8.m` looks up the
  table `air2cpu_kernels` in the process, and a library without it refuses the kernel with error 20.
- The refusals are loud: `dispatchThreadgroups` logs and refuses a dispatch with no pipeline state, an undeclared
  threadgroup block, or an empty dimension.
- `MTLBinaryArchive` (`RevenantMetalBinaryArchive.m`, `MTLBinaryArchive14.m`): an archive file that stores the descriptors
  of the render and compute pipelines added to it, in a property list, and reads them back. Its errors are in
  `MTLBinaryArchiveDomain`. The host oracle `tests/Metal/binary_archive_test.m` checks the file and the errors against real
  Metal (23 checks).

What is missing:

- The protocols. No `@protocol` definition for `MTLDevice`, `MTLTexture`, `MTLLibrary`, `MTLRenderPipelineState`,
  `MTLCommandBuffer`, `MTLBuffer`, `MTLComputePipelineState`, `MTLCommandQueue`, `MTLRenderCommandEncoder`,
  `MTLDrawable` or `MTKViewDelegate` exists in `src`; the sources only forward-declare them or reference them, as the
  MPS files do. A class that adopts one of them, or a `@protocol(...)` reference, needs a protocol object that the
  backport does not provide.
  The demand map counts these as missing, and that count is right: `MTLDevice` 37 files, `MTLTexture` 31, `MTLLibrary`
  21, `MTLRenderPipelineState` 21, `MTLCommandBuffer` 16, `MTLBuffer` 11, `MTLComputePipelineState` 11,
  `MTLCommandQueue` 10, `MTLRenderCommandEncoder` 7, `MTLDrawable` 4, `MTKViewDelegate` 2.
- Render shaders from Metal Shading Language. `RevenantMetalLibrary` keeps the source text, and `RevenantMetalPipeline.m`
  passes that text to `glShaderSource` unchanged, so it must already be GLSL ES. No translator is in the tree. A
  render pipeline built from MSL fails at compile, with the GL info log as the error.
- Compute kernels from MSL source. They need an `air2cpu` table for each kernel, which the app does not produce from
  its own MSL at run time.
- `MTLCommandQueue` completion: `RevenantMetalQueue.m` calls `glFinish` where a command buffer completes, so
  `waitUntilCompleted` waits for the whole GL queue. The cost of that on the device is not measured.
- `MTLBinaryArchive` gives no speed-up. The archive stores pipeline descriptors, not compiled programs, because
  `glGetProgramBinary` and `glProgramBinary` are stubs (`src/OpenGLES/ES3Functions.m`). A pipeline made from an archive
  compiles again when it is created, so only the file format is backported.
- `MTLBinaryArchive` has no tile or mesh pipelines. `addTileRenderPipelineFunctionsWithDescriptor:error:` and
  `addMeshRenderPipelineFunctionsWithDescriptor:error:` are not implemented, and a call to either fails with an unrecognised
  selector. The backport has no tile or mesh pipeline to add.

Decisions still open:

- Render shaders: an offline MSL to GLSL ES translator (a new tool, not in the tree), or a loud refusal of MSL libraries
  at `newLibraryWithSource:`.
- Protocol definitions: hand-written like `QuartzCoreProtocols10.m`, or generated from the SDK header, with the same
  lowering as the methods. The generated form needs the protocol list to come from what the Backports classes conform
  to, which no tool derives yet.

## CoreImage: `CIRenderDestination`

What exists, from `frameworks/Backports/src/Graphics/CIRenderDestination11.m` and `CIContextRenderDestination11.m`:

- Every destination initialiser: bitmap data, pixel buffer (32BGRA and RGBA), IOSurface (8-bit BGRA and RGBA), OpenGL
  texture (`GL_TEXTURE_2D`, RGBA8), Metal texture and texture provider. The pixel buffer and IOSurface initialisers lock
  the buffer only for the copy. The IOSurface initialiser calls the wrapper functions in `src/IOSurface/IOSurface11_0.m`,
  whose symbols are in the iOS 6.1.3 export table (see the IOSurface paragraph above).
- `startTaskToRender:toDestination:`, `startTaskToRender:fromRect:toDestination:atPoint:error:` and
  `prepareRender:fromRect:toDestination:atPoint:error:`. The host oracle `tests/CoreImage/render_destination_test.m` checks
  them against the macOS framework: the bitmap, pixel buffer, IOSurface and GL destinations over six region cases (flipped
  and unflipped, with `atPoint` clipped and interior), the texture destination, the flipped, alpha-none and unpremultiplied
  configurations, and `prepareRender` on a bitmap and on an R8 texture. The check count is 79.

What is open:

- The `CIContext` category in `CIContextRenderDestination11.m` is not compiled on the host, because macOS `CIContext` already
  has these methods. The category forwards to the destination, and only the destination methods run in the oracle.
- OpenGL: only `GL_TEXTURE_2D`. Any other target fails with error 5. The device path (`glTexSubImage2D` on OpenGL ES 2) builds,
  but the oracle runs the CGL path on the host, and the device run is not done.
- The IOSurface initialiser is not run on device. Its functions are in the 6.1.3 export table, so the open part is the run.
- `atPoint` and `fromRect` are floored to whole pixels. The oracle uses whole numbers, so the fractional mapping is not measured.
- Colour space: the destination defaults to sRGB. The SDK's pixel-buffer and IOSurface initialisers take the colour space
  from the buffer's attributes, and the backport does not read them. Not measured against a non-sRGB buffer.
- Unpremultiplied and alpha-none rendering need an 8-bit BGRA or RGBA destination. Premultiplied rendering also takes RGBAh
  and RGBAf bitmaps, which the oracle does not cover.
- `prepareRender` checks the destination's format and backing, and nothing else. It does not reserve or compile anything.
  The oracle agrees with the host on the bitmap and R8 cases.

## VideoToolbox: `VTCreateCGImageFromCVPixelBuffer` and `VTIsHardwareDecodeSupported`

What exists, from `frameworks/Backports/src/VideoToolbox/VTCreateCGImage9_0.m` and `VTIsHardwareDecodeSupported11_0.m`:

- `VTCreateCGImageFromCVPixelBuffer` converts 8-bit bi-planar 4:2:0 NV12 (video and full range) and 32BGRA and 32ARGB to a
  `CGImage` in sRGB. The matrix (BT.601 or BT.709) is read from `kCVImageBufferYCbCrMatrixKey`. The NV12 path is Q10 fixed
  point with nearest chroma, in two forms in `src/VideoToolbox/VTConvertBiPlanar.c`: a scalar reference and a NEON path
  (`vld2`, `vmlal`) that is used where the compiler defines `__ARM_NEON`. The host oracle `tests/VideoToolbox/conversion_test.m`
  runs the same seeded frames through macOS and the backport: NV12 within 1 per channel in all four range and matrix cases,
  and 32BGRA and 32ARGB exactly on valid premultiplied pixels. It also checks NEON against scalar bit for bit at widths that
  exercise the tail (1, 15, 16, 17, 37, 1920). The check count is 45.
- `VTIsHardwareDecodeSupported` answers for H.264 only. It creates a 320 by 240 format description with a 29-byte `avcC`
  and a decompression session that requires hardware acceleration, then reports whether the session was created. The
  oracle `tests/VideoToolbox/hardware_test.m` checks H.264 against macOS (both report yes), and HEVC and AV1 as no.
- The `kVTProfileLevel_H264_*` constants: the iOS 26.2 SDK and the macOS SDK declare the same 35 names. Those missing from the
  6.1.3 export table are 14, and all 14 are already defined in Backports, so the missing set is empty.

What is open:

- 10-bit refused: 10-bit bi-planar input returns `kVTPixelTransferNotSupportedErr`. macOS converts it, so the oracle asserts
  the refusal rather than a match. Telegram's calls take 8-bit formats.
- Speed: on the host, 1920x1080 NV12 video range BT.709, 100 frames: scalar 33.1 Mpix/s, NEON 234.3 Mpix/s. The A5 is not
  measured. `vImage` has no YUV-to-ARGB conversion in the 6.1.3 export table, so the NEON path is the only fast path.
- sRGB without the buffer's colour attachments: every image is tagged sRGB. A buffer's own colour attachments (primaries,
  transfer function) are not read, only the matrix.
- Hardware: the H.264 check is verified on the host only. The session with the hardware requirement has not been run on an
  A5 device, so the device answer is unknown until it is. HEVC and AV1 report no by design: the A5 has no hardware decoder
  for either, and Telegram asks only about AV1.

## WebKit (`WK*`)

What exists, from `frameworks/Backports/src/WebKit` (14 `WK*` source files):

- `WKWebView` is a `UIView` that owns a `UIWebView`. `WKWebView.m` creates `_web` (line 180) and makes the object a
  `UIWebViewDelegate` (line 119). Navigation is bridged through `WKNavigation` (`revenant_beginNavigation`). The
  demand map counts `WKWebView` as backported.
- The delegate callbacks are sent by selector. `WKWebView.m` checks `respondsToSelector:` and then sends
  `webView:decidePolicyForNavigationAction:decisionHandler:` (lines 399, 630) and
  `webView:didStartProvisionalNavigation:` (line 692). The protocol object itself is not declared (see below).
- The engine under `UIWebView`: `docs/explanation/webkit/architecture.md` ("Two WebKits in one process") records that
  UIKit loads the system WebKit for `UIWebView`, and that the port's substitution replaces the WebKit UIKit loads.
  So a `WKWebView` reaches the revenant engine where that substitution is installed. This is documented, and it was
  not checked on a device in this revision.
- Also present: `WKWebViewConfiguration.m`, `WKNavigation.m`, `WKBackForwardList.m`, `WKUserContentController.m`,
  `WKContentRuleList11.m`, `WKContentWorld14.m`, `WKWebpagePreferences13.m`, `WKWebsiteDataStore.m`, and the
  `WKWebExtension*` family.

What is missing:

- Protocols with no `@protocol` definition in `src`: `WKNavigationDelegate` (8 files), `WKScriptMessageHandler` (7),
  `WKUIDelegate` (4), `WKDownloadDelegate` (2), `WKURLSchemeHandler` (1), `WKURLSchemeTask` (1). The `WKWebExtension*`
  protocols are not in this list: `RevenantWebExtensionController.h` defines `WKWebExtensionControllerDelegate`, and the
  other extension protocols are only forward-declared.
- Classes with no source file: `WKSecurityOrigin` (4 files), `WKWindowFeatures` (4), `WKDownload` (3),
  `WKSnapshotConfiguration` (3), `WKContextMenuElementInfo` (1), `WKOpenPanelParameters` (1).
- Global variables: `WKWebsiteDataTypeFetchCache` and `WKWebsiteDataTypeServiceWorkerRegistrations` (1 file each).

Decisions still open:

- The protocols. Declaring `WKNavigationDelegate` without `WKWebView` sending the callbacks through the protocol would
  let conforming classes compile and then never be told what they need. `WKWebView.m` already sends the two callbacks
  above, so the protocol can be declared with the same selectors. Which other delegate callbacks `WKWebView.m` sends is
  not checked here, and must be before the protocol's method list is written.
- `WKSecurityOrigin`, `WKWindowFeatures`, `WKDownload` and `WKSnapshotConfiguration` need a decision on what the
  `UIWebView` engine can report: an origin, a download and a snapshot are not `UIWebView` features. A loud stub, named in
  the open gaps of `frameworks/Backports/README.md`, is the default if the engine cannot report them.

## Telegram 13.0 members: the crutches left

The members of the Telegram 13.0 series are implemented and lowered, and each has a test. These are the places where a
member stands on something weaker than a host oracle, or on an assumption a device would have to confirm.

- AVFAudio data sources (`src/AVFAudio/AVAudioSessionPortDescription7.m`): no host oracle, because the member is
  `API_UNAVAILABLE(macos)`. The test is a contract check of the SDK declarations and the backport source
  (`tests/ios6_members_test.lua`). The iOS 6 behaviour is not run on a device. It rests on the SDK's `ios(6.0)` annotation
  of `AVAudioSession.inputDataSource`, and on the port answering for the current input only.
- CLGeocoder postal address (`src/CoreLocation/CLGeocoder+PostalAddress11.m`): a contract test only. Geocoding needs the
  network, so there is no offline behavioural oracle. The mapping is the existing `RevenantContacts` one, reached through
  a forward declaration and a link dependency on `ContactsBackports`. The locale is ignored, as in
  `CLGeocoder+PreferredLocale.m`.
- NSTextAttachment attachment bounds (`src/UIKit/NSTextAttachment+Text7.m`): the host test
  (`tests/attachment_bounds_test.lua`) compiles the backport against AppKit. Its shim maps `valueWithCGRect:` and
  `CGRectValue` to the macOS names. The empty attachment is not compared, because AppKit returns a 32 by 32 placeholder
  icon there and the iOS documentation says zero.
- NWPath `usesInterfaceType:` (`src/Network/NWPathMonitor.swift`): the interface comes from the flags and the interface
  names. On macOS the backport takes an interface's type from SystemConfiguration, so a Mac whose `en0` is wired answers wired,
  as the host does. CI's Xcode 26.6 runner is that case; the backport had answered wifi there before. `NWConnection`'s path is the
  default route, not the connection's own route, so a loopback connection reports wifi where Apple reports loopback.
  The Swift code is not built for armv7 here; the swift job builds it.

Lowering of protocol properties: `protocol_status` counts a property member of a protocol as implemented only when a
class that adopts the protocol implements it. Name matches in unrelated classes do not count, so `title` or `length` on
one class does not lower `MKAnnotation` or `MTLBuffer`. Method members keep their name-based rule.

CKContainer in Swift: not reproduced. The typecheck of `CloudData.swift`'s `fetchRawData` body
(`CKContainer.default()`, `database(with:)`, `CKRecord.ID`, `CKError.errorDomain`) passes at `armv7-apple-ios6.1.3`
against the iOS 26.2 SDK with the lowered overlay, against the same SDK with the pre-change overlay, and against the raw
iOS 16.4 SDK. The `CKRecord` blocker in `reference/backports/CloudKit/CKRecord.md` is about the 16.4 generator copy of
the CloudKit headers and the `CKRecord` class, not `CKContainer`. The configuration that loses `CKContainer` is not known
here; a Swift error text and the exact typecheck command are what would settle it.

## Keychain, Photos, VideoToolbox, PassKit and IOSurface: what each item stands on

- `kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly`: the value is `"aku"` on iOS 6, the closest native class, so items
  stored with it are not refused when the device has no passcode, and they are not removed when a passcode is removed
  later. The SDK promises both, and the backport does neither. The host test checks the value against the macOS oracle
  and fails the `"akpu"` value. The refusal is not built, for two reasons this tree cannot settle:
  - The passcode predicate. The 6.1.3 MobileKeyBag exports `MKBGetDeviceLockState` and `MKBDeviceUnlockedSinceBoot`, and
    its strings name no passcode key, so the return code that means "a passcode is set" is not known from the cache. A
    measurement with and without a passcode settles it. On the 6.1.3 emulator without a passcode, the case
    `keybag_lock_state` reads 3 from `MKBGetDeviceLockState` and passes, so 3 means no passcode is set. The value for a
    set passcode is still unmeasured.
  - The call to bind to. An app built with the overlay reaches a backport's `SecItemAdd` only if the Security backport
    defines it, and it defines none. Adding one forwards to the system's `SecItemAdd`, as the IOSurface wrapper does,
    and it is a packaging decision (see `backports-loading.md`). `SecItemUpdate` would need the same check.
  Until both are in, `kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly` is a weaker class than its name, and that is the
  decision to make before Telegram's passcode storage ships on iOS 6.
- `kSecAttrAccessControl` and `SecAccessControlCreateWithFlags`: the value is defined, but the flags are not enforced.
  The constructor returns NULL with `errSecUnimplemented`, so biometric or passcode flags fail loudly. Enforcing
  `kSecUseAuthenticationContext` or an access control at `SecItemAdd`/`SecItemCopyMatching` needs interception of the
  SecItem calls, and the tree has no such layer.
- `kSecUseAuthenticationContext` and `kSecUseDataProtectionKeychain`: the values match macOS. The second is a no-op on iOS 6.
- `kSecAttrAccess` is not backported. The only use in the Telegram 13.0 tree is `PasscodeKeychainScopeTests.swift`, a
  macOS scope test, and the production code uses `kSecAttrAccessGroup`, which iOS 6 has.
- `PHImageManagerMaximumSize`: a typed SDK constant, now lowered and checked against the macOS value.
- `kVTCouldNotFindVideoEncoderErr`: the iOS 26.2 SDK declares it as a plain enum constant (`-12908`) with no availability
  annotation, and the backport already compiles against that declaration. It is not a symbol, so there is nothing to
  backport and no oracle to compare.
- `PKPaymentButton`: a `UIButton` subclass. Its title is the Apple logo (U+F8FF) followed by "Pay", with the type's phrase
  before it. The phrases checked against Apple's documentation are Buy ("Buy with"), InStore ("Pay with"), Support,
  Contribute, Donate, Book, and SetUp ("Set up" followed by Apple Pay, as the HIG shows it). The plain type and the types
  Checkout, Subscribe, Reload, AddMoney, TopUp, Order, Rent, Tip and Continue have no confirmed phrase, so they show the
  logo and "Pay" alone; the phrases for those are open. The SDK headers carry no per-type text. The logo is in the iOS 6.1.3 system font: the 6.1.3 Helvetica Neue file in
  the firmware maps U+F8FF to a glyph, and a control code point maps to none. The default corner radius is 4, Apple's
  default. The white style is a white fill with black text, the outline style adds a 1-point black border, and the black
  style is a black fill with white text. The logo is the only artwork. Telegram shows the button only when `PKPaymentAuthorizationViewController.canMakePayments(usingNetworks:)`
  is true, and both backport implementations answer NO, so the button stays hidden. The iOS 26 selectors ignore
  `disableCardArt`, because the button draws no card art. The contract test checks the SDK header and the source.
- IOSurface: 40 of the SDK's functions are forwarded to the system's private `IOSurface` library, and each one is in the
  iOS 6.1.3 export table. Six component functions and `IOSurfaceGetSubsampling`, `IOSurfaceAllowsPixelSizeCasting` and
  `IOSurfaceSetOwnershipIdentity` are not wrapped, because iOS 6.1.3 does not export them. A wrapper that cannot find a symbol
  aborts with the name. The case `iosurface_surface` runs the host oracle's operations on the 6.1.3 emulator and passes:
  the CoreSurface HLE keeps per-surface attribute values (`SetValue`, `CopyValue`, `RemoveValue`) and the use count
  (`IncrementUseCount`, `DecrementUseCount`, `GetUseCount`, `IsInUse`), and the unit test `surface_attributes` checks the
  list and the count. `xmake emulate` needs the revenant addon, and
  installing `revenant v0.8.17` fails on this host with a package-name mismatch. The in-repo emulate fixtures configure
  the whole package set first, which pulls swift and webkit, and the rules forbid building swift here.
- dyld `__interpose` from a launch-linked dylib: measured on the 6.1.3 emulator, not a fact about iOS 6 in general. The
  probe `interpose_probe.c` is loaded at launch with its `__DATA,__interpose` section present, and it replaces `getppid`.
  The main executable's `getppid()` still returns the real value (11), not the replacement's 4242. So a launch-linked
  tuple does not redirect the main executable's calls on this path, and the SecItemAdd wrapper cannot depend on it. The
  cause is not determined: it could be the main executable's binding, or the emulator's loader. The case
  `interpose_launch` is registered with `should_fail`, so it is reported as an expected failure, and it becomes a failure
  if the redirect starts to work.
- Deferred, not implemented: `MPSImageBilinearScale`. The MPS folder has 100 files and no bilinear scale. `MTLBinaryArchive`
  and `CIRenderDestination` are implemented; their gaps are under "Metal" and "CoreImage" above and below.

## Work queue: the unattempted Telegram modules

The demand scan (`frameworks/Backports/tools/demand.lua`, method in `docs/guides/backports/demand.md`) over the 2,224
source files of the 490 unattempted Telegram 13.0 modules that own sources, against the iOS 6.1.3 cache, with the Swift
runtime given as `--runtime`:

    ./xmakew l -P . frameworks/Backports/tools/demand.lua --report <dir> --files <list of source paths> \
        --runtime <swift-runtime>/lib/swift/iphoneos --ios 6.1.3

The scan now reads the tree as the registry: the lowered member list, the framework folders and the Swift declarations of
`frameworks/Backports/src`, and the objects of the build when there are some. Before that it read only the build's objects,
which this worktree holds for 12 folders, and it counted 145 backported items as missing, among them `Metal`,
`MTLTextureDescriptor`, `PHPhotoLibrary`, `LAContext`, `VNImageRequestHandler`, `MLModel` and `SCNScene`. All of them are
implemented by the tree. The corrected scan has 28 missing SDK items, so the queue is the whole list and not forty items.
Sixteen modules reference at least one of them. Each module is taken from its owning file, which is the longest module
folder that contains the file.

Member gaps: the scan reports none on a receiver of known class. The Objective-C messages with typed receivers are
backported where the tree lowers them, for example `[_wrapperView snapshotViewAfterScreenUpdates:]` (an iOS 7 selector) and
`UIView -setTintColor:`. A Swift member access is a candidate only. Of 1,277 candidate names, 289 are missing: the SDK declares them only on
classes annotated after iOS 6.1.3, and no lowered member has the name. The top names by file count (`max`, `toInt64`,
`after`, `min`) are Swift standard library or app names, so the candidates cannot be attributed to a class, and they are
not in this queue.

`exact` is a syntax-level use. `text` is a name found in the sources without syntax confirmation. The text items are not
each checked against the sources.

Introduced is the SDK's annotation in major version, where a framework row has none.

| Rank | SDK item | Kind | Introduced (iOS) | Level | Modules | Files |
| ---: | --- | --- | ---: | --- | ---: | ---: |
| 1 | `NSTextAttachmentViewProvider` | class | 15.0 | text | 2 | 2 |
| 2 | `kVTCouldNotFindVideoEncoderErr` | enum constant | 26.0 | text | 2 | 2 |
| 3 | `IOSurface` | framework | - | exact | 2 | 2 |
| 4 | `SCNSceneRenderer` | protocol | 8.0 | text | 2 | 3 |
| 5 | `AVCaptureEventInteraction` | class | 17.0 | text | 1 | 1 |
| 6 | `AVPictureInPictureVideoCallViewController` | class | 15.0 | text | 1 | 2 |
| 7 | `CIRenderDestination` | class | 11.0 | text | 1 | 2 |
| 8 | `MPSImageBilinearScale` | class | 11.0 | text | 1 | 1 |
| 9 | `NSTextLayoutFragment` | class | 15.0 | text | 1 | 1 |
| 10 | `NSTextLayoutManager` | class | 15.0 | text | 1 | 1 |
| 11 | `PKPaymentButton` | class | 8.0 | text | 1 | 1 |
| 12 | `VNGenerateForegroundInstanceMaskRequest` | class | 17.0 | text | 1 | 1 |
| 13 | `VNGeneratePersonSegmentationRequest` | class | 15.0 | text | 1 | 1 |
| 14 | `VNInstanceMaskObservation` | class | 17.0 | text | 1 | 1 |
| 15 | `Combine` | framework | - | exact | 1 | 1 |
| 16 | `Translation` | framework | - | exact | 1 | 1 |
| 17 | `PHImageManagerMaximumSize` | global variable | 8.0 | text | 1 | 1 |
| 18 | `kSecAttrAccess` | global variable | 2.0 | text | 1 | 1 |
| 19 | `kSecAttrAccessControl` | global variable | 8.0 | text | 1 | 1 |
| 20 | `kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly` | global variable | 8.0 | text | 1 | 1 |
| 21 | `kSecUseAuthenticationContext` | global variable | 9.0 | text | 1 | 1 |
| 22 | `kSecUseDataProtectionKeychain` | global variable | 13.0 | text | 1 | 3 |
| 23 | `ASAuthorizationControllerPresentationContextProviding` | protocol | 13.0 | text | 1 | 1 |
| 24 | `MTLBinaryArchive` | protocol | 14.0 | text | 1 | 2 |
| 25 | `NSTextLayoutManagerDelegate` | protocol | 15.0 | text | 1 | 1 |
| 26 | `ObservableObject` | swift type | 13.0 | text | 1 | 1 |
| 27 | `Published` | swift type | 13.0 | text | 1 | 1 |
| 28 | `TranslationSession` | swift type | 18.0 | text | 1 | 1 |

Caveats for the queue:

- `kSecAttrAccess` is annotated from iOS 2.0 in the SDK, and the iOS 6.1.3 cache does not export it, so the scan reports it
  missing. It is not checked on a device.
- `Combine` is missing because its source is the upstream package `packages/c/combine`, which xmake fetches, and no
  `--component` library is built here. `Translation`, `TranslationSession` and the iOS 17 classes are not in the tree.
- The `Metal`, `MetalKit`, `MetalPerformanceShaders`, `CoreML` and `SceneKit` rows are now backported by their folders, but
  their protocols and some classes are still missing; those are the rows above, not the framework rows.

## The system-class path of the alias proxies

What exists: the 13 classes of the alias pattern (`REVENANT_ALIAS_STATE` in `frameworks/Backports/src/revenant_alias.h`)
register their public name from the proxy's `+load` where the system has no class, and `attach.c` reparents the proxy to
the system class where it has one. On the 6.1.3 emulator, `alias_public_name` checks that each of the 12 public names is
registered once under its own name, and `alias_system_class` checks that a class of that name present before the loader
is the one `[NSPersonNameComponents class]` answers with, and that Backports registers no second class. Both pass in one
emulator run (`backports_runtime`, four cases, about 175 s).

Open:

- No run on the device. The iPhone 4S on 9.3.6 is the release where NSURLComponents, NSURLQueryItem and
  NSPersonNameComponents collide. No alias case has run on it.
- No iOS 7 to 9 image. `alias_system_class` uses a stand-in `NSPersonNameComponents` that `frameworks/Backports/tests/runtime/probe/system_stand_in.m`
  creates, not the system's class. The emulator's Darwin table maps the build prefixes `10` and `11` (iOS 6 and 7); iOS 8
  and 9 are refused. No iOS 7 firmware was fetched. The first real check is NSURLComponents on iOS 7, and the first
  reparent onto a real system class has not run anywhere.
- The reparent path (`revenant_reparent`) keeps the proxy as a subclass of NSObject and logs when the layouts differ.
  That fallback has not been seen on a real system class.
- `revenant_adopt_methods` adds backport methods to the system class where it lacks them. Whether an adopted method's
  ivar offsets match the system class's layout is not checked on a real system class.
- The `network` package has no prebuilt install or pack path, so consumers build it from source. Its key moved with the
  swift-runtime digest, and nothing is dispatched for it.
- The Network host test compares the Swift Network framework's live path state with the backport's. That state depends on
  the machine's interfaces, so the comparison is limited to deterministic output. The path mapping is checked from fixed
  inputs in `tests/Network/mapping/main.swift` (the host's answers for one recorded state, and documented cases), and the
  live path only against invariants in `tests/Network/live/main.swift`.

## Open, not fixed: a read race in the package store test

`toolchain_light/store_test` failed once on CI (run 40119837571, on the golden-stable branch at 76332140e): a reader
saw an incomplete install in 1 of 308 reads while a forced reinstall replaced it. The cause is not known. The same test
passed in 88 local runs: 18 before the failure, 30 in a plain loop, and 40 under six CPU-bound processes. The reader now
names the first file it failed on, with its text, whether it exists, and the state of the install's link, so the next
occurrence says what it read. The xmake patches 0018 (process exits) and 0019 (lock inodes) do not touch the publish
path of patch 0015, and main's xmake was not run in the loop.
