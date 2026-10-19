# Changelog

All notable changes to this project are recorded here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Dates are the day the change was measured on the device, not the day it compiled.

## [Unreleased]

### Fixed
- **A crash at load that had not happened yet.** Taking the engine branch's 97
  newest commits rolled ANGLE forward, and the new ANGLE calls `crc32_z` - a
  zlib function from 1.2.9, in 2016. This system ships zlib 1.2.5, so the
  frameworks would have been refused at load: no crash log, no output, a browser
  that simply does not start. The compatibility library implements it now,
  table-driven and self-contained, checked against the standard
  `crc32("123456789") == 0xcbf43926`. It was caught before deploying by a new
  gate that records every symbol the frameworks leave undefined and fails when
  the set grows.
- **A missing include in the 32-bit DFG.** `DFGSpeculativeJIT32_64.cpp` used
  `JSSet::offsetOfStorage()` without including `JSSet.h`. The device build never
  noticed, because it compiles that file inside a unified source that happens to
  include the header; a standalone 32-bit build does not.
- **The engine is level with its branch again.** First the five newest picks,
  then the 97 that a stale mirror had hidden - the fork's copy of
  `webkitglib/2.54` was that far behind upstream's. Two files conflicted, both
  in WTF's locks, where upstream replaced hand-rolled spin counters with a
  `SpinBackoff` helper and this port's measured iOS 6 spin policy now sits beside
  it under the guard rather than instead of it. The five picks brought the
  snapshot to `305413.1005@safari-7624.5.1.10-branch`. The roll moved ANGLE,
  which is where this port's GL backend lives, so WebGL was re-checked against
  the Khronos suite on the device: 573 framebuffer-attachment checks still
  pass, and the only failures are the two this port already attributes to the
  GPU - face culling into an IOSurface-backed attachment, and NPOT cube maps. Two are use-after-free
  fixes on paths this port actually runs: `ShareDataReader` held a raw `this`
  in the blob loader's completion handler, so a share whose document went away
  finished into freed memory, and `Attr::setValue` passed an unprotected
  `contextDocument()` into the trusted-types check, which an iframe removed
  during the call could free. The other three are B3, ANGLE's Metal shader
  translator and WebKit2's back-forward list, none of which reach the device.
  None of the five touched a file this port has changed.
- **Pages that stopped dead at their first inline script.** A documentation site
  rendered a white page: the script reads `localStorage`, which blocks the web
  thread until the storage import finishes, and the import could not finish
  because SQLite's one-time initialization hops to the main thread - which, in
  WebKitLegacy, *is* the web thread. Three threads deadlocked. SQLite is now
  initialized on the calling thread, as every non-Darwin port already does; the
  main-thread hop exists for a Network process this port does not have. It looked
  intermittent because it depends on which thread opens a database first: an
  origin that already has a storage file on disk loses the race every time.
- **Every site behind an AWS WAF challenge.** `window.WebAssembly` was installed
  by swizzling whichever class the runtime happened to list first as answering the
  window-object-cleared delegate method, so it was present only sometimes. The
  challenge needs WebAssembly, retries without it, and gives up, leaving one
  sentence about attempts exceeded where the page should be. The engine now offers a
  registration point for an embedder that is not the frame load delegate, and the
  bridge uses it.
- **A user agent no browser has ever sent.** The browser names itself after the
  engine it shipped with in 2012, so the string paired `AppleWebKit/605.1.15` with
  `Version/6.0 Safari/8536.25`. Sites branch on those tokens and were serving this
  engine the workarounds written for the one it replaced. It now reports
  `Version/18.7 Mobile/15E148 Safari/604.1`, consistent with the frozen OS version
  beside it.
- **Translucent bars that smeared on sites using the modern spelling.** This port
  drops backdrop filters and makes the element's background opaque instead, but
  only the prefixed property reached that rule; `backdrop-filter` unprefixed is
  behind a setting that was off, so a site declaring only the standard spelling
  got the smearing bar the rule exists to prevent.
- **Copying a selection took the browser down.** Long-press, Copy, and the
  process aborted with `-[__NSCFType fontWithSize:]: unrecognized selector`.
  UIFont and CTFont were unified in iOS 7; on this release they are separate
  classes, and the converter that builds what goes on the pasteboard handed
  UIKit a CTFontRef. Select, Copy and Paste complete now.
- **A crash handler that printed nothing for stack overflows.** The handler had no
  stack of its own, so the class of crash that exhausts the stack killed the
  process silently. It runs on an alternate stack now.

### Added
- **WebGL.** A canvas gets a real GL context on a GPU from 2011: shaders compile
  and the GPU draws, checked on the device by five tests rather than by eye. The
  only GL backend upstream ships for this platform goes through ANGLE's Metal
  renderer and Metal needs an A7, so the port carries an ANGLE backend on EAGL -
  `DisplayEAGL`, `PbufferSurfaceEAGL`, `IOSurfaceSurfaceEAGL`, `DeviceEAGL` -
  with ANGLE built for armv7 for the first time, and WebCore's IOSurface support
  turned on to carry the pixels to the compositor. Getting those pixels onto the
  screen took two more things: the canvas is prepared before WebKitLegacy flushes
  its layers, because those are two schedulers here and the flush went first, so
  the layer was always shown before the frame existed; and the layer is given a
  `CGImage` over the surface rather than the surface itself, which this release's
  CoreAnimation accepts and never draws. `tests/device/gl-present.sh` reads the
  colour off the screen. WebGL 2.0 stays out of reach: it needs OpenGL ES 3.0 and
  this silicon is ES 2.0. See `docs/webgl.md`.
