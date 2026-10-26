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
`.cache/emulator-slots` whatever `REVENANT_EMULATOR_ROOT` names, so a test run with a scratch root shares the
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

### The kqueue event loop at idle: one host poll per pass

While a thread waits in `kevent` on a host-backed socket, the session probes the host every 1 ms. Each probe calls
`collect_ready_kevents`, which asked `descriptor_readable` about every registration, and a host socket's `readable()` is
one `poll(2)` of its own. So a pass costs one host call per host-backed registration. The probe's deadline and host
requirement are also recomputed, once in each of two or three places per processor.

The base boot (`emulator-after`, the cache build) has the costs above. Its idle sample has `collect_ready_kevents` at
1,038 of 6,446 main-thread samples, 987 of them on the host `poll` line, and `poll` ran 95 times a second. The deadline
and host-requirement scans are 1 to 2% of the main thread's samples (`pending_event_poll_candidates` 79), so a deadline
heap would not change the cost, and no heap was built.

The change asks the host once per pass: `HostReadinessProbe` (`emulator/src/network/host_readiness.cpp`) polls every
host-backed read or write registration of the queue in one `poll(2)` with a zero timeout, and `descriptor_readable` and
`descriptor_writable` take its answer. A socket that `readable()` would not poll (a stream still in its initial state,
or a listener for writes) is not requested, so it gets the same answer as before. The deadline is computed once per
processor per pass. The test is `emulator/src/network/test/host_readiness_test.cpp` (`network.host_readiness`): it
checks each batched answer against one `poll` per descriptor, the unrequested and closed descriptors, and a hangup.

The boot pair does not measure the saving. The base boot had host-backed kqueue waits and the batch boot had none:

| Measure | base (`emulator-after`) | batch (this change) |
|---|---|---|
| Window | 14 s, one boot | 11 s, another boot |
| `getxattr` a second | 195 | 547 |
| `poll` a second | 95 | 0 |
| `collect_ready_kevents`, main-thread samples (10 s) | 1,038 | 59 |
| Host-backed registrations polled per pass | not counted | 0 (156,400 passes over the boot) |

The batch boot's guest did different work, so the count drop is the workload, not the change. Its 156,400 passes made
no host request, so the batched path never ran in it. The reduction from one poll per host registration to one per pass
follows from the code, and the unit test checks that the answers are unchanged, but no boot in this pair shows it. A
boot that waits on a host socket is needed to measure it. Under the host load of 55 to 128 this boot ran in, the base
boot's 987 samples over about 950 polls work out to about 1 ms a call. A `poll` with a zero timeout does little compute,
so that time is most likely the thread waiting for a CPU inside the call. That is an inference from the samples, not
something the counts show.

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

## Measured on 2026-10-25

### Poll calls per pass: a native microbenchmark

The guest-level probe did not finish: under a host load of about 25 its boot stalled, and the run hit its 1800 s limit
before a verdict. The numbers here come from a native loop, `emulator_network_host_readiness_bench`
(`emulator/src/network/test/host_readiness_bench.cpp`). It holds N loopback TCP listeners, connects one client to the
first, and runs passes at a 1 ms pause for 10 s, once with one `poll(2)` per socket and once with `HostReadinessProbe`.
Every mode reported one ready socket per pass. The poll counts come from the `xattrcount.dylib` interposer, which counts
the calls each second. The CPU is `getrusage` over the window. Two runs on one machine:

| N | mode | polls a second (run 1 / run 2) | passes a second (run 1 / run 2) | CPU ms a second (run 1 / run 2) |
|---|---|---|---|---|
| 1 | one poll per socket | 673 / 670 | 669.5 / 666.3 | 2.9 / 4.2 |
| 1 | batched | 674 / 670 | 669.0 / 665.0 | 3.1 / 4.8 |
| 8 | one poll per socket | 5,127 / 5,058 | 637.3 / 627.3 | 11.9 / 16.7 |
| 8 | batched | 668 / 670 | 663.2 / 665.4 | 11.3 / 6.6 |
| 32 | one poll per socket | 16,629 / 17,454 | 518.0 / 544.1 | 59.4 / 43.9 |
| 32 | batched | 401 / 668 | 400.3 / 664.3 | 16.0 / 10.3 |

