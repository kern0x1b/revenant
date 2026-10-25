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

Decisions still open:

- Render shaders: an offline MSL to GLSL ES translator (a new tool, not in the tree), or a loud refusal of MSL libraries
  at `newLibraryWithSource:`.
- Protocol definitions: hand-written like `QuartzCoreProtocols10.m`, or generated from the SDK header, with the same
  lowering as the methods. The generated form needs the protocol list to come from what the Backports classes conform
  to, which no tool derives yet.

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
- Deferred, not implemented: `MPSImageBilinearScale`, `MTLBinaryArchive` and `CIRenderDestination`. The Metal backport
  renders through GL framebuffers (`RevenantMetalEncoder.m`), and it has 84 files. `glGetProgramBinary` and
  `glProgramBinary` are stubs that report an error (`src/OpenGLES/ES3Functions.m`), so there is no compiled program to
  archive. There is no CoreImage folder, and the MPS folder has 100 files and no bilinear scale.

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

## Selectors Display calls through the delegates

The respondsToSelector check was asked for as a generator change: count a selector that a class sends through
`respondsToSelector:` as a protocol member. Two of Display's errors are the selectors that prompted it, and the probe
on the lowered iOS 6 SDK settles both without that change:

- `scrollViewDidChangeAdjustedContentInset:` on `UIScrollViewDelegate` implements without a diagnostic under
  `-Wunguarded-availability-new -Werror` for `armv7-apple-ios6.0`. The lowered header no longer marks the protocol member,
  so no generator change is needed for it.
- `accessibilityAttributedScrollStatusForScrollView:` on `UIScrollView` is in `lowered-members.txt` and implemented in
  `RevenantIOS11.m`, but the cached overlay the probe reads does not declare it, so the probe reports "no visible
  @interface". Display's error is the Swift declaration's iOS 11 mark, which the UIKit Swift overlay carries, not the ObjC
  header. The fix is in the overlay, not the generator.

Neither probe reaches the Swift compile, and the cached overlay may predate the current member list, so both are
re-checked with the next Display build.

## Open, not fixed: a read race in the package store test

`toolchain_light/store_test` failed once on CI (run 40119837571, on the golden-stable branch at 76332140e): a reader
saw an incomplete install in 1 of 308 reads while a forced reinstall replaced it. The cause is not known. The same test
passed in 88 local runs: 18 before the failure, 30 in a plain loop, and 40 under six CPU-bound processes. The reader now
names the first file it failed on, with its text, whether it exists, and the state of the install's link, so the next
occurrence says what it read. The xmake patches 0018 (process exits) and 0019 (lock inodes) do not touch the publish
path of patch 0015, and main's xmake was not run in the loop.

## baselineOffset on iOS 6: ignored by UIKit string drawing (measured)

The constant `NSBaselineOffsetAttributeName` is in the 6.1.3 image as `_NSBaselineOffsetAttributeName`, and its SDK mark
is lowered in `toolchain/modules/apple/lowered.lua`. The 6.1.3 image exports no CoreText baseline-offset key
(`_kCTBaselineOffsetAttributeName` is absent), while it exports the font, kern, stroke, underline, foreground-colour and
font-feature keys.

Measured with `toolchain/tests/emulate/baseline` (`./xmakew l -P . toolchain/tests/emulate/baseline/baseline.lua iPhone4,1 6.1.3`)
on an iPhone 4S, iOS 6.1.3: "Hxg" at 24 pt drawn with `drawAtPoint:` into a bitmap has the same ink box with and without a
6 pt `NSBaselineOffsetAttributeName` (top 33, bottom 56, left 21, right 62, 390 ink pixels), so the shift is 0. The control,
the plain string drawn 6 points higher, shifts by 6, so the measurement sees a shift. iOS 6 UIKit string drawing ignores the
attribute. The backport now honours it in `drawAtPoint:` (`frameworks/Backports/src/UIKit/NSAttributedString+BaselineOffset7.m`):
the probe with the backport linked shifts the same ink by 6 points (top 33 to 39, 390 ink pixels, `shift=6 ink-equal=1`),
the same as the control. On the host, `frameworks/Backports/tests/baseline_offset_oracle_test.lua` compares the replacement
with macOS's own drawing, which honours the attribute: plain and offset text match pixel for pixel, and an offset that is
not applied is detected. This covers single-line `drawAtPoint:` only. Runs are drawn one by one at their own font's
top, so a mix of fonts in one line is not aligned on a shared baseline, and `drawInRect:` and the layout classes are not
covered yet.

