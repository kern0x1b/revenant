# The 14.0 descriptors: twenty classes that describe, and never ask

The largest coherent block of Metal's absent rows is the family that arrived in iOS 14, and it is
one thing: **descriptors**. They are in `Metal/MTLDescriptors14.m`, twenty classes.

| group | classes | what a descriptor holds |
| --- | --- | --- |
| acceleration structure | `MTLAccelerationStructureDescriptor`, `…GeometryDescriptor`, `…BoundingBoxGeometryDescriptor`, `…TriangleGeometryDescriptor`, `MTLPrimitiveAccelerationStructureDescriptor`, `MTLInstanceAccelerationStructureDescriptor` | a usage, offsets, strides, counts, a vertex format, an index type, motion border modes and times |
| ray-tracing function tables | `MTLVisibleFunctionTableDescriptor`, `MTLIntersectionFunctionTableDescriptor` | a function count each |
| counter sampling | `MTLCounterSampleBufferDescriptor`, `MTLComputePassSampleBufferAttachmentDescriptor`, `MTLResourceStatePassSampleBufferAttachmentDescriptor`, `MTLRenderPassSampleBufferAttachmentDescriptor` | a label, a storage mode, a sample count, and the start/end sample indices of each stage |
| the arrays | `…ComputePassSampleBufferAttachmentDescriptorArray`, `…RenderPass…Array`, `…ResourceStatePass…Array` | the two indexed members, over real storage |
| passes and archives | `MTLComputePassDescriptor`, `MTLResourceStatePassDescriptor`, `MTLBinaryArchiveDescriptor` | a dispatch type, a URL |
| linked functions | `MTLLinkedFunctions`, `MTLIntersectionFunctionDescriptor` | four function arrays; **no member of its own** |

**They are all plain data holders, and that is the whole case for carrying them.** A descriptor says
what a pass or an acceleration structure is built from, and none of it asks the device anything. A
port with no ray tracing still has to hand these back when a caller asks what it would build, and
the values a caller reads back are the values it wrote.

## The twenty class names, written out, for a grep

A reader who has a row's API from the registry and greps this file must find it, so the names the
ellipses above stand for are written out here in full:

`MTLAccelerationStructureDescriptor`, `MTLAccelerationStructureGeometryDescriptor`,
`MTLAccelerationStructureBoundingBoxGeometryDescriptor`,
`MTLAccelerationStructureTriangleGeometryDescriptor`,
`MTLPrimitiveAccelerationStructureDescriptor`, `MTLInstanceAccelerationStructureDescriptor`,
`MTLVisibleFunctionTableDescriptor`, `MTLIntersectionFunctionTableDescriptor`,
`MTLCounterSampleBufferDescriptor`, `MTLComputePassSampleBufferAttachmentDescriptor`,
`MTLComputePassSampleBufferAttachmentDescriptorArray`,
`MTLResourceStatePassSampleBufferAttachmentDescriptor`,
`MTLResourceStatePassSampleBufferAttachmentDescriptorArray`,
`MTLRenderPassSampleBufferAttachmentDescriptor`,
`MTLRenderPassSampleBufferAttachmentDescriptorArray`, `MTLComputePassDescriptor`,
`MTLResourceStatePassDescriptor`, `MTLBinaryArchiveDescriptor`, `MTLLinkedFunctions`,
`MTLIntersectionFunctionDescriptor`.

**Every one of the twenty is defined under APPLE'S OWN NAME**, and that is not a naming preference:
iOS 6 carries no class of any of those twenty names, so a caller writing
`[[MTLComputePassDescriptor alloc] init]` must find one, and an earlier revision of this series
defined them as `RevenantMetal<Name>`. The 6.1.3 gate refused that series for exactly this reason -
the registry listed `MTLComputePassDescriptor` as implemented while nothing defined that name - and
the differential had not noticed, because the harness renamed the port's copy with `-D` and the case
compared the host's class with the port's under a name only the test knew. The harness now compiles
the port with the renames and the case WITHOUT them, and `descriptors.sh` proves on the DEVICE
object, where the names are not renamed, that all twenty are defined as
`_OBJC_CLASS_$_MTLComputePassDescriptor` and nineteen more.

## The hierarchy is the header's, and getting it wrong was caught by the compiler

All twenty are `@interface`, **not** `@protocol`, so none carries a conformance list. And
`MTLAccelerationStructureGeometryDescriptor` is a **sibling** of `MTLAccelerationStructureDescriptor`,
not a subclass of it — only the bounding-box and triangle geometry descriptors derive from it. The
first version of the object made the geometry a subclass and synthesized five properties on the base
that belong to the sibling, and `clang` refused it.

## Three members that were invented, and are not there

The compiler did not catch these; reading the headers did, and the compiler would have shipped them.

- `MTLAccelerationStructureUsageInstance` **does not exist**. The cases are `None` 0, `Refit`
  `(1<<0)`, `PreferFastBuild` `(1<<1)`, `ExtendedLimits` (15.0).
- `MTLMotionBorderModeWrap` **does not exist**. The cases are `Clamp` 0, `Vanish` 1.
- `MTLIntersectionFunctionDescriptor` declares **no member of its own** — everything it answers is
  inherited from `MTLFunctionDescriptor`, a different row. The `functionBufferOffset`,
  `functionBufferOffsetAlignment` and `functionStride` this file first carried are in no SDK header
  and are gone.

`MTLAttributeFormatFloat2` is 29 and `MTLIndexTypeUInt16` is 0; `MTLDispatchType` is `Serial` 0 and
`Concurrent` 1. All of them are the header's own values.

## The differential, and the device it never creates

