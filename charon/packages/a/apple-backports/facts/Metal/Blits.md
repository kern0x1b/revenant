# Blits, mip chains, fences and shared events on OpenGL ES 2.0, iOS 8.0 and later

Metal's blit encoder came in iOS 8.0 with the rest of Metal, and the port draws over OpenGL ES 2.0 on the SGX 543
(`facts/Metal/RenderPath.md`). A blit is a copy, and every resource the port has is already CPU memory: a buffer is
its own bytes, a texture is an OpenGL ES 2.0 texture the port reads and writes a region at a time. So a blit here
is a `memcpy` or a read of the source region followed by a write of the destination region, with no staging buffer
and no transfer, because there is nothing to transfer between.

Source: the header of Metal in the SDK of iOS 26.2 for the API, its options and its defaults; the extensions of
the SGX 543 on iOS 6.1.3 from `glGetString(GL_EXTENSIONS)` on a device, for what ES 2.0 has to copy with.

## What macOS Metal answers, measured

`tests/backports/host/metalblit/oracle.m` runs a real Metal device on the host and records its answers into
`tests/backports/device/metalblit-expectations.h`; `tests/backports/host/metalblit/differential.m` runs the port's
own buffer blits against them in one process and is green, and `tests/backports/device/metalblit.m` holds the
texture side and the mip chain to the same recorded answers on the device. What came out, and what it settles:

* **An overlapping buffer-to-buffer copy is exactly a `memmove`.** Metal's own answer for copying 32 bytes from
  offset 0 to offset 8 of one buffer is byte for byte what `memmove` gives, so the port's `memmove` is the right
  primitive and not a convenient one.
* **A fill writes the byte value into every byte of the range.** `fillBuffer:range:value:` with 0xAB over bytes
  8..24 leaves sixteen 0xAB bytes, which is the port's `memset`.
* **A read of a BGRA texture returns the bytes in the order they were written** — no channel swizzle — so the
  port's read with `GL_BGRA_EXT` and its repack into the texture's own channel count are the right shape.
* **A region readback lays its rows out at the stride it was given, and no further.** A 4x5 region of an 8x8
  RGBA8 texture from (2,3) into a buffer at offset 16 with a row of 64 puts the first row at 16 and the second at
  80, which is what the port's stride arithmetic does.
* **A blit past the end of the destination is not refused by Metal; it writes what fits.** The same readback
  asked for five rows into a 128-byte buffer and came back with the two that fit and nothing else. The port
  refuses the whole blit and says why in the log. That is a deliberate difference, and
  `tests/backports/host/metalblit/differential.m` pins it so it cannot widen unnoticed.
* **The chain of a 16x8 mipmapped texture has five levels, and the last one is one texel** — a 1x1 read at level 4
  is answered, where `8 >> 4` is zero. The port's `levelExtent` clamps to 1 for that reason.
* **`generateMipmapsForTexture:` leaves an unweighted box average of the four texels of the level above, rounded
  to the nearest.** Rounding to the nearest rather than truncating is the one number here an ES 2.0 box filter
  is not required to match, and it is recorded as Apple's answer so the device test compares against it rather
  than against a guess.

## What a blit does

* **Buffer to buffer** is a `memmove` of the range asked for, so overlapping source and destination copy the way
  `memmove` does. The range is checked against both buffers first.
* **Buffer to texture** writes the region into the texture's own format, row by row when the source's
  `sourceBytesPerRow` is not the width in bytes, through the same `glTexSubImage2D` path
  `-replaceRegion:mipmapLevel:withBytes:bytesPerRow:` uses. A source that does not have a whole image is refused
  with a line in the log.
* **Texture to buffer** reads the region with `glReadPixels` and repacks it into the texture's own channel count,
  which is the same code `-getBytes:bytesPerRow:fromRegion:mipmapLevel:` uses, so a blit and a region access cannot
  disagree about what a pixel is.
* **Texture to texture** reads the source region into a scratch buffer and writes the destination from it. The
  read comes first, so a copy between two levels of one texture is not a read and a write of the same name at the
  same time, which ES 2.0 leaves undefined.
* **`fillBuffer:range:value:`** is a `memset` of one byte value.
* **`generateMipmapsForTexture:`** is `glGenerateMipmap` over the chain the texture was made with. ES 2.0 wants a
  mipmapped minification filter for a chain to be complete, so the filter is one that reads the chain for the call.
  The filter is **read back and put back as it was**, not set to a constant: the filter of a texture at that moment
  is whatever the last draw through it left there, which is that draw's sampler and not the one the texture was
  created with. And because the call changes the texture's filter, the sampler the texture last had applied is
  forgotten, so the next draw through it re-applies its own sampler instead of finding the cache still holding the
  previous one and leaving the texture filtering the way this call left it.
* **`copyFromTexture:sourceSlice:sourceLevel:toTexture:destinationSlice:destinationLevel:sliceCount:levelCount:`**
  and **`copyFromTexture:toTexture:`** (13.0) copy whole surfaces, with the conditions Apple's header states: the
  same pixel format at both ends, a source level and a destination level of the same size, and enough levels in
  both. The convenience form looks for a mip of one texture the size of the other's first mip, in that order, and
  copies as many levels as both have from there.

## Mip chains

A texture is made with the levels its descriptor asks for, each allocated with `glTexImage2D` at its own size, so
a level below the first is a texture the driver can sample, blit to and read back, and `mipmapLevelCount` is the
number of levels that exist. `-getBytes:` and `-replaceRegion:` take the level they are given. ES 2.0 has no
`GL_TEXTURE_BASE_LEVEL` or `GL_TEXTURE_MAX_LEVEL`, so the chain is exactly the levels that were allocated; the
port never sets a max level. A texture whose minification filter does not read the chain samples level 0, which is
what a non-mipmapped sampler asks for.

