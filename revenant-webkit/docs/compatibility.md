# The compatibility layer, and the rule it answers to

A 2026 engine calls API that a 2012 system does not have. Around three thousand
lines in `compat/` stand in for it, and one rule governs all of them:

> **No stub may answer success while doing nothing.** Where the behaviour exists
> on this system — or existed in WebKit's own history — the real implementation
> is used instead of a bridge. Where it genuinely does not exist, the shim says
> so, in the log or by failing.

The rule is not stylistic. A shim that returns zero, `nil` or `noErr` cannot be
found by a crash, a backtrace or a test that passes; it moves the failure
somewhere else and takes the evidence with it. Every entry under *What the audit
found* below was that shape.

## What is in `compat/`

| File | Stands in for |
| --- | --- |
| `ios6_compat.c` | libSystem, Security and CommonCrypto entry points added after iOS 6: the POSIX 2008 `*at` family, `mkostemp`, `CCRandomGenerateBytes`, newer mach clocks, `SecTrust*`, `_CFHostIsDomainTopLevel` |
| `ios6_coretext.c` | CoreText the engine lays text out through: CSS generic families, font fallback coverage, the shaping entry point |
| `ios6_coregraphics.c` | CoreGraphics drawing calls: per-corner radii, the "squircle" corner, conic gradients, an IOSurface image reference |
| `ios6_missing.c` | Functions with no equivalent at all. Each reports itself once and returns zero, so anything actually reached shows up in the log |
| `ios6_missing_classes.m` | Classes dyld has to bind at load time. They carry no behaviour; reaching one means a code path needs guarding |
| `ios6_missing_constants.c` | Constants, with the system's own value where it is known and a distinctly named `CFString` where it is not, so a dictionary lookup misses rather than crashes |
| `ios6_palswift.m` | Objective-C replacements for PAL's Swift sources — `swiftc` has no armv7 target |
| `ios6_media_stubs.cpp` | The AVFoundation media engine, which is not built for this port: `registerMediaEngine` doing nothing is exactly right, because there is no engine to register |
| `ios6_uicolor.m`, `ios6_uttype.m`, `ios6_avaudio.m` | Single methods added after this release |

Definitions live here rather than as dynamic lookups so that the static linker
resolves them locally instead of recording an import dyld cannot satisfy on the
device. The archive is built from a named list rather than an `ios6_*.o` glob:
the glob kept a retired bridge's stale objects as members long after its sources
were deleted.

`compat/stubs/` is the other half: headers that close the gap between the iOS
16.4 SDK this port compiles against and what WebKit trunk expects. Almost all of
it is declarations for constants and enum values from releases after it that the
engine only ever compares against — codec identifiers, pixel formats — plus the
SPI headers iOS ships no headers for at all. A constant the SDK declares but iOS
6 does not export is defined in `compat/ios6_missing_constants.c` instead, so
the image binds it to itself rather than weakly to NULL. Two of them are not
declarations:

- **`thread_local` does not compile for this deployment target.** Mach-O
  thread-local storage needs dyld support that arrived in iOS 9, so a small
  pthread-key stand-in serves the values that fit in a pointer slot, with the
  key created on first use so nothing needs a static constructor.
- **`VM_FLAGS_PERMANENT` is not honoured by this kernel**, and passing it makes
  `mach_vm_map` fail. It is zero here, which makes the mapping an ordinary one.

### Fill-ins must not be exported

Several CoreText fill-ins share names with functions the system CoreText also
exports — `CTFontDescriptorCreateForUIType`, `CTFontShapeGlyphs`. Exported from
WebCore under a flat namespace they **interpose the system ones for the whole
process**: UIKit resolves the system font through
`CTFontDescriptorCreateForUIType`, so it starts running the port's version, and
every `UILabel`, text field and the status bar clock renders blank while
WebKit's own text still works. Hiding them keeps WebCore using them internally
without shadowing the process's CoreText.

The same class of trap, from the other end: a constant declared as data must be
defined as data. `NSProcessInfoPowerStateDidChangeNotification` as a function
stub links, and then the address of the stub is used as a string —
`CFXNotificationRegisterObserver` received a garbage name and crashed.

## What the audit found

Each of these was a shim answering success. Each is fixed, and each was verified
on the device.

- **`vDSP_vaddi` returned zero and wrote nothing to its destination**, so mixing
  32-bit integer samples in the capture ring buffer silently dropped a channel.
- **`sqlite3_bind_blob64` answered `SQLITE_OK` and bound nothing** — the shape
  that once made `localStorage` save nothing. Removed rather than implemented:
  the call site binds through `sqlite3_bind_blob` on this release, and if
  anything reaches for it again the link will say so.
