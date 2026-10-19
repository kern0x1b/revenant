# Memory and caches on a 512 MB phone

What WebKit's memory machinery does on this device, and which knobs earn their
place. Written against WebKit 2.54; the values the port actually ships are in the
code, and the reasoning for each change is in its commit.

## The JavaScript heap

WebCore creates its VM with `JSC::HeapType::Large` (`Source/WebCore/bindings/js/CommonVM.cpp`).
`Heap::Heap` sets the first-collection threshold to
`min(Options::largeHeapSize() /* 32 MB */, ramSize * Options::smallHeapRAMFraction())`, and on
iOS `Options.cpp`'s `overrideDefaults()` raises `smallHeapRAMFraction` to 0.8 — so on a 512 MB
device the threshold is a flat 32 MB, and nothing is collected until the JS heap reaches it.

Every JSC option can be set from the environment before the first VM exists.
`Options::initialize()` reads `*_NSGetEnviron()`, which is live, and none of the three
frameworks has a `__mod_init_func` section, so nothing of WebKit runs before `main()` and the
loader's own `setenv()` is seen:

    JSC_largeHeapSize=4194304          # 4 MB instead of 32 MB

The related knobs do not earn their place:

- `smallHeapRAMFraction` only enters as `min(largeHeapSize, ramSize * fraction)`. Once
  `largeHeapSize` is 4 MB the fraction would have to drop below 0.008 to bind. Inert.
- `criticalGCMemoryThreshold` is counterproductive to lower. Its third effect caps eden at
  `ramSize * (1 - threshold) / 4`, so lowering the threshold *raises* the allowance: 25.6 MB at
  the 0.80 default, 57.6 MB at 0.55.

### Mini mode, and why it no longer applies

`VM::isInMiniMode()` is true whenever `!Options::useJIT()`. In mini mode
`Heap::useGenerationalGC()` returns false — every collection is a full collection — and sweeping
is synchronous, which is why collecting less often mattered more than usual.

This port restores the ARMv7 JIT, so the VM is **not** in mini mode: generational collection is
back, eden collections do most of the work, and the growth factors that mini mode short-circuits
are live again. Any advice written for the interpreter-only build — including the 4 MB heap floor
above — has to be re-measured before it is believed.

### Concurrent collection stays off

`Options.cpp` turns `useConcurrentGC` off on every CPU but x86-64 and ARM64, and on armv7 that is
load-bearing. C++ fast paths in the runtime - array push, `putDirect`, indexing-type conversion,
`JSArray.cpp`'s `memmove` of butterfly contents - write a JSValue into a live slot as two plain
32-bit stores, outside the InvalidTag protocol `JSValue::decodeConcurrent` relies on, so a
concurrent marker could read a cell tag beside half of an old pointer. Generated code publishes
through `AssemblyHelpers::storeAndFence32`, whose fence depends on `Options::useConcurrentJIT()`,
not on concurrent collection. Enabling it starts with moving every C++ write site onto the
protocol, not with the option; see [armv7-jit.md](armv7-jit.md) §6.8.

### Full collections that free nothing

`Heap.cpp` promotes a collection to a full one while `overCriticalMemoryThreshold() &&
m_overHardMemoryThreshold`. Both compare the whole process's footprint (see *Memory pressure*), of
which the JavaScript heap is a small part, so a full collection cannot bring the footprint back
under the threshold that asked for it, and nearly every collection turns full.

Under `WEBKIT_IOS6` a full collection that frees less than 2 MB or 2% of the heap
(`WEBKIT_IOS6_GC_UNPRODUCTIVE_FLOOR_KB`, `WEBKIT_IOS6_GC_UNPRODUCTIVE_FRACTION`) suppresses the next
promotion until the heap grows by 60% (`WEBKIT_IOS6_GC_SUPPRESS_RELEASE_GROWTH_FRACTION`), 45 s pass
(`WEBKIT_IOS6_GC_SUPPRESS_RELEASE_MS`) or the footprint passes 265 MB (`JSC_IOS6_GC_ABSOLUTE_MB`).
The three are set for real navigation: values fitted to a bench with a 35 MB heap (25%, 15 s,
225 MB) release the suppression on nearly every real full collection.