One poll per socket costs N polls a pass, so its poll count grows with N, about 670 × N a second. The batch stays at one
poll a pass. At N=32 it cuts CPU from 44 to 59 ms a second down to 10 to 16. At N=1 the two modes make the same call and
the CPU is the same within noise. At N=8 the CPU runs disagree (11.9 against 11.3, and 16.7 against 6.6), so this loop
shows no saving there. Batched N=32 passed about 400 times a second in run 1 and about 665 in run 2, under the same load.
That cause is not identified. The poll-count claim holds in this loop. The guest's CPU under a real kqueue wait is not
measured.

### Memory at idle SpringBoard: the baseline

One boot of the HEAD binary (`e35247ec8`, batched poll, no memory change) under `run-footprint.sh`: time scale 10, the
SpringBoard spawn 40 s after launch, and a snapshot 60 s after that. Over the 11 s idle window the process used 8.44 s of
CPU, 77% of a core, and its RSS was 2.07 GiB. The host was shared with other builds (load average 22.6 at 10:06).

`footprint` counts dirty pages, and those include the pages the macOS memory compressor holds:

| Category | Dirty MB | Regions |
|---|---|---|
| Malloc Large | 2,388 | 240 |
| Malloc Small | 1,713 | 443 |
| Untagged (anonymous `mmap`: guest memory, the JIT code cache, renderer buffers) | 722 | 193 |
| Malloc Metadata | 11 | 31 |
| Everything else (`__DATA`, stacks, the kernel page table) | 9 in total | |
| Total physical footprint | 4,843 | 3,765 |

`mapped file` is 102 MB clean, which the footprint does not count. In `vmmap`, the writable regions were 4.7 GB written,
of which 2.1 GB was resident and 2.7 GB swapped out (compressed). The default malloc zone held 15.0 million live blocks,
3.7 GB allocated, 1.7 GB resident and 2.2 GB swapped out. The boot log shows
`Vulkan unavailable` (no `libvk_swiftshader.dylib`), so the renderer was the reference one, and no SwiftShader memory
is in this boot.

### Where the malloc heap's live blocks are

A boot with `MallocStackLogging=1` (a separate boot, footprint 4.5 GB) lists the live allocations with their stacks.
The table groups the single allocations under 16 MB by the innermost emulator frame. These are virtual sizes of live
blocks, not resident bytes. The 1,072 MiB of `clear_jit_page_table_locked` are the JIT page tables, which are `mmap`ed
and not malloc heap, so they are left out of the shares. Sizes are MiB:

| Owner (innermost emulator frame) | MiB | Share of 3,105 MiB |
|---|---|---|
| Dynarmic block translation, unnamed frames under `EmitBlock`, `Link` and `GetCurrentBlockThunk` (9.95 M blocks) | 2,248 | 72% |
| `FilePageCache::load_page` | 182 | 6% |
| `MachOImage::parse` | 150 | 5% |
| `Dynarmic::Backend::Arm64::AddressSpace::EmitBlock` | 107 | 3% |
| `AddressSpace::fault_file_pages` | 93 | 3% |
| `AddressSpace::writable_backing_locked` | 59 | 2% |
| `AddressSpace::copy_in_batch` | 57 | 2% |
| `hfs::MetadataProvider::read_xattr` | 40 | 1% |
| Everything else | 170 | 5% |

The largest single blocks, 1 to 16 MB each, sit under the same unnamed Dynarmic frames. They are growing containers,
including the `BlockRangeInformation::AddRange` interval index that Dynarmic uses for cache invalidation.

### The memory cut: the code-cache bound, measured

The target was a 30% smaller footprint, about 1.45 GB of the 4.84 GB, with no rise in boot time or idle CPU. The target is
not reached, and the default is unchanged.

The JIT code cache is sized adaptively (`adaptive_jit_code_cache_size` in `runtime/resource_policy.cpp`), which chose
128 MB on this host. `--jit-cache-mib` overrides it. Two pairs of boots of the HEAD build, alternating sizes, with the
same script (`run-footprint-jit.sh`): the SpringBoard spawn, then 60 s, then the idle window. The host load average was 7
to 9 at each launch.

