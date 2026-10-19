# MTL4CommandQueue sparse mappings: the four members, and Metal's refusals

`-[MTL4CommandQueue updateBufferMappings:heap:operations:count:]`, `-updateTextureMappings:heap:operations:count:`,
`-copyBufferMappingsFromBuffer:toBuffer:operations:count:` and `-copyTextureMappingsFromTexture:toTexture:operations:count:`
(macOS 26.0, iOS 26.0) map and copy tiles of placement sparse resources into a placement heap.

The port makes no placement sparse buffer or texture and no placement heap of the kind the call needs, so no mapping
can be performed here. The port refuses each call. It does not accept one and do nothing, and it does not log once
and carry on: a caller that maps a tile is told, at the call, that the tile was not mapped.

The decision is in `Metal/MTL4SparseMapping26.m`, and the methods that raise it are in `Metal/MTL4CommandQueue26.m`.
The host differential is `tests/backports/host/mtl4-sparse-mapping/run.sh`.

## Metal's answers, measured on the macOS 26 host

Each case ran in a child process that made its own objects. A refusal is an assertion: the process aborts (status
134) and the assertion text names the requirement.

| case | Metal | port |
| --- | --- | --- |
| buffer update, plain buffer, automatic heap | aborts: `Buffer is not a Placement Sparse Buffer` | refuses with the same text |
| buffer update, sparse buffer, automatic heap | aborts: `Heap is not a Placement` | refuses with the same text |
| buffer update, sparse buffer, nil heap, map mode | aborts: `Mapping mode must be unmap for nil heap` | refuses with the same text |
| buffer update, sparse buffer, placement heap, map mode | returns (exit 0) | refuses (see below) |
| buffer copy, sparse source, plain destination | aborts: `Destination Buffer is not a Placement Sparse Buffer` | refuses with the same text |
| buffer copy, plain source, plain destination | aborts: `Source Buffer is not a Placement Sparse Buffer` | refuses with the same text |
| texture update, plain texture, automatic heap | returns (exit 0) | refuses (see below) |
| texture copy, plain textures | returns (exit 0) | refuses (see below) |

The order is Metal's: the buffer first, then the heap, then the nil-heap rule. For the copy, the source is named
before the destination.

A probe that created its objects before `fork()` crashed the child with SIGSEGV (status 11). The same call made
with the objects created after the fork, or in an unforked process, gave the assertion text above. The crash was
the probe's fault, and it is recorded so that nobody reads it as Metal's answer.

## What Metal accepts, and the port's refusal of it

Two cases return normally on Metal, and the port refuses them. Both are the port's own answers, not Metal's.

* **The sparse buffer with a placement heap, map mode.** This is the one input the requirements accept. The port
  refuses it anyway, for the reason below.
* **The texture update and the texture copy.** Metal returned normally for a plain texture on an automatic heap, and
  for a plain texture copy. Apple's documentation makes the placement sparse texture and the placement heap the
  caller's responsibility, and it does not say what Metal does when they are missing. The port cannot map a tile of
  a texture, so it cannot accept the call as a mapping, and it refuses it on that requirement with
  `Texture is not a Placement Sparse Texture` (and the source or destination form for a copy). Nothing else was
  measured about these: what a mapping of a sparse texture does to a reader was not checked.

Why the port refuses even the accepted input: the port has no placement sparse resource to map into, and no
mapping on a resource it does not have. A call with every requirement met would still find nothing to map, so the
port refuses it with `a sparse mapping is not performed on this device: no resource of this port is placement
sparse`. That text is the port's own, and it is not one Metal gives.

## Why the refusal is a raised exception

Metal's refusal is an assertion, which aborts the process and cannot be caught. The port raises the same text as an
`NSInternalInconsistencyException`. An uncaught exception also aborts the process (status 134), so the observable
result of an unhandled call is the same as Metal's. An application that catches the exception can continue, which
Metal does not allow. That difference is recorded here and is not hidden.

## What is measured, and what is not

* Measured: the four buffer refusals and their texts, and the texture forms' acceptance by Metal (`probe*.m` in
  `.agent-work/runs/mps-metal/probe/mtl4-sparse`, not in the tree).
* Measured by the differential: the port's decision for each buffer case returns Metal's text.
* Not measured: the port's method wiring (the raise), because `MTL4CommandQueue26.m` needs the port's OpenGL ES
  queue, which the host cannot make. It runs on the device probe `tests/backports/device/metalchain-probe`, which was
  not run for this change.
* Not measured: what Metal does when a texture mapping succeeds, because the port cannot make the mapping.
