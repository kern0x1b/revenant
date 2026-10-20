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
second process. The same defect, inside one process, is the 6.1.3 bug in [iOS 6.1.3](ios-6.1.3.md).

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
- Any cache that answers a lookup without the slab's lock must forget its entries whenever a range is
  invalidated. The first prototype's published index kept answering after the ranges were retired,
  and processes that had replaced an image jumped into stale blocks.

## Status

Not in the tree. The prototype of stages 1 and 2 ran on 2026-09-18 and 2026-09-19 and is not delivered.
Its measurements are what the next steps rest on:

| | translation-blocks | of which shared region | guest instructions in 150 s |
|---|---|---|---|
| per-process slabs | 2398898 | 2255326 | 4.4 billion |
| shared image slab | 275563 | 241884 | 1.0 billion |

The translation work collapses as predicted, 8.7 times fewer blocks, and the guest reaches SpringBoard, so
the shared code runs correctly in processes that did not translate it. The guest then crawls: a quarter of the
instructions in the same wall time, and one frame instead of 187.

The slab's own serialization is not the cause of that. One `std::recursive_mutex` guards every lookup, emit and
run of the slab, and `enter_execution` waits on a condition variable until no invalidation is pending. A
lock-free index in front of the block table changed nothing. The thread that runs guest code was idling in
`LiveControl::poll()` while 53 guest threads were runnable and none ran, so the remaining question is the
scheduler's dispatch once blocks come from a slab shared between processes. The candidates, in the order to test
them:

- the execution-slot bookkeeping in `GuestExecutionCoordinator` and `XnuScheduler`, which may treat a slot as
  occupied when a Jit enters two slabs;
- the generation that `enter_execution` and `leave_execution` return for the second slab, which the scheduler may
  compare against the first slab's;
- an event-transition epoch that is not bumped when a thread becomes runnable, so the session waits for a timer
  instead of dispatching.

The next steps are the readers in parallel (a shared lock or a lock-free map, and `run_code` not taking the lock),
a slab that takes no invalidations never waits in `enter_execution`, and a test with two Jits over one image range
and different process memory: one translation between them, identical results, and the test must fail when the
range check is removed.