| Run | cache | boot s | RSS MB | idle CPU s over 11 s | footprint MB | Malloc Large MB | Malloc Small MB |
|---|---|---|---|---|---|---|---|
| 1 | 64 MB | 50 | 660 | 9.08 | 4,357 | 2,088 | 1,563 |
| 1 | 128 MB | 40 | 998 | 8.72 | 4,375 | 2,107 | 1,572 |
| 2 | 64 MB | 45 | 930 | 9.05 | 4,185 | 1,986 | 1,537 |
| 2 | 128 MB | 50 | 751 | 8.33 | 4,408 | 2,102 | 1,609 |

- Going from 128 MB to 64 MB lowered the mean footprint by about 120 MB, 2.7%, and the malloc categories by about 3%. That
  is far from 30%.
- The 64 MB runs used about 0.5 s more idle CPU in the 11 s window (9.07 against 8.53 on average). Two runs each cannot
  separate that from load. Boot time did not show a difference (47.5 s against 45 s on average).
- The 128 MB runs in this window (4,375 and 4,408 MB) are the matched baseline. The 09:53 baseline of 4,843 MB has the same
  config and sat about 10% higher. The footprint moves that much between windows, so only matched runs compare. The
  split moved too: the sweep runs had 0.36 to 0.54 GB resident and 3.6 to 3.9 GB swapped out, against 2.1 GB and 2.7 GB in
  the baseline.
- Halving the cache moved the footprint by about 3%, so the footprint does not scale with the cache size. The sweep was
  not stack-logged, so which owner stayed the same was not measured.

So the code-cache bound is not the cut. Reaching 30% needs one of two changes, and neither is in this commit:

- Dynarmic's per-block bookkeeping (the `BlockRangeInformation` interval index, the patch vectors and the 1 to 16 MB
  containers under `EmitBlock` and `Link`) made smaller or sparser. This is a backend change with a boot-time measurement.
- A translation cache with usage-based eviction in the backend. Each eviction costs a retranslation, so it needs the
  boot-time and idle-CPU limits measured on a quiet host, which this machine was not.

The choice between them is the coordinator's. The per-owner resident bytes are still unmeasured.

The next section takes the first of the two: the per-block bookkeeping.

## Per-block bookkeeping: measured 2026-10-25

The live-block table above put 72% of the malloc heap under Dynarmic's block translation. A stats build (an environment
flag, not committed) printed the containers of one address space each time it had translated another 20,000 blocks. The
checkpoint below is the one with 17,072 live blocks, from the build before the change, with the default robin_map load
factor of 0.5:

| Structure | Bytes | Per block |
|---|---|---|
| `block_infos` buckets (65,536 slots of 208 B) | 13.63 MB | 798 B |
| `block_references` (20,707 descriptors, 26,140 referrers) | 6.22 MB | 364 B |
| Emit-time relocations (142,371 entries of 16 B) | 2.28 MB | 133 B |
| `block_relocations` (26,508 entries) | 2.10 MB | 123 B |
| Code, for comparison | 6.78 MB | 397 B |

The bookkeeping came to 1,419 B a block against 397 B of code. The `block_entries` map was sized the same way and was not
changed here.

The IR is not kept after emit. In the default path `translation_completed` returns before any artifact is published or
recorded, unless artifact publication is on (`emulator/src/foundation/cpu.cpp`, the early return near line 1237). The IR
block is a local of the translate-and-emit call and is freed on return. Persistence is off, so there was nothing to
drop here.

Retranslation, per address space. At each checkpoint the stats build counted unique guest descriptors against all
translations:

| Translations in the address space | Unique descriptors | Repeats |
|---|---|---|
| 20,000 (9 samples) | 18,070 to 18,844 | 6% to 10% |
| 40,000 (4 samples) | 37,784 to 38,822 | 3% to 6% |
| 60,000 (1 sample) | 57,916 | 3.5% |

No sample had a retirement (`retired=0`), so these repeats did not come from `RetireCodeRange`. The source of the repeats
is not identified. The boot-wide unique count was not taken, so the 2.28 M translations per boot have no matching unique
count here, and no retranslation saving is claimed.

The change (patch `0010-Keep-the-per-block-bookkeeping-compact.patch`, in `packages/d/dynarmic/patches/`):

