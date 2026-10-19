# MTLComputePipelineDescriptor, the iOS 9 descriptor

`MTLComputePipelineDescriptor` is the class `MTLComputePipeline.h` declares at 9.0. It is in
`Metal/MTLComputePipelineDescriptor9.m`, and it is a plain data holder: it says what a compute pipeline is
built from and asks no device anything. The device side (a compute pipeline state made from a descriptor) is
not part of this row, and the descriptor is carried so that a caller reads back what it wrote.

## What is measured, and against what

`tests/backports/host/compute-pipeline-descriptor/run.sh` builds the port's class for Catalyst beside Apple's
Metal in one process, renamed `CharonHostMTLComputePipelineDescriptor`, and compares every readable member
of the two descriptors at four moments: a fresh descriptor, one with every settable member set away from its
default, the same one after `-reset`, and a copy of the set one. The comparison is a snapshot of each member's
value, so a disagreement names the member and both values. A mutant that makes `-reset` also clear the required
threadgroup size must turn the reset comparison red, and it does.

Apple's values, measured on the host (not read off the header):

| member | fresh | after `-reset` |
| --- | --- | --- |
| `stageInputDescriptor` | non-nil | non-nil |
| `buffers` | non-nil; every slot answers a descriptor, mutability `MTLMutabilityDefault` | the set slot reads back with `MTLMutabilityDefault` |
| `insertLibraries`, `preloadedLibraries` | empty arrays | **nil** |
| `binaryArchives` | nil | nil |
| `linkedFunctions` | non-nil, with empty arrays | non-nil |
| `maxCallStackDepth` | 1 | 1 |
| `shaderValidation` | `MTLShaderValidationDefault` | `MTLShaderValidationDefault` |
| `supportIndirectCommandBuffers`, `supportAddingBinaryFunctions` | NO | NO |
| `label`, `computeFunction` | nil | nil |
| `threadGroupSizeIsMultipleOfThreadExecutionWidth` | NO | **keeps the value set (YES)** |
| `maxTotalThreadsPerThreadgroup` | 0 | **keeps the value set (256)** |
| `requiredThreadsPerThreadgroup` | 0 x 0 x 0 | **keeps the value set (4 x 2 x 1)** |

`-reset` is therefore not a fresh descriptor: three members keep what they were set to, and the two library
arrays go to nil rather than empty. The port does the same, and the port's `-init` gives the fresh values.

Copy: the copy's stage input, buffers and linked functions are new objects. A buffer slot set in the original
reads back in the copy with the mutability it was set with, and the copy's slot is not the original's object.

## What is not measured

- `computeFunction` is a device's object, so it is only ever nil here, on both sides; the set-then-copy path
  for it is not exercised.
- `linkedFunctions` is Apple's own `MTLLinkedFunctions` in the case, not the port's. The port's file
  `Metal/MTLDescriptors14.m` does not compile against the SDK of macOS 26 the host builds with, because
  `CharonMetalProtocols.h` forward-declares the `MTL4*Sparse*` classes, which that SDK declares as typedefs.
  The case measures the descriptor's own members; the linked functions it holds are the host's on both sides.
- Device-side use (`-[MTLDevice newComputePipelineStateWithDescriptor:...]`) is not carried by this row.

## The members the SDK this package compiles against does not declare

`shaderValidation` (18.0) and `requiredThreadsPerThreadgroup` (26.0) are declared for the port by
`Metal/CharonMetal26Types.h` and implemented as explicit accessors in the class file. Their types, and the
values they take, are the header's.
