#import <MetalKit/MetalKit.h>
#import <ModelIO/ModelIO.h>

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
