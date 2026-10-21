# Measurements

What was measured on the iPhone 4S (A5, 512 MB, iOS 6.1.3) for this engine, the settings that the measurements chose,
and the hypotheses the measurements refuted. Each entry says what was measured and against what. The bug fixes that
these measurements led to are in the commit messages.

## Rendering

- **WebGL frame rate.** A spinning triangle runs at 29 fps at 64x64, 30 fps at 320x240 and 28 fps at 320x480. The rate
  barely moves with the canvas, so the cost is per frame, not per pixel.
- **WebGL conformance.** Khronos' suite runs on the device: 2236 checks pass over the areas run so far. The remaining
  failures are the GPU's, each with a probe that shows it without ANGLE or WebKit in the way. The GPU does not sample
  non-power-of-two cube maps, and it ignores face culling when the colour attachment is an IOSurface-backed texture,
  which is what a canvas draws into here. After the ANGLE roll, 573 framebuffer-attachment checks still pass.
- **WebGL 2.0** is out of reach: it needs OpenGL ES 3.0, and this silicon is ES 2.0.
- **Font weight.** `-apple-system` at weight 700 draws bold and measures 34.2 px, against 33.0 px at 400. Before the fix
  both were identical.
- **Tile layout.** Counted on the phone, 527 layout passes were skipped against 10 that ran. After the bounded wait,
  129 ran and 451 were skipped.
- **Tile coverage.** A tile is 1.6 MB at this scale, and three screens came to 19 MB of layers, not the 7 MB the old
  note claimed. A scroll keeps 11 or 12 tiles, a screen above and below. One soak in three ended in a fault inside the
  GPU driver with the larger set; two further soaks did not reproduce it. `WEBKIT_IOS6_MINIMAL_TILES` restores the
  smaller set.
- **Image memory.** Forty-eight cached images on a live feed cost 0.9 to 1.3 MB decoded, which is under the ideal
  decode-to-shown-size estimate for the same screen.
## Colour and filters

- **SVG filters are computed on gamma-encoded pixels.** This CoreGraphics matches colour by primaries and ignores the
  transfer function, so linear light is not available. An identity colour matrix in linearRGB is exact now. Against a
  flat 192,64,64, `saturate 0` gives 92 grey, where linear light would give 110. Doing it properly means managing colour
  by hand, which is not done.
- **Identity colour matrix.** Before the fix it turned 192,64,64 into 171,76,66.

## JavaScript

- **Inline caches.** Upstream's `forceICFailure` defaults to `is32Bit()`, so on armv7 no call linked and no property
  access cached. With the default changed, per operation on the device: a method call 706 ns to 71 ns, a call through a
  variable 676 to 33, `Math.abs` 553 to 53, `Function.length` 605 to 31, `node.nodeType` 1235 to 60, `element.firstChild`
  1310 to 140, `document.getElementById` 3175 to 610, `element.style.top = ...` 17800 to 11020. The synthetic
  route-change workload fell from 6300 to 8000 ms to 4979 ms. Resident memory was 224 MB both ways.
- **Generated interpreter.** Pinning the opcode table in a register takes the interpreter from 74,154 instructions to
  61,690.
- **Style resolver rebuilds.** Rebuilding the resolver costs 950 ms each time, and it happened 47 times in a
  four-minute session, 35 s in all. Keeping it: 1.4 s of rebuilding in the same scripted session, and resident memory of
  195 MB against 202 MB.
- **Style caches** are kept at upstream sizes. Cutting `MatchedDeclarationsCache` to two entries per hash and 256
  buckets cost about 12% of the time to `domInteractive` (6508 to 7010 ms against 7213 to 12296 ms).
- **Launch.** Of the 26.5 s from application start to the feed, the web thread is busy for 98%. About 40% runs the
  site's JavaScript, about 10% compiles it, and three of those seconds are a single stylesheet, parsed once.
- **Compiled scripts written to disk.** Writing the compiled form of the two largest bundles when the page loads, and
  again every thirty seconds in use, leaves twelve entries and 15 MB after one session, against four entries and 3 MB.
  The feed arrives in 20 to 23 s, where the same build without the write took 29.5 s.
- **Bytecode cache, for the large bundles only.** Caching every script costs 31 MB of resident memory to save about
  1.5 s, which is why it is off. With the floor raised to half a megabyte of source, the feed comes up in 24.0 s against
  28.3 s, for 7 MB. Its ceiling is 192 MB, since one bundle compiles to a 7 MB blob; at 32 MB it held four bundles and
  missed everything else (one hit against forty-three). Warmed by three launches, it reaches 21 hits against 5 misses
  and brings the feed up in 24.9 s instead of 26.5 s, for 31 MB more resident memory (226 MB against 195 MB). It is
  off by default.
