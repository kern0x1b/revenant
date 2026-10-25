# Emulator performance: measurements

Measured on an Apple M4 Pro (12 cores, 24 GB), one emulator at a time, iPhone3,1 with iOS 6.0 (2026-09-18).

| run | SpringBoard spawned | 100 frames drawn | log |
|---|---|---|---|
| default (trace off) | 19.3 s | 47.8 s | 50 KB |
| `--verbose` (full trace) | 19.4 s | 48.7 s | 7.0 MB |

Tracing is not the cost when the log is a file: 2%. It was the cost in the lab, where every line went
through a per-line timestamp filter on a pipe, and that is why the scripts' boots looked like minutes.
Tracing is now off unless a run asks for it.

## Counters of a 120 s boot

`--perf-summary` of a 120 s boot:

```
cpu-ticks=4363253587        4.4 billion guest instructions, about 36 MIPS
translation-blocks=2396811  2.4 million blocks translated
jit=86                      one JIT per process (and per CPU)
jit-full-generation-clears=84
jit-range-invalidations=42614  which dropped jit-invalidated-descriptors=597 blocks
jit-rsb=0/35724             the return-stack buffer never hit
jit-host-yield-checks=1127753218 for jit-host-yields=8786
```

## Run profile: `xmake emulate run`

`run` boots without SpringBoard and gives each emulated process the default 128 MB JIT cache. The run's clone of the image has the SpringBoard LaunchDaemon plist removed, so the runner does not wait for its services, and the verdict does not need SpringBoard. `launch` keeps both, because it needs SpringBoard to start an app.

### Cause of the footprint

Dynarmic's address space ran `invalidate_all` over its whole code cache when a process created it. On macOS that is `sys_icache_invalidate` over a MAP_JIT range, and the kernel touches every page of the range, so the whole reservation became resident in every process whether or not code was emitted into it. A probe on a MAP_JIT region showed it: invalidating the whole reserved range raised the footprint from 1 MB to 129 MB, and invalidating only the emitted prelude left it at 1 MB.

The fix is the Dynarmic patch `packages/d/dynarmic/patches/0004-Invalidate-only-the-emitted-prelude-when-a-code-cache-is-created.patch`. Both prelude emitters now invalidate from the start of the cache to `code.offset()`, which is the emitted prelude alone. Block emission already invalidates the range it emits into, so no emitted code goes unflushed. The patch is kept apart from the emulator's patches 0001 to 0003.

The other paths that could sweep the slab were read in the patched tree and do not: a cache refill (`AddressSpace::ClearCache`, `ClearCacheAndRanges`) only resets the maps and the code offset, and each block emitted after it invalidates its own range. The remaining `invalidate_all` calls flush a 4 KB spin-lock block, and the emulator's `madvise` is on the guest page table. A refill's footprint was read from the code, not measured.

### Matched pairs

Full boots of iPhone4,1 on 6.1.3, run back to back on one host: each pair is an unfixed build (the same tree with patch 0004 left out) and a fixed build. Each boot logs `host-start-ms` on its first line, the host time of each `spawn-setexec` as `host-ms`, and the same stamp on the `stopped()` milestone, so the time to SpringBoard is its spawn's host time minus the start.

| build | pair | load at start | wall | CPU s (user + sys) | max RSS | peak footprint | footprint at 60 s | SpringBoard spawned |
|---|---|---|---|---|---|---|---|---|
| unfixed | 1 | 10 | 242.8 s | 237.3 (184.0 + 53.3) | 4.40 GiB | 11.7 GiB | 1284 MB | 120 s |
| fixed | 1 | 10 | 240.5 s | 231.4 (186.0 + 45.4) | 2.88 GiB | 4.7 GiB | 445 MB | 119 s |
| unfixed | 2 | 32 | 611.2 s | 456.0 (363.1 + 92.9) | 4.03 GiB | 11.7 GiB | not taken | 123 s |
| fixed | 2 | 32 | 601.3 s | 443.6 (361.2 + 82.5) | 2.90 GiB | 4.7 GiB | not taken | 117 s |

Provenance: the shared package store's Dynarmic source was rewritten at 15:07, after the unfixed build and before the fixed one, so the unfixed build's source can no longer be read. Its binary was checked against the fixed one instead. The store's source now matches main's patches 0001 to 0003 with patch 0004 on every file (generated MIG stubs aside), and the two binaries differ in 125 bytes: the Mach-O UUID, the A32 `EmitPrelude` and three small code blocks. A series that changed the backend's code would have changed far more.

