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

## Open decisions

- Code publication. A direct store that loaded its write entry before the page became code can land after the
  translation was made, which leaves a stale translation. Closing it needs the other cores to leave the JIT before
  a page becomes code. The options are a quiescence wait at publication, which must run without the address-space
  lock or it can deadlock, or accepting and documenting the window. This blocks the code step.
- The ABA window in step 2. Accept and document it, or send the stores next to a reservation through the callback,
  which brings back callbacks.

## Verification

- `monitor_counter` (exact count from two threads), `connect_writable_dispatch` and the libdispatch connect probe
  (`bd31c5b51`, the refcount trap).
- The store and connect probes named `9e7a4a86` (0/2000 and 1989/2000) are not in this repository, even after
  fetching all remotes. Their meaning cannot be checked here until that commit is available.
- The emulator tests, the dynarmic suite, and a SpringBoard boot on two cores.