`WEBKIT_IOS6_GC_SUPPRESS_UNPRODUCTIVE_FULLS=0`, or the file `/tmp/jsc-gc-no-suppress`, turns
suppression off; `WEBKIT_IOS6_GC_LOG=<path>` writes one line per collection. Judge a change here by
the collection counts in that log: frame counts and footprint on a live site vary twofold between
identical settings.

### The eden allocation floor

`WEBKIT_IOS6_GC_EDEN_ALLOC_FLOOR_KB` (96 KB) skips an eden collection requested with less than that
allocated since the last one, at most `WEBKIT_IOS6_GC_EDEN_ALLOC_FLOOR_MAX_SKIPS` (8) times in a
row, on all three triggers: the allocation check in `Heap.cpp`, `EdenGCActivityCallback`, and the
opportunistic collections in `VM.cpp`. It is safe - the live heap after collection and the crash
count do not change - and it is not shown to help: on clean repeats the GC log shows no skips and as
many eden collections as without it.

## Cache model

`+[WebView _setCacheModel:]` derives everything from the model and the RAM size. At 512 MB:

| | DocumentViewer | DocumentBrowser | PrimaryWebBrowser |
|---|---|---|---|
| back-forward cache pages | 0 | 2 | 2 |
| MemoryCache total | 16 MB | 16 MB | 32 MB |
| NSURLCache memory | 0 | 1 MB | 8 MB |
| tile layer pool | 12 MB | 12 MB | 24 MB |

**Do not set a cache model at all.** This reverses the earlier advice. `+_setCacheModel:` runs only
off the cache-model-changed notification, and on iOS `+standardPreferences` — what an unnamed
`WebView` gets — is built with `sendChangeNotification:NO` and never posts it. So on this app the
model has never been applied, and WebCore's own constructor defaults are tighter than every rung of
the ladder above: `MemoryCache` 8 MB total, `BackForwardCache::m_maxSize` 0, tile layer pool 0.

`DocumentViewer`'s appeal is its dead capacity of zero, but that is worth nothing here.
`deadCapacity()` is `clamp(m_capacity - m_liveSize, m_minDead, m_maxDead)`, so under the 8 MB
default a page whose live resources already exceed 8 MB *also* gets a dead capacity of zero. What
changes is `liveCapacity()`, which is what `pruneLiveResources` destroys decoded image data against:
8 MB today, 16 MB under `DocumentViewer`. On a heavy page the model would retain roughly 7.6 MB
**more** decoded image data, and hand the tile layer pool 12 MB it does not have today.

`setAutomaticallyDetectsCacheModel:NO` is **not** required on iOS either, correcting the same note.
The promotion happens in `-_checkDidPerformFirstNavigation`, which sits inside
`#if !PLATFORM(IOS_FAMILY)`; the iOS `-_didCommitLoadForFrame:` does not call it.

If a model ever is set: it is process-global, ratcheting up on any higher value and only recomputing
a maximum when a preference goes down, and it never shrinks the `NSURLCache` capacities — `std::max`
against the existing value on both memory and disk.

`setUsesPageCache:` decides nothing while the capacity is zero: `BackForwardCache::canCache()`
returns false on `!m_maxSize` before it looks at `Settings::usesBackForwardCache()`.

## Tiles

`LegacyTileCache` uses a hardcoded 512×512 logical tile (`LegacyTileCache.h`, `m_tileSize`) with no
setter anywhere. Tiles are clipped to the host layer's bounds, so on a 320-point-wide viewport a
tile is 320×512 points — 640×1024 px at 2× screen scale, **2.5 MB of backing store**. The grid's
own accounting still charges the unclipped 4 MB.

