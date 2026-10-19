#import <MetalKit/MetalKit.h>
#import <ModelIO/ModelIO.h>

// The 9.0 half of the model bridge: the four single-value conversions, without the error pointer.
//
// An object carries the API of ONE release, and release-split measured on the GATE's own object which
// is which: these four are exported from 9.0, and the two WithError siblings in
// MTKModelBridgeWithError10.m are exported from 10.0.1. One object for all six mixed releases.
//
// Each of these is its WithError sibling with the error pointer dropped, so the conversion is made
// once and the value returned; a format neither table has answers the enumeration's own invalid case,
// which is the same answer the sibling gives with no error pointer to fill.

// The two conversion tables, in MTKModelBridgeWithError10.m where the WithError forms are: they are
// one table each and a second copy would be a second answer to the same question.
extern MDLVertexFormat CharonMDLFormatFromMetal(MTLVertexFormat format);
extern MTLVertexFormat CharonMetalFormatFromMDL(MDLVertexFormat format);

MDLVertexDescriptor *MTKModelIOVertexDescriptorFromMetal(MTLVertexDescriptor *metalDescriptor)
{
    return MTKModelIOVertexDescriptorFromMetalWithError(metalDescriptor, NULL);
}

MTLVertexDescriptor *MTKMetalVertexDescriptorFromModelIO(MDLVertexDescriptor *modelIODescriptor)
{
    return MTKMetalVertexDescriptorFromModelIOWithError(modelIODescriptor, NULL);
}

MDLVertexFormat MTKModelIOVertexFormatFromMetal(MTLVertexFormat vertexFormat)
{
    MDLVertexFormat format = CharonMDLFormatFromMetal(vertexFormat);
    return format == MDLVertexFormatInvalid ? MDLVertexFormatInvalid : format;
}

MTLVertexFormat MTKMetalVertexFormatFromModelIO(MDLVertexFormat vertexFormat)
{
    MTLVertexFormat format = CharonMetalFormatFromMDL(vertexFormat);
    return format == MTLVertexFormatInvalid ? MTLVertexFormatInvalid : format;
}
