# The order and the scope, measured

`build.sh SOURCE.metal` compiles one Metal Shading Language file **at run time** with
`-[MTLDevice newLibraryWithSource:options:]` and `MTLLibraryTypeDynamic`, writes the file with
`-[MTLDynamicLibrary serializeToURL:error:]`, and unpacks its AIR with the same `0xB17C0DE` scan
`tools/air2es/metallib2es.py` does. No `metal` tool is involved: `xcrun -f metal` on this Mac is
`unable to find utility "metal"`, and it is not needed — the host's Metal framework compiles the
source and the runtime writes the file.

## What the two fields are

`scopes.metal` holds both tests. The order test is five threadgroup `fetch_add`s whose **only**
difference is the order; the scope test is the same operation in the same order in a device buffer and
in a threadgroup block. Read out of the AIR:

```
air.atomic.local.add.u.i32  (ptr, value, 0, ORDER, SCOPE, i1)
    i32 1, i32 0, i32 1, i32 2   relaxed
    i32 1, i32 0, i32 2, i32 2   acquire
    i32 1, i32 0, i32 3, i32 2   release
    i32 1, i32 0, i32 4, i32 2   acq_rel
    i32 1, i32 0, i32 5, i32 2   seq_cst
air.atomic.local.load.i32    (ptr, ORDER, SCOPE, i1)
    i32 2, i32 1, i32 2         acquire
```

and cross-checked on the operations that appear once each: an `or` at acq_rel (4), a `max` at
seq_cst (5), an `xchg` at release (3), a store at release (3).

**So the order is the field that varies with the order, and it is Metal's own enumeration —
1 relaxed, 2 acquire, 3 release, 4 acq_rel, 5 seq_cst — which is NOT the C11 enum's values.** That
is the whole mis-mapping that had the tool reading a **threadgroup store's scope** as its order: the
scope is the field that is `2` for a threadgroup atomic and `0` for a device one, and it sits after
the order.

## The device family, measured the same way

`device.metal` holds one **relaxed** operation of every form on a device buffer — twelve of them, from
`add` to the signed `min` — so each form's own layout is read rather than assumed from the threadgroup
one. Every one of them is identical:

```
air.atomic.global.{add,sub,max,min,and,or,xor,xchg,store}.u.i32  (ptr, value, 0, 2, 0, i1)
air.atomic.global.add.s.i32 / .min.s.i32                          (ptr, value, 0, 2, 0, i1)
air.atomic.global.load.i32                                         (ptr,        2, 0, i1)
```

against the threadgroup family, measured on five orders of one operation:

```
air.atomic.local.add.u.i32   (ptr, value, 0, ORDER, SCOPE, i1)    relaxed 0 1 2
```

So both families have the **same** shape — `(ptr, [value], ?, order, scope, i1)` — and differ in
**what the numbers are**: a relaxed device operation carries `2` where a relaxed threadgroup one
carries `1`. That is the piece that had the tool reading a device operation's order as an acquire, and
it is not yet settled **which of the two trailing fields is the scope and which the order in the device
family** — the two families use the same positions and different values, and one reading of them is
consistent with the measurement and so is its opposite.

**So the table is not rewritten yet**, and that is the discipline rather than the delay: a table built
on an unresolved reading of which field is which is a wrong ordering, and a wrong ordering is the one
thing an atomic must never be. The two readings are distinguishable by one more measurement — a
*threadgroup* operation written with `mem_flags::mem_device` would put the device's numbers in the
threadgroup's positions, or a device operation with a mem_flags argument would do the same — and
`orderKernel2` (all five orders, threadgroup) and its device variant are in the tree as the fixtures
that will hold whichever reading wins.

## What a device atomic can carry: one

`deviceOrders` writes the same `fetch_add` with each of the five orders Metal's language has. **Four of
them do not compile**, and that is the measurement — the compiler's own diagnostic is
`candidate disabled: 'order' argument must be 'metal::memory_order_relaxed' if no 'mem_flags' argument
is provided`. A device atomic carries `relaxed` or nothing; the threadgroup family, which takes a
`mem_flags` argument, carries all five.

Also measured: **MSL has no `atomic_compare_exchange_strong`** — the compiler offers only the weak
form, so `air.atomic.local.cmpxchg.weak.i32` is the only compare-exchange a kernel can produce.

## The settling measurement, and what it settled

