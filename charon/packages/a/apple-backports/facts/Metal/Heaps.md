# Heaps on OpenGL ES 2.0, iOS 10.0 and later

`MTLHeap` came in iOS 10.0 with argument buffers. On this device a heap is literally what a heap can
be where every resource is already CPU memory: **one allocation that resources are taken out of**. A
buffer from a heap is a view into that allocation at the offset the heap or the application chose, and
a texture from a heap takes its size out of it. That is not a reduced stand-in for a GPU heap — a GPU
heap's whole purpose is to place resources in memory the GPU reads, and every resource of this port
*is* memory the GPU reads, because it is all one address space — and it is why the accounting is exact
rather than approximate.

Source: Apple's headers of Metal in the SDK of 16.4, which this package builds against, for the API
and its defaults; Apple's Metal documentation for the heap alignment, named below; `facts/Metal/RenderPath.md`
for the unified-memory model this builds on.

## The accounting is real

* `-[MTLResource heap]` and `-[MTLResource heapOffset]` (10.0, 13.0) are answered on every resource of the port,
  of the SDK's own declaration of them: the heap a resource was taken out of and the offset it was placed at, and
  nil and zero for a resource that was not created from a heap, which is what the header says each of those means.
  The render encoder's `-useHeap:` check reads that property rather than a type test of its own.
* `size` is the size the descriptor asked for, and the heap is that many bytes.
* `usedSize` is the offset the next automatic allocation starts at, so it includes the padding each
  allocation was aligned up to; `currentAllocatedSize` is the sum of the sizes actually handed out.
  Apple's headers are what make those two different things, and here they are.
* `maxAvailableSizeWithAlignment:` is what is left from the next aligned offset, rounded down to the
  alignment asked for. A zero or past-the-end alignment asks for the heap's own.
* An allocation that does not fit is refused: `nil` and a line in the log naming the size, not an
  allocation that runs past the end of the memory.
* `-[MTLHeap newBufferWithLength:options:offset:]` and `newTextureWithDescriptor:offset:` (13.0) place a
  resource at the offset the application chose, after checking that the offset is a multiple of the
  heap's alignment and that the resource fits. `usedSize` then reaches past it, so the next automatic
  allocation starts after it. Two placements that overlap are the application's own doing; Metal
  leaves that undefined and so does the port.

## The alignment

Allocations are aligned to **256 bytes**, which is the alignment Apple's Metal documentation gives a
heap allocation. It is named rather than measured, because it is a property of Metal's heaps and not
of this device, and nothing an application can observe here depends on the exact value beyond the
offsets it asks for: an offset that is a multiple of 256 is also a multiple of 16, the largest
alignment an ARMv7 allocation needs. What a native fix would change, if one were wanted, is nothing
measurable: a different documented alignment would move the offsets `usedSize` reports and nothing
else.

## Heap types

* `MTLHeapTypeAutomatic` — a heap allocates at the next free aligned offset, which is what
  `-newBufferWithLength:options:` and `-newTextureWithDescriptor:` do.
* `MTLHeapTypePlacement` — the application places every resource, and the two methods without an
  offset refuse with a line in the log and an error saying a placement heap is placed by the
  application. This is a real difference from Metal's behaviour on a device with a placement heap,
  where the no-offset methods are the ones Metal refuses, and it is the safer of the two: a
  placement heap that quietly allocated anyway would hand the application a resource at an offset it
  did not choose.
* `MTLHeapTypeSparse` — refused at creation, with an `NSError` and a line in the log saying why. A
  sparse heap maps its pages in on demand, and one allocation of the size asked for is not that; there
  is no page mapping to do on this device, where a heap is already all of memory and is never paged.
  `MTLHeapDescriptor.sparsePageSize` (16.0) is therefore carried and reads back what the application
  set, and is never used, because no heap this port makes is sparse.

## Hazard tracking and storage modes

`hazardTrackingMode` is stored and read back. Nothing tracks hazards with it, because there is nothing
to track: a command here is a call into OpenGL ES 2.0 that has already been made by the time it is
encoded, so the work of an earlier encoder is done and no resource can be read while another writes
it. The value is reported, not acted on, and this is said here rather than left silent.

`storageMode` and `cpuCacheMode` are stored and read back, and `resourceOptions` (13.0) is the storage
mode as a resource's options say the same thing. Every resource of the port is CPU-resident whatever
they are, for the reason in `facts/Metal/RenderPath.md`; these three are how the application asked,
and the port reports what it asked rather than changing it. `MTLStorageModeManaged` is macOS only —
Apple's header marks it unavailable on iOS — so there is no case for it.

