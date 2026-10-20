#import <MetalKit/MetalKit.h>
#import <ModelIO/ModelIO.h>

extern MDLVertexFormat RevenantMDLFormatFromMetal(MTLVertexFormat format);
extern MTLVertexFormat RevenantMetalFormatFromMDL(MDLVertexFormat format);

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
    MDLVertexFormat format = RevenantMDLFormatFromMetal(vertexFormat);
    return format == MDLVertexFormatInvalid ? MDLVertexFormatInvalid : format;
}

MTLVertexFormat MTKMetalVertexFormatFromModelIO(MDLVertexFormat vertexFormat)
{
    MTLVertexFormat format = RevenantMetalFormatFromMDL(vertexFormat);
    return format == MTLVertexFormatInvalid ? MTLVertexFormatInvalid : format;
}