`settle.metal` writes **the same atomic twice with everything held fixed but the `mem_flags`
argument** — a threadgroup atomic with `mem_threadgroup` and with `mem_device`, and a device atomic
with `mem_device` and with `mem_none`. In all four pairs **only the last field before the `i1` flag
moves**:

```
local.add.u.i32  (ptr, value, 0, 1, 2, i1)   mem_threadgroup
local.add.u.i32  (ptr, value, 0, 1, 1, i1)   mem_device
global.add.u.i32 (ptr, value, 0, 2, 1, i1)   mem_device
global.add.u.i32 (ptr, value, 0, 2, 0, i1)   mem_none
```

**The last field is the scope — 2 threadgroup, 1 device, 0 none — and the field before it is the
order.** That is what settles it: a field that moves when only the scope moves is the scope.

**And the two families number the order differently.** A relaxed *threadgroup* operation carries `1`;
a relaxed *device* operation carries `2`. One table over both numbers is what read a device
operation's relaxed as an `acquire` — which a C atomic store may not take, so an ordinary device
store came out refused. The table is per family now, and the family is the scope the compiler put in
the intrinsic's own name:

| family | order codes, measured |
|---|---|
| `air.atomic.local.*` (threadgroup) | 1 relaxed, 2 acquire, 3 release, 4 acq_rel, 5 seq_cst |
| `air.atomic.global.*` (device) | 2 relaxed — and nothing else, because the language allows no other |

## Real libraries on this Mac that carry `air.kernel`

`air2cpu`'s entry-point discovery reads the named metadata `air.kernel` when there is any, and falls
back to a name heuristic when there is none — because a library **Metal's runtime compiled from
source** has no stage marker at all, while one the **`metal` tool** built has them. The second kind is
what an application actually ships, and there are plenty of them here: `air-kernel-scan.txt` counts
`air.kernel` across every `*.metallib` under `/System/Library` and `/System/iOSSupport`
(150 of them have at least one), on **macOS 27.0 build 26A428, SDK 27.0**.

| `air.kernel` nodes | library |
|---|---|
| 12812 | `/System/Library/PrivateFrameworks/GESS.framework/…/mlx.metallib` |
| 6180 | `/System/Library/PrivateFrameworks/CoreRE.framework/…/default-binaryarchive.metallib` |
| 2920 | `/System/Library/PrivateFrameworks/Vista.framework/…/VSTPrecompiledPipelines.metallib` |
| 1985 | `/System/Library/PrivateFrameworks/Espresso.framework/…/default.metallib` |
| **1837** | **`/System/Library/Frameworks/MetalPerformanceShaders.framework/…/MPSImage…/default.metallib`** |
| 1800 | `/System/Library/Frameworks/CoreImage.framework/…/ubershader_archive_bin.metallib` |
| 1483 | `/System/Library/PrivateFrameworks/Morpheus.framework/…/default.metallib` |
| 1280 | `/System/Library/PrivateFrameworks/MXI.framework/…/mxi_archive.metallib` |
| **894** | **`…/MPSNeuralNetwork…/default.metallib`** |
| 576 | `/System/Library/PrivateFrameworks/GPUToolsReplay.framework/…/default.metallib` |
| **521** | **`…/MPSNDArray…/default.metallib`** |
| 366 | `/System/iOSSupport/System/Library/PrivateFrameworks/VFX.framework/…/default.metallib` |

**What may and may not come out of those files.** Measuring the translator's path on them is fine and
is what the scan is for: they are read **in place**, and what this repository records is their path,
their kernel count and this Mac's build — nothing else. **No kernel from any of them may enter this
repository, not as a fixture, not as expected output, not as a disassembled listing.** MPS's kernels
are Apple's code, and the port's MPS is its own implementation; a port that carried Apple's kernels
translated would be shipping Apple's code, and a test whose expectation came out of one would be
holding the translator to Apple's answer rather than to the kernel it was given. The next family uses
those libraries to *read the shape* of what a real library looks like — the `air.kernel` metadata, the
entry signature, the address spaces — and writes its own kernels.

Three of them are **this band's own next families** — MPSImage, MPSNeuralNetwork and MPSNDArray ship
their kernels as real AIR with real `air.kernel` metadata, which means the path a real application's
`.metallib` takes is measurable here, not only described. They are read **in place**: the files are
system libraries and they are never copied into this repository.
