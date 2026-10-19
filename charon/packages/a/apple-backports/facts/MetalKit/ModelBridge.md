# MTKMetalVertexDescriptorFromModelIOWithError / MTKModelIOVertexDescriptorFromMetalWithError, iOS 10

Measured before writing code, per instruction: both functions only touch `MDLVertexDescriptor`
(`facts/ModelIO/VertexDescriptor.md`), a plain vertex-layout description with no dependency on
ModelIO's real wall, the asset/mesh file importer (`MDLAsset`/`MDLMesh`, see
`facts/MetalKit/TextureLoader.md`'s account of `MTKMesh`). Neither function reads or writes a
file, a mesh or an asset - they convert one descriptor's attribute/layout data into the other's.

## What the port does

Both directions share a format-mapping table between `MTLVertexFormat` and `MDLVertexFormat`: the
plain float/int/uint 1-4 component formats, the four normalized 8/16-bit packed formats
(`UChar4Normalized`/`Char4Normalized`/`UShort2Normalized`/`Short2Normalized`) and `half2`/`half3`/`half4` -
the formats this port's own `MTLVertexDescriptor`/`CharonMetal` rendering pipeline already
understands and could plausibly receive from a converted descriptor. `MTKMetalVertexDescriptorFromModelIOWithError`
walks the Model I/O descriptor's `attributes`/`layouts` and builds a real `MTLVertexDescriptor`;
`MTKModelIOVertexDescriptorFromMetalWithError` does the inverse, building real `MDLVertexAttribute`/
`MDLVertexBufferLayout` entries.

## What differs from the release

An attribute whose format falls outside that mapped set - anything from the wider
`MDLVertexFormat`/`MTLVertexFormat` enums this port's own pipeline never uses, such as the packed
1010102 formats or narrower single-component 8/16-bit types - answers a real `NSError` in
`MTKModelErrorDomain`, with `MTKModelErrorKey` naming the attribute index that failed, rather than
silently mapping to the wrong format or `Invalid`. Neither non-`WithError` sibling
(`MTKMetalVertexDescriptorFromModelIO`, `MTKModelIOVertexDescriptorFromMetal`) is carried, since
they have no error output to report the same gap through and were not this pass's demand.
