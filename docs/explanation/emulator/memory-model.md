# Guest memory under parallel execution

Status: implemented on `work/emulator-memory`. The design is from 2026-10-25; the code is in `dd3c1da0c`, and the CI
runs below are on head `d318d1f5b`. The calibration is in `docs/reference/emulator/performance.md`, section "Why guest
memory accesses leave the inline page table". The CI numbers are in "CI numbers" below.

## Problem

With two guest cores, `AddressSpace::set_parallel_access(true)` runs before the JIT is built
(`runtime/emulator_session.cpp:569` and `:1784`). From then on `jit_read_page_table` and
`jit_write_page_table` return an empty static table (`foundation/address_space.cpp`, the `checked_reads` and
`checked_writes` branches). The JIT then sends every guest load and store to the memory callback, which takes the
address-space lock. In the idle window 99.4% of the callbacks come from that choice.

Calibration on the current main, cold boot, 20 s idle window, two repeats per core count. The host was loaded and
the numbers vary a lot:

| cores | callbacks per window | window CPU | boot to SpringBoard |
|---|---|---|---|
| 1 | 0.74 M, 1.54 M | 4.4 s, 9.0 s | 147 s, 154 s |
| 2 | 101.6 M, 108.4 M | 11.6 s, 7.4 s | 462 s, 108 s |

On one core the callbacks fall by about two orders of magnitude. The CPU and boot-time ranges overlap across
repeats, so they do not show the saving yet.

## Constraints

- Guest behaviour is identical. The probes below keep their meaning.
- The exclusive monitor keeps the ARM semantics that `adb67ad64` gave it: a store-exclusive fails once the
  reserved page's write generation has changed.
- The host must never read freed backing.

## Design

1. Table. Under parallel execution the JIT gets the populated table. Each entry is written with an atomic
   pointer store (`std::atomic_ref`). The JIT reads entries with plain loads, which on arm64 are single-copy
   atomic for an aligned pointer. The refresh rules stay: a page that needs every store to reach the emulator
   (translated code, an exclusive reservation, a file-cached page, a copy-on-write page, a shared-writable page)
   has a null write entry, so its stores still take the callback.

2. Exclusive monitor. The reservation keeps the generation check. A store-exclusive also compares the stored
   value with the value its load-exclusive read. That covers a direct store, which does not advance the
   generation: a store that changed the value fails the store-exclusive.
   Difference from ARM, recorded here: a direct store that writes the reserved value back inside the reservation
   window does not fail the store-exclusive, where ARM fails it. The runtimes that use the monitor (libdispatch,
   OSAtomic, pthread) use value-checked compare-and-swap loops and retry on either result, so their outcomes do not
   change, but the window is real and is an ABA window.

