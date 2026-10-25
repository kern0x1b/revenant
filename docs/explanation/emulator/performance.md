# Where the emulator's time goes

The measurements are in [the performance reference](../../reference/emulator/performance.md). This page says why the time goes where it does; the counters it cites are [measured there](../../reference/emulator/performance.md#counters-of-a-120-s-boot).

## What the boot actually spends

An iPhone 4 runs roughly 20 times as many instructions per second as we emulate. The gap is not the
emulation of one instruction, it is how much work is repeated:

1. **Translations are per process.** Each `CpuExecutionPool` builds its own `ExecutionContext`
   (`src/foundation/cpu.cpp:3357`), so the dyld shared cache - the same read-only code at the same
   guest addresses in every process - is translated again for each of the 45 processes a boot starts.
   That is most of the 2.4 million blocks. The fork already has the machinery a shared slab needs: it
   refuses to share unless the runtime state it must not bake in is linked
   (`a32_interface.cpp`, "shared native code slab requires linked runtime state").
2. **The return path is not measured.** The `jit-rsb` counter counts `Run()` entries, not return predictions:
   its misses equal `cpu-exec` (180971 of each in a 2026-10-24 boot) and no hit is counted anywhere. The C++ run
   loop is entered only that many times in 4.0 billion instructions, so most returns never leave native code; which
   native path they take is not counted. `FastDispatchHint` still takes `ReturnToDispatcher` in the backend patch.
3. **The host-yield check is off on the measured path.** `jit-host-yield-checks` is 0 in every 2026-10-24 boot. The
   1.1 billion checks of the 2026-09-18 boot are not reproduced on main; the cause is not identified.

Invalidation is *not* a cost: 42614 range invalidations dropped 597 blocks between them.

## How much of the work is the same code in every process

A counter for blocks first read from the shared region (`translation-blocks-shared-region`) answers
it: **2255326 of 2398898 blocks, 94%**. That is the dyld shared cache - the same read-only code at
the same addresses in every process - translated again for each of them.

Two things measured on the way there:

- A machine-wide execution context for *everything* is not a shortcut: processes hold different code
  at the same addresses (a heap page of one is a library page of another), and the boot dies at the
  second process. Sharing has to be restricted to the shared region, where the mapping is provably
  the same.
- Reusing the host cache between runs does not reduce translation. On 2026-10-24 a warm boot translated the
  same 2250814 blocks as the cold one, with `jit-demand-artifact=0/0/0`. Demand translation does not publish
  artifacts (`cpu.cpp`, the `explicit_artifact_publication_` gate), and the profile modes only precompile in
  `startup` and `idle` (`jit_policy.hpp`). `adaptive` records 15.4 MB of block locations and loads them, but
  nothing imports them, so the second run translated 2248016 blocks. The 15.3 s figure of 2026-09-18 is not
  reproduced.

## What a persisted translation would save, measured 2026-10-25

A translation of one block averages 21.4 µs: the frontend (decode, IR, optimization) and the emit into
native code. The emit is the same work on a hit, so a hit saves only the frontend. Measured in one warm boot
(400 million ticks) with every candidate admitted:

- the stored translation time, what the cold run paid per block: 21.4 µs (4.08 s over 190893 blocks);
- the emit of a block taken from the store: 17.5 µs (3.32 s over 190000 blocks);
- the lookup, payload read and IR deserialization: 22.3 µs (4.23 s over 190150 blocks).

The frontend is the difference, 21.4 − 17.5 ≈ 3.9 µs per block. Across the 2.25 million blocks a warm boot
translates, that is about 9 s of user CPU. A zero-copy store is worth building only if the frontend is above
8.9 µs per block, which would make the saving 20 s. A hit costs 22.3 µs in lookup and deserialization alone,
about five times the frontend it replaces, so the persisted path loses CPU as it is built.

The admission rule rejected 189517 of 190845 candidates, because its 185 µs load estimate is above the saving
for most blocks. Forcing admission shows the block count can fall: 15552 translated blocks in a 400 million tick
warm boot, against 204920 without it, 92% fewer. The CPU cost of those hits is why that is not taken. 777 IR
blocks (0.4%) do not round-trip through the deserializer and stay misses.

Full boots, 4.0 billion ticks, one repeat each, host load varying: cold 2261504 blocks, 166 s user, 193 s wall;
warm 2247932 blocks, 196 s user, 545 s wall. The warm boot imported nothing, only the 256 hotset prefetches.

## The register allocator's seed, measured 2026-10-25

Dynarmic's arm64 register allocator built a `std::random_device` and seeded a `std::mt19937` for every block it
emitted (patch 0009 seeds it once per emitting thread). In the emit profile that `arc4random` path was 3% of the
samples (237 of 8004). The boot matrix ran 4.0 billion ticks (`--time-scale 10`, headless, software GLES), serially,
three cold and three warm boots per build, each warm boot from its cold run's store. The host load varied, so the
spread is the honest figure:

| build | cold, µs per block (min–max) | warm, µs per block (min–max) | cold user s | warm user s |
|-------|------------------------------|------------------------------|-------------|-------------|
| baseline, no 0009 | 21.1 (18.2–24.5) | 22.3 (18.9–25.6) | 111 | 112 |
| patched, 0009 | 19.1 (16.8–22.4) | 23.7 (15.9–30.8) | 109 | 113 |

Translation time is the `translation-compile-ns` counter: the time the arm64 backend spends in one translation
(frontend and emit). Every run translated 2.28–2.29 million blocks and reached SpringBoard with no CPU fault. The
cold difference is 9% in the mean, and the warm one goes the other way, so three repeats cannot tell the two builds
apart. The patch removes a real cost, but about 3% of the emit, which is below what the host noise resolves.

The 2× target is not reached by this change. The next emit items are `RegAlloc::UpdateAllUses` (about 10% of
the samples), `BlockRangeInformation::AddRange` (boost::icl, about 7%) and `Link` with `RelinkForDescriptor` (about
7%). Removing all three would leave about three quarters of the emit, so 2× needs a change to how the register
allocator tracks uses, not one more allocation.

## What would make the matrix affordable

- Share the translated shared cache between processes (1 above): translate UIKit once per machine
  instead of once per process.
- Snapshot and restore a booted machine. The emulator has none (`grep snapshot` finds only perf snapshots),
  so every run pays the whole boot. With one, a test restores in seconds and throws the memory away.
- Run many tests per boot, and do not boot SpringBoard at all for daemon, library and tweak tests.

## Ranking, 2026-10-24

The measurements are in [the reference](../../reference/emulator/performance.md#measured-on-2026-10-24). Each
technique is ranked by the cost it removes from a boot on those counters, and whether it fits one change.

| technique | how it applies here | expected win | fits one pass |
|---|---|---|---|
| Persist translated blocks across boots: publish IR or native code on demand, import it before the dispatcher translates, shared-region blocks first | 2.25 million blocks per boot, 93% from the shared region, none reused today; the machinery (`publish_artifact`, `import_artifact`, the profile) is present but not wired on demand | the frontend only: about 3.9 µs of each 21.4 µs translation, about 9 s of user CPU at 2.25 million blocks; a hit costs 22.3 µs (see above) | no: a hit costs more than the frontend it replaces, and admission rejects 99% of candidates |
| Snapshot and restore a booted machine (qemu's `savevm` is the model: per-subsystem state, then memory) | skips the whole boot; SpringBoard came at 107 s under load; `snapshot` in the control channel is a frame capture, not machine state | the whole boot for every restored test | no: guest memory (2 to 9 GB resident), Mach, BSD, IOKit, device state, scheduler and the file page cache all need a serialised form |
| One shared image slab for the dyld cache across processes | 2.40 million to 0.28 million translations in the 2026-09-18 prototype; the guest then crawls (one frame instead of 187) | most translation time | no: the scheduler dispatch bug in [the shared translation design](shared-translation.md) is unresolved |
| Cache the executable catalog scan | 36962 files, 602 Mach-O images, once per host cache; later boots load the manifest | 8 to 10 s of CPU on a cold host cache, not on warm ones | yes, but a 16-byte prefix read via POSIX `pread` measured no gain (3 runs each, reverted) |
| Shorten the indirect-branch path (qemu-ios's per-site cache with a shared second level, keyed by context) | `FastDispatchHint` takes `ReturnToDispatcher`; the cost is not measured | unknown until the return path is counted | no until the path is measured |
| Make the per-block host-yield check cheaper | the check is 0 on the measured path | none | not applicable |

Light Touch and its qemu-ios fork, read on GitHub on 2026-10-24: chaining of translated blocks (qemu links a block only
when its target is in one page), the indirect-branch cache (two inline entries per site, a shared hash keyed by a
context id), and `savevm`/migration (per-device state plus RAM). Our Dynarmic already links blocks and has a fast
dispatch table, so chaining and a per-site cache could only help the return path, which is not measured yet. The fork's
`contrib/portable/engine-qmp-snapshot.c` and `JIT-SNAPSHOTS.md` are read-only statistics, not machine snapshots.

## Why not another emulator

- armv7 (3GS, 4, 4S, iPad 1 and 2, iPod touch 4) cannot be virtualized on Apple Silicon at all: the
  M-series dropped AArch32, so a hypervisor cannot run those instructions. Any emulator has to
  translate them, which is what this one does.
- QEMU's iOS work targets arm64 devices (t8030 is an iPhone 11) and boots the real kernel without an
  HLE layer: more accurate, slower, and nothing for iOS 6 on an A5.
- touchHLE replaces iPhone OS with its own Foundation and UIKit for iPhone OS 2 and 3 games. It never
  runs the real firmware, so it cannot answer whether a build works on the owner's phone.
- Corellium runs ARM on ARM and is fast, but it is a paid service aimed at modern iOS.
- The one place hardware speed is available is iOS 7 and later on A7 and later, which is arm64:
  Apple Silicon can run that guest code natively under Hypervisor.framework with an HLE kernel. It
  does nothing for the 4S, and it is the right answer for the modern half of the coverage map.
