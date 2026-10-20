# MTLIndirectCommandBufferDescriptor, iOS 12

`MTLIndirectCommandBufferDescriptor` is the class `MTLIndirectCommandBuffer.h` declares at 12.0. It is in
`Metal/MTLIndirectCommandBufferDescriptor12.m`, and it is a plain data holder: which commands an indirect command
buffer may hold, which state each command inherits from its encoder, and how many buffer bindings a command may make
per stage. It asks no device anything. The buffer it describes is a device's object, and this port has no indirect
command buffer to hand back, so nothing here creates one.

## What is measured, and against what

`tests/backports/host/indirect-command-buffer-descriptor/run.sh` builds the port's class for Catalyst beside Apple's
Metal in one process, renamed `RevenantHostMTLIndirectCommandBufferDescriptor`, and compares its members with Apple's: a
fresh descriptor (from `init` and from `new`), one with every member set away from its default, a copy of that one,
and the original after the copy was taken. Equality and the hash are compared too. A mutant that makes the fresh
kernel threadgroup memory bind count 0 turns the fresh comparison red, and it does.

Apple's fresh defaults, measured on the macOS host:

| member | fresh |
| --- | --- |
| `commandTypes` | 0 (no command type) |
| `inheritPipelineState`, `inheritBuffers` | NO |
| `inheritDepthStencilState`, `inheritDepthBias`, `inheritDepthClipMode`, `inheritCullMode`, `inheritFrontFacingWinding`, `inheritTriangleFillMode` | YES |
| `maxVertexBufferBindCount`, `maxFragmentBufferBindCount`, `maxKernelBufferBindCount`, `maxObjectBufferBindCount`, `maxMeshBufferBindCount` | 0 |
| `maxKernelThreadgroupMemoryBindCount` | 31 |

Copy: a new object with the same members; changing the original afterwards does not change the copy. Equality is by
value, and a copy hashes the same as its original.

## What Apple does not validate, measured

A command type with bits Apple does not name (`0xFF`, and `1 << 40`), and a bind count of 99999, are read back as set,
and no child process aborts. The port does not validate them either, and `run.sh` sets such values on both sides and
compares.

## The members the SDK this package compiles against does not declare

The 16.4 SDK declares the inheritance flags from `inheritPipelineState` and `inheritBuffers` and the bind counts
through `maxKernelBufferBindCount`. The six 26.0 inheritance flags and the 17.0 threadgroup, object and mesh bind
counts are implemented as explicit accessors in the class file, with their own ivars, the way the compute descriptor
carries its 26.0 members.

## What is not carried

- The three blit methods on indirect command buffers are separate registry rows, and they are not decided by this
  descriptor: they act on a device's buffer, which this descriptor never creates.
- `description` is NSObject's, not Apple's member listing.
