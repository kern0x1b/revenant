# The core of Metal Performance Shaders on this port

`MPSKernel`, `MPSState`, `MPSStateResourceList`, `MPSPredicate`, `MPSCommandBuffer`, the two functions
`MPSCoreTypes.h` and `MetalPerformanceShaders.h` declare, and `MPSRectNoClip`. The matrix and vector
kernels built on them are in [Matrix.md](Matrix.md).

Source: the headers of `MPSCore` in the SDK of iOS 16.4, which is the SDK this package compiles
against, for every signature, default and formula; the behaviour was measured against the MPS of macOS
26.5 by `tests/backports/host/mpsmatrix/run.sh`, which runs the same program twice, once against the
system's own MPS and once against this port's classes compiled under names of their own, and compares
the two answers element by element.

## What the device is

MPS asks a question of a device: can this one run an MPS kernel. `MPSSupportsMTLDevice` answers it, and
on this port every `MTLDevice` that exists is charon's own OpenGL ES 2.0 bridge
(`facts/Metal/RenderPath.md`), over which every kernel in this library runs, so the answer is yes for
any device and no for none. `MPSGetPreferredDevice` walks devices in the release and returns the first
that matches the `MPSDeviceOptions` given; this port has one device and no removable or low-power
choice among several, so it returns that one and the options have nothing to choose between.

`MPSRectNoClip` is the release's "do not clip" region. Its value was read from the running system, not
assumed: `MTLRegionMake(0, 0, 0, -1, -1, -1)` — an origin at the first pixel and a negative size, which
is the region no pixel lies in.

## MPSKernel

The base of every kernel: a device, a label and `MPSKernelOptions`, all of which the port keeps and
reads back. `options` is a set of hints the release's kernels act on — skip API validation, allow
reduced precision, disable internal tiling, insert debug groups, be verbose. This port's kernels run on
the CPU with their own size checks rather than the release's, so `MPSKernelOptionsSkipAPIValidation`
has nothing to switch off; the other four are kept and read back and nothing here acts on them, which
is recorded rather than hidden: they are performance and diagnostics hints for a GPU pipeline, and
this port has no GPU pipeline to hint.

`copyWithZone:device:` and `initWithCoder:device:` carry what the class carries. A subclass's own state
— a neuron's type and parameters, a kernel's shape, its transpositions, its scales — is copied and
encoded by the subclass that declares it, which is what the release's own per-class overrides do.
`-initWithCoder:` without a device decodes on the port's own device, which is the only device there is.

## MPSState

A state is the storage a kernel writes its intermediate results into, described before it runs: some
buffers of given sizes, some textures of given descriptors, or resources the caller already has. This
port keeps the description and makes the storage from the device when `-resourceAtIndex:allocateMemory:`
or `-resource` is asked for it, which is what the release does with a heap sub-allocation and differs
only in where the bytes come from — the device's allocator, which is where the heap's own storage comes
from. `-resourceAtIndex:allocateMemory:NO` answers the resource if the caller supplied one and nil
otherwise, since asking for it without the memory to hold it is a question with no answer.
`-bufferSizeAtIndex:`, `-textureInfoAtIndex:` and `-resourceTypeAtIndex:` answer from the description,
and `-resourceSize` the bytes the description implies.

A temporary state (`+temporaryStateWithCommandBuffer:` and its three siblings) is the same state marked
temporary, with a read count. The release returns a temporary state's storage to its own heap as soon as
the read count reaches zero, which is what lets the next temporary alias it. There is no pool here, so
nothing is invalidated: `-readCount` is kept and a kernel that reads a temporary decrements it, and the
storage stays valid whatever the count says. That is a weaker promise than the release's in one
direction only — a caller that relies on the contents becoming undefined will read what it wrote,
which is not a wrong answer — and `MPSStateBatchIncrementReadCount` clamps at zero and at
`NSUIntegerMax` as an unsigned count of remaining reads does.

`-destinationImageDescriptorForSourceImages:sourceStates:forKernel:suggestedDescriptor:` is **not**
carried yet: it answers a descriptor built from `MPSImage`, and `MPSImage` is the next part of this
library. Until it is, `respondsToSelector:` answers honestly for it, and the registry entry says so.

## MPSPredicate and MPSCommandBuffer

A predicate is a `uint32` in a buffer: not zero runs the kernel, zero does not. The port reads the same
four bytes the release's does, so a caller that fills a predicate buffer on the CPU and hands it to an
`MPSCommandBuffer` gets the same branch. `+predicateWithBuffer:offset:` wraps a buffer the caller owns.
`-initWithDevice:` is the release's other initialiser, which takes its predicate bytes from an MPS heap
and never shows the caller the buffer; there is no MPS heap here, so this port makes a four byte buffer
of its own and answers it through `-predicateBuffer`, which a caller may write through.

`MPSCommandBuffer` wraps a command buffer and carries the predicate and the heap provider with it.
Everything the `MTLCommandBuffer` protocol asks for is the wrapped buffer's own answer forwarded, so an
`MPSCommandBuffer` is usable everywhere a command buffer is, and `-rootCommandBuffer` walks a stack of
wrappers to the one that will be committed. `-commitAndContinue` forwards to the wrapped buffer where it
has that method — which arrived in iOS 14 — and commits otherwise. `-prefetchHeapForWorkloadSize:` has
nothing to pre-warm: every temporary in this library takes its storage from the device, which is what a
heap's sub-allocation would have been.

`-init` and the initialisers the headers mark unavailable answer nil with a line in the log naming the
initialiser to use. The headers mark them unavailable so a caller cannot make one; a caller that reaches
them through a runtime lookup is told why rather than handed an object that answers every question about
its storage with zero.

## The batch functions

`MPSStateBatchIncrementReadCount` adds to each state's read count, stops at zero and at `NSUIntegerMax`,
and answers the count the last state was left at. `MPSStateBatchSynchronize` synchronizes each state.
`MPSStateBatchResourceSize` adds up the sizes. `MPSImageBatch…` is the same three over images and is
not carried yet, for the same reason `MPSImage` is not.
