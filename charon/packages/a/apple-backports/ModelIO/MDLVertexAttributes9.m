#import <Foundation/Foundation.h>
#import <ModelIO/ModelIO.h>

#pragma clang diagnostic ignored "-Wobjc-missing-property-synthesis"

// The names the fifteen vertex attributes go by. They arrived with iOS 9, and they are exported data
// symbols, which is the trouble: a band at iOS 9 or later has them from the release and drops ours,
// while the 6.1.3 band has them from us - and the ModelIO library needs them in both, so they are
// defined here, in the library that is always linked, and MetalKit's copy references them.
//
// Every value is the one the host's own symbol holds, read off it; the guard prints them.

NSString *const MDLVertexAttributePosition = @"position";
NSString *const MDLVertexAttributeNormal = @"normal";
NSString *const MDLVertexAttributeTextureCoordinate = @"textureCoordinate";
NSString *const MDLVertexAttributeTangent = @"tangent";
NSString *const MDLVertexAttributeBitangent = @"bitangent";
NSString *const MDLVertexAttributeBinormal = @"binormal";
NSString *const MDLVertexAttributeColor = @"color";
NSString *const MDLVertexAttributeJointIndices = @"jointIndices";
NSString *const MDLVertexAttributeJointWeights = @"jointWeights";
NSString *const MDLVertexAttributeOcclusionValue = @"occlusionValue";
NSString *const MDLVertexAttributeEdgeCrease = @"edgeCrease";
NSString *const MDLVertexAttributeAnisotropy = @"anisotropy";
NSString *const MDLVertexAttributeShadingBasisU = @"shadingBasisU";
NSString *const MDLVertexAttributeShadingBasisV = @"shadingBasisV";
NSString *const MDLVertexAttributeSubdivisionStencil = @"subdivisionStencil";