- **Compilation thresholds.** Lowering `thresholdForJITAfterWarmUp` to 2000 and `thresholdForOptimizeAfterWarmUp` to 5000
  brings the feed up two seconds sooner and costs 43% on the JavaScript benchmark, so the upstream values stay.
- **Code deletion.** The threshold is 275 MB, ten megabytes above the collector's absolute band of 265 MB. Both moved up
  from 235 and 225 MB, because 225 MB sits inside ordinary navigation load, and the valve kept releasing full-collection
  suppression that did not need releasing. Left at 235 MB, the code-deletion valve would fire thirty megabytes before the
  collector's on ordinary load.
- **Optimising JIT cost.** The hypothesis that the optimising JIT costs more than it returns on armv7 was refuted: the
  feed took 20 s with it and 24 s without.
- **Tab switches.** Sampled from inside the page, the stretches where it cannot run a timer across four tab switches
  come to 77 s with the code deleted, and 53 s with it kept.
- **Bot checks.** A challenge script of 227 KB does not mention WebAssembly, so WebAssembly was not what it needed.
- **Feed refusals.** The refusal that looked like a rate limit carried `"require_login": true`; the feed paginates
  once signed in.
- **Polyfills.** `core-js`, `regeneratorRuntime` and `Zone` are absent from the live page, and the JavaScriptCore in this
  tree has every modern language feature a React bundle would detect.
- **Memory spread.** Identical runs on this device differ by 27 to 36 MB, so memory is measured over three cold runs and
  reported as a median.
- **Purgeable decoded images, left off.** Marking decoded bytes transient saves a median 42 MB after four heavy sites
  (160.9 MB against 203.4 MB), and takes the process down on a page that draws one image six hundred times, cropped. The
  switch that reproduces it is in the code.
- **Stability.** Twenty soaks of eight rounds produced four deaths with two signatures: a null dereference inside the GPU
  driver, and a fault in the allocator. They appear with the inline caches on and off, and with the tile coverage large
  and small.

## Settings the measurements left off

- **Second DFG compiler thread.** The Darwin tuning asks for two threads on ARM64, and armv7 has one. Two is worse: the mean
  age of a plan waiting in the queue rose from 267 ms to 330 ms, and the count waiting over half a second rose from 82
  to 195.
- **Native chrome promotion** stays off until it can carry the site's icons rather than their labels.
- **ENABLE_POINTER_LOCK, ENABLE_APPLICATION_MANIFEST and ENABLE_PICTURE_IN_PICTURE_API** are off. Upstream's
  `OptionsIOS.cmake` forces them on for `PORT=IOS`, but the port never reaches them, and they cost 32 KB of `__TEXT`.
- **Idle-tab prefetch.** Prefetching the other tab routes in a hidden frame during idle time does not hide their cost: the
  disk bytecode cache covers only the four startup bundles, and the 8 s a tab switch costs is not JavaScript compilation.
  Profiling the transition shows no new bytecode misses on either visit.

## Size

- **Identical code folding** cannot shrink the frameworks: the linker in this toolchain (ld64, ld-prime) has no ICF
  support. `-Wl,-icf=all` fails with `ld: unknown options:`, and `man ld` has no such entry.
- **Hot-cold splitting** did not shrink them. `__TEXT` came back identical the first time, because the flag reached the
  per-file bitcode and not the ThinLTO backend that generates code. Applied where it takes effect, `__TEXT` grew by 1.0
  to 1.6%. The pass was reverted.
- **WebCore** is already built at `-Oz`, behind `WEBKIT_IOS6_SIZE_OPTIMIZED`, with the interpreter on `-O3`.

## Open

- **Scroll race of the fixed bars.** A fixed bar can lose its position for one frame during a scroll that relayouts at
  the same time. The fix is behind `/tmp/native-flush-race-fix`, which holds the layer lock across the commit to the
  republish, with no measured scroll cost. The synthetic repro hits it in 3 of 3111 frames (0.1%), while the live site
  showed it in 12.5% of an 8-frame sample. The gap is not explained, so the fix is not merged.
- **Upstream ceilings.** The JSC optimisation-cost ceiling that upstream lowers for 32-bit ARM is never reached on the real
  web: 1629 DFG dispatches on SoundCloud, The Verge, Google and Hacker News, none refused for cost.