- `block_infos` stores a copy of the emitted info without the emit-time relocation list.
- `block_references` holds a vector of entry points per descriptor, not a set. `RetireCodeRange` removes an entry point
  with `std::remove` and drops the descriptor when its list is empty.
- `block_relocations` and the fastmem patch list are vectors, not per-block maps.
- `ClearCache` swaps each container for an empty one, so the buckets are released. `block_infos` uses a 0.9 maximum
  load factor.
- `Link` no longer checks for a duplicate referrer (a block links each target once, and `std::remove` already removes
  every copy). `RelinkForDescriptor` no longer inserts an empty entry for a descriptor with no referrers.

The dynarmic patch was measured in alternating boots against the control. The control is `main` with dynarmic patches 1
to 9. Each boot ran `run-footprint-v2.sh`: the SpringBoard spawn, then 60 s, then a 10 to 19 s idle window. The host load
is the load average at launch.

Footprint, MB (`footprint`, dirty plus compressed):

| Pair | Control | Compact | Change |
|---|---|---|---|
| A, round 1 (load 5.6, earlier build with the duplicate check) | 4,723 | 3,104 | −34% |
| A, round 2 (load 4.7, earlier build with the duplicate check) | 4,571 | 2,551 | −44% |
| B, round 1 (load 15 to 16, final build) | 3,540 | 2,382 | −33% |
| B, round 2 (load 17 to 39, final build) | 2,842 | 1,715 | −40% |

The final build (set B) averages 3,191 MB against 2,049 MB, −36%. Both final pairs are past the −30% target. Two pairs
per build are too few to bound the spread, so the number needs a repeat on a quiet host.

Boot, the SpringBoard spawn:

| Pair | Control wall s (CPU s at spawn) | Compact wall s (CPU s at spawn) | Load at start |
|---|---|---|---|
| A, round 1 | 40 (39.9) | 35 (35.7) | 5.6 |
| A, round 2 | 35 (35.6) | 50 (50.5) | 4.7 |
| B, round 1 | 111 (65.6) | 132 (70.3) | 15.0 |
| B, round 2 | 208 (72.7) | 182 (62.1) | 17.3 |

Within the control build the wall-clock time runs from 35 s to 208 s, so it follows the host load. The CPU at spawn is
steadier. The final build averages 66.2 s against 69.1 s for the control. The earlier build with the duplicate check
(set A) averaged 43.1 s against 37.8 s, a rise of about 5 s that the final build does not show. Two pairs cannot tell
whether that rise was real.

Idle CPU, cores over the idle window:

| Pair | Control | Compact |
|---|---|---|
| A, rounds 1 and 2 | 0.90, 0.81 | 0.91, 0.73 |
| B, rounds 1 and 2 | 0.56, 0.18 | 0.25, 0.25 |

Within one build the idle CPU ranges from 0.18 to 0.91 cores, so these pairs do not separate the builds, and nothing
here shows a rise.

The dynarmic suite passes with the patch: 47 test cases and 200,561 assertions, built with
`DYNARMIC_ENABLE_TEST_EMIT_FAILURE=ON` (the fault-injection hooks, so the emit-failure paths run).

Not done: the retranslation source, the `block_entries` map, and a quiet-host repeat of the footprint and boot pairs.
The next section supersedes the first two items.

## Retranslation: the exec reset and the shared image slab, measured 2026-10-25

A repeat is a descriptor emitted again in the same address space after an invalidation removed it. A probe build (not
committed) tagged every removed descriptor with the call that removed it and counted the repeats by that tag. The
counts come from one default boot, with the probe reporting every 100,000 emits.

Default boot, 1.9 M emits by SpringBoard plus the idle window:

| Removed by | Repeats |
|---|---|
| Exec reset, `emulator/src/runtime/emulator_session.cpp:3913` (`exec_cpu.clear_cache()` after the new image is loaded) | 110,192 |
| Range invalidation, `userland_hle.cpp:2479` and `kernel.cpp:3075` | 8 |

That is 110,200 repeats in 1.9 M emits, 5.8%. The repeats fall in two 16 MB regions of guest address space: 0x39 has
94,445 (86%) and 0x2f has 15,627 (14%). On this device those regions hold the shared-cache libraries; that is inferred
from the addresses and not checked against the mapping. An exec reset clears the runtime's native code slab, so the
new image translates the same library code again.

