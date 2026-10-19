# MDLVertexDescriptor, MDLVertexAttribute, MDLVertexBufferLayout, iOS 9

Brought into the port for MetalKit's ModelIO vertex-descriptor bridge functions
(`facts/MetalKit/ModelBridge.md`), not independently demanded. ModelIO's real wall is its
asset/mesh file importer (`MDLAsset`, `MDLMesh`); these three classes are a plain layout
description with no dependency on it - the measurement the coordinator asked for before writing
any ModelIO code, done here rather than assumed.

## What the port does

`MDLVertexAttribute`'s `name`, `format`, `offset`, `bufferIndex`, `time` and `initializationValue`
hold what is set; `format` defaults to `MDLVertexFormatInvalid` and `initializationValue` to
`(0, 0, 0, 1)`, as the header documents. `MDLVertexBufferLayout.stride` holds what is set.
`MDLVertexDescriptor.attributes`/`.layouts` are real mutable arrays; `-attributeNamed:` searches
them by name, `-addOrReplaceAttribute:` replaces an entry sharing the given attribute's name and
`time` or appends, `-removeAttributeNamed:` removes every attribute with that name, `-reset` empties
both arrays, and `-initWithVertexDescriptor:`/`-copyWithZone:` deep-copy every attribute and layout.

`-setPackedStrides` and `-setPackedOffsets` compute real per-format component sizes rather than
assuming a single width for everything: 1 byte for the 8-bit formats, 2 for the 16-bit and half
formats, 4 for everything else (int/uint/float and the packed 1010102 formats), read off the
format's own bit-range constant rather than guessed.

## What is not carried

The `MDLVertexAttribute*` name constants (`MDLVertexAttributePosition`, `...Normal`, and so on) are
not carried: nothing in this pass names an attribute by one of them, since neither bridge function
this pass serves ever inspects `name`. No other part of ModelIO - `MDLMesh`, `MDLAsset`,
`MDLMaterial`, `MDLObject`, `MDLTexture` and the rest - is carried; see
`facts/MetalKit/TextureLoader.md` for exactly where `MTKMesh` and `MTKTextureLoader`'s
`-newTextureWithMDLTexture:` meet that boundary.
