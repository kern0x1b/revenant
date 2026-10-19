#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

@interface revenantHost_MTL4RenderPassDescriptor : NSObject <NSCopying>
@property (readonly) MTLRenderPassColorAttachmentDescriptorArray *colorAttachments;
@property (nonatomic, copy) MTLRenderPassDepthAttachmentDescriptor *depthAttachment;
@property (nonatomic, copy) MTLRenderPassStencilAttachmentDescriptor *stencilAttachment;
@property (nonatomic) NSUInteger renderTargetArrayLength;
@property (nonatomic) NSUInteger tileWidth;
@property (nonatomic) NSUInteger tileHeight;
@property (nonatomic) NSUInteger imageblockSampleLength;
@property (nonatomic) NSUInteger threadgroupMemoryLength;
@property (nonatomic) NSUInteger defaultRasterSampleCount;
@property (nonatomic) NSUInteger renderTargetWidth;
@property (nonatomic) NSUInteger renderTargetHeight;
@property (nonatomic, strong) id rasterizationRateMap;
@property (nonatomic, strong) id visibilityResultBuffer;
@property (nonatomic) MTLVisibilityResultType visibilityResultType;
@property (nonatomic) BOOL supportColorAttachmentMapping;
- (void)setSamplePositions:(const MTLSamplePosition *)positions count:(NSUInteger)count;
- (NSUInteger)getSamplePositions:(MTLSamplePosition *)positions count:(NSUInteger)count;
@end
@interface revenantHost_MTL4AccelerationStructureGeometryDescriptor : NSObject <NSCopying>
@property (nonatomic) NSUInteger intersectionFunctionTableOffset;
@property (nonatomic) BOOL opaque;
@property (nonatomic) BOOL allowDuplicateIntersectionFunctionInvocation;
@property (nonatomic, copy) id label;
@property (nonatomic) NSUInteger primitiveDataStride;
@property (nonatomic) NSUInteger primitiveDataElementSize;
@end
@interface revenantHost_MTL4AccelerationStructureTriangleGeometryDescriptor : revenantHost_MTL4AccelerationStructureGeometryDescriptor
@property (nonatomic) MTLAttributeFormat vertexFormat;
@property (nonatomic) NSUInteger vertexStride;
@property (nonatomic) MTLIndexType indexType;
@property (nonatomic) NSUInteger triangleCount;
@property (nonatomic) MTLMatrixLayout transformationMatrixLayout;
@end
@interface revenantHost_MTL4AccelerationStructureBoundingBoxGeometryDescriptor : revenantHost_MTL4AccelerationStructureGeometryDescriptor
@property (nonatomic) NSUInteger boundingBoxStride;
@property (nonatomic) NSUInteger boundingBoxCount;
@end
@interface revenantHost_MTL4AccelerationStructureCurveGeometryDescriptor : revenantHost_MTL4AccelerationStructureGeometryDescriptor
@property (nonatomic) MTLAttributeFormat controlPointFormat;
@property (nonatomic) MTLAttributeFormat radiusFormat;
@property (nonatomic) NSUInteger segmentCount;
@property (nonatomic) MTLCurveType curveType;
@property (nonatomic) MTLCurveBasis curveBasis;
@property (nonatomic) MTLCurveEndCaps curveEndCaps;
@end
@interface revenantHost_MTL4AccelerationStructureMotionTriangleGeometryDescriptor : revenantHost_MTL4AccelerationStructureGeometryDescriptor
@property (nonatomic) MTLAttributeFormat vertexFormat;
@property (nonatomic) MTLIndexType indexType;
@end
@interface revenantHost_MTL4AccelerationStructureMotionBoundingBoxGeometryDescriptor : revenantHost_MTL4AccelerationStructureGeometryDescriptor
@property (nonatomic) NSUInteger boundingBoxStride;
@end
@interface revenantHost_MTL4AccelerationStructureMotionCurveGeometryDescriptor : revenantHost_MTL4AccelerationStructureGeometryDescriptor
@property (nonatomic) MTLAttributeFormat controlPointFormat;
@property (nonatomic) MTLAttributeFormat radiusFormat;
@end
@interface revenantHost_MTL4FunctionDescriptor : NSObject <NSCopying>
@end
@interface revenantHost_MTL4SpecializedFunctionDescriptor : revenantHost_MTL4FunctionDescriptor
@property (nonatomic, copy) id functionDescriptor;
@property (nonatomic, copy) id specializedName;
@property (nonatomic, copy) id constantValues;
@end
@interface revenantHost_MTL4StitchedFunctionDescriptor : revenantHost_MTL4FunctionDescriptor
@property (nonatomic, copy) id functionGraph;
@property (nonatomic, copy) NSArray *functionDescriptors;
@end
@interface revenantHost_MTL4LibraryFunctionDescriptor : revenantHost_MTL4FunctionDescriptor
@property (nonatomic, copy) id name;
@property (nonatomic, retain) id library;
@end
@interface revenantHost_MTL4PipelineOptions : NSObject
@property (nonatomic) MTLShaderValidation shaderValidation;
@property (nonatomic) MTL4ShaderReflection shaderReflection;
@end
@interface revenantHost_MTL4StaticLinkingDescriptor : NSObject
@property (nonatomic, copy) NSArray *functionDescriptors;
@property (nonatomic, copy) NSArray *privateFunctionDescriptors;
@property (nonatomic, copy) NSDictionary *groups;
@end
@interface revenantHost_MTL4PipelineStageDynamicLinkingDescriptor : NSObject
@property (nonatomic) NSUInteger maxCallStackDepth;
@property (nonatomic, copy) NSArray *binaryLinkedFunctions;
@property (nonatomic, copy) NSArray *preloadedLibraries;
@end
@interface revenantHost_MTL4RenderPipelineDynamicLinkingDescriptor : NSObject
@property (readonly) revenantHost_MTL4PipelineStageDynamicLinkingDescriptor *vertexLinkingDescriptor;
@property (readonly) revenantHost_MTL4PipelineStageDynamicLinkingDescriptor *fragmentLinkingDescriptor;
@property (readonly) revenantHost_MTL4PipelineStageDynamicLinkingDescriptor *tileLinkingDescriptor;
@property (readonly) revenantHost_MTL4PipelineStageDynamicLinkingDescriptor *objectLinkingDescriptor;
@property (readonly) revenantHost_MTL4PipelineStageDynamicLinkingDescriptor *meshLinkingDescriptor;
@end
@interface revenantHost_MTL4RenderPipelineBinaryFunctionsDescriptor : NSObject
@property (nonatomic, copy) NSArray *vertexAdditionalBinaryFunctions;
@property (nonatomic, copy) NSArray *fragmentAdditionalBinaryFunctions;
@property (nonatomic, copy) NSArray *tileAdditionalBinaryFunctions;
@property (nonatomic, copy) NSArray *objectAdditionalBinaryFunctions;
@property (nonatomic, copy) NSArray *meshAdditionalBinaryFunctions;
- (void)reset;
@end
@interface revenantHost_MTL4RenderPipelineColorAttachmentDescriptor : NSObject
@property (nonatomic) MTLPixelFormat pixelFormat;
@property (nonatomic) MTL4BlendState blendingState;
@property (nonatomic) MTLBlendFactor sourceRGBBlendFactor;
@property (nonatomic) MTLBlendFactor destinationRGBBlendFactor;
@property (nonatomic) MTLBlendOperation rgbBlendOperation;
@property (nonatomic) MTLBlendFactor sourceAlphaBlendFactor;
@property (nonatomic) MTLBlendFactor destinationAlphaBlendFactor;
@property (nonatomic) MTLBlendOperation alphaBlendOperation;
@property (nonatomic) MTLColorWriteMask writeMask;
- (void)reset;
@end
@interface revenantHost_MTL4RenderPipelineColorAttachmentDescriptorArray : NSObject
- (revenantHost_MTL4RenderPipelineColorAttachmentDescriptor *)objectAtIndexedSubscript:(NSUInteger)index;
- (void)setObject:(revenantHost_MTL4RenderPipelineColorAttachmentDescriptor *)attachment atIndexedSubscript:(NSUInteger)index;
- (void)reset;
@end
@interface revenantHost_MTL4PipelineDescriptor : NSObject
@property (nonatomic, copy) NSString *label;
@property (nonatomic, retain) id options;
@end
@interface revenantHost_MTL4RenderPipelineDescriptor : revenantHost_MTL4PipelineDescriptor
@property (nonatomic, copy) id vertexFunctionDescriptor;
@property (nonatomic, copy) id fragmentFunctionDescriptor;
@property (nonatomic, copy) id vertexDescriptor;
@property (nonatomic) NSUInteger rasterSampleCount;
@property (nonatomic) MTL4AlphaToCoverageState alphaToCoverageState;
@property (nonatomic) MTL4AlphaToOneState alphaToOneState;
@property (nonatomic, getter=isRasterizationEnabled) BOOL rasterizationEnabled;
@property (nonatomic) NSUInteger maxVertexAmplificationCount;
@property (readonly) revenantHost_MTL4RenderPipelineColorAttachmentDescriptorArray *colorAttachments;
@property (nonatomic) MTLPrimitiveTopologyClass inputPrimitiveTopology;
@property (nonatomic, copy) id vertexStaticLinkingDescriptor;
@property (nonatomic, copy) id fragmentStaticLinkingDescriptor;
@property (nonatomic) BOOL supportVertexBinaryLinking;
@property (nonatomic) BOOL supportFragmentBinaryLinking;
@property (nonatomic) MTL4LogicalToPhysicalColorAttachmentMappingState colorAttachmentMappingState;
@property (nonatomic) MTL4IndirectCommandBufferSupportState supportIndirectCommandBuffers;
- (void)reset;
@end
@interface revenantHost_MTL4ComputePipelineDescriptor : revenantHost_MTL4PipelineDescriptor
@property (nonatomic, copy) id computeFunctionDescriptor;
@property (nonatomic) BOOL threadGroupSizeIsMultipleOfThreadExecutionWidth;
@property (nonatomic) NSUInteger maxTotalThreadsPerThreadgroup;
@property (nonatomic) MTLSize requiredThreadsPerThreadgroup;
@property (nonatomic) BOOL supportBinaryLinking;
@property (nonatomic, copy) id staticLinkingDescriptor;
@property (nonatomic) MTL4IndirectCommandBufferSupportState supportIndirectCommandBuffers;
- (void)reset;
@end
@interface revenantHost_MTL4TileRenderPipelineDescriptor : revenantHost_MTL4PipelineDescriptor
@property (nonatomic, copy) id tileFunctionDescriptor;
@property (nonatomic) NSUInteger rasterSampleCount;
@property (readonly) MTLTileRenderPipelineColorAttachmentDescriptorArray *colorAttachments;
@property (nonatomic) BOOL threadgroupSizeMatchesTileSize;
@property (nonatomic) NSUInteger maxTotalThreadsPerThreadgroup;
@property (nonatomic) MTLSize requiredThreadsPerThreadgroup;
@property (nonatomic, copy) id staticLinkingDescriptor;
@property (nonatomic) BOOL supportBinaryLinking;
- (void)reset;
@end
@interface revenantHost_MTL4MeshRenderPipelineDescriptor : revenantHost_MTL4PipelineDescriptor
@property (nonatomic, copy) id objectFunctionDescriptor;
@property (nonatomic, copy) id meshFunctionDescriptor;
@property (nonatomic, copy) id fragmentFunctionDescriptor;
@property (nonatomic) NSUInteger maxTotalThreadsPerObjectThreadgroup;
@property (nonatomic) NSUInteger maxTotalThreadsPerMeshThreadgroup;
@property (nonatomic) MTLSize requiredThreadsPerObjectThreadgroup;
@property (nonatomic) MTLSize requiredThreadsPerMeshThreadgroup;
@property (nonatomic) BOOL objectThreadgroupSizeIsMultipleOfThreadExecutionWidth;
@property (nonatomic) BOOL meshThreadgroupSizeIsMultipleOfThreadExecutionWidth;
@property (nonatomic) NSUInteger payloadMemoryLength;
@property (nonatomic) NSUInteger maxTotalThreadgroupsPerMeshGrid;
@property (nonatomic) NSUInteger rasterSampleCount;
@property (nonatomic) MTL4AlphaToCoverageState alphaToCoverageState;
@property (nonatomic) MTL4AlphaToOneState alphaToOneState;
@property (nonatomic, getter=isRasterizationEnabled) BOOL rasterizationEnabled;
@property (nonatomic) NSUInteger maxVertexAmplificationCount;
@property (readonly) revenantHost_MTL4RenderPipelineColorAttachmentDescriptorArray *colorAttachments;
@property (nonatomic, copy) id objectStaticLinkingDescriptor;
@property (nonatomic, copy) id meshStaticLinkingDescriptor;
@property (nonatomic, copy) id fragmentStaticLinkingDescriptor;
@property (nonatomic) BOOL supportObjectBinaryLinking;
@property (nonatomic) BOOL supportMeshBinaryLinking;
@property (nonatomic) BOOL supportFragmentBinaryLinking;
@property (nonatomic) MTL4LogicalToPhysicalColorAttachmentMappingState colorAttachmentMappingState;
@property (nonatomic) MTL4IndirectCommandBufferSupportState supportIndirectCommandBuffers;
- (void)reset;
@end