The speculative cover rect is the visible rect inflated by half a width each side and a full height
above and below — 2w × 3h, so 320×1440 here, three to four tiles.

    [wakWindow setTilingMode:kWAKWindowTilingModeMinimal];

collapses the cover rect to exactly the visible rect and centres the grid so 480 points fall inside
one 512-point row: one tile. `removeAllNonVisibleTiles` gives manual control. `keepsZoomedOutTiles`
already defaults to NO, which is what keeps the second grid from ever being allocated.

Dropped tile layers go to `LegacyTileLayerPool` rather than being freed, so the pool capacity has to
be zero for the drop to return memory promptly. It already is: the only caller of
`setLayerPoolCapacity` is `+_setCacheModel:`, which never runs here.

## Encoded image bytes

Jetsam judges this process by resident pages, and the only resident pages the kernel can take back
without killing it are clean file-backed ones: this release has no swap and no memory compressor.
So a cached image of 16 KB or more does not keep its encoded bytes in the heap. When
`CachedImage::finishLoading` completes, `fileBackEncodedDataIfWorthwhile()` hands them to
`fileBackEncodedImageData` (`Source/WebCore/loader/cocoa/DiskCacheMonitorCocoa.mm`), which writes
them to a temporary file on its own work queue, maps it back with `MappedFileMode::Shared`, unlinks
it, and swaps the mapping in through `CachedResource::tryReplaceEncodedData` on the web thread.

On a page of twenty 750 KB photographs this takes dirty memory from 48.6 MB to 38.0 MB; on ordinary
sites it moves tens of KB to about a hundred. A 4 KB threshold moves the same amount with three
times the files, hence 16 KB. Measure a change here by the bytes moved: one cold run of a live site
varies more than the effect.

## Bytecode caching is not available to us

This corrects an earlier assumption. `-[JSScript cacheBytecodeWithError:]` exists, but:

- **WebCore never uses it.** `CachedScriptSourceProvider` does not override `cachedBytecode()`, so
  script loads always return null. There are zero references to `CachedBytecode` in `Source/WebCore`
  and zero to "bytecode" in `Source/WebKitLegacy`.
- **A cache cannot be shipped in a bundle.** `GenericCacheEntry::isUpToDate` validates the Mach-O
  UUID of the JavaScriptCore binary *and* `kern.bootsessionuuid` — so any cache is invalidated on
  every reboot.

What remains is the in-memory `CodeCacheMap` (10 s working set, 16 MB, 2000 entries, all
hardcoded). Keep `useCodeCache` and `useSourceProviderCache` on.

The only way to get precompiled bytecode is to run our own scripts through the `JSScript` API in a
`JSContext` we control, and accept one warm-up write per boot.

## Preferences

`+[WebView _setCacheModel:]` and the tile knobs above are reached through
`WebPreferences`. Any generated preference not exposed in a header is still reachable through
`-[WebPreferences _setBoolPreferenceForTestingWithValue:forKey:]` with the key from
`UnifiedWebPreferences.yaml` — and the defaults themselves are set in that file's WebCore column,
which is what the port edits rather than calling setters at runtime.

`_setMaxParseDuration:` overrides the 500 ms parser yield limit: raise it to cut runloop overhead
on a slow core, lower it for responsiveness.

Some knobs are dead in current trunk — hardcoded stubs that decide nothing: DNS prefetching, the
offline application cache (removed from WebKit entirely), `requestAnimationFrameEnabled`,
`linkPreloadEnabled`.

## Memory pressure

`WebInstallMemoryPressureHandler()` is already called from `-[WebView _commonInitialization]`, so
the low-memory handler is registered — only the trigger was missing. This system refuses the
ungraded VM pressure source (`dispatch_source_create` returns nothing rather than failing) and the
graded one is iOS 8, so nothing ever reached the handler.

The signal this kernel does export is `kern.memorystatus_level`, the system-wide free-memory
percentage jetsam itself decides on; `LegacyTileCache` already sizes its tile budget from the same
sysctl. `MemoryPressureHandler::install()` now polls it on `s_minimumHoldOffTime` and grades it by
the bands `LegacyTileCache` uses: below 15% critical, below 30% a warning.