`tests/backports/host/metal-census/descriptors.m` compares the port **property by property against
Apple's own objects**, and **creates no device anywhere**. That is possible because a descriptor is
`[[X alloc] init]` on both sides, and a descriptor asks a device nothing, so nothing in this family
calls one and a round trip of
the port against *itself* would prove only that the port agrees with the port.

Fresh **defaults** are compared as well as written values, because a port that invented a default
would pass every written value and still be wrong — and extending that comparison from three members
to all of them is what found the twelve below.

## The fresh defaults: the ones the header warrants, and the one it does not

`MTLAccelerationStructureDescriptor.usage` is the only fresh value the header *enumerates*
(`MTLAccelerationStructureUsageNone = 0`). Three more are warranted in the header's own words and
the port now carries them:

| member | the header's warrant | value |
| --- | --- | --- |
| `…BoundingBoxGeometryDescriptor.boundingBoxStride` | `MTLAccelerationStructure.h:277-281`, at least 24 | 24 |
| the six `…SampleBufferAttachmentDescriptor` `…SampleIndex` members | `MTLCounterDontSample`, which `MTLCounters.h:20` defines as `((NSUInteger)-1)` | `MTLCounterDontSample` |
| `MTLInstanceAccelerationStructureDescriptor.instanceDescriptorStride` | `MTLAccelerationStructure.h:184-187`, the size of the descriptor type | 64, **measured** for `…DescriptorTypeDefault`, not assumed |
| `…GeometryDescriptor.allowDuplicateIntersectionFunctionInvocation` | `MTLAccelerationStructure.h:101-103`, YES | `YES` |
| `MTLPrimitiveAccelerationStructureDescriptor.motionEndTime` | `MTLAccelerationStructure.h:181-182`, 1.0f | 1.0f |
| `MTLPrimitiveAccelerationStructureDescriptor.motionKeyframeCount` | `MTLAccelerationStructure.h:186-187`, 1 | 1 |
| `…TriangleGeometryDescriptor.vertexFormat` | `MTLAccelerationStructure.h:213-215`, `MTLAttributeFormatFloat3` packed | 30, from `MTLStageInputOutputDescriptor.h` |

**One more, where the header states no default at all and the two sides differ.** Its doc says
nothing but its name. It is recorded by name rather than asserted equal, because making them equal
would be the port copying a private default it has no warrant for:

| member | the port answers | Apple's own object answers |
| --- | --- | --- |
| `…TriangleGeometryDescriptor.indexType` | unset (0) | `UInt32` (1) |

**This file previously called five members unwritten and four of the five was false.**
`allowDuplicateIntersectionFunctionInvocation`, `motionEndTime`, `motionKeyframeCount` and
`vertexFormat` are each stated in `MTLAccelerationStructure.h`, and the port now carries all four
so a caller reading a fresh descriptor gets the specified value rather than a zero. Only `indexType`
is genuinely left open.

The two pass descriptors' `sampleBufferAttachments` are the opposite case: the header declares them
**readonly** and Apple hands one back on a fresh object, so the port makes one too — its own array
class, no device needed — and the case compares that the array exists on both sides.

Each mutant breaks one class and must go red on that class's line. `descriptors.sh` runs these
three, and the table is the harness's own output rather than a list kept beside it:

| mutant | breaks | red line |
| --- | --- | --- |
| `M1` | `MTLVisibleFunctionTableDescriptor`'s `-functionCount` | `MTLVisibleFunctionTableDescriptor.functionCount: the port 0 and Apple's own object 5` |
| `M2` | `MTLIntersectionFunctionTableDescriptor`'s `-functionCount` | `MTLIntersectionFunctionTableDescriptor.functionCount: the port 0 and Apple's own object 7` |
| `M3` | `MTLCounterSampleBufferDescriptor`'s `-sampleCount` | `MTLCounterSampleBufferDescriptor.sampleCount: the port 0 and Apple's own object 12` |

An earlier revision of this table listed **one** mutant while the runner ran **three** — the same
disagreement between a claim and the thing that produced it that this file keeps running into, and
the reason every table in it is either generated or checked.

## What is NOT measured, by name

Every property that holds a **device-made object** is carried and read `nil`, and is not measured:
`primitiveDataBuffer`, `boundingBoxBuffer`, `vertexBuffer`, `indexBuffer`, `transformationMatrixBuffer`,
`instanceDescriptorBuffer`, `motionTransformBuffer`, `geometryDescriptors`,
`instancedAccelerationStructures`, `counterSet`, `sampleBuffer` on all three attachment
descriptors, and `functions` / `binaryFunctions` / `groups` / `privateFunctions` on `MTLLinkedFunctions`.

The reason is the same for every one of them: both sides answer `nil` with no device, and a round
trip with a real one would need a device to make it. The case asserts the `nil` on both sides and
says it is going no further.

## The eleven protocols, and the rule they are bound by

`MTLAccelerationStructure`, `MTLAccelerationStructureCommandEncoder`, `MTLBinaryArchive`,
`MTLCommandBufferEncoderInfo`, `MTLCounter`, `MTLCounterSampleBuffer`, `MTLCounterSet`,
`MTLDynamicLibrary`, `MTLFunctionHandle`, `MTLIntersectionFunctionTable` and
`MTLVisibleFunctionTable` are declared in `RevenantMetalProtocols.h`, so a caller resolving one by its
own name finds it — the rule from the stack-20 gate failure.

`tools/transcribe-protocols.py@52253c0650` wrote all eleven, and each arrives as a **forward declaration**: the
SDK this package compiles against already declares them, so the body comes from the umbrella import
and the generator writes only the name. It **refuses** to write anything for the fifteen protocols
already in that header, so the file is a union of runs — this run's eleven were merged into it, and
the header now carries twenty-six.