## What a blit is refused for, and what it says

Every refusal writes one line naming the reason and copies nothing, which is what an application gets from Metal
for a blit Metal does not allow, rather than a crash inside the copy:

* a blit option other than `MTLBlitOptionNone` (9.0): the option names a compressed row to decompress or a packed
  depth and stencil pair, and this port has neither;
* a texture whose pixel format has no OpenGL ES 2.0 form, and a region past the edge of the texture or past the end
  of a buffer;
* an array slice, a cube face or a 3D slice: this port has no array, cube or 3D textures;
* a copy between two textures of a different number of channels, and a copy whose source and destination regions
  differ in shape: this port copies the bytes of a region, and those two would not be the same bytes;
* a whole-surface copy between different pixel formats, a level either texture does not have, or two levels of
  different sizes.

## Fences and shared events

`MTLSharedEvent` (12.0) and `MTLSharedEventListener` (12.0) are real: an event is a signal value and a condition
that is broadcast when the value is set, and a listener is a dispatch queue that a notification block is run on.

* **`-updateFence:`** (10.0) records how many commands this encoder has encoded, and writes that as the event's
  signalled value. It is the honest value on this device: a command here is a call into OpenGL ES 2.0 that has
  already been made, so the work behind that many commands is done, not in flight.
* **`-waitForFence:`** (10.0) waits for the value the fence carries. Since the work was issued as it was encoded,
  that value has been reached, and the wait returns; a value another thread lowers is waited for in the ordinary
  way.
* **`-signaledValue`**, **`-notifyListener:atValue:block:`** and **`-waitUntilSignaledValue:timeoutMS:`** (15.0) are
  the event's own state: a block is run on the listener's queue when the value is reached, and a wait ends when the
  value is signalled or the timeout passes, whichever is first.
* **`-newSharedEventHandle`** and **`-newSharedEventWithHandle:`** are real, and the round trip through a handle is
  the point of them. `-newSharedEventHandle` is **not nullable** in Apple's header, so the port answers it with a
  handle rather than with nil: `MTLSharedEventHandle` is carried (iOS 6 has no class of that name), and a handle
  names the *state* of an event — the signal value and the condition a wait blocks on — which is why those live in
  an object of their own. `-newSharedEventWithHandle:` hands back a **different event object over the same state**,
  so a value signalled through the first is seen by the second and a wait on the second ends when the first
  signals. That is the shape of Metal's own: an event opened in another process is not the object that was created
  here, it is the same signal.
* **What a handle cannot do here: be opened in another process, and be archived.** A handle is passed to another
  process over XPC, and the port runs one process on one device, so there is no second process to open it in.
  Apple's class of this name is `NSSecureCoding`, and a handle here names a signal value and a condition that exist
  in this process, so there is nothing of them to write into an archive: `+supportsSecureCoding` answers NO and an
  encode is refused through the archiver's own `-failWithError:` with a line in the log, rather than left to reach
  a method the class does not have. Nothing else about the handle is affected, and a handle of a class that is not
  the port's is refused with a line in the log rather than silently opening nothing.
* **`MTLFence`** and **`MTLEvent`** (10.0, 12.0) stay absent, as `registry/Metal/absent_Metal.json` says: the port
  defines no protocol object of either name. What an application uses is the event above, whose methods are those
  two protocols' members.

## The access hints

**`optimizeContentsFor{CPU,GPU}Access:`** (12.0) and their `slice:level:` forms do nothing, and that is what doing
nothing means here rather than a refusal: the API asks for a performance, not for a value, and the performance is
already the case. Every resource of this port is CPU-resident — a buffer is its own bytes, a texture is read and
written on the CPU — so there is nothing to migrate between two residency modes that do not exist.

## What is not here yet

* The three indirect-command-buffer blits of 12.0 (`copyIndirectCommandBuffer:sourceRange:destination:destinationIndex:`,
  `optimizeIndirectCommandBuffer:withRange:`, `resetCommandsInBuffer:withRange:`) take an `MTLIndirectCommandBuffer`,
  which this port does not carry; that protocol is in `absent_Metal.json` as absent. Carrying it is the indirect
  command buffer group, with `MTLIndirectRenderCommand`, `MTLIndirectComputeCommand` and the render encoder's
  `drawPrimitivesIndirect:` family.
* The counter blits of 13.0 and 14.0 (`getTextureAccessCounters:…`, `resetTextureAccessCounters:…`,
  `sampleCountersInBuffer:atSampleIndex:withBarrier:`, `resolveCounters:inRange:destinationBuffer:destinationOffset:`)
  and `sampleCountersInBuffer:atSampleIndex:withBarrier:` need `MTLCounterSampleBuffer` and the counter sample
  buffers, which the port does not carry yet. `MTLCounterSamplingPointAtBlitBoundary` is a constant of the header,
  so an application that asks the device whether it has one (`supportsCounterSampling:`) is what the port answers;
  that is the counter buffers group.
* The tensor blit of 26.0 needs `MTLTensor`, which arrived with the machine learning tensors and is not carried.
* `barrierAfterQueueStages:beforeStages:` (26.0) is a barrier between the work of two encoders on one command queue.
  The port has one queue and issues each command as it is encoded, so there is no other work to wait for and the
  barrier returns; this is the same reasoning as the access hints above, and it is stated here rather than left
  silent.