- **A WebGL context asked for without alpha.** `getContext("webgl", {alpha:false})`
  lost its context on creation: WebKit asks for `GL_RGB` as the surface's
  internal format and this backend accepted only BGRA and RGBA. It is served
  from the same BGRA surface now, with the alpha answered as opaque - swizzled
  away when sampling and cleared once in the surface itself - which is what the
  CGL backend does. Found by Khronos' conformance suite, which now runs on the
  device through `tests/device/conformance.sh`: 2236 of its checks pass over the
  areas run so far. The two failures left are the driver's, and each has a probe
  that says so with no ANGLE and no WebKit in the way: this GPU does not sample
  non-power-of-two cube maps at all, and it ignores face culling when the colour
  attachment is a texture made from an IOSurface - which is what a canvas draws
  into here. `docs/webgl.md` has both, and what conformant culling would cost.
- **WebGL that animates, rather than drawing one frame.** A page that redrew in
  `requestAnimationFrame` froze the web thread after its first frame - no timers,
  no callbacks, no crash. `CVOpenGLESTextureCache` requires a flush to let go of
  the textures it hands out, and this backend never called one, so every
  IOSurface stayed referenced, `IOSurfaceIsInUse` never went false, and WebKit
  threw the drawing buffer away and built a new one every frame. The surface now
  releases its texture and flushes the cache when the image is released. A
  spinning triangle runs at **29 fps at 64x64, 30 at 320x240 and 28 at 320x480** -
  the rate barely moves with the canvas, so what it costs is per frame, not per
  pixel. `tests/device/gl-frame-rate.sh` is the check that would have caught the
  freeze, which every single-frame check in the suite missed.
