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

`run` boots without SpringBoard and with a 64 MB JIT cache per process. The run's clone of the image has the SpringBoard LaunchDaemon plist removed, so the runner does not wait for its services, and the verdict does not need SpringBoard. `launch` keeps both, because it needs SpringBoard to start an app.

Measured on one 12-core, 24 GB host shared with other workers, one run per row. The load average at start is in the table. Wall time follows that load: the same daemon test took 110 s at load 17 and 531 s at load 65, so compare CPU seconds and peak footprint, not wall time.

Daemon test (a guest `launchctl version` job, about 100 s on an idle host):

| profile | SpringBoard | JIT cache | load at start | wall | CPU s | peak RSS | peak footprint |
|---|---|---|---|---|---|---|---|
| before | yes | 128 MB | 17 | 110 s | 90 | 4.34 GB | 10.39 GB |
| before | yes | 128 MB | 65 | 531 s | 108 | 4.88 GB | 9.92 GB |
| SpringBoard removed | no | 128 MB | 54 | 477 s | 104 | 4.49 GB | 9.93 GB |
| 64 MB cache | yes | 64 MB | 49 | 494 s | 103 | 3.57 GB | 6.57 GB |
| run profile | no | 64 MB | 26 | 102 s | 89 | 4.19 GB | 6.53 GB |

Full boot to service check-in (SpringBoard launched, not matched in work; the runs stop at different points):

| profile | load at start | wall | CPU s | peak RSS | peak footprint | JIT reserved | JIT committed |
|---|---|---|---|---|---|---|---|
| 128 MB, frame output | 28 | 311 s | 291 | 5.33 GB | 13.04 GB | 7.65 GB | 0.74 GB |
| 64 MB, `--ticks` | 77 | 1176 s | 323 | 6.02 GB | 9.31 GB | 4.23 GB | 0.77 GB |
| 128 MB, no frame output | 89 | 1334 s | 321 | 4.25 GB | 13.59 GB | 8.05 GB | 0.77 GB |

What the rows show:

- Removing SpringBoard from the run changed no footprint in the daemon test (9.92 to 9.93 GB at 128 MB). RSS fell 0.39 GB and CPU fell 4% at near-equal load, which is within what load does to these numbers.
- The 64 MB cache cut peak footprint from 10.4 GB to 6.5 GB (37%) against the same daemon test, with CPU and wall unchanged within the load spread (89 to 103 CPU s).
- The full boot at 64 MB reached service check-in with 157 services against 158 at 128 MB. Its footprint was lower and its RSS was higher (5.33 to 6.02 GB). Committed JIT memory did not fall (0.74 to 0.77 GB) while reserved JIT memory fell from 7.65 to 4.23 GB, so the footprint cut is not yet explained by committed code.
- 32 MB was rejected. Its SpringBoard boot thrashed the cache, ran far slower than the 64 MB runs, and did not finish: it was killed at frame 286.

Not measured: wall time to SpringBoard. The boot log has no host time stamp for the SpringBoard spawn or for check-in, so these numbers give only whole-run wall time.