Both `WTF::memoryFootprint()` and `WTF::memoryStatus()` were reading `phys_footprint` out of
`task_vm_info`, which this kernel answers at revision 0 — the field is never written and the
returned value was uninitialised stack. They read `MACH_TASK_BASIC_INFO`'s `resident_size` here,
which is also what jetsam judges by on this release. That mattered beyond the pressure handler:
`memoryStatus()` feeds JSC's `Heap::overCriticalMemoryThreshold()`.

`UIApplicationDidReceiveMemoryWarningNotification` is the same pressure graded by the kernel rather
than by us, and is wired to `+[WebView _releaseMemoryNow]` in the app.

Also available: `+[WebCoreStatistics garbageCollectJavaScriptObjects]`, `returnFreeMemoryToSystem`,
`purgeInactiveFontData`, `+[WebCache empty]`.

Under `WEBKIT_IOS6`, `WebInstallMemoryPressureHandler()` (`WebView.mm`) gives the handler a 300 MB
ceiling with fractions 0.5 and 0.65: Conservative from 150 MB, Strict from 195 MB, polled every
10 s, and every poll under either policy releases memory. A heavy page lives under Strict for its
whole life. That looks like a misconfiguration and is what keeps the process alive: with Strict at
236 or 256 MB the retained caches carry a browse of a few heavy sites into a jetsam kill. Leave the
thresholds alone.

What is exempt instead is the cheap part of the release: under `WEBKIT_IOS6`,
`TextMeasurementCache::addSlowCase` and `GlyphDisplayListCache::getDisplayList` keep caching under
pressure, since both are bounded. Dead resources, layer pools, tiles, the back/forward cache and
the font cache are still released.

A jetsam kill leaves a `LowMemory-*.plist` in the device's crash-report directory, naming the
process and its resident pages. Counting those files before and after a run is the cheapest check
of whether a change made the process die.

## Values that look wrong and are not

Each of these is set on purpose. Paths are relative to `webkit-254/Source`.

- **`minimumBytesPerCollectionCycle` = 8 MB on armv7** (`JavaScriptCore/runtime/OptionsList.h`,
  applied in `JavaScriptCore/heap/Heap.cpp`). It is most of the gap between the heap's capacity
  and its live size on a heavy page. Lower, a full collection comes after a few percent of growth,
  frees little and is marked unproductive, which suppresses full collections for up to 45 s while
  the heap keeps growing: the worst case rises instead of falling.
- **`forceICFailure` = false** (`JavaScriptCore/runtime/OptionsList.h`). True leaves every call
  site unlinked and every property access uncached, so the DFG sees no call status and inlines
  nothing: a method call costs 706 ns instead of 71, `node.nodeType` 1235 instead of 60,
  `getElementById` 3175 instead of 610.
- **2 MB block granules** (`JavaScriptCore/heap/Ios6BlockReservationPool.h`). The FastMalloc,
  Gigacage and Structure allocators take their 16 KB `MarkedBlock`s from one pool of 2 MB
  reservations, committing and decommitting per block; a granule stays reserved. Through
  `posix_memalign` every block is a libmalloc VM region of its own: about 3700 regions on a heavy
  page against about 1000, with the same footprint and marking speed.
- **`codeDeletionThresholdMegabytes()` = 275 MB** (`WebCore/page/MemoryRelease.cpp`,
  `WEBKIT_IOS6_CODE_DELETION_THRESHOLD_MB`). Above it a memory release, including the one on every
  top-level navigation, throws away all compiled code, hot functions included. It sits 10 MB above
  `JSC_IOS6_GC_ABSOLUTE_MB` (265, `JavaScriptCore/heap/Heap.cpp`) so the collector runs out of room
  first; move the two together. Below that ceiling it fires on routine navigation and every page
  recompiles.
