# MTLStageInputOutputDescriptor, iOS 10

Part of the Tier 2 Metal/MetalKit verdict: a compute-stage input/output layout descriptor, real
independently of any GPU driver.

## What the port does

`MTLStageInputOutputDescriptor.layouts`/`.attributes` are real `MTLBufferLayoutDescriptorArray`/
`MTLAttributeDescriptorArray` objects, the two support classes it declares its own properties in
terms of and this pass carries alongside it. Indexed subscripting (`layouts[i]`, `attributes[i]`)
reads and writes real `MTLBufferLayoutDescriptor`/`MTLAttributeDescriptor` entries; an unset index
answers a fresh default descriptor rather than nil or a crash, matching how the real class answers
an index nobody configured. `indexType` and `indexBufferIndex` hold what is set. `-reset` clears
both arrays back to empty and restores the two index properties to their defaults. `+stageInputOutputDescriptor`
gives a fresh default instance, and `-copyWithZone:` deep-copies every attribute and layout slot.

## What differs from the release

Nothing in this port ever reads an `MTLStageInputOutputDescriptor`: it exists because an
application that builds one (to hand to a compute pipeline, say) must not LOAD-FAIL doing so, not
because this port's own compute path consults it. This port carries no compute pipeline at all
(`CharonMetalDevice` implements only the render path over OpenGL ES 2.0), so a descriptor built
here has nowhere real to go yet - a fact about the wider compute gap, not about this descriptor.