- **`kCTFontWeight*` and `kCTFontWidth*` were `CFString`s where the headers
  declare `CGFloat`.** The linker matches by name, so every rung of the weight
  ladder was a pointer read as a float and every `-apple-system` request
  resolved at Regular.
- **`kCTFontVariationAxesAttribute` was `#define`d to
  `kCTFontVariationAttribute`** — an array read out of a dictionary, on every
  `@font-face` load. The port reads no variation axes at all now, which is the
  truth about this CoreText.
- **`CTFontCopyColorGlyphCoverage` returning null was read as "this font has no
  colour glyphs"** rather than "not known". A font declaring the colour trait is
  taken at its word, which is what WebKit itself did until that query became
  unconditional in 2025.
- **`SecTrustGetTrustResult` and `SecTrustEvaluateWithError` were stubs.** They
  are the accept/reject decision for every WebSocket connection and for
  `ResourceResponseCocoa.mm`'s certificate metadata, so the trust evaluation
  never ran. Both are implemented in terms of `SecTrustEvaluate`, present since
  iOS 2. See [network.md](network.md).
- **A conic gradient cast every parameter to void and made no paint call**, so a
  site's `conic-gradient()` background came out fully transparent instead of the
  documented fallback. It now fills with the gradient's first stop, read back
  from the gradient itself: `CGGradientRef` has no accessor for its stops, so
  one pixel is rendered off-screen inside the region
  `kCGGradientDrawsBeforeStartLocation` defines as a flat fill of the colour at
  location 0.
- **`-[NSDateComponentsFormatter stringFromTimeInterval:]` was missing entirely
  while its properties worked**, being auto-synthesized from Foundation's own
  `@interface`. WebKit's media accessibility text set them and then called the
  method, got an unrecognized selector, and the process died on real playback —
  `WebKit discarding exception` only catches what the guard block is still
  inside when the throw happens.

## WebKitLegacy's own compatibility API

`WebLegacyCompatibilityAPI.mm` is the other half of the same rule: methods the
system's UIKit and Safari call on `WebView` and `WebFrame`, which upstream left
as empty bodies when the API stopped being used on the Mac. Fourteen of them are
now real, routed through exported `Page`, `Editor` and `PrintContext` calls
rather than reimplemented:

- memory pressure — `discardAllCompiledCode`, `releaseFastMallocMemory`,
  `_clearBackForwardCache`, `_setMinimumTimerInterval:`, all of which this
  project actively tunes
- copy and serialize — `_markupStringFromRange:nodes:`,
  `_stringWithDocumentTypeStringAndMarkupString:`
- the AirPrint page-geometry group — `isPageBoxVisible:`,
  `pageNumberForElement::`, `pageProperty::`, `pageSizeAndMarginsInPixels:`
- animation — `_suspendAnimations`, `_resumeAnimations`,
  `cssAnimationsSuspended`

Two more sat in the injected dylib and reported invented numbers:
`MemoryMeasure::taskMemory()` returned zero, and `systemTotalMemory()` had
512 MB written into it. Both read the device now, through `task_info` and
`sysctlbyname("hw.memsize")`.

## What is deliberately empty, and why

| Shim | Answer | Why that is the honest answer |
| --- | --- | --- |
| `CTFontCopyGlyphCoverageForFeature` | null | Small caps are synthesized. No native path ever existed; upstream's own `#else` hardcodes the same answer |
| `CTFontDescriptorCreateWithTextStyle` | Helvetica, one size | Dynamic Type is iOS 7. This system has two fixed interface sizes and no style scale, and shipping Apple's per-style table would invent data the system does not have |
| `CTFontGetSbixImageSizeForGlyphAndContentsScale` | 0 | Its only consumer is behind `isInGPUProcess()`, and WebKit1 has no GPU process |
| `CTFontShapeGlyphs` | horizontal metrics only | Real shaping arrived in iOS 17. It is not reached — `Font::applyTransforms` returns early and complex text goes through `CTTypesetter`, which is real shaping — but the call site is still compiled in, and filling in bulk advances would overwrite the deliberate zero advances the engine sets for a zero-width glyph |
| `CGContextAddSquircleRect` and kin | ordinary rounded rect | Which is what every corner on this system looked like anyway |
| `+[LSAppLink openWithURL:…]` | "no app link" | No app-link resolver exists on this system to ask. The honest "no" is what makes the caller open the link in the browser itself, rather than a crash from an unimplemented class method |
| `+[WebView _allowCookies]`, `currentCFHTTPCookieStorage()` | `YES`, `0` | Untouched on purpose: the real backing exists, and changing the cookie-accept policy risks the logged-in sessions this port is used with. WebCore uses its own default behind the null |
| `-_touchEventRegions` | `nil` | Measured on the device: reporting a region made UIKit deliver neither mouse nor touch events |
| `RenderLayerCompositor::allowBackingStoreDetachingForFixedPosition` | `false` | `WebChromeClientIOS::updateViewportConstrainedLayers` moves fixed layers on every scroll frame, while the engine's estimate of where they are comes from the last layout, which is rare here. Once the two diverge the engine takes the header and footer for off screen and drops their backing store: the layers stay in place and paint empty. Keeping them costs about 145 KB for a typical header and footer at 320 points |
| `+drainLayerPool` | `{}` | `LayerPool::drain()` exists and was deliberately reverted once — it caused live fixed-bar jitter. Not to be re-enabled without a live re-test |
| `_addVisitedLinksToPageGroup:` | `{}` | The bulk seed only. Per-URL visit recording and `:visited` styling already work through `_visitedURL:withTitle:`, which is real |
| DumpRenderTree, NPAPI, AppCache, remote inspector, `WebHTMLView`'s AppKit category, every `finalize` | `{}` | The feature is genuinely gone from 2.54, or is Mac-only, or is GC-only under manual retain/release. Empty is correct |

