# Translating the shared cache once instead of once per process

## Why

A 6.0 boot translates 2398898 blocks, and 2255326 of them - 94% - are read from the shared region
(`translation-blocks-shared-region`). That is the dyld shared cache: the same read-only code, mapped
at the same guest addresses, in every one of the 45 processes a boot starts, translated again for
each of them. The emulator runs about 36 MIPS against roughly 800 on the device it emulates, and this
is where most of the difference goes.

## Why it is possible here

Emitted code in this fork is state-relative, not address-baked. A shared slab is refused unless the
runtime state it must not bake in is handed over as link cells (`a32_interface.cpp`: "shared native
code slab requires linked runtime state"), and the emitted code loads those pointers out of the
JitState - the callbacks, the lookup function, the page tables, the exclusive monitor. That is what
already lets the CPUs of one process share one slab, and it is what lets processes share one too.

## Why it cannot simply be switched on

Blocks are keyed by guest address. Two processes hold different code at the same address - each has
its own executable at 0x1000 and its own plugins - so one machine-wide slab for everything executes
one process's code in another. Measured: a boot with a single context for all processes dies at the
second process. The same defect, inside one process, is the 6.1.3 bug this session fixed.

Sharing is therefore restricted to a range where the mapping is provably the same: the shared cache,
which the kernel maps from one file at a fixed address with slide 0 in every process.

## Design

- One machine-wide execution context holds a second slab, the *image slab*, with the shared cache's
  address range. Every Jit keeps its own process slab as today and takes the image slab beside it.
- Lookup: `GetBasicBlock` picks the slab by the block's address. Each slab keeps its own generation,
  so the generation travels with the slab rather than as a parameter of the lookup.
- Emission: a block whose start is in the range is emitted into the image slab, but only if its end
  is in the range too; a block that runs past the boundary belongs to the process slab.
- Execution: `run_code` enters through the prelude of the slab that owns the entry block, and marks
  both slabs as executing so neither retires code under a running thread. Blocks link directly only
  within a slab; a branch that crosses slabs returns to the dispatcher, which resolves it through the
  lookup link as it already does for any block it has not linked.
- Invalidation: a process clearing its cache clears only its own slab. A range invalidation applies
  to the slab or slabs whose range it intersects; for the image slab that is machine-wide, and the
  shared cache being read-only it should not happen at all.
- Divergence: a process that privatises part of the shared region (`shared_region_make_private_np`)
  stops using the image slab from that point. The flag is per process and one-way.

## Stages

1. Thread the second slab through the Jit with the image slab equal to the process slab: no
   behavioural change, every path exercised, tests and a boot green.
2. Give the image slab its own machine-wide context and the range, with the guards above. Measure
   `translation-blocks` and the time to SpringBoard.
3. Fork per test on top of it: one booted machine, a child per test, which is what removes the boot
   from the cost of a test entirely.

## What to watch

- `translation-blocks` and `translation-blocks-shared-region` before and after.
- `jit-shared-used`: 583 MB of code cache for one boot today; most of it should become one copy.
- A 6.1.3 boot, because that is the release with plugin loading and unloading, where a stale block
  shows up as the wrong image's code.

## First measurement of the implementation (2026-09-18)

Stages 1 and 2 are written in the lab tree, not delivered. With the image slab holding the shared
cache's executable range and every process taking it beside its own slab, a 6.0 boot of iPhone3,1:

| | translation-blocks | of which shared region | guest instructions in 150 s |
|---|---|---|---|
| per-process slabs | 2398898 | 2255326 | 4.4 billion |
| shared image slab | 275563 | 241884 | 1.0 billion |

The translation work collapses as predicted - 8.7 times fewer blocks - and the guest reaches
SpringBoard, so the shared code runs correctly in processes that did not translate it. But the guest
then crawls: a quarter of the instructions in the same wall time, one frame instead of 187, and the
stall report fills with processes waiting for replies from processes that are not running.

The cause is the slab's own serialization, not the sharing. One `std::recursive_mutex` guards every
`find_block`, `emit`, `enter_execution`, `leave_execution` and the `touch_code_segment` of every
`run_code`; with one slab per process that is a handful of threads, and with one slab for the machine
it is every thread of every process. `enter_execution` also waits on a condition variable until no
invalidation is pending, which with 45 processes is a stop-the-world.

Next, in this order:

1. Readers in parallel: the block lookup is read-mostly, so the slab needs a shared lock (or a
   lock-free map) rather than one exclusive mutex, and `run_code` must not take the lock at all - its
   only reason is the segment's last-touch, which can be an atomic store.
2. The shared slab is never invalidated - the range is read-only by construction and a process that
   unmaps or reprotects any of it diverges - so `enter_execution` has nothing to wait for there. That
   is already implemented; the wait must simply not exist for a slab that takes no invalidations.
3. Re-measure, then take the guards to a test: two Jits over the same image range with different
   process memory, one translation between them, identical results, and removing the range check
   must make the test fail.

## Where it stands after the second attempt

The lock was not the cause. A lock-free published index in front of the slab's block table (readers
answer without taking the slab lock, anything that removes blocks bumps an epoch) changed nothing:
still 1.0 billion guest instructions in 150 s and one frame.