With `--shared-image-slab` (the machine-wide image slab, which survives an exec), the same probe at 500,000 emits:

| Region or reason | Repeats |
|---|---|
| Exec reset | 15,816 |
| Region 0x39 | 47 |
| Region 0x2f | 15,767 |

The image slab removes the 0x39 repeats. The 0x2f repeats remain; the section at the end of this file identifies them as dyld. The emit total for
the slab boot is lower: the probe's last report was at 500,000 emits, against 1.9 M for the default boot to the same
point in the boot.

Footprint, boot CPU and idle CPU on clean `main` (no probe), two alternating rounds, host load 9 to 58:

| Pair | Default MB | `--shared-image-slab` MB | Change |
|---|---|---|---|
| 1 | 2,885 | 1,615 | −44% |
| 2 | 2,669 | 1,399 | −48% |

The mean is 2,777 MB against 1,507 MB, −46%. CPU to the SpringBoard spawn was 54.2 and 54.4 s by default against 29.8 and
35.0 s with the flag, about 38% less. The wall-clock boot times were 55 and 65 s by default and 30 and 41 s with the
flag, with load averages at launch of 40 and 12 against 11 and 10, so they are not comparable. Idle CPU was 0.37 and
0.71 cores by default and 1.32 and 0.51 with the flag, over 11 to 13 s windows; that does not settle a difference.

The flag was opt-in when this was measured. The default changes in the section at the end of this file.

The reverse block index is now a sorted vector (patch `0011-Keep-the-reverse-block-index-in-a-sorted-vector.patch`). Its
`std::map` node was 48 B a block, and a vector entry is 16 B plus the spare capacity, about 25 to 30 B a block saved, or
about 2% of the 1,419 B of bookkeeping per block. The dynarmic suite passes (47 test cases, 200,561 assertions). A sanity
boot reaches SpringBoard with a footprint of 2,697 MB, inside the default range above, so the saving is too small to
show in single boots.

`block_entries` stays at the default 0.5 load factor. It holds 65,536 buckets for 17,072 blocks, about 1.6 MB or 92 B a
block at 24 B a bucket. A maximum load factor of 0.9 would halve that, but the map is the lookup for every link and
native-slab find, and robin-hood probes lengthen at 0.9. That lookup cost needs measuring before the change is made.

## The shared image slab is the default, and the 0x2f repeats are dyld, measured 2026-10-25

`--shared-image-slab` is now the default, and `--no-shared-image-slab` turns the machine-wide image slab off.
`--image-slab-mib` still needs the slab, so only `--no-shared-image-slab` makes it fail.

The slab publishes translations by guest address and does not record which process made them. That is sound only while
every process that runs an address runs the same bytes there. A process can break that: copy-on-write detaches a page
it writes, and the userland HLE writes trampolines and continuation SVCs into guest memory (`userland_hle.cpp`). Before
the flip, `emulator/tests/unit/image_slab_test.cpp` showed the hole. A process that writes its private copy of a shared
page and invalidates it publishes that code into the slab, and a clean process then runs it. With the rule below
disabled, the test fails with `clean.run() is 7, expected 1`.

The rule: an `ExecutionContext` that invalidates a range inside the image region is private from then on. Its Jit is
built without the machine slab, and the Jit is rebuilt at the next run boundary (`service_pending_shared_invalidation`).
Clean processes keep the slab. The test checks that a process runs the new code after an exec and a copy-on-write
write and invalidate, that a clean process still runs the original bytes after another process wrote, and that the
writer does not grow the slab. The machine-wide invalidation still happens on every write. Not covered: mprotect and
unmap reach the same `request_cache_range` call (`kernel.cpp:2989`, `3075`, `3101`), and the test calls that function
rather than the kernel path.

Results:

- The suite (`./xmakew test -P .`) ran 177 tests: 176 passed, including `emulator_image_slab_test` and
  `emulator_machine_image_region_test`. One failed: `toolchain_light/compat_test`, a host libdispatch cancellation
  probe. It timed out once and failed on a timing measurement the second time. Nothing in this change is in its build,
  and it was not checked on `main`.