static int failures;
static int checks;

static void check(BOOL ok, NSString *what)
{
    checks++;
    if (ok) printf("  ok   %s\n", [what UTF8String]);
    else { printf("  FAIL %s\n", [what UTF8String]); failures++; }
}

static void same_l(long port, long host, NSString *what)
{
    check(port == host, ([NSString stringWithFormat:@"%@: the port %ld and Apple's own object %ld",
                          what, port, host]));
}

static void same_u(unsigned long port, unsigned long host, NSString *what)
{
    check(port == host, ([NSString stringWithFormat:@"%@: the port %lu and Apple's own object %lu",
                          what, port, host]));
}

static id hostSlot(id array, NSUInteger index)
{
    @try { return [(MTL4RenderPipelineColorAttachmentDescriptorArray *)array objectAtIndexedSubscript:index]; }
    @catch (NSException *why) { printf("       Apple's side raised at %lu: %s\n", (unsigned long)index, [[why reason] UTF8String]); return nil; }
}

static id portSlot(id array, NSUInteger index)
{
    @try { return [(revenantHost_MTL4RenderPipelineColorAttachmentDescriptorArray *)array objectAtIndexedSubscript:index]; }
    @catch (NSException *why) { printf("       the port raised at %lu: %s\n", (unsigned long)index, [[why reason] UTF8String]); return nil; }
}

