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