- **Blank labels under the system activities in the share sheet.** The cause was
  the measurement, not the drawing: this port's `UIStringDrawing` answered a
  string's typographic bounds as its line height - `ceil(ascent) + ceil(descent)
  + ceil(leading)`, which is 13 for Helvetica 12 - where UIKit wanted the font's
  own `lineHeight` of 15. `-[UIActivityButton titleRectForContentRect:]` counts
  a title's lines as `floor(measured / lineHeight)`, so a single-line title
  measured at 13 gave zero lines and a label frame of zero height. Safari's own
  two-line activities measured tall enough, which is why only the system
  single-line ones were blank. A `UIFont` is now asked for its own line height;
  raw `CTFont`s, which is what web content uses, keep the typographic height, so
  page layout is unchanged.
- **`navigator.share`.** A page can hand a title, a text and a URL to the system
  share sheet, and the promise settles the way the specification says: it
  resolves when an activity ran and rejects with `AbortError` when the sheet is
  cancelled. The setting was off because nothing implemented the client side of
  it; the implementation belongs to `WebChromeClientIOS`, which is the concrete
  chrome client on this platform - the base class's empty one is never called.
  The sheet is presented on the main thread and the answer comes back on the web
  thread, which are two different threads in WebKitLegacy.
  `tests/device/share-sheet.sh` taps the button and then Cancel and checks both.
- **A page console that can be turned on from Settings.** RevWebKit gains a
  Diagnostics switch that routes what a page logs - including its uncaught errors -
  to `/tmp/rev-safari-stderr.log` with file and line. Reading a site's JavaScript
  failure used to mean rebuilding the engine with a preference flipped.
- **The asynchronous clipboard.** `navigator.clipboard.writeText` works: the
  write path used NSItemProvider and `-[UIPasteboard setItemProviders:]`, both
  iOS 11, so it crashed; it now writes an item dictionary through
  `-[UIPasteboard setItems:]` with the types mapped to uniform type identifiers,
  which is what makes a copy visible to the rest of the phone. Reading still
  rejects with `NotAllowedError`, as the specification asks for without a paste
  gesture. Copy buttons work.
- **A platform report card and a real-site sweep.** `tests/device/web-platform.html`
  checks the APIs a page written this decade reaches for, and `tests/device/sweep.sh`
  loads real sites and reports whether each survived, painted, and what it held in
  memory. Both exist because the WebAssembly failure above was invisible to a suite
  that only checks numbers it produces itself.
- **WebP, which was being asked for and could not be read.** The image Accept
  header offered WebP, AVIF, JPEG-XL and HEIC ahead of everything else, and ImageIO
  here decodes none of them - WebP arrived in it with iOS 14, AVIF with iOS 16,
  JPEG-XL never shipped, HEIC needs iOS 11 and HEVC hardware this device lacks. So
  every server that negotiates image formats sent a picture that rendered as
  nothing: The Verge's lead image was an empty grey box and BBC News looked like a
  page without photographs. WebKit's own WebP decoder is built instead, reached
  through `ScalableImageDecoder`, with `scripts/build-libwebp.sh` building the
  decoder and demuxer for armv7. The other three are no longer claimed.
- **A page's own favicon, instead of Google's copy of it.** The start page fetched
  every tile's icon from Google's favicon service by host, disclosing every
  bookmarked host to a third party and bypassing this port's TLS. WebCore's icon
  loader is compiled and was simply switched off for iOS; it now runs, and the
  bytes travel to the application as a notification. Sites' real declared icons
  arrive - Wikipedia's ICO, GitHub's SVG mark - rather than a rasterised guess.

- **Web Crypto that performs every algorithm, through WebKit's own backend.** The
  Cocoa backend works in CryptoKit, whose Swift has no armv7 target, so this port
  had aliased the missing entry points to a no-op and then hand-written AES-GCM,
  AES-KW, HKDF and HMAC over OpenSSL - reimplementing what WebKit already carries
  in `crypto/openssl` for the ports without CryptoKit. The curve algorithms were
  not reimplemented at all; their constructors were aliased to that same no-op,
  which leaves an object with no vtable. That backend is built instead, against
  the OpenSSL 3.0 this port already builds for its TLS. **ECDSA, ECDH, RSA-OAEP,
  RSASSA-PKCS1, PBKDF2 and AES-CBC/CFB/CTR can be performed for the first time.**
  Five reconciliations were needed, since no port had asked a Darwin platform for
  this backend before, and three were genuine version bugs in it: RSA-OAEP was
  compiled out by a `defined()` test on names that became functions in OpenSSL
  3.0, AES-GCM set its padding mode before the cipher was installed, and
  `EVP_PKEY_get0_RSA` now returns a const pointer.

- **Web fonts, in every format the web serves.** No `@font-face` had ever
  produced a font. `FontCustomPlatformData::create` is built on a private CoreText
  parser and on an iOS 7 API, neither of which exists here, so it returned nothing
  and every custom font failed silently - icon fonts included, which is why so
  many sites drew blank squares. It now takes the documented route that predates
  both: a data provider, `CGFontCreateWithDataProvider`,
  `CTFontCreateWithGraphicsFont`, then that font's descriptor. `HAVE_WOFF_SUPPORT`
  claims the system parser reads WOFF, true from iOS 7 but not here, so WebKit's
  own converter is compiled back in for WOFF; WOFF2 needed the library, which
  `scripts/build-woff2.sh` now builds for armv7 alongside the brotli decoder it
  rests on.
- **Scrolling inside a page.** Nothing in a page could be moved with a finger -
  not an overflow block, not the body of a cookie dialog, not a frame. Only the
  main frame scrolled, because only the main frame has a scroll view. The rest of
  the contract was already whole: promote the area, hand the layer to the embedder
  through `LegacyWebKitScrollingLayerCoordinator`, and the embedder wraps it in a
  `UIWebOverflowScrollView` and reports back through
  `-[WebView _overflowScrollPositionChangedTo:forNode:isUserScroll:]`. Nothing was
  ever promoted, so none of it ran. Frames needed three further gates opened, each
  false for its own reason, and their layer is keyed by the element that owns the
  frame.
- `tools/revpid.c`, which lists pids by name. The device has no `ps`, and `revmem`
  takes a pid, so a process's memory could not be measured without it.

- **Web Crypto that performs its operations.** AES-GCM, HMAC, HKDF and AES key
  wrapping over OpenSSL. Upstream routes all four through CryptoKit, whose Swift
  has no armv7 target, so this port aliased them to one stub returning an empty
  result and no error: a page encrypting a password received an empty buffer and
  sent it. Signing in to a site works from this change on.
- **The engine's own TLS.** `TLS.dylib`, OpenSSL 1.1.1 behind the twenty-five
  SecureTransport entry points CFNetwork imports, inserted at relaunch. The
  system's TLS offers only cipher suites a current server refuses — measured
  against claude.ai, which accepts nothing but AEAD suites. Verification is
  unchanged: the peer chain is returned as a `SecTrustRef` and evaluated by the
  system against its own trust store.
- `requestIdleCallback`, which the engine implements and this port had disabled.
- The page's console, recorded to `/tmp/native-console.log` behind a switch.
- The faulting address and the register file in the crash report. A stack names
  the function; it does not say which pointer was bad.

### Changed
- **The port's own libraries are `@revenant/stable`.** `@ios6/stable` is left to
  what ios6-toolchain serves: `ld64`, `libcxx`, `ldid` and `ios6-base`.
- **Theos is gone from the build.** The tweak, the compat and TLS dylibs and the
  Settings bundle are built by CMake from `platform/`, and the `.deb` is written
  by `conan export-pkg` through ios6-base. `packaging/` keeps only `control` and
  `DEBIAN/postinst`.
- **cmake, ninja and ldid come from Conan**, not from `PATH`.
- **Unused files removed.**
- **CI is pinned to Conan 2.32.0** through `conan-io/setup-conan`.

- **Font feature tags are translated instead of dropped.** `font-feature-settings`
  and every `font-variant-*` were discarded, because features are addressed by
  OpenType tag only from iOS 8 and handing this CoreText a tag-keyed dictionary
  crashes descriptor matching. Apple's own mapping to the numeric AAT
  type/selector pairs - the one that stood in this repository before commit
  `06230e738722` replaced it - is restored for this port. A font carrying AAT
  feature tables now honours the request: `font-variant-caps: small-caps` renders
  in genuine small capitals. A font with only OpenType tables, which is most of
  what the web serves, still will not - this CoreText does not translate an AAT
  selector into a GSUB feature.

- **canPlayType() answers from AVFoundation instead of a list of five.** The
  player factory named five container types, so every other format the framework
  plays was denied - 3GPP, M4V, WAV, AIFF, bare AAC, the `audio/mp3` spelling and
  both spellings of HLS - and a page choosing between `<source>` elements skipped
  formats it could have played. `AVAssetMIMETypeCache` was in the tree for exactly
  this and merely excluded.
- **An asset's description is loaded off the layout path.** `hasVideo()` and
  `hasAudio()` read the asset's tracks synchronously, from layout, before anything
  was ready - which blocks the calling thread on whatever loading remains. They are
  requested asynchronously now, and a failure to load the description is reported
  as a load failure rather than as a decode error, so a missing file no longer
  looks like a corrupt one.

- **A second pass, on what the first one named and could not reach.** String
  hashing on this port no longer runs a mixer built from 64x64 multiplies, which
  armv7 performs in four instructions plus carries; it is a 32-bit mixer, one
  `umull` per eight bytes. That hash is reproduced by three build-time generators
  which emit the static property tables the runtime probes, so all three were
  ported with it and checked against the C++ over 1280 strings and every key of
  all 68 generated tables. The interpreter no longer rebuilds the address of the
  opcode table before each dispatch - it is pinned in a register - which takes
  the generated interpreter from 74,154 instructions to 61,690, and the baseline
  JIT stops emitting two memory barriers for every write to a call frame. The
  collector stops recomputing its heap bounds for every word of the stack it
  scans, and stops suspending every thread twice per collection to measure before
  copying.
- **The compiled form of the site's scripts is now actually written.** The cache
  commits an entry when the engine drops a script's source provider, and the
  provider for a bundle the page holds open is dropped only when the process
  ends - which for this application means never, since it is killed rather than
  asked to quit. The two largest bundles were therefore recompiled at every
  launch. They are written now when the page finishes loading, and again every
  thirty seconds while it is in use - the engine compiles a function the first
  time it is called, so a blob written at load time holds only what had run by
  then, and a third of the launch is that lazy compilation. Twelve entries and
  15 MB after one session of use, against four entries and 3 MB; the feed
  arrives in 20 to 23 s where the same build without the write took 29.5.
- **The engine rewritten for this processor, area by area.** Twelve passes over
  the source, each one looking for work that costs time on an 800 MHz in-order
  core and buys nothing here. Among what came out of it: a structure-consistency
  check that ran in release builds from thirteen call sites on every object shape
  transition, each one reading thread-local storage through `mrc p15`; the
  inspector's `timelineAgentTracking()` called on every JavaScript function
  invocation through the bindings, and 153 other instrumentation points that can
  never fire here; the HTML tokenizer walking `<script>` and `<style>` bodies one
  character at a time; a two kilobyte vector allocated and freed for every CSS
  rule; a namespace map copied for every declaration; `intHash` widening to 64
  bits to run a mixer built from 64x64 multiplies, which armv7 does in four
  instructions; the timer heap removing an element by pushing it to the root and
  then sifting it back down; `Page::updateRendering` walking the frame tree
  twenty eight times per frame and allocating a `WTF::Function` for each walk;
  the tile grid asking CoreAnimation for the layer bounds once per tile per pass.
  Measured after: `element.getAttribute` 810 ns against 930, `document.createElement`
  5.96 us against 6.9, `element.style.top = x` 10.0 us against 11.2, reading
  `className` 195 ns against 240. The launch and the JavaScript benchmark did not
  move.
- Tile coverage is half a screen above and below rather than a whole one. Each
  tile is 1.6 MB at this scale and three screens came to nineteen megabytes of
  layers, not the seven the old note claimed; two screens still cover a flick.
  `WEBKIT_IOS6_TILE_COVERAGE_HALVES` changes it.
- The crash report says how much memory the process was holding, how long it had
  been running and which thread took the signal. Twenty soaks of eight rounds
  produced four deaths with two signatures - a null dereference inside the GPU
  driver and a fault in the allocator - and they appear with the inline caches
  on and off, with the tile coverage large and small, so none of this session's
  changes is behind them.
- Stylesheet parsing can be timed through `WEBKIT_IOS6_STYLE_LOG`, which is how
  the launch was accounted for: of the twenty six and a half seconds between
  the application starting and the feed appearing, the web thread is busy for
  ninety eight percent of them. About forty percent is running the site's
  JavaScript, ten percent compiling it, and three of those seconds are a single
  stylesheet - one file, parsed once. Compiling later (`thresholdForJITAfterWarmUp`
  2000, `thresholdForOptimizeAfterWarmUp` 5000) brings the feed up two seconds
  sooner and costs 43% on the JavaScript benchmark, so the upstream numbers stay.
- **The bytecode cache is on, for the large bundles only.** Caching every
  script cost 31 MB of resident memory to save a second and a half, which is
  why it was off. The site's weight is in four bundles: with the engine's floor
  raised to half a megabyte of source, the feed comes up 24.0 s after launch
  against 28.3 s without, for 7 MB. Its ceiling is 192 MB rather than 32 - one
  of these bundles compiles to a seven megabyte blob - and
  `/tmp/native-no-bytecode-cache` turns it off,
  `WEBKIT_IOS6_BYTECODE_MINIMUM_BYTES` moves the floor.
- Stylesheet parsing can be timed through `WEBKIT_IOS6_STYLE_LOG`, which is how
  the launch was accounted for: of the twenty six and a half seconds between
  the application starting and the feed appearing, the web thread is busy for
  ninety eight percent of them. About forty percent is running the site's
  JavaScript, ten percent compiling it, and three of those seconds are a single
  stylesheet - one file, parsed once. Compiling later (`thresholdForJITAfterWarmUp`
  2000, `thresholdForOptimizeAfterWarmUp` 5000) brings the feed up two seconds
  sooner and costs 43% on the JavaScript benchmark, so the upstream numbers stay.
- The bytecode cache's ceiling is 192 MB rather than 32, and a number written
  into `/tmp/native-bytecode-cache` sets it. At 32 MB it held four of this
  site's bundles and missed everything else - one hit against forty three. It
  is still off by default. Warmed by three launches it reaches twenty one hits
  against five misses and brings the feed up in 24.9 s instead of 26.5, which
  costs 31 MB of resident memory - 226 against 195 over the same scripted
  session. On this device that is the wrong side of the trade.

### Changed
- **The device is checked with numbers now, not screenshots.** `tests/device/run.sh`
  runs pages in the browser on the phone; each page computes its own verdicts and
  reports them, and the runner reads them out of the serving HTTP server's request
  log. A page that reports nothing counts as a failure. Memory is measured over
  three cold runs and reported as a median, because the spread between identical
  runs on this device is 27-36 MB and a single run proved nothing several times
  over.
- **Purgeable decoded images: measured, and left off.** Marking decoded bytes
  transient saves a median 42 MB after four heavy sites (160.9 MB against
  203.4 MB) and takes the process down on a page that draws one image six hundred
  times cropped. The measurement and the switch to reproduce it are in the code.
- **The last-resort code-deletion valve was reading the wrong quantity.** Its
  threshold was derived against `WTF::memoryFootprint()` - the task's own
  anonymous memory - while the test itself read resident size, three fifths of
  which is shared cache and framework text that deleting code cannot release.
  Now both are on the same scale.
- **Idle local storage databases are closed on a memory warning again.** Each
  open connection holds a SQLite page cache; the call was part of the historical
  memory-warning path and lost its caller when that path was rewritten.

### Fixed
- **Joined emoji were drawn as their parts.** A family, a profession, a couple -
  anything built with a zero-width joiner - came out as two or three separate
  glyphs. A grapheme cluster here was CoreFoundation's idea of one, and this
  CoreFoundation is from 2012: `kCFStringComposedCharacterCluster` knows nothing
  of the sequences Unicode added from 2015 on. The character, caret and deletion
  iterators now use WebKit's ICU backing - version 74 in this port, and the
  backing every non-Cocoa port already uses. An astronaut is one 26px glyph
  where it had been two.
- **The system font ignored `font-weight`.** Two separate faults, both fixed:
  `kCTFontWeight*` and `kCTFontWidth*` are declared as `CGFloat` and the
  compatibility layer had defined them as CFStrings, so every rung of the ladder
  was a pointer read as a float; and asking for a face through a numeric weight
  trait is an iOS 7 mechanism, so the request is now also made through
  `CTFontCreateCopyWithSymbolicTraits`, which this release answers.
  `-apple-system` at weight 700 draws bold and measures 34.2px against 33.0 at
  400 - it had been identical.
- **Thirteen of the eighteen `feBlend` modes were erased.** This port re-enables
  NEON, which upstream disables on iOS, and `FEBlendNeonApplier` predates the CSS
  blend modes: it implements five and writes transparent black for the rest. The
  generic applier is compiled alongside it now and takes the other thirteen.
- **Rounded corners were parabolas, and uneven ones were on the wrong corner.**
  The shims for the two CoreGraphics entry points this system lacks put both
  bezier control points on the corner vertex. WebKit's own exact beziers draw
  them now, and both shims fall out of the path.
- **A colour font was treated as having no colour glyphs**, because the query for
  which glyphs are coloured does not exist here and its absence was read as "none"
  rather than "unknown". A font that declares the colour trait is taken at its
  word, which is what WebKit itself did until that query became unconditional.
- **Two shims answered success and did nothing**: integer vector addition, which
  silently dropped a channel in the audio ring buffer, and a blob bind that
  reported SQLITE_OK while binding nothing.
- **Foundation kept a second copy of every response.** A phone was given 8 MB of
  URL cache on top of the 8 MB WebCore is allowed here, and a `std::max` that
  could only ever raise it; it is 1 MB now. The back/forward cache held two fully
  suspended pages and now holds one.
- **SVG filters are interpolated in linear light, as the specification asks.**
  linearRGB is the space filters interpolate in by default, and it had been a
  name with nothing behind it: this CoreGraphics matches colour by primaries and
  ignores the transfer function, so every filter was computed on gamma encoded
  pixels. WebKit carried the answer until 2020 - `ImageBuffer::transformColorSpace`
  built a 256 entry table from its own sRGB transfer function and handed it to
  the port's `platformTransformColorSpace`; the CG ports never needed one. The
  table is back, in the backend that owns the pixels, and the filter machinery
  takes the branch written for ports whose graphics library cannot convert. So
  that the two spaces can be told apart at all - both resolve to the single RGB
  space this system has - `DestinationColorSpace` carries a tag for the linear
  one. Measured against a flat 192,64,64: an identity colour matrix in linearRGB
  is exact, `saturate 0` gives 109 where linear light asks for 110 and gamma
  encoded pixels gave 92, and a red to blue gradient desaturates to 71 grey
  rather than 37.
- **A buffer asked for in another colour space came back black.** Crossing
  colour spaces goes through `vImageConverter_CreateWithCGImageFormat`, iOS 7,
  which fails here; the accelerated path then zero-fills rather than expose
  stale heap. `convertImagePixels` now performs the sRGB and linearRGB pair
  itself, as its own note suggested.
- **An SVG filter that changes nothing tinted what it touched.** linearRGB is the
  space filters interpolate in by default, and this port had been given a
  calibrated colour space with a gamma of one so that would be true. Measured on
  the device, that space did neither half of its job: this CoreGraphics matches
  colour by primaries and ignores the transfer function, so the pixels reaching a
  filter stayed gamma encoded - `saturate 0` gave the same 92 grey through
  linearRGB as through sRGB, where linear light asks for 110 - while the round
  trip through those primaries shifted colour, so an identity colour matrix
  turned 192,64,64 into 171,76,66. linearRGB now resolves to the one RGB space
  the system has. An identity filter is exact again. Filters are still computed
  on gamma encoded pixels: doing otherwise means performing the colour management
  by hand, which is not done here.
- **Any page using small-caps ended the process.** `Font::supportsSmallCaps()`
  asks CoreText which glyphs a feature covers; this one answers nothing for a
  feature it does not know, and the union of that coverage counted the bits of a
  null vector. Guarded where both coverage queries arrive.

- **Every piece of text the engine supplies read "localized string not found".**
  That string is a sentinel `CFBundleCopyLocalizedString` is asked to return when a
  key is absent, so a debug assertion trips; in a release build it reaches the
  interface instead. The staged framework carries the media controls' strings and
  no `Localizable.strings` beside them, so every key missed - the file chooser
  buttons, a valueless submit or reset button, the context menus, the accessibility
  labels and a multiple select were all labelled with it. A missing key now falls
  back to the key, which is the English string.

- **A software-decoded image drew nothing at all.** `ImageBackingStoreCG` asked
  CoreGraphics for its colour space by name, and this one answers to no name:
  `kCGColorSpaceSRGB` returned nothing, `CGImageCreate` got a null space, and the
  picture decoded, reported its size and painted nothing. It goes through the
  engine's own `sRGBColorSpaceSingleton` now.
- **A playing video told the page nothing about itself.** readyState stayed 0 and
  videoWidth was zero while the movie ran, so anything measuring a video, or
  waiting for loadeddata or canplay, saw a media element that had never loaded. The
  status observation asked for no options and so only heard about a *change*, while
  an item from a fast source is already ready before observation starts; and the
  natural size came only from the item, which is empty until then, rather than from
  the video track, which carries it as soon as metadata is loaded.

- **Form controls were painted entirely in transparent.** Every button, checkbox,
  radio, select, text field and progress bar on every page: no box, no border, no
  label. Only `-webkit-appearance: none` drew. The user agent stylesheet dresses
  controls in the semantic colours, which map to UIColor selectors introduced in
  iOS 13; the lookup correctly declines, and the base `RenderTheme` answers a name
  it does not know with an invalid colour, which is fully transparent. Layout, hit
  testing and events all worked, so a button was clickable and unreadable - which
  is why pages read as frozen. Each name is now answered with the specification
  colour of the same role, so every value still comes from WebKit's own table.
- **Two crashes in image drawing.** Drawing scales the source rectangle by one
  size divided by another, and either can still be empty when frame metadata has
  not arrived; the division put infinities in the rectangle and the draw faulted.
  This was the most frequent crash on this port, ten of fifteen that could be
  symbolicated. Separately, asking for an image's size reached for a frame that
  did not exist yet and re-entered itself until the stack was gone.
- **A constructor that returned without running.** `MediaSampleAVFObjC`'s
  constructor was aliased to a shared no-op, which leaves the object with no
  vtable; six built files reference it. The real file needs none of what forced
  its exclusion and now compiles. Its callers turn out to be unreachable today,
  so this removes a hazard rather than an observed crash.

- **Tile layout, which was being skipped almost every frame.** The interface
  stops waiting for the engine before laying out tiles, which is right, but the
  engine holds the web lock nearly all the time on this device: counted on the
  phone, 527 layout passes were skipped against 10 that ran. That method is also
  where tiles for newly exposed page are made, so a flick landed on page that
  was laid out and never painted - photographed, a white screen with the content
  behind it, which stayed white until something else moved. Skipping is now
  bounded: after a quarter of a second without a real pass the interface waits
  for the engine however long it takes. The same counter afterwards reads 129
  passes run against 451 skipped.
- **Tile coverage, cut to the visible screen whenever memory was tight.** Which
  is always here, so every scroll dropped the tiles it had and made two new
  ones. Coverage now follows the system's own pressure reading rather than the
  process's memory policy, and a scroll keeps eleven or twelve tiles - a screen
  above and below - instead of two. `WEBKIT_IOS6_MINIMAL_TILES` restores the old
  behaviour; one soak in three ended in a fault inside the GPU driver with the
  larger set of layers, which two further soaks did not reproduce.
- **Compiled JavaScript, thrown away on the same schedule.** The memory-release
  path also deletes every code block in the process, and the site's route change
  then spends its time parsing and generating bytecode again - parser, bytecode
  generator and `newCodeBlockFor` together dominate the profile of a tab switch.
  Sampled from inside the page, the stretches where it cannot run a timer at all
  across four switches: 77 s in total with the code deleted, 53 s with it kept.
  The code is now deleted only above 160 MB resident, just under the point where
  the app makes its own last-resort release, so deletion happens with a full
  release and never routinely;
  `WEBKIT_IOS6_CODE_DELETION_THRESHOLD_MB` moves the line. This entry previously
  said that deleting only the linked code crashes, an inline cache outliving the
  code block it points at. That was a misdiagnosis. Both variants free machine
  code through the same call, a property cache is owned by its own code block and
  dies with it, and calls into a block are reverted as it is destroyed, so nothing
  is left pointing at freed code. The crash of that session is better explained by
  the two register defects in the compiler fixed in this same batch.
- **The style resolver, thrown away every time the system asked for memory.**
  WebCore's memory-release path clears the resolver, and on a 512 MB device
  running a 250 MB process that path runs constantly. Rebuilding it means
  re-reading every rule of the site's stylesheets: measured at 950 ms a time,
  47 times in a four-minute session - 35 seconds of processor spent
  reconstructing something that had not changed. The compiled selectors are
  still released. Over the same scripted session: 1.4 s of rebuilding instead of
  35.5, and resident memory lower rather than higher, 195 MB against 202.
- **Inline caches, which this architecture had them switched off for.**
  `forceICFailure` — the option that makes every inline cache refuse to install —
  defaults to `is32Bit()` upstream, so on armv7 no call ever linked and no
  property access ever cached. Every call went through the slow path for the life
  of the process: the compiler saw an empty call profile at every site, declined
  to inline anything, and emitted a full call frame for `a + 1`. Measured on the
  device, per operation: a method call 706 ns to 71, a call through a variable
  676 to 33, `Math.abs` 553 to 53, reading `Function.length` 605 to 31; through
  the DOM, `node.nodeType` 1235 ns to 60, `element.firstChild` 1310 to 140,
  `document.getElementById` 3175 to 610, `element.style.top = ...` 17800 to
  11020. The synthetic route-change workload fell from 6300–8000 ms to 4979.
  Resident memory is unchanged for the same amount of page: 224 MB against 224
  over an identical scripted session.
- **A register clobbered by the regular-expression JIT.** Its prologue computed
  the new stack pointer into `regT0` before saving the callee-saved registers,
  and on ARM_THUMB2 `regT0` is `r4`, which is in that set — so the caller's `r4`
  was destroyed, then saved, then restored. `'aaa'.matchAll(/\w+/g)` took SIGBUS
  in `JSRegExpStringIterator::nextImpl`. The registers are saved first now.
- **Text drawn invisibly.** The attributed string carried only a font, so
  CoreText painted its own default colour — black — whatever colour UIKit had
  set. The status bar's clock and carrier were painted black on black; the
  battery and the signal, being images, were fine.
- **Text drawn in the wrong place.** `drawAtPoint:` is given a baseline and
  `drawInRect:` the top of a rectangle; both had the ascent added. Each is
  corrected where it belongs.
- **A process abort inside CoreGraphics** when a page drew text into an
  offscreen canvas: the glyph recorder builds a scratch context through the
  context-delegate interface, which this system's CoreGraphics does not have.
  Glyph runs are recorded whole on this port instead of being taken apart.
- **The promoted bottom bar outliving its site.** It is a view in the window, so
  nothing removed it when the reader left; it was found sitting over another
  site still carrying the first one's items.
- Native chrome promotion is off until it can carry the site's icons rather than
  their labels. Five words where the reader expects five pictures is not a
  promotion.

### Changed
- Style caches restored to their upstream sizes. The port had cut
  `MatchedDeclarationsCache` to two entries per hash and 256 buckets; a miss
  there costs a full cascade rebuild, and the cut cost about 12% of the time to
  `domInteractive` (6508–7010 ms against 7213–12296).
- The repository no longer tracks build trees or dependencies. The port's
  changes to the engine are exported to `patches/engine/` instead of carrying an
  upstream checkout.
- The JIT code-deletion threshold moved from 235 MB to 275 MB, ten megabytes
  above the collector's own absolute band (`JSC_IOS6_GC_ABSOLUTE_MB`), which
  moved from 225 to 265 the same night on live-device evidence that 225 sat
  inside ordinary navigation load and kept releasing full-collection
  suppression that did not need releasing. The two constants were always a
  paired ten-megabyte margin, one always firing just after the other's last
  resort; left at 235 the code-deletion valve would have started firing
  thirty megabytes *before* the collector's, on ordinary load, which is the
  same class of regression this pairing already exists to avoid one order of
  magnitude smaller than the first time it was caught.
- `ENABLE_POINTER_LOCK`, `ENABLE_APPLICATION_MANIFEST` and
  `ENABLE_PICTURE_IN_PICTURE_API` turned off; `OptionsIOS.cmake` force-defaults
  them on for `PORT=IOS` even though the upstream default is off, and this
  port never reaches any of the three. 32 KB of `__TEXT`, confirmed by
  isolating each candidate through source reading rather than the disable-and-
  see-what-breaks pass this repeats from an earlier session: sixteen of that
  earlier session's twenty-five `ENABLE_APPLE_PAY_*`/`ENABLE_WK_WEB_EXTENSIONS`
  flags turn out to be dead code on this tree regardless of their setting, and
  could not have owned any of the 254 KB once credited to the whole batch.
- `Ios6BlockReservationPool`, one shared 2 MB-granularity block-reservation
  pool for JSC's `MarkedBlock`-sized (16 KB) allocations, replacing three
  independently-growing copies in `FastMallocAlignedMemoryAllocator`,
  `GigacageAlignedMemoryAllocator` and `StructureAlignedMemoryAllocator`.
  `Structure`'s `!CPU(ADDRESS64)` `StructureID` encoding does not require its
  blocks to come from a separate address range on this port, so sharing one
  grower across all three is safe. Strictly reduces JSC's own contribution to
  32-bit address-space fragmentation from three families to one.
- `GlyphGeometryCache`'s upstream cap of 500,000 entries per
  `FontCascadeFonts` instance lowered to 20,000, and `ShapedTextCache`'s cap
  of 3,000 to 500. At roughly 176 bytes a slot in a sub-50%-loaded hash
  table, the old glyph-geometry cap alone bounded a single font's worst case
  above 180 MB on a 512 MB device — a valve sized for hardware this port
  does not run on. Neither cache commonly approaches even the lowered
  ceiling in ordinary use; both remain a guard against the pathological
  case (a feed rendering thousands of unique short strings against one
  font), not a limit on the common one.

### Refuted by measurement
- **The JSC optimization cost ceiling.** Upstream lowers it for 32-bit ARM in a
  block gated on Linux whose reasoning is about the architecture. Measured at the
  lower value across SoundCloud, The Verge, Google and Hacker News: 1629 DFG
  dispatches, none refused for cost. No code block on the real web comes near
  either ceiling, so the two values are indistinguishable.
- **A second DFG compiler thread.** The Darwin thread tuning is gated on ARM64, so
  armv7 falls back to one thread while that block would ask for two here. Two is
  worse: the mean age of a plan waiting in the queue rose from 267 ms to 330 ms,
  and the number waiting longer than half a second went from 82 to 195. With two
  cores and a busy main thread, the second compiler takes the time the first one
  needed.

- That the optimising JIT costs more than it returns on armv7: 20 s with it,
  24 s without.
- That WebAssembly was what the bot check needed: its script, 227 KB, does not
  mention WebAssembly at all.
- That the feed stopped loading because of a rate limit: the refusal carried
  `"require_login": true`, and the feed paginates once signed in.
- That the site's own polyfill loading was the memory cost of running an old
  UA: `core-js`, `regeneratorRuntime` and `Zone` are all absent from the live
  page, and every modern JS-language feature a React bundle would plausibly
  feature-detect for is native to the JavaScriptCore in this tree already.
- That decoded image memory could be cut by decoding to display size instead
  of source resolution: the port already does this (`ImageDecoderCG.cpp`,
  committed as part of the port's own baseline patches, not new). 48 cached
  images on a live feed cost 0.9–1.3 MB decoded — under the ideal
  decode-to-shown-size estimate for the same screen, not over it.
- That prefetching the other bottom-tab routes in a hidden iframe during idle
  time would hide their first-visit compile cost: it does not, on this build,
  because the disk bytecode cache only ever covers the four large startup
  bundles — confirmed by the cache directory holding the same four files
  before and after the prefetch ran. The 8 s a tab switch costs is not JS
  compilation; profiling during the transition shows no new bytecode misses
  on either the first or the second visit to a tab.
- That identical code folding could shrink the three shipped frameworks:
  the linker in this toolchain (Apple ld64/ld-prime) has no ICF support at
  all — `-Wl,-icf=all` and the two spellings after it fail with
  `ld: unknown options:`, and `man ld` carries no such entry. Not attempted
  further; there is nothing to attempt it with.
- That WebCore could be compiled `-Os` while keeping the interpreter at
  `-O3`: it already is, at `-Oz`, behind `WEBKIT_IOS6_SIZE_OPTIMIZED`, with
  the interpreter already carved out onto its own flags. Already done, more
  aggressively than proposed.
- That enabling LLVM's hot-cold code splitting would shrink the three
  frameworks: `__TEXT` came back byte-for-byte identical the first time (the
  flag reached the per-file bitcode emission, not the ThinLTO backend that
  actually generates code) and 1.0–1.6% *larger* the second time, once the
  flag was moved to where it does take effect. The pass trades size for
  instruction-cache locality by outlining cold blocks into their own
  functions with their own prologues; it does not reduce total code size on
  this codebase, and reverted cleanly.
- That merging the three independently-growing JSC block-reservation pools
  (Structure, Gigacage, FastMalloc) into one, and cutting `GlyphGeometryCache`
  and `ShapedTextCache`'s upstream desktop-scale caps, were behind a live
  jitter regression in the fixed top/bottom bars: reverting both did not stop
  it. The actual cause is upstream (`RenderLayerCompositor`, see Fixed, below)
  and predates this session. The pool merge and cache caps were real, safe,
  and unrelated to the regression they were first blamed for — reinstated
  the same night once that was established, verified clean on-device a
  second time (no crash, no code-deletion firing, comparable memory profile
  to the first measurement).

### Fixed
- The fixed top and bottom bars losing their position for one frame during a
  scroll that concurrently triggers a relayout (infinite-scroll appending
  content is the common trigger; the bottom bar sees it far more often than
  the top, because this port's layout is always whole-document and
  infinite-scroll appends near the bottom). `RenderLayerCompositor::flushPendingLayerChanges`
  commits new CALayer geometry on the web thread, unlocked, and only
  afterward republishes the UI thread's `ViewportConstraints` snapshot under
  `webFixedPositionContentDataLock`; a scroll tick landing in that gap
  combines a freshly-read layer offset with a stale constraint, producing a
  bar that is torn out of position for a frame. Diagnosed on both the live
  site and a deterministic repro added to `tests/scrollbench.html`. A fix
  exists behind `/tmp/native-flush-race-fix` (holds the existing lock across
  the commit-to-republish window, no measured scroll-performance cost) but is
  not yet merged: the synthetic repro's hit rate under the fix (0.1%, 3 of
  3111) is two orders of magnitude below the live-site visual estimate
  (12.5%, from an 8-frame sample), and that gap is not yet explained. Left as
  a branch pending a wider repro before it is trusted as the whole story.