## Still open

- `-[WebFrame imageForNode:…]` returns `nullptr`. The backing exists
  (`WebCore::snapshotNode`) but needs an `ImageBuffer`→`CGImageRef` bridge with
  careful ownership, and it is only exercised by node-image drag and share.
- The cookie pair above, which needs a device session to verify against.
- `WebFixedPositionContent`'s `lockLayers`/`addOrUpdateLayer:` family is
  vestigial — superseded by `WebChromeClientIOS::updateViewportConstrainedLayers`
  — and should be deleted once nothing is confirmed to call the old names.
- `_smartDeleteRangeForProposedRange:` returns its input, so there is no smart
  delete. Real `Editor` backing exists, but this touches the live field editor
  in the address bar, where a wrong range over-deletes.
- **Subnormal doubles are flushed to zero.** `0 < Number.MIN_VALUE` answers
  false here, and `5e-324 * 2` is 0: the VFP unit runs with FPSCR.FZ set, so
  every denormal result becomes zero. This is the platform's default and not
  something the engine chose - the shipping fork answers the same - and it is a
  real deviation from the language, which has no flush-to-zero. Clearing FZ per
  thread would fix the semantics and hand every denormal operation to the
  support code path instead of the hardware, so it is a trade to measure before
  it is made rather than an oversight. Found by JSC's own
  `JSTests/stress/big-int-less-than-general.js`, which compares `0n` against
  `Number.MIN_VALUE`.
- **`new WebAssembly.Instance(module)` throws.** WebAssembly here is the wasm3
  interpreter behind `platform/safari/RevWasm.m`. Its bootstrap answers
  `validate`, `compile`, `instantiate` and the synchronous `new
  WebAssembly.Module(bytes)`, but exports a stub for the synchronous `Instance`
  constructor that throws `sync Instance unsupported`, although a working
  `Instance` is defined in the same `kRevWasmBootstrap`. A page that
  instantiates synchronously fails until the export is switched to it.
- **`mix-blend-mode: hue | saturation | color | luminosity` on an element is
  drawn unblended**, while the separable modes are exact and all four are
  exact through a canvas (`tests/device/gradients-and-blends.html`). The
  element is not composited; the tile Safari paints into is not a bitmap
  context, and this CoreGraphics drops the non-separable modes there. The
  measurements and the one attempt not to repeat are in `tests/device/README.md`.

## Soft-linked constants

PAL soft-links constants and asserts when `dlsym` returns nothing. On a current
OS that is right: an absent constant means a broken install. On iOS 6 absence is
normal — the constant is missing because the feature it names was invented
later — so every one of them is a crash waiting for the first page that reaches
it, and chasing them one backtrace at a time never ends.

`tools/probe-soft-links.py` generates a probe that asks the device about all of
them at once. Run on the iPhone 4S (iOS 6.1.3):

    present 140   missing 135

Missing, by framework:

| framework | missing |
|---|---|
| AVFoundation | 70 |
| CoreMedia | 58 |
| UIKit | 4 |
| DataDetectorsUI | 3 |

Absent entirely, so every constant in them is missing: AppSSO, Contacts,
CoreMaterial, PassKitCore, ScreenCaptureKit, Vision, WebPrivacy.

Almost all of the 135 are capture-device, DRM or HLS names that an ordinary page
load never reaches, and this port already reports "AVFoundation media engine is
not available", which removes most of the rest. The ones that actually fired:

- `AVSystemController_ServerConnectionDiedNotification` and
  `AVSystemController_PIDToInheritApplicationStateFrom` (MediaExperience, a
  framework that postdates this OS by years) — reached from
  `MediaSessionHelperIOS` when a script touches a media element's `muted`.
  Guarded by turning off `HAVE_MEDIAEXPERIENCE_AVSYSTEMCONTROLLER`, whose two
  use sites were already written to expect it.
