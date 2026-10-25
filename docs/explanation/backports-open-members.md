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

## Open, not fixed: a read race in the package store test

`toolchain_light/store_test` failed once on CI (run 40119837571, on the golden-stable branch at 76332140e): a reader
saw an incomplete install in 1 of 308 reads while a forced reinstall replaced it. The cause is not known. The same test
passed in 88 local runs: 18 before the failure, 30 in a plain loop, and 40 under six CPU-bound processes. The reader now
names the first file it failed on, with its text, whether it exists, and the state of the install's link, so the next
occurrence says what it read. The xmake patches 0018 (process exits) and 0019 (lock inodes) do not touch the publish
path of patch 0015, and main's xmake was not run in the loop.

## Emulator crutches (exclusive monitor and libdispatch trap)

These are not backport members. They are emulator items from the libdispatch connect investigation on branch
`work/dynarmic-decoder`, written here so that nobody reads an open item as fixed.

Exclusive monitor. Commit `adb67ad64` had two parts, and they were separated:

- Kept: each processor's exclusive state is cleared at the start of each slice and on each SVC. The clear comes from
  XNU's return to user mode: `return_to_user_now` in `osfmk/arm/locore.s` runs `clrex` on every return to user space,
  and a thread that was switched out resumes through it. The copy checked is the `master` mirror at
  `https://gitea.com/matteyeux/darwin-xnu` (line 1922), not the iOS 6.1.3 kernel. The copy has no `clrex` in its
  context-switch routine, so the citation is the return path, not the switch. Cost: one golden boot took 392.8 s on the
  current tree under load; no before number was kept, so the cost of this clear is not measured.
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
  resumed the source a second time, so libdispatch trapped on the over-resume. The trap PC `0x392a2e3c` is in a
  stripped helper at `0x392a2e04`, before `_dispatch_resume` at `0x392a4f94`.
- The fixed probe passes on two and on one core: 20 rounds, 0 connections not writable, and 0 deliveries after cancel.
  Per round the writable events were 32 to 73, and the most for one connection was 3. A writable socket re-arms its
  write source on each handler return, so repeats are expected; no event arrives after the source is cancelled.
- Not done: the emulator does not log kevent returns for an ident. The per-connection counts come from the probe.

Fault dump. `foundation/fault_dump` describes the guest words at a fatal fault: the eight words at each register
that points into mapped memory, and the four words at the address in the first word, with the image and offset of each
word. The unit test `emulator_fault_dump_test` passes, and the fatal-fault path calls it. In the trap runs it printed
no `[fault-words]` lines, although the emulator binary contains the code. The cause is not found, and no dyld-cache
symbol names are printed, so the trap object was read from the probe instead. Open.
