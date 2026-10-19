# The 13.0 rasterization-rate family: a map, its layers, and their sample rates

Four classes in `Metal/MTLRasterizationRate13.m`, all introduced in **13.0** and all implemented under
**Apple's own names**, because iOS 6 carries no class of any of them and a caller writing
`[[MTLRasterizationRateMapDescriptor alloc] init]` must find one.

| class | what it holds |
| --- | --- |
| `MTLRasterizationRateMapDescriptor` | a screen size, a label, and a layer count over its layer array |
| `MTLRasterizationRateLayerArray` | the layers, with the two indexed members the header declares |
| `MTLRasterizationRateLayerDescriptor` | a sample count and the two sample arrays |
| `MTLRasterizationRateSampleArray` | the sample rates, with the two indexed members |

They are mutually dependent and land together: the map **owns** the layer array and a layer
**owns** the two sample arrays, so a map without them is not the family.

**They are all plain data holders, and that is the whole case for carrying them.** A rasterization-rate
map says how densely a render target is sampled. A caller writes a screen size, a label and some
sample rates, and reads the same numbers back. Nothing here asks a device anything, and **no device is
created** — a descriptor asks a device nothing (`facts/Metal/DeviceOnThisMachine.md`).

## `layerCount` is the leading contiguous run, not the array's length

This is Apple's own answer, measured rather than assumed, and an earlier revision of this port got it
wrong. On a fresh map, writing a layer at **index 2** makes `layerAtIndex:2` return it while
`layerCount` stays **0**. Writing index 0 raises the count to 1; writing index 1 raises it to 3; and
writing index 5 afterwards leaves the count at 3 with index 5 still readable. So the count is the
length of the **leading run of written layers from index 0**, and the port answers that.

## Two defects this family actually had, and the case found them

**Neither container had an `-init`.** `MTLRasterizationRateLayerArray` and
`MTLRasterizationRateSampleArray` each hold an `NSMutableArray` in an ivar, and each grows it in a
`while` loop. With no `-init` the ivar was never created, a message to nil does not advance a count,
and **the loop never ended** — writing one layer into a map, and one sample into an array, each hung.
Both create their own storage now, and neither has a member that can grow without it.

**And the fault that was not a fault:** `MTLSize` is `{ NSUInteger width, height, depth }` —
**integers**. The first version of the case printed those fields with `%g`, so a width of `1920` was
read as the *double whose bit pattern is 1920*, which is `9.48606e-321`. The round trip was working the
whole time and three separate experiments "proved" a struct-copy bug that did not exist. Every field is
printed and compared as an `unsigned long` now.

## What the case measures, and where Apple is not the oracle

`tests/backports/host/metal-census/rasterrate.m` compares the **map** against Apple's own map on every
member — the screen size, the label, `layerAtIndex:`, and the contiguous-run count. The **layer's two
counters** are compared against the **header**, not against Apple: `initWithSampleCount:` is ignored
for on a host with no device and those two then read back `9.88131e-324`, so comparing against them
would be comparing against uninitialised memory. What the port answers instead is the count the
caller built the layer with.

**What is null and what is not, probed rather than assumed.** `MTLRasterizationRate.h` declares four
members `_Nullable` and the sample array's indexed getter is **not** one of them:

| member | header | Apple answers | the port answers | |
| --- | --- | --- | --- | --- |
| `MTLRasterizationRateLayerArray objectAtIndexedSubscript:` (`:136`) | `_Nullable` | `nil` | `nil` | agree, and the port's `nil` is what the contract says |
| `MTLRasterizationRateMapDescriptor layerAtIndex:` (`:189`) | `_Nullable` | `nil` | `nil` | agree |
| `MTLRasterizationRateSampleArray objectAtIndexedSubscript:` (`:24`) | **not** nullable | `0` | `nil` | **a deviation** |

The sample row is the one to be honest about: the header does **not** promise `nil` there, Apple's
own object hands back a non-null `NSNumber` carrying `0`, and the port hands back `nil`. That is a
deviation from a non-null contract, taken because a port with no device has no sample to read and
`nil` says that, where `0` would claim a measurement. It is a difference, not a matching, and the
case prints both answers so it stays visible.

## The mutants

Four, one per class, each red and named: the map's fresh screen size, the layer array's `count` (and
so the map's `layerCount`), the layer's `sampleCount`, and the sample array's read bound. A mutation
that does not build is `RUN FAILED` with a non-zero exit and is never counted as red, and a mutation
that **aborts** is reported as a red that aborted rather than being called a harness failure.

`rasterrate.sh` proves both sides of the naming: the host binary holds the four under their **renamed**
names — the runtime will bind a same-named class to the framework's, and on this host Metal.framework
implements all four, so an unrenamed port is silently not the port — and the **device** object holds
all four under **Apple's own names**.

## Not here

`MTLRasterizationRateMap` is the object a **device** makes out of a map: every member is readonly and
reads device-made state, so it is carried with the device work. `MTLSharedTextureHandle` is a handle
over a device-made texture. `MTLIndirectComputeCommand` and `MTLResourceStateCommandEncoder` take
device objects in every member. None of the four is a data holder, and none is flipped here.