- `AVAudioSessionPortCarAudio` (CarPlay, iOS 7) — reached from
  `MediaSessionHelperIOS::updateCarPlayIsConnected()`, which had no guard at
  all. Added `HAVE_AVAUDIOSESSION_CARAUDIO_PORT`.

One is avoided by construction. The camera source for `getUserMedia`
(`RevCameraSource::deliverSampleBuffer` in
`WebCore/platform/mediastream/rev/RevCameraCaptureSource.mm`) hands
`VideoFrameCV::create` an explicit, empty colour space. The overload without
one computes the space from the buffer's attachments by comparing them with
soft-linked CoreMedia constants (DCI-P3, P3-D65, BT.2020) that iOS 6 does not
export, so it would assert on the first frame.

The assert in `WTF/wtf/cocoa/SoftLinking.h` now names the symbol and its
framework, so the next one is a one-line diagnosis rather than a backtrace to
decode: it used to report only `dlerror()`, which is empty here.

Re-run the probe after any engine update — the list grows as WebKit adds
soft-links.

## Cookie API

Every private cookie entry point the engine reaches for is absent on this
Foundation, and every public equivalent is present.

| absent | the public thing that does the same job |
|---|---|
| `-_setCookies:forURL:mainDocumentURL:policyProperties:` | `-setCookies:forURL:mainDocumentURL:` |
| `-_getCookiesForURL:…partition:policyProperties:…` | `-cookiesForURL:` |
| `+_cookieForSetCookieString:forURL:partition:` | `+cookiesWithResponseHeaderFields:forURL:` |
| `-_initWithCFHTTPCookieStorage:` | there is one storage; it is the shared one |
| `-_getCookiesForDomain:`, `-_getCookiesForPartition:` | `-cookiesForURL:`; partitions do not exist here |
| `-_saveCookies:` | CFNetwork writes the jar itself on this release |
| `-_setCookiesChangedHandler:onQueue:` and kin | `NSHTTPCookieManagerCookiesChangedNotification` |
| `-_storagePartition`, `-sameSitePolicy` | neither concept exists on this CFNetwork |
| `-removeCookiesSinceDate:` | nothing; iOS 8 API, and the caller already probes for it |

Present, and so needing no work: `-_cookieStorage`, `+_cf2nsCookies:`,
`-_GetInternalCFHTTPCookie`, `CFHTTPCookieStorageCopyCookies`,
`CFHTTPCookieStorageDeleteAllCookies`.

Two behaviours settled by measurement rather than by reading:

- `+cookieWithProperties:` **accepts** the non-public keys WebKit puts in —
  `Created`, `HttpOnly`, `SameSite` — so `createNSHTTPCookie()` works.
- `NSHTTPCookieManagerCookiesChangedNotification` **fires** on this release.
  `CookieStorageObserver` therefore has a real signal.

Why this mattered: WebKit wraps these calls in exception guards, so every one of
them failed *silently*. `document.cookie = "x=y"` read back as empty and nothing
in any log said why.

## AVAudioSession

`AudioSessionIOS.mm` is reached the moment a page has a media element, which on
threads.com and instagram.com is immediately.

| absent | what this release has instead |
|---|---|
| `-maximumOutputNumberOfChannels` (iOS 7) | `-outputNumberOfChannels`; on a device whose outputs are a speaker, a jack and Bluetooth that is also the maximum |
| `-setCategory:mode:routeSharingPolicy:options:error:` (iOS 11) | `-setCategory:withOptions:error:` then `-setMode:error:` |
| `-routeSharingPolicy` (iOS 11) | the concept does not exist |
| `-routingContextUID` | the concept does not exist |
| `-setHostProcessAttribution:` | already behind `ENABLE(APP_PRIVACY_REPORT)` |
| `-setPreferredOutputNumberOfChannels:error:` | not used on the paths we reach |
| `-secondaryAudioShouldBeSilencedHint` | not used on the paths we reach |

Present: `-category`, `-mode`, `-categoryOptions`, `-setCategory:withOptions:error:`,
`-setCategory:error:`, `-setMode:error:`, `-setActive:error:`, `-sampleRate`,
`-outputNumberOfChannels`, `-outputLatency`, `-IOBufferDuration`,
`-preferredIOBufferDuration`, `-setPreferredIOBufferDuration:error:`,
`-setPreferredSampleRate:error:`, `-currentRoute`, `-outputVolume`,
`-isOtherAudioPlaying`, `-currentHardwareOutputNumberOfChannels`,
`-currentHardwareSampleRate`.

## Related

- [architecture.md](architecture.md) — how the engine is loaded in place of the system one
- [network.md](network.md) — the TLS and HTTP layers, and why trust may never be a stub
- [tools.md](tools.md) — the probes that produced the numbers above