`-[MTLHeap setPurgeableState:]` answers NO, the same answer `-[MTLBuffer setPurgeableState:]` gives:
purgeable memory is memory the system may page out and back, and this device has none.

## What an encoder does with a heap

`-[MTLRenderCommandEncoder useHeap:]`, `useHeaps:count:` (11.0) and their `stages:` forms (13.0) record
the heaps. A resource bound afterwards that did not come from one of them — a vertex buffer, a
fragment buffer, a fragment texture — is named in the log together with the heaps that were given,
because Metal leaves undefined what happens in that case and passing it by in silence is the one
thing that would be worse. An encoder that was given no heap is not checked at all, which is the
common case and costs nothing.

**The check itself, and what it caught.** The first version of this reached every bind path with
`-charonCheckHeapOf:what:` and every `useHeap` row with `-charonUseHeaps:count:`, declared both in
`CharonMetal.h` and implemented neither: nothing links an Objective-C method by name, so the compiler
took the calls, the gate saw no missing symbol, the registry carries no private selector, and the
first vertex or fragment bind on 4.3 or 6.1.3 raised `doesNotRecognizeSelector:` — every draw through
the port. It was found by review, not by any check. `tests/backports/host/metalblit/check-private-selectors.py`
is the check that was missing: it matches the `charon…` declarations of the folder's header against the
definitions in the folder, by name, and it runs first in that test's `run.sh`, before anything is
built. Run on the tree as it stood, it named the two unimplemented methods and one dead declaration
(`-charonForgetNotification:`, left over from the event handle, which nothing called and which is
gone).

`stages` says which stages of a pipeline may read the heaps. This port has one stage set, so the mask
changes nothing: every heap is visible to every stage.

## The difference that is named, not hidden

**A texture made from a heap is a real texture whose pixels are the texture's own, and the heap's span
it was given holds nothing.** ES 2.0 textures cannot be backed by memory the application can address —
`glTexImage2D` copies — so the port cannot make a heap's bytes be a texture's pixels, which is what a
placement heap on a Metal device buys. Everything else about it is exact: the size it takes out of the
heap is the real size of the whole mip chain at the texture's own channel count, the offset is the one
asked for, `usedSize` and `currentAllocatedSize` count it, and a later placement never overlaps it.

What an application can observe: it cannot read or write a heap texture's pixels through the heap's
own bytes. It can do everything else, and it is told this once per texture in the log rather than
being left to find out. On a device without compute, without argument buffers' GPU-side indirection
and without sparse memory, that is the whole of what a heap is for, and the rest of its API is
carried exactly.

**What a native fix would be:** make the texture's level-0 and mip pixels live in the heap's span and
keep the ES 2.0 texture in step with it at the boundaries — on every `replaceRegion:`, `getBytes:`,
blit in and blit out, and after any render pass that targeted the texture. That is a second
representation of a heap texture's pixels with explicit synchronisation points, and it costs a
read-back of the texture after every pass that draws into it. It is not done here, and it is not
hidden here.

## Not here

* `-[MTLComputeCommandEncoder useHeap:]` and `useHeaps:count:` (11.0) are **absent**: there is no
  compute command encoder on this device — `-[MTLCommandBuffer computeCommandEncoder]` answers nil —
  so the methods have no object to be called on.
* `-[MTLAccelerationStructureCommandEncoder useHeap:]` / `useHeaps:count:` (14.0) and
  `-[MTLHeap newAccelerationStructureWith…]` (16.0) are **absent** with the acceleration structures
  themselves, which need ray tracing hardware an A7 has not.
* `MTL4CounterHeap`, `MTL4CounterHeapDescriptor`, `-[MTLDevice newCounterHeapWithDescriptor:error:]`
  and the 26.0 counter methods are **absent**: the counter heaps arrived with the 26.0 SDK, whose types
  the backports of this package do not build against (it builds against 16.4), and they are counters,
  which is the counter sample buffers' group.

## The two compute-encoder heap rows, named as the registry names them

`-[MTLComputeCommandEncoder useHeap:]` and `-[MTLComputeCommandEncoder useHeaps:count:]` are
implemented rows, and their `facts` pointer is this file, so the row's own API has to be greppable
here. Both take a heap the port's encoder answers for, and both are the compute-encoder forms of the
`-useHeap:` family written above; the render-encoder and resource-state forms are separate rows.
