# The command queue and the command buffer, iOS 8 to 16

The port's `CharonMetalQueue` and `CharonMetalCommandBuffer` carry the command queue protocol and the
command buffer protocol of the SDK. Their members are in the files named by release: `CharonMetalQueue.m`
(8.0: the base), `MTLCommandQueue8.m`, `MTLCommandQueue14.m`, `MTLCommandBuffer10.m`,
`MTLCommandBuffer11.m`, `MTLCommandBuffer12.m`, `MTLCommandBuffer13.m`, `MTLCommandBuffer14.m` and
`MTLCommandBuffer16.m`.

## How a buffer works on this port

The encoders of the port do their work as they are encoded: the OpenGL ES 2.0 draws and the CPU kernels run
inside the encoder's own call. So a command buffer's work is already done when it is committed. What a commit
decides is the buffer's life as Metal reports it:

1. `NotEnqueued`, then `Enqueued` after `-enqueue`.
2. `Committed` when `-commit` begins, the work's flush follows, and the buffer's end time is read.
3. `Scheduled`: the scheduled handlers run, in the order they were added.
4. `Completed`: the completed handlers run, in the order they were added.

`-waitUntilCompleted` returns at once for a committed buffer, since the commit has finished the work; it
reads nothing else. `error` is nil, since the port reports no failure of a command.

The times `GPUStartTime`, `GPUEndTime`, `kernelStartTime` and `kernelEndTime` are 0 until the buffer has
completed. The start is the first encoder the buffer vends (a buffer that vends none starts at its commit),
and the end is the end of the commit. The port has one processor, so the GPU span and the kernel span are the
same span and carry the same values.

## Members, and what each one answers

| Member | Release | Answer |
| --- | --- | --- |
| `-commandBuffer`, `-commandBufferWithUnretainedReferences` | 8.0 | a buffer whose `retainedReferences` is YES and NO |
| `-commandBufferWithDescriptor:` | 14.0 | a buffer made with the descriptor's `retainedReferences` and `errorOptions`; nil with a log for a nil descriptor |
| `-insertDebugCaptureBoundary` | 8.0 (deprecated 11.0) | no effect and no log: no capture runs on a device |
| `retainedReferences` | 8.0 | the setting the buffer was made with |
| `GPUStartTime`, `GPUEndTime`, `kernelStartTime`, `kernelEndTime` | 10.3 | the relations in the section above |
| `-pushDebugGroup:`, `-popDebugGroup` | 11.0 | a stack of names; a pop with nothing open is refused with a log |
| `-computeCommandEncoderWithDispatchType:` | 12.0 | the compute encoder of `-computeCommandEncoder`; the type does not change the order (see below) |
| `-resourceStateCommandEncoder` | 13.0 | nil, with a log (hardware, see below) |
| `errorOptions` | 14.0 | the options as made, read back |
| `logs` | 14.0 | an empty container of `MTLLogContainer`, enumerated with no entries |
| `-blitCommandEncoderWithDescriptor:` | 14.0 | the port's blit encoder; nil with a log for a nil descriptor |
| `-computeCommandEncoderWithDescriptor:` | 14.0 | the compute encoder of the descriptor's dispatch type; nil with a log for a nil descriptor |
| `-accelerationStructureCommandEncoder` | 14.0 | nil, with a log (hardware, see below) |
| `-resourceStateCommandEncoderWithDescriptor:` | 14.0 | nil, with a log (hardware, see below) |
| `-accelerationStructureCommandEncoderWithDescriptor:` | 16.0 | nil, with a log (hardware, see below) |

**Dispatch type.** A serial encoder runs its dispatches in encoding order; a concurrent one may run them in any
order its caller is prepared for. The port's compute encoder runs each dispatch to completion before the next
call returns, so every dispatch runs in encoding order. That order is a legal schedule for either type, so the
type changes nothing the port can show.

**Pass descriptors.** A blit or compute pass names counter sample buffers. A counter sample buffer is made by the
device, and this device makes none (its counter-sample member is still owed; `registry/Metal/absent_Metal.json`),
so no attachment of a descriptor can hold one. A pass is encoded as the plain encoder of its kind.