- Peak footprint fell from 11.7 GiB to 4.7 GiB in both pairs, 60%. At 60 s the fixed build's footprint was 445 MB against 1284 MB.
- Peak RSS fell by about a third, 4.4 to 2.9 GiB, since the JIT pages that were resident without any code are gone.
- CPU fell 2.5% and 2.7%, and wall time 1% and 1.6%. Those are within the load spread: CPU-seconds nearly doubled from pair 1 (load 10) to pair 2 (load 32), so only the comparison inside a pair means anything.
- SpringBoard spawned 119 to 120 s after start in pair 1 and 117 to 123 s in pair 2. The spread between pairs is as large as the change, so this table makes no speed claim.

### End-to-end check on the fixed build

`xmake emulate run` of the daemon test `emulatelaunchd` (the port of `toolchain/tests/emulate/launchd`, iPhone4,1 on 6.1.3, built from this branch) passed: the probes found `com.apple.cvmsServ` registered at the first instruction and 244 Mach services declared, and the verdict was pass in 1.9 guest s, 218.8 host s at time scale 10. `/usr/bin/time -l` over the xmake command gave 249 s wall and 109 CPU s (77 user, 33 sys); the emulator's own footprint was not captured for this run.

The device test `toolchain_device/emulator_test` no longer has a queue step: the heavy job pool it tested is gone, and an addon install check replaces it (see `docs/reference/toolchain/tests.md`).

### Earlier 64 MB and 32 MB runs

Before the fix, the cap held the footprint down: 64 MB per process cut the daemon test's peak footprint from 10.4 to 6.5 GB, and 32 MB thrashed its SpringBoard boot and was killed at frame 286. Those runs were on the unfixed build. The fix removes the cost the cap was hiding, so the cap is gone and 128 MB is the default. A smaller cache was not measured on the fixed build.

## Measured on 2026-10-24

Commit `d4dca6c47` with no change. iPhone4,1 on 6.1.3 (10B329), `--time-scale 10 --ticks 4000000000 --perf-summary
--display headless --gles-backend software`. The Mac ran with a load average of 60 to 110 on 12 cores (other workers'
boots and builds), so wall-clock times are not usable here. The table gives user and system CPU from `/usr/bin/time -l`
and the emulator's own counters.

| run | user s | sys s | max RSS | cpu-ticks | translation-blocks | translation timer |
|---|---|---|---|---|---|---|
| cold, fresh host cache | 164.3 | 28.2 | 8.83 GB | 4001602492 | 2250731 | 78.6 s |
| warm, host cache of the cold run | 155.1 | 22.4 | 6.29 GB | 4001602489 | 2250814 | 55.9 s |
| `--jit-profile-mode adaptive --jit-artifact-disk-mib 512`, fresh | 182.6 | 36.1 | 2.24 GB | 4001617723 | 2293500 | 481.8 s |
| the same, reusing that cache | 180.0 | 27.4 | 3.69 GB | 4001602012 | 2248016 | 357.4 s |

`jit-demand-translation-total-ns` is wall time inside Dynarmic's translation, so under this load it bounds what
translation costs on a quiet Mac from above. The warm run translated the same 2250814 blocks as the cold one:
`jit-demand-artifact=0/0/0` in every run, and the adaptive run's artifact file stayed 92 bytes while its profile held
15.4 MB of block locations.

- `jit-rsb=0/180971` is `hits/misses`, and the misses equal `cpu-exec=180971`: the counter is bumped once per entry to
  `Run()` (the Dynarmic patch, `jit_state.rsb_misses`), and no hit is ever counted. The return-stack buffer is not
  measured.
- `jit-host-yield-checks=0 jit-host-yields=0` in all four runs: the per-block host-yield check is not running on this
  path.
- `jit-range-invalidations=41454 jit-invalidated-descriptors=598`, `jit-shared-used=672759848` bytes of code cache.
- The executable catalog, `emulator catalog` with a fresh host cache, three runs on one rootfs: 36962 regular files,
  602 Mach-O images, 1176 entries, 291321 reliable entry points. User 3.3 to 4.3 s, system 5.0 to 7.2 s, wall 38 to 48 s
  under the load. Later boots load the manifest (`source=manifest`).
- SpringBoard spawned 106.6 s after launch in the cold run, under the same load. The other runs were not timed to
  SpringBoard.
- A 30 s `sample` of a warm boot 120 s in shows the translator under `GetCurrentBlockThunk` →
  `AddressSpace::EmitBlock` in the largest stack (1674 samples); the emulator's symbols for its own functions are
  merged by LTO, so the rest of the time is seen only through Dynarmic and libc frames.

