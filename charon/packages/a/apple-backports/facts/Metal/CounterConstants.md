# The 14.0 counter family: twenty-one names the header declares and never spells

Fifteen `MTLCommonCounter`, three `MTLCommonCounterSet` and three `NSErrorDomain`, in
`Metal/MTLCounterConstants14.m`, all introduced in **14.0**. They are here because a caller that
builds a counter set writes them by name, and iOS 6 carries no constant of any of them.

**The header declares each one and never spells the string.** `MTLCounters.h` gives every counter a
one-line `@constant` entry saying what it counts — the GPU time when the sample is taken, the number
of patches input to the tessellator, the amount of cycles spent writing to the render targets — and
no value anywhere. `Metal.apinotes` says which error class each *domain* belongs to and nothing
about these. So every string below is **Apple's own, measured**, and the port's source is generated
from that measurement rather than written by hand; `tests/backports/host/metal-census/counters.m`
repeats the measurement on every run and compares the bytes.

| constant | the string Apple holds | bytes |
| --- | --- | --- |
| `MTLCommonCounterTimestamp` | `GPUTimestamp` | 12 |
| `MTLCommonCounterTotalCycles` | `TotalCycles` | 11 |
| `MTLCommonCounterSetStatistic` | `statistic` | 9 |
| `MTLCommonCounterSetTimestamp` | `timestamp` | 9 |
| `MTLCommonCounterVertexCycles` | `VertexCycles` | 12 |
| `MTLCommonCounterFragmentCycles` | `FragmentCycles` | 14 |
| `MTLCommonCounterFragmentsPassed` | `FragmentsPassed` | 15 |
| `MTLCommonCounterVertexInvocations` | `VertexInvocations` | 17 |
| `MTLCommonCounterClipperInvocations` | `ClipperInvocations` | 18 |
| `MTLCommonCounterTessellationCycles` | `TessellationCycles` | 18 |
| `MTLCommonCounterFragmentInvocations` | `FragmentInvocations` | 19 |
| `MTLCommonCounterSetStageUtilization` | `stageutilization` | 16 |
| `MTLCommonCounterClipperPrimitivesOut` | `ClipperPrimitivesOut` | 20 |
| `MTLCommonCounterRenderTargetWriteCycles` | `RenderTargetWriteCycles` | 23 |
| `MTLCommonCounterComputeKernelInvocations` | `KernelInvocations` | 17 |
| `MTLCommonCounterTessellationInputPatches` | `TessellationInputPatches` | 24 |
| `MTLCommonCounterPostTessellationVertexCycles` | `PostTessellationCycles` | 22 |
| `MTLCommonCounterPostTessellationVertexInvocations` | `PostTessellationVertexInvocations` | 33 |

## A name is not a value

Four of the twenty-one are not what their name suggests, and all twenty-one are distinct:

- `MTLCommonCounterSetTimestamp` is `timestamp` — nine bytes, all lower case.
- `MTLCommonCounterSetStageUtilization` is `stageutilization`.
- `MTLCommonCounterSetStatistic` is `statistic`.
- `MTLCommonCounterPostTessellationVertexCycles` is `PostTessellationCycles` — **22 bytes**, not the
  twenty-eight character `PostTessellationVertexCycles` that belongs to the *invocations* constant.
  An earlier revision of this work wrote it from the name, and the case caught it by length.

## What the case compares, and why the port is renamed on the host

Apple's copy is read by **`dlsym` on Apple's Metal, by name, from a handle opened by path** — not by
naming the extern, because the link would bind each name to whichever definition won and a port that
defined all twenty-one wrongly would be compared with itself. The port's copies are **renamed** while
they are compiled for the host (`-D<name>=charonHost_<name>`), so the two sets coexist and the case
reads one of each. `counters.sh` proves both sides: the host binary holds all twenty-one **renamed**,
and the device object holds all twenty-one **under Apple's own names**, which is what a caller on iOS 6
binds to.

Three answers are told apart, because two look alike in a boolean: a name that is **not there**
(dlsym returns NULL, and a **planted** name proves the lookup can say so), a name that is there and
holds **NULL**, and a name that is there and holds a string whose **length and bytes** are compared.
Comparing the text without the length would pass a string that is a prefix of Apple's — which is
exactly the `PostTessellationCycle` near-miss above.

**No device is created.** These are strings, and a descriptor asks a device nothing (the measurement
that settles it, and the machine these cases run on, are in `facts/Metal/DeviceOnThisMachine.md`).

## The mutants

One per constant, twenty-one in all, each changing exactly one value and each red on its own line. The
mutation is **scoped to the constant's own definition line**, so changing one value cannot change
another's, and a mutation that does not build is `RUN FAILED` with a non-zero exit and is never
counted as red.

## The three error domains

| constant | declared | the string Apple holds | the error class it belongs to |
| --- | --- | --- | --- |
| `MTLBinaryArchiveDomain` | `MTLBinaryArchive.h:17` | `MTLBinaryArchiveDomain` (22 bytes) | `MTLBinaryArchiveError` |
| `MTLCounterErrorDomain` | `MTLCounters.h:202` | `MTLCounterErrorDomain` (21 bytes) | `MTLCounterSampleBufferError` |
| `MTLDynamicLibraryDomain` | `MTLDynamicLibrary.h:14` | `MTLDynamicLibraryDomain` (23 bytes) | `MTLDynamicLibraryError` |

The same shape as the twenty-one: the header declares the name and never the string, and
**`Metal.apinotes` is where the SDK says which error class each domain belongs to** — it binds
`MTLBinaryArchiveError`, `MTLCounterSampleBufferError` and `MTLDynamicLibraryError` to these three.
So the string is Apple's own, measured by dlsym, and the case compares the bytes and the length.

**What is measured about the domain, and what is not.** The port **builds no `NSError`**: nothing in
it calls `errorWithDomain:` today, and a row that said it did would be claiming a constructor that
does not exist. What the case measures instead is the constant: it constructs an `NSError` **here**
with the port's own domain and reads `.domain` back, comparing it byte for byte with Apple's string.
So the claim is a fact about the CONSTANT — a caller that constructed an error with it would get the
same domain an Apple-built one carries — and not a claim that the port constructs one.

## The mutants

One per constant, **twenty-one in all**, each changing exactly one value and each red on its own
line. The mutation is **scoped to the constant's own definition line** — for a counter that is
`MTLCommonCounter const <name> = @"…";` and for a domain `NSErrorDomain const <name> = @"…";` — so
changing one value cannot change another's, and a mutation that does not build is `RUN FAILED` with a
non-zero exit and is never counted as red.

## What is NOT here

The two 14.0 `useHeap:` methods are device work belonging to the acceleration-structure family, and
the 13.0 rasterization-rate and 15.0 motion-geometry classes are their own families. All are named
in the next slice, so this one's claim is exactly what its tree holds.