static void compare_size(MTLSize port, MTLSize host, NSString *what)
{
    check(port.width == host.width && port.height == host.height && port.depth == host.depth,
          ([NSString stringWithFormat:@"%@: the port %lux%lux%lu and Apple's own object %lux%lux%lu",
            what, (unsigned long)port.width, (unsigned long)port.height, (unsigned long)port.depth,
            (unsigned long)host.width, (unsigned long)host.height, (unsigned long)host.depth]));
}

int main(void)
{
    setvbuf(stdout, NULL, _IONBF, 0);
    @autoreleasepool {
        printf("no device is created: a descriptor asks for none, and both sides are [[X alloc] init]\n");
        checks++;
        if (NSClassFromString(@"ZZZNoSuchNameRevenantR16") == nil)
            printf("  ok   the control: ZZZNoSuchNameRevenantR16 is not a class of this framework\n");
        else {
            printf("  FAIL the control: ZZZNoSuchNameRevenantR16 exists, so this harness's answers mean nothing\n");
            failures++;
        }

        printf("MTL4PipelineOptions\n");
        {
            MTL4PipelineOptions *host = [[MTL4PipelineOptions alloc] init];
            revenantHost_MTL4PipelineOptions *port = [[revenantHost_MTL4PipelineOptions alloc] init];
            same_l((long)port.shaderValidation, (long)host.shaderValidation, @"fresh: shaderValidation");
            same_u((unsigned long)port.shaderReflection, (unsigned long)host.shaderReflection, @"fresh: shaderReflection");
            [host setShaderValidation:MTLShaderValidationDisabled];
            [port setShaderValidation:MTLShaderValidationDisabled];
            [host setShaderReflection:MTL4ShaderReflectionBufferTypeInfo];
            [port setShaderReflection:MTL4ShaderReflectionBufferTypeInfo];
            same_l((long)port.shaderValidation, (long)host.shaderValidation, @"after a set: shaderValidation");
            same_u((unsigned long)port.shaderReflection, (unsigned long)host.shaderReflection, @"after a set: shaderReflection");
            MTL4PipelineOptions *hostCopy = [host copy];
            revenantHost_MTL4PipelineOptions *portCopy = [port copy];
            same_l((long)portCopy.shaderValidation, (long)hostCopy.shaderValidation, @"copy of a changed one: shaderValidation");
            same_u((unsigned long)portCopy.shaderReflection, (unsigned long)hostCopy.shaderReflection, @"copy of a changed one: shaderReflection");
        }

        printf("MTL4StaticLinkingDescriptor\n");
        {
            MTL4StaticLinkingDescriptor *host = [[MTL4StaticLinkingDescriptor alloc] init];
            revenantHost_MTL4StaticLinkingDescriptor *port = [[revenantHost_MTL4StaticLinkingDescriptor alloc] init];
            check(host.functionDescriptors == nil && port.functionDescriptors == nil, @"fresh: functionDescriptors is nil on both sides");
            check(host.privateFunctionDescriptors == nil && port.privateFunctionDescriptors == nil, @"fresh: privateFunctionDescriptors is nil on both sides");
            check(host.groups == nil && port.groups == nil, @"fresh: groups is nil on both sides");
        }

        printf("MTL4PipelineStageDynamicLinkingDescriptor\n");
        {
            MTL4PipelineStageDynamicLinkingDescriptor *host = [[MTL4PipelineStageDynamicLinkingDescriptor alloc] init];
            revenantHost_MTL4PipelineStageDynamicLinkingDescriptor *port = [[revenantHost_MTL4PipelineStageDynamicLinkingDescriptor alloc] init];
            same_u((unsigned long)port.maxCallStackDepth, (unsigned long)host.maxCallStackDepth,
                   @"fresh: maxCallStackDepth, and it is Apple's own 1 and not a zero");
            check(host.binaryLinkedFunctions == nil && port.binaryLinkedFunctions == nil, @"fresh: binaryLinkedFunctions is nil on both sides");
            check(host.preloadedLibraries == nil && port.preloadedLibraries == nil, @"fresh: preloadedLibraries is nil on both sides");
            MTL4PipelineStageDynamicLinkingDescriptor *hostCopy = [host copy];
            revenantHost_MTL4PipelineStageDynamicLinkingDescriptor *portCopy = [port copy];
            same_u((unsigned long)portCopy.maxCallStackDepth, (unsigned long)hostCopy.maxCallStackDepth, @"copy: maxCallStackDepth");
        }

        printf("MTL4RenderPipelineDynamicLinkingDescriptor\n");
        {
            MTL4RenderPipelineDynamicLinkingDescriptor *host = [[MTL4RenderPipelineDynamicLinkingDescriptor alloc] init];
            revenantHost_MTL4RenderPipelineDynamicLinkingDescriptor *port = [[revenantHost_MTL4RenderPipelineDynamicLinkingDescriptor alloc] init];
            check(host.vertexLinkingDescriptor != nil && port.vertexLinkingDescriptor != nil, @"fresh: vertexLinkingDescriptor is an object on both sides");
            check(host.fragmentLinkingDescriptor != nil && port.fragmentLinkingDescriptor != nil, @"fresh: fragmentLinkingDescriptor is an object on both sides");
            check(host.tileLinkingDescriptor != nil && port.tileLinkingDescriptor != nil, @"fresh: tileLinkingDescriptor is an object on both sides");
            check(host.objectLinkingDescriptor != nil && port.objectLinkingDescriptor != nil, @"fresh: objectLinkingDescriptor is an object on both sides");
            check(host.meshLinkingDescriptor != nil && port.meshLinkingDescriptor != nil, @"fresh: meshLinkingDescriptor is an object on both sides");
        }

        printf("MTL4RenderPipelineBinaryFunctionsDescriptor\n");
        {
            MTL4RenderPipelineBinaryFunctionsDescriptor *host = [[MTL4RenderPipelineBinaryFunctionsDescriptor alloc] init];
            revenantHost_MTL4RenderPipelineBinaryFunctionsDescriptor *port = [[revenantHost_MTL4RenderPipelineBinaryFunctionsDescriptor alloc] init];
            check(host.vertexAdditionalBinaryFunctions == nil && port.vertexAdditionalBinaryFunctions == nil, @"fresh: vertex is nil on both sides");
            check(host.fragmentAdditionalBinaryFunctions == nil && port.fragmentAdditionalBinaryFunctions == nil, @"fresh: fragment is nil on both sides");
            check(host.tileAdditionalBinaryFunctions == nil && port.tileAdditionalBinaryFunctions == nil, @"fresh: tile is nil on both sides");
            check(host.objectAdditionalBinaryFunctions == nil && port.objectAdditionalBinaryFunctions == nil, @"fresh: object is nil on both sides");
            check(host.meshAdditionalBinaryFunctions == nil && port.meshAdditionalBinaryFunctions == nil, @"fresh: mesh is nil on both sides");
            [host setVertexAdditionalBinaryFunctions:@[@"a"]];
            [port setVertexAdditionalBinaryFunctions:@[@"a"]];
            check([(MTL4RenderPipelineBinaryFunctionsDescriptor *)[host copy] vertexAdditionalBinaryFunctions].count ==
                  [(revenantHost_MTL4RenderPipelineBinaryFunctionsDescriptor *)[port copy] vertexAdditionalBinaryFunctions].count,
                  @"after a set: a copy carries the vertex array on both sides");
            [host reset]; [port reset];
            check(host.vertexAdditionalBinaryFunctions == nil && port.vertexAdditionalBinaryFunctions == nil,
                  @"after -reset: the vertex array is nil on both sides");
        }

        printf("MTL4RenderPipelineColorAttachmentDescriptor\n");
        {
            MTL4RenderPipelineColorAttachmentDescriptor *host = [[MTL4RenderPipelineColorAttachmentDescriptor alloc] init];
            revenantHost_MTL4RenderPipelineColorAttachmentDescriptor *port = [[revenantHost_MTL4RenderPipelineColorAttachmentDescriptor alloc] init];
            same_l((long)port.pixelFormat, (long)host.pixelFormat, @"fresh: pixelFormat, and it is MTLPixelFormatInvalid");
            same_l((long)port.blendingState, (long)host.blendingState, @"fresh: blendingState");
            same_l((long)port.sourceRGBBlendFactor, (long)host.sourceRGBBlendFactor, @"fresh: sourceRGBBlendFactor, and it is One");
            same_l((long)port.destinationRGBBlendFactor, (long)host.destinationRGBBlendFactor, @"fresh: destinationRGBBlendFactor, and it is Zero");
            same_l((long)port.rgbBlendOperation, (long)host.rgbBlendOperation, @"fresh: rgbBlendOperation");
            same_l((long)port.sourceAlphaBlendFactor, (long)host.sourceAlphaBlendFactor, @"fresh: sourceAlphaBlendFactor");
            same_l((long)port.destinationAlphaBlendFactor, (long)host.destinationAlphaBlendFactor, @"fresh: destinationAlphaBlendFactor");
            same_l((long)port.alphaBlendOperation, (long)host.alphaBlendOperation, @"fresh: alphaBlendOperation");
            same_u((unsigned long)port.writeMask, (unsigned long)host.writeMask, @"fresh: writeMask, and it is MTLColorWriteMaskAll");
            [host setPixelFormat:MTLPixelFormatRGBA8Unorm]; [port setPixelFormat:MTLPixelFormatRGBA8Unorm];
            [host setBlendingState:MTL4BlendStateEnabled]; [port setBlendingState:MTL4BlendStateEnabled];
            [host setWriteMask:MTLColorWriteMaskRed]; [port setWriteMask:MTLColorWriteMaskRed];
            same_l((long)port.pixelFormat, (long)host.pixelFormat, @"after a set: pixelFormat");
            same_l((long)port.blendingState, (long)host.blendingState, @"after a set: blendingState");
            same_u((unsigned long)port.writeMask, (unsigned long)host.writeMask, @"after a set: writeMask");
            [host reset]; [port reset];
            same_l((long)port.pixelFormat, (long)host.pixelFormat, @"after -reset: pixelFormat is back to the default");
            same_u((unsigned long)port.writeMask, (unsigned long)host.writeMask, @"after -reset: writeMask is back to All");
        }

        printf("MTL4RenderPipelineColorAttachmentDescriptorArray\n");
        {
            MTL4RenderPipelineColorAttachmentDescriptorArray *host = [[MTL4RenderPipelineColorAttachmentDescriptorArray alloc] init];
            revenantHost_MTL4RenderPipelineColorAttachmentDescriptorArray *port = [[revenantHost_MTL4RenderPipelineColorAttachmentDescriptorArray alloc] init];
            for (NSUInteger index = 0; index < 8; index++)
                check(hostSlot(host, index) != nil && portSlot(port, index) != nil,
                      ([NSString stringWithFormat:@"read %lu: both sides answer a descriptor", (unsigned long)index]));
            MTL4RenderPipelineColorAttachmentDescriptor *hostAttachment = [[MTL4RenderPipelineColorAttachmentDescriptor alloc] init];
            revenantHost_MTL4RenderPipelineColorAttachmentDescriptor *portAttachment = [[revenantHost_MTL4RenderPipelineColorAttachmentDescriptor alloc] init];
            hostAttachment.pixelFormat = MTLPixelFormatRGBA8Unorm;
            portAttachment.pixelFormat = MTLPixelFormatRGBA8Unorm;
            [host setObject:hostAttachment atIndexedSubscript:2];
            [port setObject:portAttachment atIndexedSubscript:2];
            check(hostSlot(host, 2) != hostAttachment && portSlot(port, 2) != portAttachment,
                  @"a write copies: the slot holds a copy on both sides, not the object handed in");
            same_l((long)((MTL4RenderPipelineColorAttachmentDescriptor *)hostSlot(host, 2)).pixelFormat,
                   (long)((revenantHost_MTL4RenderPipelineColorAttachmentDescriptor *)portSlot(port, 2)).pixelFormat,
                   @"a write copies: the copy carries the format");
            [host setObject:nil atIndexedSubscript:2];
            [port setObject:nil atIndexedSubscript:2];
            same_l((long)((MTL4RenderPipelineColorAttachmentDescriptor *)hostSlot(host, 2)).pixelFormat,
                   (long)((revenantHost_MTL4RenderPipelineColorAttachmentDescriptor *)portSlot(port, 2)).pixelFormat,
                   @"a nil empties the slot: the format is the default on both sides");
            [host reset]; [port reset];
            check(hostSlot(host, 2) != nil && portSlot(port, 2) != nil, @"after -reset: both sides still answer a descriptor");
        }

        printf("MTL4PipelineDescriptor\n");
        {
            MTL4PipelineDescriptor *host = [[MTL4PipelineDescriptor alloc] init];
            revenantHost_MTL4PipelineDescriptor *port = [[revenantHost_MTL4PipelineDescriptor alloc] init];
            check(host.label == nil && port.label == nil, @"fresh: label is nil on both sides");
            check(host.options == nil && port.options == nil,
                  @"fresh: options is nil on both sides, and NOT a fresh MTL4PipelineOptions");
            [host setLabel:@"h"]; [port setLabel:@"h"];
            same_u((unsigned long)[host.label length], (unsigned long)[port.label length], @"after a set: label");
        }

        printf("MTL4RenderPipelineDescriptor\n");
        {
            MTL4RenderPipelineDescriptor *host = [[MTL4RenderPipelineDescriptor alloc] init];
            revenantHost_MTL4RenderPipelineDescriptor *port = [[revenantHost_MTL4RenderPipelineDescriptor alloc] init];
            check(host.vertexFunctionDescriptor == nil && port.vertexFunctionDescriptor == nil, @"fresh: vertexFunctionDescriptor is nil on both sides");
            check(host.fragmentFunctionDescriptor == nil && port.fragmentFunctionDescriptor == nil, @"fresh: fragmentFunctionDescriptor is nil on both sides");
            check(host.vertexDescriptor != nil && port.vertexDescriptor != nil,
                  @"fresh: vertexDescriptor IS an object on both sides");
            for (NSUInteger index = 0; index < 8; index++)
                check([host.vertexDescriptor.attributes objectAtIndexedSubscript:index] != nil &&
                      [((MTLVertexDescriptor *)port.vertexDescriptor).attributes objectAtIndexedSubscript:index] != nil,
                      ([NSString stringWithFormat:@"fresh: that vertex descriptor answers attribute %lu", (unsigned long)index]));
            same_u((unsigned long)port.rasterSampleCount, (unsigned long)host.rasterSampleCount, @"fresh: rasterSampleCount, and it is Apple's own 1");
            same_l((long)port.alphaToCoverageState, (long)host.alphaToCoverageState, @"fresh: alphaToCoverageState");
            same_l((long)port.alphaToOneState, (long)host.alphaToOneState, @"fresh: alphaToOneState");
            check(port.rasterizationEnabled == host.rasterizationEnabled && host.rasterizationEnabled,
                  @"fresh: isRasterizationEnabled is YES on both sides");
            same_u((unsigned long)port.maxVertexAmplificationCount, (unsigned long)host.maxVertexAmplificationCount,
                   @"fresh: maxVertexAmplificationCount, and it is Apple's own 1");
            check(host.colorAttachments != nil && port.colorAttachments != nil, @"fresh: colorAttachments is an object on both sides");
            same_l((long)port.inputPrimitiveTopology, (long)host.inputPrimitiveTopology, @"fresh: inputPrimitiveTopology");
            check(host.vertexStaticLinkingDescriptor != nil && port.vertexStaticLinkingDescriptor != nil,
                  @"fresh: vertexStaticLinkingDescriptor is an object on both sides");
            check(host.fragmentStaticLinkingDescriptor != nil && port.fragmentStaticLinkingDescriptor != nil,
                  @"fresh: fragmentStaticLinkingDescriptor is an object on both sides");
            check(host.supportVertexBinaryLinking == port.supportVertexBinaryLinking, @"fresh: supportVertexBinaryLinking");
            check(host.supportFragmentBinaryLinking == port.supportFragmentBinaryLinking, @"fresh: supportFragmentBinaryLinking");
            same_l((long)port.colorAttachmentMappingState, (long)host.colorAttachmentMappingState, @"fresh: colorAttachmentMappingState");
            same_l((long)port.supportIndirectCommandBuffers, (long)host.supportIndirectCommandBuffers, @"fresh: supportIndirectCommandBuffers");

            [host setRasterSampleCount:4]; [port setRasterSampleCount:4];
            [host setMaxVertexAmplificationCount:7]; [port setMaxVertexAmplificationCount:7];
            [host setRasterizationEnabled:NO]; [port setRasterizationEnabled:NO];
            [host setInputPrimitiveTopology:MTLPrimitiveTopologyClassTriangle]; [port setInputPrimitiveTopology:MTLPrimitiveTopologyClassTriangle];
            same_u((unsigned long)port.rasterSampleCount, (unsigned long)host.rasterSampleCount, @"after a set: rasterSampleCount");
            same_u((unsigned long)port.maxVertexAmplificationCount, (unsigned long)host.maxVertexAmplificationCount, @"after a set: maxVertexAmplificationCount");
            check(port.rasterizationEnabled == host.rasterizationEnabled, @"after a set: isRasterizationEnabled");
            same_l((long)port.inputPrimitiveTopology, (long)host.inputPrimitiveTopology, @"after a set: inputPrimitiveTopology");

            [host reset]; [port reset];
            same_u((unsigned long)port.rasterSampleCount, (unsigned long)host.rasterSampleCount, @"after -reset: rasterSampleCount is 1 again");
            check(port.rasterizationEnabled == host.rasterizationEnabled && host.rasterizationEnabled, @"after -reset: isRasterizationEnabled is YES again");
            check(port.vertexStaticLinkingDescriptor != nil, @"after -reset: the null_resettable getter still answers an object");
        }

        printf("MTL4ComputePipelineDescriptor\n");
        {
            MTL4ComputePipelineDescriptor *host = [[MTL4ComputePipelineDescriptor alloc] init];
            revenantHost_MTL4ComputePipelineDescriptor *port = [[revenantHost_MTL4ComputePipelineDescriptor alloc] init];
            check(host.computeFunctionDescriptor == nil && port.computeFunctionDescriptor == nil, @"fresh: computeFunctionDescriptor is nil on both sides");
            check(host.threadGroupSizeIsMultipleOfThreadExecutionWidth == port.threadGroupSizeIsMultipleOfThreadExecutionWidth, @"fresh: threadGroupSizeIsMultipleOfThreadExecutionWidth");
            same_u((unsigned long)port.maxTotalThreadsPerThreadgroup, (unsigned long)host.maxTotalThreadsPerThreadgroup, @"fresh: maxTotalThreadsPerThreadgroup");
            compare_size(port.requiredThreadsPerThreadgroup, host.requiredThreadsPerThreadgroup, @"fresh: requiredThreadsPerThreadgroup");
            check(host.supportBinaryLinking == port.supportBinaryLinking, @"fresh: supportBinaryLinking");
            check(host.staticLinkingDescriptor != nil && port.staticLinkingDescriptor != nil, @"fresh: staticLinkingDescriptor is an object on both sides");
            same_l((long)port.supportIndirectCommandBuffers, (long)host.supportIndirectCommandBuffers, @"fresh: supportIndirectCommandBuffers");
        }

        printf("MTL4TileRenderPipelineDescriptor\n");
        {
            MTL4TileRenderPipelineDescriptor *host = [[MTL4TileRenderPipelineDescriptor alloc] init];
            revenantHost_MTL4TileRenderPipelineDescriptor *port = [[revenantHost_MTL4TileRenderPipelineDescriptor alloc] init];
            check(host.tileFunctionDescriptor == nil && port.tileFunctionDescriptor == nil, @"fresh: tileFunctionDescriptor is nil on both sides");
            same_u((unsigned long)port.rasterSampleCount, (unsigned long)host.rasterSampleCount, @"fresh: rasterSampleCount");
            check(host.colorAttachments != nil && port.colorAttachments != nil, @"fresh: colorAttachments is an object on both sides");
            check(host.threadgroupSizeMatchesTileSize == port.threadgroupSizeMatchesTileSize, @"fresh: threadgroupSizeMatchesTileSize");
            same_u((unsigned long)port.maxTotalThreadsPerThreadgroup, (unsigned long)host.maxTotalThreadsPerThreadgroup, @"fresh: maxTotalThreadsPerThreadgroup");
            compare_size(port.requiredThreadsPerThreadgroup, host.requiredThreadsPerThreadgroup, @"fresh: requiredThreadsPerThreadgroup");
            check(host.staticLinkingDescriptor != nil && port.staticLinkingDescriptor != nil, @"fresh: staticLinkingDescriptor is an object on both sides");
            check(host.supportBinaryLinking == port.supportBinaryLinking, @"fresh: supportBinaryLinking");
            for (NSUInteger index = 0; index < 8; index++)
                check([host.colorAttachments objectAtIndexedSubscript:index] != nil &&
                      [port.colorAttachments objectAtIndexedSubscript:index] != nil,
                      ([NSString stringWithFormat:@"tile colour attachment %lu: both sides answer a descriptor", (unsigned long)index]));
        }

        printf("MTL4MeshRenderPipelineDescriptor\n");
        {
            MTL4MeshRenderPipelineDescriptor *host = [[MTL4MeshRenderPipelineDescriptor alloc] init];
            revenantHost_MTL4MeshRenderPipelineDescriptor *port = [[revenantHost_MTL4MeshRenderPipelineDescriptor alloc] init];
            check(host.objectFunctionDescriptor == nil && port.objectFunctionDescriptor == nil, @"fresh: objectFunctionDescriptor is nil on both sides");
            check(host.meshFunctionDescriptor == nil && port.meshFunctionDescriptor == nil, @"fresh: meshFunctionDescriptor is nil on both sides");
            check(host.fragmentFunctionDescriptor == nil && port.fragmentFunctionDescriptor == nil, @"fresh: fragmentFunctionDescriptor is nil on both sides");
            same_u((unsigned long)port.maxTotalThreadsPerObjectThreadgroup, (unsigned long)host.maxTotalThreadsPerObjectThreadgroup, @"fresh: maxTotalThreadsPerObjectThreadgroup");
            same_u((unsigned long)port.maxTotalThreadsPerMeshThreadgroup, (unsigned long)host.maxTotalThreadsPerMeshThreadgroup, @"fresh: maxTotalThreadsPerMeshThreadgroup");
            compare_size(port.requiredThreadsPerObjectThreadgroup, host.requiredThreadsPerObjectThreadgroup, @"fresh: requiredThreadsPerObjectThreadgroup");
            compare_size(port.requiredThreadsPerMeshThreadgroup, host.requiredThreadsPerMeshThreadgroup, @"fresh: requiredThreadsPerMeshThreadgroup");
            check(host.objectThreadgroupSizeIsMultipleOfThreadExecutionWidth == port.objectThreadgroupSizeIsMultipleOfThreadExecutionWidth, @"fresh: objectThreadgroupSizeIsMultipleOfThreadExecutionWidth");
            check(host.meshThreadgroupSizeIsMultipleOfThreadExecutionWidth == port.meshThreadgroupSizeIsMultipleOfThreadExecutionWidth, @"fresh: meshThreadgroupSizeIsMultipleOfThreadExecutionWidth");
            same_u((unsigned long)port.payloadMemoryLength, (unsigned long)host.payloadMemoryLength, @"fresh: payloadMemoryLength");
            same_u((unsigned long)port.maxTotalThreadgroupsPerMeshGrid, (unsigned long)host.maxTotalThreadgroupsPerMeshGrid, @"fresh: maxTotalThreadgroupsPerMeshGrid");
            same_u((unsigned long)port.rasterSampleCount, (unsigned long)host.rasterSampleCount, @"fresh: rasterSampleCount");
            same_l((long)port.alphaToCoverageState, (long)host.alphaToCoverageState, @"fresh: alphaToCoverageState");
            same_l((long)port.alphaToOneState, (long)host.alphaToOneState, @"fresh: alphaToOneState");
            check(port.rasterizationEnabled == host.rasterizationEnabled && host.rasterizationEnabled, @"fresh: isRasterizationEnabled is YES on both sides");
            same_u((unsigned long)port.maxVertexAmplificationCount, (unsigned long)host.maxVertexAmplificationCount, @"fresh: maxVertexAmplificationCount");
            check(host.colorAttachments != nil && port.colorAttachments != nil, @"fresh: colorAttachments is an object on both sides");
            check(host.objectStaticLinkingDescriptor != nil && port.objectStaticLinkingDescriptor != nil, @"fresh: objectStaticLinkingDescriptor is an object on both sides");
            check(host.meshStaticLinkingDescriptor != nil && port.meshStaticLinkingDescriptor != nil, @"fresh: meshStaticLinkingDescriptor is an object on both sides");
            check(host.fragmentStaticLinkingDescriptor != nil && port.fragmentStaticLinkingDescriptor != nil, @"fresh: fragmentStaticLinkingDescriptor is an object on both sides");
            check(host.supportObjectBinaryLinking == port.supportObjectBinaryLinking, @"fresh: supportObjectBinaryLinking");
            check(host.supportMeshBinaryLinking == port.supportMeshBinaryLinking, @"fresh: supportMeshBinaryLinking");
            check(host.supportFragmentBinaryLinking == port.supportFragmentBinaryLinking, @"fresh: supportFragmentBinaryLinking");
            same_l((long)port.colorAttachmentMappingState, (long)host.colorAttachmentMappingState, @"fresh: colorAttachmentMappingState");
            same_l((long)port.supportIndirectCommandBuffers, (long)host.supportIndirectCommandBuffers, @"fresh: supportIndirectCommandBuffers");
        }

        printf("MTL4FunctionDescriptor and the three that extend it\n");
        {
            MTL4FunctionDescriptor *host = [[MTL4FunctionDescriptor alloc] init];
            check(host != nil, @"fresh MTL4FunctionDescriptor is an object, and it has no members to compare");
            check([host isKindOfClass:[NSObject class]], @"and it is an NSObject, as its declaration says");
        }

        printf("the acceleration structure geometry descriptors\n");
        {
            MTL4AccelerationStructureGeometryDescriptor *host = [[MTL4AccelerationStructureGeometryDescriptor alloc] init];
            revenantHost_MTL4AccelerationStructureGeometryDescriptor *port = [[revenantHost_MTL4AccelerationStructureGeometryDescriptor alloc] init];
            same_u((unsigned long)port.intersectionFunctionTableOffset, (unsigned long)host.intersectionFunctionTableOffset, @"fresh: intersectionFunctionTableOffset");
            check(host.opaque == port.opaque, @"fresh: opaque");
            check(host.allowDuplicateIntersectionFunctionInvocation == port.allowDuplicateIntersectionFunctionInvocation &&
                  host.allowDuplicateIntersectionFunctionInvocation,
                  @"fresh: allowDuplicateIntersectionFunctionInvocation is YES on both sides - Apple's own, not a NO");
            check(host.label == nil && port.label == nil, @"fresh: label is nil on both sides");
            same_u((unsigned long)port.primitiveDataStride, (unsigned long)host.primitiveDataStride, @"fresh: primitiveDataStride");
            same_u((unsigned long)port.primitiveDataElementSize, (unsigned long)host.primitiveDataElementSize, @"fresh: primitiveDataElementSize");
        }
        {
            MTL4AccelerationStructureTriangleGeometryDescriptor *host = [[MTL4AccelerationStructureTriangleGeometryDescriptor alloc] init];
            revenantHost_MTL4AccelerationStructureTriangleGeometryDescriptor *port = [[revenantHost_MTL4AccelerationStructureTriangleGeometryDescriptor alloc] init];
            same_l((long)port.vertexFormat, (long)host.vertexFormat, @"fresh: vertexFormat, and it is Apple's own Float3");
            check(host.vertexFormat == MTLVertexFormatFloat3, @"that format is MTLVertexFormatFloat3, the enumeration's 30");
            same_u((unsigned long)port.vertexStride, (unsigned long)host.vertexStride, @"fresh: vertexStride");
            same_l((long)port.indexType, (long)host.indexType, @"fresh: indexType, and it is Apple's own Uint32");
            check(host.indexType == MTLIndexTypeUInt32, @"that index type is MTLIndexTypeUint32, the enumeration's 1");
            same_u((unsigned long)port.triangleCount, (unsigned long)host.triangleCount, @"fresh: triangleCount");
            same_l((long)port.transformationMatrixLayout, (long)host.transformationMatrixLayout, @"fresh: transformationMatrixLayout");
        }
        {
            MTL4AccelerationStructureBoundingBoxGeometryDescriptor *host = [[MTL4AccelerationStructureBoundingBoxGeometryDescriptor alloc] init];
            revenantHost_MTL4AccelerationStructureBoundingBoxGeometryDescriptor *port = [[revenantHost_MTL4AccelerationStructureBoundingBoxGeometryDescriptor alloc] init];
            same_u((unsigned long)port.boundingBoxStride, (unsigned long)host.boundingBoxStride, @"fresh: boundingBoxStride, and it is Apple's own 24");
            check(host.boundingBoxStride == 24, @"that stride is 24, three float32s");
            same_u((unsigned long)port.boundingBoxCount, (unsigned long)host.boundingBoxCount, @"fresh: boundingBoxCount");
        }
        {
            MTL4AccelerationStructureCurveGeometryDescriptor *host = [[MTL4AccelerationStructureCurveGeometryDescriptor alloc] init];
            revenantHost_MTL4AccelerationStructureCurveGeometryDescriptor *port = [[revenantHost_MTL4AccelerationStructureCurveGeometryDescriptor alloc] init];
            same_l((long)port.controlPointFormat, (long)host.controlPointFormat, @"fresh: controlPointFormat");
            check(host.controlPointFormat == MTLVertexFormatFloat3, @"a curve's control point format is MTLVertexFormatFloat3");
            same_l((long)port.radiusFormat, (long)host.radiusFormat, @"fresh: radiusFormat, and it is NOT the control point's");
            check(host.radiusFormat == MTLVertexFormatFloat,
                  @"a curve's radius format is MTLVertexFormatFloat - ONE component, the enumeration's 28 - and this assertion said Float2 until the measurement corrected it");
            same_u((unsigned long)port.segmentCount, (unsigned long)host.segmentCount, @"fresh: segmentCount");
            same_l((long)port.curveType, (long)host.curveType, @"fresh: curveType");
            same_l((long)port.curveBasis, (long)host.curveBasis, @"fresh: curveBasis");
            same_l((long)port.curveEndCaps, (long)host.curveEndCaps, @"fresh: curveEndCaps");
        }
        {
            MTL4AccelerationStructureMotionTriangleGeometryDescriptor *host = [[MTL4AccelerationStructureMotionTriangleGeometryDescriptor alloc] init];
            revenantHost_MTL4AccelerationStructureMotionTriangleGeometryDescriptor *port = [[revenantHost_MTL4AccelerationStructureMotionTriangleGeometryDescriptor alloc] init];
            same_l((long)port.vertexFormat, (long)host.vertexFormat, @"fresh motion triangle: vertexFormat");
            same_l((long)port.indexType, (long)host.indexType, @"fresh motion triangle: indexType");
        }
        {
            MTL4AccelerationStructureMotionBoundingBoxGeometryDescriptor *host = [[MTL4AccelerationStructureMotionBoundingBoxGeometryDescriptor alloc] init];
            revenantHost_MTL4AccelerationStructureMotionBoundingBoxGeometryDescriptor *port = [[revenantHost_MTL4AccelerationStructureMotionBoundingBoxGeometryDescriptor alloc] init];
            same_u((unsigned long)port.boundingBoxStride, (unsigned long)host.boundingBoxStride, @"fresh motion bounding box: boundingBoxStride");
        }
        {
            MTL4AccelerationStructureMotionCurveGeometryDescriptor *host = [[MTL4AccelerationStructureMotionCurveGeometryDescriptor alloc] init];
            revenantHost_MTL4AccelerationStructureMotionCurveGeometryDescriptor *port = [[revenantHost_MTL4AccelerationStructureMotionCurveGeometryDescriptor alloc] init];
            same_l((long)port.controlPointFormat, (long)host.controlPointFormat, @"fresh motion curve: controlPointFormat");
            same_l((long)port.radiusFormat, (long)host.radiusFormat, @"fresh motion curve: radiusFormat");
        }

        printf("MTL4RenderPassDescriptor\n");
        {
            MTL4RenderPassDescriptor *host = [[MTL4RenderPassDescriptor alloc] init];
            revenantHost_MTL4RenderPassDescriptor *port = [[revenantHost_MTL4RenderPassDescriptor alloc] init];
            check(host.colorAttachments != nil && port.colorAttachments != nil, @"fresh: colorAttachments is an object on both sides");
            for (NSUInteger index = 0; index < 8; index++)
                check([host.colorAttachments objectAtIndexedSubscript:index] != nil &&
                      [port.colorAttachments objectAtIndexedSubscript:index] != nil,
                      ([NSString stringWithFormat:@"fresh: colour attachment %lu answers on both sides", (unsigned long)index]));
            check(host.depthAttachment != nil && port.depthAttachment != nil, @"fresh: depthAttachment is an object on both sides");
            check(host.stencilAttachment != nil && port.stencilAttachment != nil, @"fresh: stencilAttachment is an object on both sides");
            same_u((unsigned long)port.renderTargetArrayLength, (unsigned long)host.renderTargetArrayLength, @"fresh: renderTargetArrayLength");
            same_u((unsigned long)port.imageblockSampleLength, (unsigned long)host.imageblockSampleLength, @"fresh: imageblockSampleLength");
            same_u((unsigned long)port.threadgroupMemoryLength, (unsigned long)host.threadgroupMemoryLength, @"fresh: threadgroupMemoryLength");
            same_u((unsigned long)port.tileWidth, (unsigned long)host.tileWidth, @"fresh: tileWidth");
            same_u((unsigned long)port.tileHeight, (unsigned long)host.tileHeight, @"fresh: tileHeight");
            same_u((unsigned long)port.defaultRasterSampleCount, (unsigned long)host.defaultRasterSampleCount, @"fresh: defaultRasterSampleCount");
            same_u((unsigned long)port.renderTargetWidth, (unsigned long)host.renderTargetWidth, @"fresh: renderTargetWidth");
            same_u((unsigned long)port.renderTargetHeight, (unsigned long)host.renderTargetHeight, @"fresh: renderTargetHeight");
            check(host.rasterizationRateMap == nil && port.rasterizationRateMap == nil, @"fresh: rasterizationRateMap is nil on both sides");
            check(host.visibilityResultBuffer == nil && port.visibilityResultBuffer == nil, @"fresh: visibilityResultBuffer is nil on both sides");
            same_l((long)port.visibilityResultType, (long)host.visibilityResultType, @"fresh: visibilityResultType");
            check(host.supportColorAttachmentMapping == port.supportColorAttachmentMapping &&
                  !host.supportColorAttachmentMapping, @"fresh: supportColorAttachmentMapping is NO on both sides");
            MTLSamplePosition written[4];
            for (unsigned i = 0; i < 4; i++) { written[i].x = 0.125f * (i + 1); written[i].y = 0.0625f * (i + 1); }
            [host setSamplePositions:written count:4];
            [port setSamplePositions:written count:4];
            MTLSamplePosition readBack[8];
            memset(readBack, 0, sizeof(readBack));
            same_u((unsigned long)[host getSamplePositions:readBack count:4],
                   (unsigned long)[port getSamplePositions:readBack count:4],
                   @"after four positions: how many getSamplePositions:count: answers");
            check(memcmp(readBack, written, sizeof(written)) == 0,
                  @"after four positions: the four positions come back unchanged");
            @try { [port setSamplePositions:written count:3]; check(NO, @"a count of 3 must be refused"); }
            @catch (NSException *why) {
                check([[why reason] rangeOfString:@"0, 2, 4 or 8"].location != NSNotFound,
                      @"a count of 3 is refused, and the message names the counts Metal accepts");
            }
            same_u((unsigned long)[port getSamplePositions:readBack count:4],
                   (unsigned long)4, @"and the positions programmed before it are still there");
            [host setSamplePositions:written count:2];
            [port setSamplePositions:written count:2];
            memset(readBack, 0, sizeof(readBack));
            same_u((unsigned long)[host getSamplePositions:readBack count:2],
                   (unsigned long)[port getSamplePositions:readBack count:2],
                   @"after two positions: how many getSamplePositions:count: answers");
            check(memcmp(readBack, written, 2 * sizeof(MTLSamplePosition)) == 0,
                  @"after two positions: the two positions come back unchanged");
            [host setSamplePositions:NULL count:0];
            [port setSamplePositions:NULL count:0];
            same_u((unsigned long)[host getSamplePositions:readBack count:0],
                   (unsigned long)[port getSamplePositions:readBack count:0],
                   @"after a NULL pointer with a count of zero: the two positions are STILL there");
            [host setSamplePositions:written count:0];
            [port setSamplePositions:written count:0];
            same_u((unsigned long)[host getSamplePositions:readBack count:0],
                   (unsigned long)[port getSamplePositions:readBack count:0],
                   @"after a non-NULL pointer with a count of zero: none are left");
        }

        printf("%d checks, each one against Apple's own object\n", checks);
    }
    if (failures) { printf("%d failure(s)\n", failures); return 1; }
    printf("all checks passed\n");
    return 0;
}