## How many emulators run at once

Every emulator start takes one of the machine's slots (`emulator.acquire`): the emulate plugin's boots, its debug
command, the first boot of a golden image, and the runtime driver's boot. The slot files live in
`~/.revenant/emulator-slots` whatever `REVENANT_EMULATOR_ROOT` names, so a test run with a scratch root shares the
machine's slots. The count is `emulator.capacity_of(cores, megabytes)`. Its constants come from the fixed-build rows of
the matched pairs above, pair 1 (load 10) and pair 2 (load 32): CPU was 231.4 s over 240.5 s of wall time and 443.6 s
over 601.3 s, so one core is the upper figure, and the peak footprint was 4.7 GiB in both pairs, rounded up to 4800 MB.
The constants in `toolchain/modules/emulator.lua` are one core and 4800 MB per emulator, with 2 cores and 4096 MB kept
for the system and builds. On the measured machine (12 cores, 24 GB) that is 4 slots. The samples of where an
emulator's threads wait under load are in the next section. They show a booted emulator's main thread busy about
three-quarters of the time after SpringBoard, which is consistent with one core per emulator and leaves the constants
unchanged.

## Where an emulator's time goes under load

Three `sample` windows of 10 s each on one boot of the golden-sample image, under host load of 55 to 128 on 12 cores,
on 2026-10-24. The binary was the package's `emulator boot`, built from the checkout and stripped:

- early: installd startup, about 3:50 into the boot;
- springboard: 18 s after the SpringBoard spawn;
- idle: 60 s after the SpringBoard spawn, with the boot still running.

A thread is busy in a sample when its top frame is not a host wait (`__psynch_cvwait`, `mach_msg`, `poll` and the
like). Across all threads, 96.5%, 96.8% and 96.6% of the samples are waits, so most threads sleep. The main thread
(`com.apple.main-thread`) is busy in 30% of its samples early, 75% after SpringBoard and 77% at idle. Its busy samples
split as follows, as a share of the main thread's busy samples:

| Group | early | springboard | idle |
|---|---|---|---|
| JIT compile (Dynarmic, symbolized) | 41% | 19% | 7% |
| Translated guest code (JIT region) | 7% | 15% | 21% |
| Emulator code with no symbol | 36% | 41% | 42% |
| File and memory syscalls | 0.1% | 8% | 18% |
| Other host syscalls | 0.7% | 2% | 1% |
| malloc, new/delete, TLS | 8% | 6% | 5% |
| Other libraries | 6% | 8% | 6% |

The two unnamed worker threads are busy 32% to 33% of their samples early, mostly in JIT compile and translated code,
and 5% to 8% after SpringBoard. The other threads were never busy in these windows. The `mach_msg2_trap` samples are on
one of these worker threads, not the main thread.

Caveats:

- Each point is one 10 s window. Under load a busy thread can be runnable but not running, so the busy share is an
  upper bound on CPU use.
- The package binary hid its local symbols, so the 36% to 42% in "emulator code with no symbol" is split in the next
  section, which uses a build with debug information.
- The early window overlaps installd's startup, so it shows that phase, not steady state.
- The file and memory syscall share at idle is mostly `getxattr`. Every `getxattr` in the emulator is in
  `filesystem/hfs_metadata.cpp`, which reads the guest's metadata from host xattrs on each stat.

### The unsymbolized bucket, resolved

A build with `-g` keeps the local symbols that the package build hides, so the same kind of sample names the functions.
One boot of that build, before the metadata cache below, gives the main thread's busy samples by group:

| Group | springboard | idle |
|---|---|---|
| Translated guest code (JIT region) | 14% | 34% |
| Memory translation (`AddressSpace`, guest loads and stores) | 10% | 32% |
| File and metadata syscalls | 7% | 15% |
| JIT compile (Dynarmic) | 29% | 4% |
| malloc, free, copies, TLS, locks | 12% | 6% |
| Other emulator code | 17% | 4% |
| Dispatch and block lookup | 5% | 3% |
| HLE and kernel emulation | 3% | 2% |
| Other host syscalls and libraries | 2% | 1% |

Memory translation is the largest emulator group at idle: `AddressSpace::read_integer` and `write_integer` (1,117
samples together), `JitCallbacks::MemoryRead32` and `MemoryWrite32`, and the page-tracking functions behind them. HLE
and dispatch are each 2% to 5% of the main thread's busy time. The two worker threads are busy 4% to 23% of their
samples and do not change the picture.