The probe's first runs trapped in `[UIFont systemFontOfSize:]`: ARM exception 8 at 0x311150d4, a `udf #254` in
CoreFoundation's trap stub, which `_CFRuntimeCreateInstance` calls through a callback slot after `_GSFontCreateWithName`
loads a type ID that is still 0. `GSFontGetTypeID()` returned 0 until `GSInitialize()` ran, and then 257. The probe never
ran `GSInitialize`, which `UIApplicationMain` runs in an app. The probe now runs it first.

An app that `UIApplicationMain` launches does not trap. `toolchain/tests/emulate/fontapp` installs one, has SpringBoard
start it on iPhone4,1 6.1.3, and the app's `[UIFont systemFontOfSize:24]` returns a font: its output has `FONT-APP-DONE`
and it exits with status 0. So the emulator needs no change for this trap; the trap is the precondition the probe skipped.
No device daemon was run to compare. The launch took a long boot under load: SpringBoard checked in 570 to 800 host
seconds after boot at a load of about 100, so `launch` needs `-s` and `-t` raised on a busy machine.

## Emulate cases are not in `./xmakew test -P .`

The emulate cases under `toolchain/tests/emulate/` (`install`, `launchd`, `output`, `pin-leak`, `baseline`, `fontapp`) run
by hand, as `docs/reference/toolchain/tests.md` says, and are not xmake tests. Registering them in `./xmakew test -P .` is a
separate job: each needs a booted firmware image for minutes, so the registration has to say which device and release it
boots and where a CI slot for it comes from. Until then the cases are the record of what the emulator is checked against.
## Emulator crutches (exclusive monitor and libdispatch trap)

These are not backport members. They are emulator items from the libdispatch connect investigation on branch
`work/dynarmic-decoder`, written here so that nobody reads an open item as fixed.

Exclusive monitor. Commit `adb67ad64` had two parts, and they were separated:

- Kept: each processor's exclusive state is cleared at the start of each slice and on each SVC. The clear comes from
  XNU's return to user mode: `return_to_user_now` in `osfmk/arm/locore.s` runs `clrex` on every return to user space,
  and a thread that was switched out resumes through it. The copy checked is the `master` mirror at
  `https://gitea.com/matteyeux/darwin-xnu` (line 1922), not the iOS 6.1.3 kernel. The copy has no `clrex` in its
  context-switch routine, so the citation is the return path, not the switch. Cost: a counter on the clear path and the
  process's CPU time over the same golden boot, three repeats each with and without the clear (the switch was a
  temporary variable, not committed). The boots made 0.63 to 0.80 million clears (per slice and per SVC). CPU time,
  user plus system, with the clear: 420.6, 367.3 and 402.8 s, mean 396.9. Without it: 353.8, 408.1 and 391.5 s, mean
  384.5. The difference, 12.4 s or 3.2%, has a standard error near 22 s, so it is not distinguishable from noise. The
  wall times ran 372 to 487 s with the host at load 13 on 12 cores, so they do not isolate the clear. One no-clear
  boot printed no counter line; the other two no-clear boots skipped every clear.
