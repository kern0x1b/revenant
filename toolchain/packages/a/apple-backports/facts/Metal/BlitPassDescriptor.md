# MTLBlitPassDescriptor, iOS 14

Part of the Tier 2 Metal/MetalKit verdict: a collection of sample-buffer attachment configuration
for a blit pass, real independently of any GPU driver.

## What the port does

`+blitPassDescriptor` gives a fresh default instance. `sampleBufferAttachments` holds a real
`MTLBlitPassSampleBufferAttachmentDescriptorArray` of the header's own `MTLMaxBlitPassSampleBuffers`
(4) slots; indexed subscripting reads and writes real `MTLBlitPassSampleBufferAttachmentDescriptor`
entries, an unset index answering a fresh default rather than nil. Each attachment descriptor's
`sampleBuffer`, `startOfEncoderSampleIndex` and `endOfEncoderSampleIndex` hold what is set, the two
indices defaulting to `MTLCounterDontSample` as the header documents. `-copyWithZone:` deep-copies
every attachment slot.

## What differs from the release

This port's `CharonMetalEncoder`/`CharonMetalQueue` carry no blit command encoder or counter
sampling of their own, so a descriptor built here is not yet consumed by anything real - the same
situation `MTLStageInputOutputDescriptor` is in (`facts/Metal/StageInputOutputDescriptor.md`): the
object exists and is correct, the pipeline stage it configures is a separate, larger gap.
