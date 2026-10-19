# MTLTileRenderPipelineDescriptor, the iOS 11 descriptor

`MTLTileRenderPipelineDescriptor` is the class `MTLRenderPipeline.h` declares at 11.0. It is in
`Metal/MTLTileRenderPipelineDescriptor11.m`, and it is a plain data holder: it says what a tile pipeline is built
from and asks no device anything. Its colour attachments and tile buffers are the classes the port already carries
(`Metal/MTLTileRenderPipelineAttachments11.m` and `Metal/MTLReflection11.m`).

## What is measured, and against what

`tests/backports/host/tile-render-pipeline-descriptor/run.sh` builds the port's class for Catalyst beside Apple's Metal
in one process, renamed `RevenantHostMTLTileRenderPipelineDescriptor`, and compares the members both sides can be asked
without harm at four moments: a fresh descriptor, one with its settable members set away from their defaults, the
same one after `-reset`, and a copy of the set one. A mutant that stops `-reset` clearing the threadgroup limit turns
the reset comparison red, and it does.

Apple's values, measured on the host:

| member | fresh | after `-reset` |
| --- | --- | --- |
| `rasterSampleCount` | 1 | 1 (the set value, 4, is restored) |
| `colorAttachments[i].pixelFormat` | `MTLPixelFormatInvalid` | `MTLPixelFormatInvalid` (a set slot, RGBA8Unorm, is restored) |
| `threadgroupSizeMatchesTileSize`, `supportAddingBinaryFunctions` | NO | NO |
| `maxTotalThreadsPerThreadgroup` | 0 | 0 (the set value, 128, is restored) |
| `binaryArchives` | nil | nil |
| `preloadedLibraries` | an empty array | **nil** |
| `linkedFunctions` | non-nil | non-nil |
| `maxCallStackDepth` | 1 | 1 |
| `shaderValidation` | `MTLShaderValidationDefault` | `MTLShaderValidationDefault` |
| `requiredThreadsPerThreadgroup` | 0 x 0 x 0 | 0 x 0 x 0 (the set 8 x 8 x 1 is restored) |
| `label`, `tileFunction` | nil | nil |

So `-reset` restores every member here, except that the library array reads nil rather than empty.

Copy: the copy owns its colour attachments, tile buffers and linked functions; a colour attachment set in the original
reads back in the copy.

## Apple's `-reset` crashes once the tile buffers have been touched

Measured on the macOS host (the `apple-tile-reset` child of `run.sh`):

- `[descriptor reset]` on a fresh tile descriptor returns.
- If the descriptor's `tileBuffers` has been read (`objectAtIndexedSubscript:`) or set (`setObject:atIndexedSubscript:`)
  before `-reset`, the process segfaults (status 139). Setting a colour attachment before the reset does not.
- After the failed reset, the same descriptor's `tileBuffers[2]` reads back an object of another class
  (`MTLTileRenderPipelineColorAttachmentDescriptorInternal`), so the reset damages the array before it crashes.

The port does not reproduce this. Its `-reset` restores each tile buffer slot to a default descriptor and returns,
and the case checks that. Apple's tile buffers are therefore never touched by the differential, which would otherwise
measure the crash rather than a default.

**Not measured:** this is the macOS host. The release's own `-reset` on iOS is not measured here, and no device
has the class before iOS 11, so the crash is recorded as the host's behaviour and not as the device's.

## Tile buffers, checked by the port's own expectations

`tileBuffers[i]` answers a fresh `MTLPipelineBufferDescriptor` for every slot (as the buffer array does). A buffer set
at slot 2 reads back with its mutability; the copy keeps it and owns its own descriptor; `-reset` gives the slot its
default mutability back. These are the port's expectations and are not compared against Apple's object.

## What is not measured

- `tileFunction` is a device's object, so it is only ever nil here, on both sides.
- `linkedFunctions` is Apple's `MTLLinkedFunctions` in the case, not the port's: `Metal/MTLDescriptors14.m` does not
  compile against the SDK of macOS 26 the host builds with (see `facts/Metal/ComputePipelineDescriptor.md`).
- Device-side use (`-[MTLDevice newRenderPipelineStateWithTileDescriptor:...]`) is not carried by this row.

## The members the SDK this package compiles against does not declare

`shaderValidation` (18.0) and `requiredThreadsPerThreadgroup` (26.0) are declared for the port by
`Metal/RevenantMetal26Types.h` and implemented as explicit accessors in the class file.