- Reverted: the write generation check and the write tracking on reserved pages. The commit's premise was that the
  resolver-backed monitor does not see plain writes. On the tree before that change, a pinned store probe shows the
  premise false for two or more processors: with the other thread storing to the reserved word, 2000 of 2000 rounds had
  the store-exclusive fail (0 leaked); with the store removed as a negative control, 1989 of 2000 succeeded. The reason
  is in the shared memory: with more than one processor `AddressSpace::set_parallel_access(true)` is on, so every write
  goes through `reservation_invalidation_required_locked` and `invalidate_reservation_identity`, and the reservation key
  is that identity. The commit stays in history to restore it, but nothing in this tree needs it. Its write-tracking
  cost was therefore not measured.

Crutches that remain:

- The pin: under `--test-concurrent-threads`, each thread is bound with `bind_thread` to its slot modulo the core count
  at registration. Placement is not logged, so the pinned result rests on that code path, not on a logged placement.
- Only one and two cores were run.
- The store probe's strex fails in every concurrent round by design, because the writer stores each round. The
  negative control is what shows that the failures come from the store.

Libdispatch trap. Resolved as a probe fault, not an emulator fault.

- The trapping object is `writes[0]` of `emulator/tests/guest/connect_writable_dispatch.c`. The fatal `r0` equals its
  address in every trap run.
- Class: its first word is the vtable at `0x3ae41ec4` in libdispatch's `__DATA`. Its `do_type` is `0x00020001` and its
  `do_kind` is `"kevent-source"`, which is `DISPATCH_SOURCE_KEVENT_TYPE` in `src/object_internal.h` of libdispatch-228.23.
- Type: the kevent behind `ds_dkev` (`ds_dkev` is at offset 64 of `dispatch_source_s`) has ident 11, the probe's
  descriptor, filter -2 (`EVFILT_WRITE`), and flags `0x85` (`EV_ADD|EV_ENABLE|EV_DISPATCH`). The source is a write
  source.
- State at the trap: `do_suspend_cnt` (offset 28) is 1, the locked bit with a count of zero. The probe's cleanup
  resumed the source a second time, so libdispatch trapped on the over-resume. The trap PC `0x392a2e3c` is in
  `_dispatch_resume$VARIANT$up` (`+0x3a`), the copy of `_dispatch_resume` at `0x392a2e04`. That is not the exported
  `_dispatch_resume` at `0x392a4f94`; the earlier note that called it a stripped helper was a symbol-table gap, closed
  by the local-symbol reader.
- The fixed probe passes on two and on one core: 20 rounds, 0 connections not writable, and 0 deliveries after cancel.
  Per round the writable events were 32 to 73, and the most for one connection was 3. A writable socket re-arms its
  write source on each handler return, so repeats are expected; no event arrives after the source is cancelled.
- Not done: the emulator does not log kevent returns for an ident. The per-connection counts come from the probe.

Fault dump. `foundation/fault_dump` describes the guest words at a fatal fault: the eight words at each register
that points into mapped memory, and the four words at the address in the first word, with the image and offset of each
word. The unit test `emulator_fault_dump_test` passes. The first trap runs printed no `[fault-words]` lines because the
concise output filter drops every bracketed line that is not on its allowlist, and this prefix was not on it. With the
prefix added, the forced libdispatch fault on one core logs the words: `r0` points at the trapping object, whose first
word is the vtable, labelled `libdispatch.dylib`__dispatch_source_vtable`. Each word that lands in a dyld cache image
is labelled with the image and the nearest symbol at or below it in the section that holds it, as `image`symbol+0xNN`.
The lookup finds the image from its segments, so data such as a vtable is labelled too. The trap PC is labelled
`libdispatch.dylib`_dispatch_resume$VARIANT$up+0x3a`. The exports come from the image's own symbol table, and the
locals from the cache's local-symbol region, so no export-trie reader was needed. A word with no symbol in its section
below it keeps the image and offset from the guest's image table. Named symbols are nearest-below, not sized, so a
label with a large offset means the section has no closer symbol, not that the word belongs to that symbol.
