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
| Persist translated blocks across boots: publish IR or native code on demand, import it before the dispatcher translates, shared-region blocks first | 2.25 million blocks per boot, 93% from the shared region, none reused today; the machinery (`publish_artifact`, `import_artifact`, the profile) is present but not wired on demand | translation share of every boot; the timer bounds it at 56 to 79 s of 155 to 164 s user CPU under load | no: publish and import both need validation and invalidation that the cache code does not yet do on demand |
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
