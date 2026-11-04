#include "../revenant_impl.h"
#import <MetalKit/MetalKit.h>
#import <ModelIO/ModelIO.h>

extern MDLVertexFormat RevenantMDLFormatFromMetal(MTLVertexFormat format);
extern MTLVertexFormat RevenantMetalFormatFromMDL(MDLVertexFormat format);

MDLVertexDescriptor *BACKPORT_IMPL(MTKModelIOVertexDescriptorFromMetal)(MTLVertexDescriptor *metalDescriptor)
{
    return MTKModelIOVertexDescriptorFromMetalWithError(metalDescriptor, NULL);
}

MTLVertexDescriptor *BACKPORT_IMPL(MTKMetalVertexDescriptorFromModelIO)(MDLVertexDescriptor *modelIODescriptor)
{
    return MTKMetalVertexDescriptorFromModelIOWithError(modelIODescriptor, NULL);
}

MDLVertexFormat BACKPORT_IMPL(MTKModelIOVertexFormatFromMetal)(MTLVertexFormat vertexFormat)
{
    MDLVertexFormat format = RevenantMDLFormatFromMetal(vertexFormat);
    return format == MDLVertexFormatInvalid ? MDLVertexFormatInvalid : format;
}

MTLVertexFormat BACKPORT_IMPL(MTKMetalVertexFormatFromModelIO)(MDLVertexFormat vertexFormat)
{
    MTLVertexFormat format = RevenantMetalFormatFromMDL(vertexFormat);
    return format == MTLVertexFormatInvalid ? MTLVertexFormatInvalid : format;
}
