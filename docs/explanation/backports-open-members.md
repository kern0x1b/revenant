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

## Emulate cases are not in `./xmakew test`

The emulate cases under `toolchain/tests/emulate/` (`install`, `launchd`, `output`, `pin-leak`, `baseline`, `fontapp`) run
by hand, as `docs/reference/toolchain/tests.md` says, and are not xmake tests. Registering them in `./xmakew test` is a
separate job: each needs a booted firmware image for minutes, so the registration has to say which device and release it
boots and where a CI slot for it comes from. Until then the cases are the record of what the emulator is checked against.
