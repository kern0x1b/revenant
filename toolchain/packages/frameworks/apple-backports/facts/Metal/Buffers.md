# Buffers: debug markers and the GPU address, iOS 10.0 and later

A buffer on this port is CPU memory. `RevenantMetalBuffer` allocates its bytes once with `calloc`, or takes
them as a window onto a heap's allocation, and `-contents` returns that pointer. The members here are the
ones of `MTLBuffer` the port did not define before this file.

## Debug markers, `-addDebugMarker:range:` and `-removeAllDebugMarkers` (10.0)

A marker names a range of a buffer for a capture. Metal keeps the marker for the capture tool, and no
capture runs on this device, so the port accepts the call and keeps nothing: the signpost of an encoder
takes the same course (`facts/Metal/EncoderDebugGroups.md`).

Measured on the host (`tests/backports/device/buffer-probe/buffer.m`, recorded in
`tests/backports/device/buffer-probe/host-expectations.txt`): a marker over a window, a marker over the
whole buffer, and `-removeAllDebugMarkers` (called once and twice) each leave every byte of the buffer as
it was, and leave `gpuAddress` as it was. A marker over a buffer of zeros leaves it zero.

What is not asked: a range outside the buffer. Metal's answer to that is not recorded, so the port makes
no claim about it.

## GPU address, `-gpuAddress` (16.0)

Metal's `gpuAddress` is the address a shader uses to name the buffer. The port's shaders are CPU kernels
that take the buffer's bytes as a pointer (`facts/Metal/Compute.md`), so the port answers that pointer,
widened to 64 bits. The bytes never move while the buffer lives, so the answer is stable.

Measured on the host, as relations and not as values: the address is nonzero, it is the same on every read
while the buffer lives, and two live buffers have different addresses. The values are not compared: Metal's
is a GPU address and the port's is a CPU one, and they are not the same numbers.

## Owed: `-newTextureWithDescriptor:offset:bytesPerRow:` (8.0)

A texture over a window of a buffer's bytes is a texture whose storage is those bytes, so writes through
either name show in the other. The port's texture storage is built in the MTLTexture tranche, which comes
after the buffer, and the aliasing rules of Metal for a texture over a buffer are not measured. The row is
owed until the texture storage exists.

## Where this is not checked

The probe's port side has not been run on a device: it is built the same way as
`tests/backports/device/commandbuffer-probe`, and the device run is a heavy job the band has not started.
The compile of `MTLBuffer10.m` and `MTLBuffer16.m` for armv7 with the iOS 16.4 SDK is the check made here.