- **Layer pool 48 MB** (`maximumLayerPoolBytes()`, `WebCore/platform/graphics/ca/LayerPool.cpp`,
  `WEBKIT_IOS6_LAYER_POOL_KB`). A 6 MB pool makes the `position: fixed` bars jitter after minutes
  of scrolling and navigation, their layers rebuilt instead of reused. A short check does not show
  it; a change here needs a soak of real use.
- **`preciseLocalCSEBlockLimit` = 800** (`JavaScriptCore/dfg/DFGCommon.cpp`,
  `WEBKIT_IOS6_DFG_CSE_PRECISE_BLOCK_LIMIT`), a cap over
  `maxDFGNodesInBasicBlockForPreciseAnalysis` (20000). At 20000 the compile time shows up as stalls
  on two cores: a p99 stall of 756 ms and 30 stalls over 400 ms, against 127 ms and one at 800.
- **The DFG worklist is FIFO** (`queueOrderingEnabled()` in `JavaScriptCore/jit/JIT.cpp`, off
  unless `WEBKIT_IOS6_DFG_QUEUE_HOTTEST_FIRST` is set). Ordering by re-warm count is worse on a
  live site: mean wait 571 ms against 317, maximum 2674 ms against 1785, 895 compilations against
  1096. Under real load the queue is long, and the scan on every dequeue costs more than the
  reordering returns.
- **Marking prefetch off, pipeline depth 0, no mark fences** (`JavaScriptCore/heap/SlotVisitor.h`
  and `SlotVisitor.cpp`: `WEBKIT_IOS6_GC_STRUCTURE_PREFETCH`, `WEBKIT_IOS6_GC_BUTTERFLY_PREFETCH`,
  `WEBKIT_IOS6_GC_MARK_PIPELINE_DEPTH`, `WEBKIT_IOS6_GC_MARK_FENCES`). Marking is about four fifths
  of a full collection and bound by memory latency - the cell, its `Structure`, its butterfly, each
  a dependent miss - so a prefetch has nothing to hide: prefetching one object ahead takes a full
  collection from 248 to 274 ms, pipeline depth 8 from 209 to 375 ms; the fences change nothing.
- **The grid's column-axis stretch requirement is ignored** (`WebCore/rendering/RenderGrid.cpp`,
  the `canSetColumnAxisStretchRequirementForItem` branch returns false).
  `logicalHeightForGridItem()` dirties the item and sets that requirement in the same step, so
  honouring it lays out every item of a card grid a second time on every pass with nothing changed:
  a settled feed lays out 7800 blocks in 2100 ms with it and 710 in 250 ms without, with identical
  screenshots.
- **Matched-declarations cache 4 per hash and 1024 in total, match-result cache 512**
  (`WebCore/style/MatchedDeclarationsCache.cpp`, `WebCore/style/MatchResultCache.cpp`). A miss
  rebuilds the whole property cascade, which costs far more than the two style clones an entry
  holds: at 2 and 256, domInteractive on the same page is 7213-12296 ms against 6508-7010, resident
  unchanged. `/tmp/native-small-style-cache` and `/tmp/native-small-match-cache` select the small
  sizes for a comparison.

## Measured dead ends

- **The 32 MB executable pool is address space, not memory.** It is upstream's size for
  `CPU(ARM_THUMB2)` with jump islands (`JavaScriptCore/jit/ExecutableAllocator.cpp`), and the
  allocator commits and frees pages on demand (`notifyNeedPage`, `notifyPageIsFree`), so resident
  JIT memory follows the code actually compiled - 1.7 to 9.7 MB over a heavy scroll session. A
  smaller pool saves no RAM, and running out of it under `JITCompilationMustSucceed` is a crash.
- **The hot objects are already packed.** `Node` is held at its size by upstream's own
  `static_assert` against `SameSizeAsNode` (`WebCore/dom/Node.cpp`), and `JSCell` is 8 bytes
  (`JavaScriptCore/runtime/JSCell.cpp`). Reordering fields gains nothing, and `Structure` fields
  are read at fixed offsets from JIT code.