**Logs.** A function log is written by a shader that logs. The port's shaders are translated kernels, and no code of
the port creates a `MTLFunctionLog`, so the container enumerates nothing for every buffer. The container conforms to
`MTLLogContainer` so that a caller enumerates it as it enumerates Metal's.

## Measured on the host, and what that does and does not show

The probe `tests/backports/device/commandbuffer-probe/commandbuffer.m` asks the same questions of Apple's Metal
(macOS, host) and of the port (the iPhone 4S guest). Its host answers are in
`tests/backports/device/commandbuffer-probe/host-expectations.txt`, captured from one run. Measured on the host:

- A fresh buffer has status 0, `retainedReferences` YES, `errorOptions` 0, no entries in `logs`, and zero times.
- `-commandBufferWithUnretainedReferences` answers `retainedReferences` NO. A descriptor that clears
  `retainedReferences` and sets `errorOptions` to `MTLCommandBufferErrorOptionEncoderExecutionStatus` answers
  NO and 1 back.
- The status through a commit: 0, then 1 after `-enqueue`, then 1 before the commit; **2 (Committed) right after
  `-commit`**, then 4 after `-waitUntilCompleted`.
- The scheduled handler runs with status 3 (Scheduled), before the completed handler, which runs with status 4.
- After completion the four times are positive, and the end is not before the start; the kernel span is positive
  and ordered the same way. The probe asks relations only, so Apple's values are not compared to the port's.
- A completed or scheduled handler added **after** the commit aborts the process: Metal asserts
  ("Completed handler provided after commit call", and the same for scheduled), exit 134. Each such form is in its
  own process in the expectations file.
- The capture boundary returns, and a buffer committed after it completes with status 4.

## Where the port differs from the release, and what is not measured

- **Status right after commit.** Apple's buffer is `Committed` (2) at that point, measured once; the port's buffer
  is `Completed` (4), because its work is done inside the encoders. Both are states a committed buffer passes
  through, and the port reaches the later one at once. Reasoned from the code; the port's value is not measured.
- **Handlers added after the commit.** Apple aborts (measured above). The port logs the mistake and calls the handler
  at once when its point has passed, so the caller is not aborted. A handler added while the buffer is committed but
  not yet completed (inside a scheduled handler) is queued for completion. Neither port answer is measured.
- **Commit twice.** The port logs and does nothing the second time. Apple's answer is not measured.
- **Wait for a buffer never committed.** Apple would wait for ever on the calling thread, and a hang cannot be
  recorded as a result, so it is not measured. The port logs and returns.
- **The kernel span equals the GPU span.** The port's are equal by construction. Apple's are not compared.

## Reasoned, not measured: the factories this device cannot answer

`-resourceStateCommandEncoder` and its descriptor form (sparse texture page mapping), and
`-accelerationStructureCommandEncoder` and its descriptor form (ray tracing) answer nil on this device. The
iPhone 4S's SGX 543 has no page mapping for sparse textures and no ray-tracing unit, so the encoder each records
has no hardware to run on. The host has both and cannot show the answer of a device without them; the nil is
the answer this reasoning gives, and the registry rows say so.

Measured on the host by `tests/backports/device/library-probe/features.m`, whose run is in
`features-expectations.txt`: the host's device is an Apple M4 Pro, `supportsRaytracing` is 1, `supportsFamily:
MTLGPUFamilyApple7` is 1, the sparse tile size for RGBA8 2D is 64x64x1, and both factories return an encoder. So the
host has both features, and its answer on a device without them is not measured here. The two factories stay as the
port's answer, recorded as crutches in `coordination/crutches.md`.

## Owed

- `-encodeSignalEvent:value:` and `-encodeWaitForEvent:value:`. The port's encoders run as they are encoded, so a
  wait cannot hold back work that is already done. Needs deferred command recording in the encoders, then the
  event's signal and wait placed in the encoding order.
- `-parallelRenderCommandEncoderWithDescriptor:`. Needs `MTLParallelRenderCommandEncoder` (owed in the registry)
  and the render encoder's pass-level load actions, applied once for the whole parallel pass rather than for each
  sub-encoder.

## The port side of the probe

The probe compiles for armv7 against the 16.4 SDK with the port's own sources, and its objects carry the answers
above. The run on the iPhone 4S guest is not recorded in this file: no port answer in this file is a measured
result until that run's output is compared with `host-expectations.txt`.
