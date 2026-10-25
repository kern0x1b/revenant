# Guest memory under parallel execution

Status: design, 2026-10-25. Not implemented. The measurements are in `docs/reference/emulator/performance.md`,
section "Why guest memory accesses leave the inline page table".

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

4. Code. A write to translated code keeps the callback, because the write entry of a tracked page is null. The idle
   window had no code writes, so this costs nothing measured.

## Decisions

1. Code publication: quiescence, no accepted window. A direct store that loaded its write entry before a page
   became code can land after the translation was made, which would leave a stale translation. So before a page
   becomes code, every other guest core reaches a safe point (a block boundary) and acknowledges. The wait runs
   without the address-space lock held, so a core that is waiting for that lock can still reach its safe point.
   Cost per publication: not measured yet. The calibration counts callbacks, translation blocks and CPU per
   window, but not publications (a page's first translation), so it cannot give the cost. The code step adds a
   publication counter and a timer around the wait, and records the numbers here. The expected bound is one guest
   slice of each other core, if a core reaches a block boundary when its slice ends. The code step checks that
   assumption before it relies on it.

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
   The code step runs that probe on two cores and on one core and records both results here. A trap on two cores
   that the code step does not remove means this decision is wrong for libdispatch and must be reopened.
   The 69,152 exclusive callbacks in the `counted2` idle window (14.0 M callbacks, two cores) show that
   load-exclusive is not rare.

## Verification

- `monitor_counter` (exact count from two threads), `connect_writable_dispatch` and the libdispatch connect probe
  (`bd31c5b51`, the refcount trap).
- The store and connect probes named `9e7a4a86` (0/2000 and 1989/2000) are not in this repository, even after
  fetching all remotes. Their meaning cannot be checked here until that commit is available.
- The emulator tests, the dynarmic suite, and a SpringBoard boot on two cores.