Sampling the emulator in that state says why it is not contention: the thread that runs guest code
spends 1475 of 1801 samples in `LiveControl::poll()`, which is the session idling. The guest is not
slow, it is not being dispatched. The control channel agrees:

```
[control] status frame=1 submitted-frame=1 processes=52 threads=186 runnable=53 active-process=none
```

Fifty-three runnable guest threads and nothing executing. SpringBoard's main thread is runnable in
dyld's range, not waiting on anything. So the next question is not about the slab at all: it is why
the session's scheduler stops dispatching runnable threads once blocks come from a slab shared
between processes. Candidates, in the order worth testing:

- the execution-slot bookkeeping in `GuestExecutionCoordinator`/`XnuScheduler`, which may treat a
  slot as occupied when a Jit enters two slabs,
- `enter_execution`/`leave_execution` of the second slab returning a generation the scheduler then
  compares against the first slab's,
- an event-transition epoch that is not bumped when a thread becomes runnable, so the session waits
  for a timer instead of dispatching.

Reproduction: `SHADE_SHARED_IMAGE_CODE=1 sh scripts/measure.sh <name> iPhone3,1 <6.0 rootfs> 150`,
then `status` and `threads SpringBoard` through the control pipe once SpringBoard is up.

## The published index served removed blocks (2026-09-19)

The index above was not a harmless experiment: it is on for every Jit, with or without
`SHADE_SHARED_IMAGE_CODE`, and "anything that removes blocks bumps an epoch" was not true. A range
invalidation (`request_range_transition` -> `finish_pending_invalidation` ->
`A32AddressSpace::InvalidateCacheRanges`) removes blocks but keeps the slab's generation, and it
never touched the index. The locked path refuses while `pending_ranges` is non-empty; the index
answered before that check and went on answering after the ranges were retired, with pointers to
translations that no longer existed. Every process that unmapped or reprotected code it had already
run - dyld replacing one image with another at the same base - could jump into a stale block.

On iPhone3,1 6.0 with SpringBoard, an injected dylib and an application that was 45 SIGILL
crashes, all at `pc=0x3476ce0a` (CoreTelephony+0x2ee0a) in the daemons that load CoreTelephony
(run `memfix2-085642`: 45 fatals, 11 frames). The index now forgets everything when a range
invalidation is requested and again when it completes (`published_index.discard()` in
`request_range_transition` and both `InvalidateCacheRanges` paths of `finish_pending_invalidation`).
Same build otherwise, same recipe: 0 fatals, 1089 frames (run `indexfix-133146`). The packaged
emulator never had the index, which is why it booted the same image clean.

The descent session saw the same crash on 5.0 and 5.1.1, which fits a fault of the emulator rather than of a release; those have not been re-run with the fix yet.

## Building HEAD from commits alone

Shade at upstream 411248c calls arm64 umbra interfaces (`NativeCodeSlab`,
`Jit::Precompile`, `Jit::GeneratePortableIR`, `Jit::GetDispatchCounters`, ...) whose arm64
implementations exist only in Charon's `packages/i/shade/patches/2026.09.16/umbra.patch`; the
pinned umbra implements them for x64 only. So an arm64 Mac cannot link HEAD from the submodule
as committed. The reproducible control is upstream 411248c + Charon's `shade.patch` +
`umbra.patch` - what the `shade` package builds - and the lab tree's own work is its difference
from that, not from HEAD. The macOS portability that HEAD itself lacked (stat timestamps, xattr,
libplist iterator, `madvise`, `shared_ptr::unique`) is committed as 4e39ea1 and 63b62e4.
