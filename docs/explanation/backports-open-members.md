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
  names. On a Mac whose `en0` is wired, the host answers wired and the backport answers wifi. `NWConnection`'s path is the
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