3. Retirement. A guest page is a separate heap object owned by a `shared_ptr<GuestPageBacking>`. It is not inside
   a reserved arena, so a raw pointer to a freed page is a host use-after-free, not a fault that the host can
   absorb. Unmapping, copy-on-write breaks and file eviction therefore null the entries under the lock and move
   the old backing to a retire list. The list is released once every core has returned to the host since the
   retirement. The scheduler runs guest cores in slices, so each core returns at least once per slice.
   A backing that is held only by the retire list is not an owner: the copy-on-write decision counts owners
   (`page_backing_owner_count_locked`, the use count minus the retire list's references), so retiring a backing
   does not add a copy.

4. Code. A write to translated code keeps the callback, because the write entry of a tracked page is null. The idle
   window had no code writes, so this costs nothing measured.

Where it lives: `foundation/address_space.cpp` (`store_jit_entry`, `publish_code_page`, `GuestQuiescence`,
`retire_page_backing_locked`, `reclaim_retired_backings`), `foundation/cpu.cpp` (the slice scope and the publication
on a code read), and `runtime/emulator_session.cpp` (the reclaim before each batch).

## Decisions

1. Code publication: quiescence, no accepted window. A direct store that loaded its write entry before a page
   became code can land after the translation was made, which would leave a stale translation. So before a page
   becomes code, every other guest core reaches a safe point (a block boundary) and acknowledges. The wait runs
   without the address-space lock held, so a core that is waiting for that lock can still reach its safe point.
   Cost per publication, boot `40228044518`: 42,136 publications waited 10,870,771 ns in total, 258 ns on average
   (see "CI numbers"). The mean is far below one guest slice, so the slice bound did not show on average; the
   counters do not give the maximum. The calibration above counts callbacks per window, not publications, so this
   boot is the only measure of the cost.

2. ABA window: accepted, with the difference documented. Guest synchronization is value-based: the generation
   check from `adb67ad64` stays, and the store-exclusive also compares the value. A store sequence that writes A,
   then B, then A to a reserved granule between the load-exclusive and the store-exclusive makes the
   store-exclusive succeed here. On ARM the same sequence fails it, because the architecture clears the monitor on
   another observer's write to the reserved address whatever value that write carries. So the premise that the
   difference is not observable on real hardware does not hold for this sequence. The decision accepts the
   difference anyway. No callbacks are added for these stores.

   Recorded risk: a reference-count update written as load-exclusive, compare, store-exclusive commits a value from
   a stale read when the count goes A, B, A in that window. libdispatch's refcount has that shape. The connect
   probe in `bd31c5b51` hits a libdispatch refcount trap on two cores (old count 1, over-release). Its cause is not
   proven there: it could be a race in the shared monitor, or a libdispatch behaviour that the emulator exposes.
   The probe runs on two cores and on one core, and both results go here. No result exists yet: its first CI run
   failed before the probe ran (see "CI numbers"). A trap on two cores that the code does not remove means this
   decision is wrong for libdispatch and must be reopened.
   The 69,152 exclusive callbacks in the `counted2` idle window (14.0 M callbacks, two cores) show that
   load-exclusive is not rare.

## CI numbers

Only CI runs are cited here. The boot, the copy-on-write test and the check run are on head `d318d1f5b`.

- Boot, run `40228044518`, `emulator.yml` job `boot`: two guest cores, `--time-scale 10`, bounded by
  `--ticks 4000000000`, with `--perf-summary`. The perf summary records the spawn of
  `SpringBoard.app/SpringBoard` at host-ms 1792961256721, 31.9 s after the boot started (host-ms 1792961224816). No
  `[cpu] fatal` line. The run's conclusion is `failure` only because the cleanup step could not remove the read-only
  files of the root filesystem clone; `82468c724` changes that step. `boot.log` is 85 bytes, so the frame counter is
  not in the artifact.
- Memory, whole boot: `memory-callbacks=26956068`, `memory-exclusive=11065220`, `memory-shared-write=9582223`,
  `memory-reservation-write=315778`, `memory-code-write=201686`, `memory-misaligned=49516`,
  `memory-unbacked=42042`, `memory-file-or-cow=8936`.
- Code publication: `code-publications=42136`, `code-publication-wait-ns=10870771`.
- Copy-on-write: `copy-on-write-detaches=13214` over the boot. No boot of the same head without the change was run,
  so this boot does not show whether the retire list adds copies. The deterministic test is the evidence.
- Copy-on-write test: `emulator_copy_on_write_detach_test/copy_on_write_detach` passed in check run `40228037758`
  (head `d318d1f5b`). It forks, unmaps the parent's page, has the child and then the parent write, and expects two
  detaches.
- Check run `40232940328` (head `82468c724`): 193 tests, 98% passed, 2 failed: `SceneKitBackports_audio_test/default`
  and `toolchain_packages/objc_test` (the firmware inventory read did not finish within 60 s). Neither is an emulator
  test. The `package` job failed compiling the SwiftUI demo. Every emulator test in that run passed.
- Probe, run `40231296277` (head `85f5fc06b`): failed before the probe ran. The probe's nested `emulator-guest`
  install downloaded the iOS 6.0 restore image and failed at 34%. No `connect_writable` line exists. `65a744e26`
  fetches the iOS 6.0 shared cache in the probe job; that probe run is pending.
- Measure, run `40232948349`: cancelled before it reported. No branch-against-main numbers exist.

## Verification

- `monitor_counter` (exact count from two threads), `connect_writable_dispatch` and the libdispatch connect probe
  (`bd31c5b51`, the refcount trap). The CI probe is pending, see "CI numbers".
- `emulator_copy_on_write_detach_test/copy_on_write_detach` (deterministic, expects two detaches after a fork):
  passed in check `40228037758`.
- The store and connect probes named `9e7a4a86` (0/2000 and 1989/2000) are not in this repository, even after
  fetching all remotes. Their meaning cannot be checked here until that commit is available.
- The two-core SpringBoard boot is boot `40228044518`, and the emulator tests are in check `40232940328`, where every
  emulator test passed.
