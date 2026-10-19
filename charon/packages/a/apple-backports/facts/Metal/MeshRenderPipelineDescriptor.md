# MTLMeshRenderPipelineDescriptor, iOS 16

`MTLMeshRenderPipelineDescriptor` is the class `MTLRenderPipeline.h` declares at 16.0. It is in
`Metal/MTLMeshRenderPipelineDescriptor16.m`, and it is a plain data holder: what a mesh pipeline is built from
(its object, mesh and fragment functions, threadgroup limits, payload size, buffers, colour and depth/stencil
attachments, and the linked-function sets). It asks no device anything. Nothing here hands back a pipeline state.

## What is measured, and against what

`tests/backports/host/mesh-render-pipeline-descriptor/run.sh` builds the port's class for Catalyst beside Apple's Metal
in one process, with the class, its colour attachment array and descriptor (`Metal/MTLRenderPipelineDescriptor8.m`) and
its buffer array (`Metal/MTLReflection11.m`) all renamed `CharonHost<Name>`. It compares the members at a fresh
descriptor, one with every member set away from its default, a copy of that one, and the set one after `-reset`. A
mutant that makes the fresh rasterization off turns the fresh comparison red, and it does.

Apple's fresh defaults, measured on the macOS host:

| member | fresh |
| --- | --- |
| `label`, the three functions | nil |
| sizes and threadgroup limits (`maxTotal...`, `payloadMemoryLength`, `maxTotalThreadgroupsPerMeshGrid`) | 0 |
| the two threadgroup SIMD flags | NO |
| `rasterSampleCount` | 1 |
| `alphaToCoverageEnabled`, `alphaToOneEnabled` | NO |
| `rasterizationEnabled` | YES |
| `maxVertexAmplificationCount` | 1 |
| `depthAttachmentPixelFormat`, `stencilAttachmentPixelFormat` | Invalid (0) |
| `supportIndirectCommandBuffers` | NO |
| `binaryArchives` | nil |
| the three linked-function sets | fresh objects |
| `shaderValidation` | `MTLShaderValidationDefault` |
| `requiredThreadsPerObjectThreadgroup`, `requiredThreadsPerMeshThreadgroup` | 0 x 0 x 0 |
| the three buffer arrays and the colour array | fresh, every slot a default descriptor |

Measured zero values are accepted: `rasterSampleCount` and `maxVertexAmplificationCount` read back what is set, 0 included.

## `-reset`

Measured: every member above goes back to its default. The buffer arrays and the colour array become **new objects**
(their identity is not kept), so a caller holding an old one keeps its old values. A copy taken before the reset keeps
its own arrays.

## Copy and linked functions

The three linked-function properties are `null_resettable` and `copy`, measured: a set value reads back as a copy, not
the object set, and a nil set reads back a fresh object. The port does the same (`CharonCopyLinkedFunctions`
copies the four members, since `MTLLinkedFunctions` has no `NSCopying` in the port).

`binaryArchives` is a `copy` array; nil is its own answer, and an empty array set reads back as an empty array.

## Equality

Apple's `isEqual:` compares by value, measured: a fresh descriptor equals another fresh one, a copy equals its
original, and a change to any one member (label, rasterization sample count, shader validation, the required size, a
colour slot, a buffer slot, indirect command buffer support, a depth format) makes them unequal. A fresh descriptor
equals one with an empty linked-function set, and equals one with an empty binary archive array rather than nil
(measured). The port does the same over every member. The hash agrees with equality (it is taken over the scalar
members, so equal descriptors hash the same).

The function members are compared by identity in the port, since nothing here can make a function (see below).

## The members the SDK this package compiles against does not declare

The 16.4 SDK declares the members up to `stencilAttachmentPixelFormat`. `supportIndirectCommandBuffers` (17.0), the
binary archives (18.0), the three linked-function sets (17.0), `shaderValidation` (18.0) and the required sizes (26.0)
are implemented as explicit accessors in the class file.

## Not measured

- **The function members** (`objectFunction`, `meshFunction`, `fragmentFunction`): a function is a device's object,
  and the host case creates no device (facts/Metal/DeviceOnThisMachine.md). They read as nil on both sides, and
  nothing here measures them set.
- **Device-side use**: `-[MTLDevice newRenderPipelineStateWithMeshDescriptor:...]` is not carried by this row.
