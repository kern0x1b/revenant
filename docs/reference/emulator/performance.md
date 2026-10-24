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
machine's slots. The count is `emulator.capacity_of(cores, megabytes)`, sized from the measurements above: a full boot
kept about one core busy (231 CPU s in 240 s of wall time, fixed build), and its peak footprint was 4.7 GiB. The
constants in `toolchain/modules/emulator.lua` are one core and 4800 MB per emulator, with 2 cores and 4096 MB kept for
the system and builds. On the measured machine (12 cores, 24 GB) that is 4 slots.