Grouping: "translated guest code" is the frames in the JIT region; "JIT compile" is `Dynarmic::IR`, `Optimization`,
`Frontend` and the arm64 register allocator and emitter; "memory translation" is `emulator::AddressSpace` and the
`JitCallbacks` memory callbacks; "HLE and kernel" is `CompatibilityKernel`, `XnuScheduler` and the kernel's event
loop; "dispatch" is the block cache and `GuestExecutionPolicy`. The waits are excluded from the busy shares.

### The metadata cache: getxattr at idle

Each guest `stat` reads the guest's metadata from host xattrs: a file's mode, owner, group, flags, catalog id, dates
and Finder info, and the owner and group of every ancestor when the file has none. Before the cache, that was 3,354
`getxattr` calls a second at idle: 33,542 in a 10 s window. The `MetadataProvider` now keeps the results per host path
and name, and drops them on the emulator's own writes under the rootfs: a link, a create, a symlink, a directory, a
rename and any removal through `remove_name`. The same window after the change made 614 calls, about 61 a second.

| Measure | before | after |
|---|---|---|
| `getxattr` calls a second at idle | 3,354 | 61 |
| `getxattr` top-of-stack samples at idle (10 s) | 587 | 19 |
| Process CPU over an 11 s idle window | 70% of a core | 51% of a core |

The CPU row is one window per boot, under host load of 55 to 128, and the two boots did different guest work: translated
guest code was 1,943 idle samples before and 543 after, and the main thread was busy 55% of its springboard samples
before and 84% after. So the cache's saving is the `getxattr` count, not the CPU figure. After the change, the idle
main thread's busy samples move to the kernel's event loop: `descriptor_readable`, `pending_io_deadline_locked` and
`collect_ready_kevents` and the rest of that group take 1,091 samples (28% of its busy time) against 88 before, and
`poll` is the largest wait.

The cache assumes the emulator owns the rootfs while it runs. A host write by another process during a boot is not
seen until the emulator writes under the same path. The test is `emulator/src/filesystem/test/metadata_cache_test.cpp`
(`filesystem.metadata_cache`).

## Why guest memory accesses leave the inline page table, measured 2026-10-25

The window is `perf-begin idle` at 60 s after the SpringBoard spawn and `perf-end` 20 s later, one cold boot,
quit after the window. Each guest load and store that reaches a
memory callback is counted once, by the reason the page table did not serve it (`AddressSpace::jit_slow_path_reason`,
evaluated before the access). Two boots:

| reason | boot 1, 20 s window | boot 2, 20 s window |
|---|---|---|
| all memory callbacks | 76,283,053 | 14,025,124 |
| parallel-checked (the JIT holds the checked tables) | not split out | 13,934,970 (99.4%) |
| other, not split out | 75,320,885 | 0 |
| exclusive (LDREX, STREX, track) | 375,554 | 69,152 |
| shared-write (shared backing or shared writable page) | 430,281 | 550 |
| misaligned | 151,057 | 20,049 |
| unbacked (page not materialized) | 1,949 | 254 |
| reservation-write, file-or-cow, code-write, table-disabled, unmapped | under 3,400 each, 0 for code-write, table-disabled, unmapped | under 100 each |
| process CPU over the window | 9.2 s | 2.2 s |

The table is never disabled in either boot (`jit-page-table-disables=0`). `disable_jit_write_page_table` has no caller.
`disable_jit_page_table` is reached only through `Cpu::set_memory_write_watchpoint`, which runs only with
`--watch-address`.

The boots differ in guest work, so the counts are not a fixed-work comparison: boot 1 spent 4 times the CPU in its
window. The split is the stable part: almost every callback comes from the checked tables.

The checked tables are chosen when the JIT is built. `set_parallel_access(guest_processor_count > 1)` runs before the
CPUs are created (`runtime/emulator_session.cpp:569`, `:1784`), and then `AddressSpace::jit_read_page_table` and
`jit_write_page_table` return an empty static table instead of the populated one (`address_space.cpp:223–254`). The
commit that introduced that choice is `d91976a92` ("Scope direct JIT access to serialized guest execution"); its
message is the title only. The populated tables already exclude the pages that parallel execution cannot read or
write directly (`refresh_jit_page_locked`), so the choice is about what the rest of the design guarantees: a direct
store does not pass through `release_exclusive_write_tracking_locked`, so an exclusive reservation held on another
core would not see it, and a direct access does not hold the lock that serializes mapping changes.

Moving the 2-core guest onto the populated tables is therefore a change to the cross-core memory model, not a cache
tweak, and it is not made here. The 5× target needs that decision first.