- A boot with the default prints `[jit] image-slab-mib=shared`. SpringBoard finished starting after 66 s wall (52.6 s
  of CPU at spawn) at load 25, and after 246 s at load 22 to 33. The footprint at the default was not measured:
  `vmmap` and `footprint` did not return in two attempts. The paired numbers above (2,777 MB by default and 1,507 MB
  with the flag) are the footprint evidence, since the default takes that path.

The 0x2f repeats. A probe tagged each repeat by reason, by 1 MiB region and by 64 KiB page (dynarmic patch 0012, reverted
by hand). In the default boot, the first 2.5 M emits held 17,449 repeats. SpringBoard was not reached within 900 s at
load 20 to 25, so the probe covers the boot before it:

| Reason or place | Repeats |
|---|---|
| Clear (the exec reset) | 17,435 of 17,449 |
| Region 0x2f | 17,360 |
| Page 0x2fe10000 | 12,781 |
| Page 0x2fe00000 | 4,579 |

The boot log has `[loader] dyld_entry=0x2fe01028`. So the 0x2f repeats are dyld, mapped at 0x2fe00000. On the classic
layout the shared region starts at 0x30000000, so the image slab does not cover dyld. Each exec clears the native slab
(`emulator_session.cpp:3913`), and every process retranslates dyld: about 0.7% of emits in this boot.

The candidate fix, dyld in the image slab as a second range under the same copy-on-write rule, is measured in the next
section.

Not done: the `block_entries` load factor, and a quiet-host repeat of the footprint and boot pairs.

## dyld in the machine image slab, measured on CI 2026-10-26

The branch puts dyld's `__TEXT` in the machine-wide image slab as a second range, under the same copy-on-write rule as the
shared cache (dynarmic patch 0012; the emulator reads the range from `usr/lib/dyld`). While the slab is on, a process
whose dynamic linker is not that system file is refused. Measured with `emulator.yml` job `measure`: branch `ac1d5f5ae`
against `control=main`, two alternating rounds, on the GitHub macOS runner (run 40232911987). Each boot runs to 4·10⁹
guest ticks, so the guest does the same work in every boot: `cpu-ticks` is 4,001,587,547 to 4,001,588,027 and each boot
makes about 542k SVCs.

| Build | Round | Real s | User s | Sys s | Max RSS MB | Peak footprint MB | Translated blocks | Translation compile s |
|---|---|---|---|---|---|---|---|---|
| control (main) | 1 | 209.6 | 195.0 | 19.5 | 2,368 | 3,055 | 2,276,890 | 50.05 |
| branch | 1 | 201.3 | 187.7 | 18.4 | 2,326 | 3,011 | 2,226,861 | 46.93 |
| branch | 2 | 177.2 | 172.8 | 15.2 | 2,534 | 3,006 | 2,226,849 | 42.03 |
| control (main) | 2 | 198.7 | 190.2 | 17.9 | 2,427 | 3,061 | 2,276,875 | 47.32 |

Means of the two boots per build, branch against control: real 189.3 s against 204.2 s (−7%), user 180.3 s against 192.6 s
(−6%), peak footprint 3,008 MB against 3,058 MB (−2%), translated blocks 2,226,855 against 2,276,882 (−2.2%), translation
compile 44.5 s against 48.7 s (−9%). The jit-cache bytes fall from 705.7 MB to 695.9 MB. The invalidation counts are the
same in all four boots (43,792 shared, 82 full), so the workload is the same and the difference is in translation.

Caveats:

- Two pairs. Within the branch build, real time spans 177 s to 201 s, so the wall-clock gain is suggestive, not settled.
  Both rounds point the same way on user time and on translation compile.
- The boots stop at the tick budget, not at SpringBoard finish. CPU to SpringBoard was not measured on CI.
- The CI output has no repeat tally, so the 17,449 repeats of the local probe have no after-number. Translated blocks is
  the proxy.
- The counter that fell, `translation-blocks-shared-region` (2,099,646 to 2,049,623), is the shared-region count, not a
  dyld count. The counters don't split region 0x2f, so this run does not show which blocks were saved. A per-region tally
  on CI would settle it.
- The first measure dispatch (run 40228062638) stopped after its first control boot: the read-only dyld cache each boot
  leaves in its rootfs clone made `rm -rf` fail. `emulator.yml` now makes each clone writable before removing it.
