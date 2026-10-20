# Where the emulator's time goes

The measurements are in [the performance reference](../../reference/emulator/performance.md). This page says why the time goes where it does; the counters it cites are [measured there](../../reference/emulator/performance.md#counters-of-a-120-s-boot).

## What the boot actually spends

An iPhone 4 runs roughly 20 times as many instructions per second as we emulate. The gap is not the
emulation of one instruction, it is how much work is repeated:

1. **Translations are per process.** Each `CpuExecutionPool` builds its own `ExecutionContext`
   (`src/foundation/cpu.cpp:3319`), so the dyld shared cache - the same read-only code at the same
   guest addresses in every process - is translated again for each of the 45 processes a boot starts.
   That is most of the 2.4 million blocks. The fork already has the machinery a shared slab needs: it
   refuses to share unless the runtime state it must not bake in is linked
   (`a32_interface.cpp`, "shared native code slab requires linked runtime state").
2. **Every return goes through the dispatcher.** The return-stack buffer hit nothing in 35724
   dispatches.
3. **The host-yield check runs on every block**, 1.1 billion times, to yield 8786 times.

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
- Reusing the host cache between runs helps a little and for another reason: 15.3 s to SpringBoard
  instead of 19.3 s, with the same 2.4 million translations and `jit-demand-artifact=0/0/0`. The
  artifact store holds 2.8 MB against a 583 MB code cache, so it is not carrying translated code
  today.

## What would make the matrix affordable

- Share the translated shared cache between processes (1 above): translate UIKit once per machine
  instead of once per process.
- Snapshot and restore a booted machine. The emulator has none (`grep snapshot` finds only perf snapshots),
  so every run pays the whole boot. With one, a test restores in seconds and throws the memory away.
- Run many tests per boot, and do not boot SpringBoard at all for daemon, library and tweak tests.

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
