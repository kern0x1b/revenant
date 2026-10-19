#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

NS_ASSUME_NONNULL_BEGIN

#if defined(__IPHONE_OS_VERSION_MAX_ALLOWED)
#define REVENANT_METAL_SDK_MAX __IPHONE_OS_VERSION_MAX_ALLOWED
#elif defined(__MAC_OS_X_VERSION_MAX_ALLOWED)
#define REVENANT_METAL_SDK_MAX __MAC_OS_X_VERSION_MAX_ALLOWED
#else
#define REVENANT_METAL_SDK_MAX 0
#endif

#if REVENANT_METAL_SDK_MAX < 260000
@protocol MTL4BinaryFunction <NSObject>
@property (nullable, readonly) NSString *name;
@property (readonly) MTLFunctionType functionType;
@end

#if REVENANT_METAL_SDK_MAX < 180000
API_AVAILABLE(ios(18.0))
typedef NS_ENUM(NSInteger, MTLShaderValidation) {
    MTLShaderValidationDefault  = 0,
    MTLShaderValidationEnabled  = 1,
    MTLShaderValidationDisabled = 2,
};
#endif

#if REVENANT_METAL_SDK_MAX < 260000
API_AVAILABLE(ios(26.0))
typedef NS_OPTIONS(NSUInteger, MTL4ShaderReflection) {
    MTL4ShaderReflectionNone           = 0,
    MTL4ShaderReflectionBindingInfo    = 1 << 0,
    MTL4ShaderReflectionBufferTypeInfo = 1 << 1,
};

API_AVAILABLE(ios(26.0))
typedef NS_ENUM(NSInteger, MTL4AlphaToOneState) {
    MTL4AlphaToOneStateDisabled = 0,
    MTL4AlphaToOneStateEnabled  = 1,
};

API_AVAILABLE(ios(26.0))
typedef NS_ENUM(NSInteger, MTL4AlphaToCoverageState) {
    MTL4AlphaToCoverageStateDisabled = 0,
    MTL4AlphaToCoverageStateEnabled  = 1,
};

API_AVAILABLE(ios(26.0))
typedef NS_ENUM(NSInteger, MTL4BlendState) {
    MTL4BlendStateDisabled     = 0,
    MTL4BlendStateEnabled      = 1,
    MTL4BlendStateUnspecialized = 2,
};

API_AVAILABLE(ios(26.0))
typedef NS_ENUM(NSInteger, MTL4IndirectCommandBufferSupportState) {
    MTL4IndirectCommandBufferSupportStateDisabled = 0,
    MTL4IndirectCommandBufferSupportStateEnabled  = 1,
};

API_AVAILABLE(ios(26.0))
typedef NS_ENUM(NSInteger, MTL4LogicalToPhysicalColorAttachmentMappingState) {
    MTL4LogicalToPhysicalColorAttachmentMappingStateIdentity  = 0,
    MTL4LogicalToPhysicalColorAttachmentMappingStateInherited = 1,
};
#endif

API_AVAILABLE(ios(26.0))
@interface MTL4FunctionDescriptor : NSObject <NSCopying>
@end

API_AVAILABLE(ios(26.0))
@interface MTL4PipelineOptions : NSObject <NSCopying>
@property (readwrite, nonatomic) MTLShaderValidation shaderValidation;
@property (readwrite, nonatomic) MTL4ShaderReflection shaderReflection;
@end

API_AVAILABLE(ios(26.0))
@interface MTL4StaticLinkingDescriptor : NSObject <NSCopying>
@property (readwrite, nonatomic, copy, nullable) NSArray<MTL4FunctionDescriptor *> *functionDescriptors;
@property (readwrite, nonatomic, copy, nullable) NSArray<MTL4FunctionDescriptor *> *privateFunctionDescriptors;
@property (readwrite, nonatomic, copy, nullable) NSDictionary<NSString *, NSArray<MTL4FunctionDescriptor *> *> *groups;
@end

API_AVAILABLE(ios(26.0))
@interface MTL4PipelineStageDynamicLinkingDescriptor : NSObject <NSCopying>
@property (readwrite, nonatomic) NSUInteger maxCallStackDepth;
@property (readwrite, nonatomic, copy, nullable) NSArray<id<MTL4BinaryFunction>> *binaryLinkedFunctions;
@property (readwrite, nonatomic, copy) NSArray<id<MTLDynamicLibrary>> *preloadedLibraries;
@end

API_AVAILABLE(ios(26.0))
@interface MTL4RenderPipelineDynamicLinkingDescriptor : NSObject <NSCopying>
@property (readonly, nonatomic) MTL4PipelineStageDynamicLinkingDescriptor *vertexLinkingDescriptor;
@property (readonly, nonatomic) MTL4PipelineStageDynamicLinkingDescriptor *fragmentLinkingDescriptor;
@property (readonly, nonatomic) MTL4PipelineStageDynamicLinkingDescriptor *tileLinkingDescriptor;
@property (readonly, nonatomic) MTL4PipelineStageDynamicLinkingDescriptor *objectLinkingDescriptor;
@property (readonly, nonatomic) MTL4PipelineStageDynamicLinkingDescriptor *meshLinkingDescriptor;
@end

API_AVAILABLE(ios(26.0))
@interface MTL4RenderPipelineBinaryFunctionsDescriptor : NSObject <NSCopying>
@property (nullable, nonatomic, copy) NSArray<id<MTL4BinaryFunction>> *vertexAdditionalBinaryFunctions;
@property (nullable, nonatomic, copy) NSArray<id<MTL4BinaryFunction>> *fragmentAdditionalBinaryFunctions;
@property (nullable, nonatomic, copy) NSArray<id<MTL4BinaryFunction>> *tileAdditionalBinaryFunctions;
@property (nullable, nonatomic, copy) NSArray<id<MTL4BinaryFunction>> *objectAdditionalBinaryFunctions;
@property (nullable, nonatomic, copy) NSArray<id<MTL4BinaryFunction>> *meshAdditionalBinaryFunctions;
- (void)reset;
@end

API_AVAILABLE(ios(26.0))
@interface MTL4RenderPipelineColorAttachmentDescriptor : NSObject <NSCopying>
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

API_AVAILABLE(ios(26.0))
@interface MTL4RenderPipelineColorAttachmentDescriptorArray : NSObject <NSCopying>
- (MTL4RenderPipelineColorAttachmentDescriptor *)objectAtIndexedSubscript:(NSUInteger)attachmentIndex;
- (void)setObject:(nullable MTL4RenderPipelineColorAttachmentDescriptor *)attachment atIndexedSubscript:(NSUInteger)attachmentIndex;
- (void)reset;
@end

API_AVAILABLE(ios(26.0))
@interface MTL4PipelineDescriptor : NSObject <NSCopying>
@property (nullable, copy, nonatomic) NSString *label;
@property (nullable, readwrite, nonatomic, retain) MTL4PipelineOptions *options;
@end

API_AVAILABLE(ios(26.0))
@interface MTL4RenderPipelineDescriptor : MTL4PipelineDescriptor
@property (nullable, readwrite, nonatomic, copy) MTL4FunctionDescriptor *vertexFunctionDescriptor;
@property (nullable, readwrite, nonatomic, copy) MTL4FunctionDescriptor *fragmentFunctionDescriptor;
@property (nullable, nonatomic, copy) MTLVertexDescriptor *vertexDescriptor;
@property (readwrite, nonatomic) NSUInteger rasterSampleCount;
@property (readwrite, nonatomic) MTL4AlphaToCoverageState alphaToCoverageState;
@property (readwrite, nonatomic) MTL4AlphaToOneState alphaToOneState;
@property (readwrite, nonatomic, getter=isRasterizationEnabled) BOOL rasterizationEnabled;
@property (readwrite, nonatomic) NSUInteger maxVertexAmplificationCount;
@property (readonly) MTL4RenderPipelineColorAttachmentDescriptorArray *colorAttachments;
@property (readwrite, nonatomic) MTLPrimitiveTopologyClass inputPrimitiveTopology;
@property (null_resettable, copy, nonatomic) MTL4StaticLinkingDescriptor *vertexStaticLinkingDescriptor;
@property (null_resettable, copy, nonatomic) MTL4StaticLinkingDescriptor *fragmentStaticLinkingDescriptor;
@property (readwrite, nonatomic) BOOL supportVertexBinaryLinking;
@property (readwrite, nonatomic) BOOL supportFragmentBinaryLinking;
@property (readwrite, nonatomic) MTL4LogicalToPhysicalColorAttachmentMappingState colorAttachmentMappingState;
@property (readwrite, nonatomic) MTL4IndirectCommandBufferSupportState supportIndirectCommandBuffers;
- (void)reset;
@end

API_AVAILABLE(ios(26.0))
@interface MTL4ComputePipelineDescriptor : MTL4PipelineDescriptor
@property (nullable, readwrite, nonatomic, copy) MTL4FunctionDescriptor *computeFunctionDescriptor;
@property (readwrite, nonatomic) BOOL threadGroupSizeIsMultipleOfThreadExecutionWidth;
@property (readwrite, nonatomic) NSUInteger maxTotalThreadsPerThreadgroup;
@property (readwrite, nonatomic) MTLSize requiredThreadsPerThreadgroup;
@property (readwrite, nonatomic) BOOL supportBinaryLinking;
@property (nullable, copy, nonatomic) MTL4StaticLinkingDescriptor *staticLinkingDescriptor;
@property (readwrite, nonatomic) MTL4IndirectCommandBufferSupportState supportIndirectCommandBuffers;
- (void)reset;
@end

API_AVAILABLE(ios(26.0))
@interface MTL4TileRenderPipelineDescriptor : MTL4PipelineDescriptor
@property (nullable, readwrite, nonatomic, copy) MTL4FunctionDescriptor *tileFunctionDescriptor;
@property (readwrite, nonatomic) NSUInteger rasterSampleCount;
@property (readonly) MTLTileRenderPipelineColorAttachmentDescriptorArray *colorAttachments;
@property (readwrite, nonatomic) BOOL threadgroupSizeMatchesTileSize;
@property (readwrite, nonatomic) NSUInteger maxTotalThreadsPerThreadgroup;
@property (readwrite, nonatomic) MTLSize requiredThreadsPerThreadgroup;
@property (null_resettable, copy, nonatomic) MTL4StaticLinkingDescriptor *staticLinkingDescriptor;
@property (readwrite, nonatomic) BOOL supportBinaryLinking;
- (void)reset;
@end

API_AVAILABLE(ios(26.0))
@interface MTL4MeshRenderPipelineDescriptor : MTL4PipelineDescriptor
@property (nullable, readwrite, nonatomic, copy) MTL4FunctionDescriptor *objectFunctionDescriptor;
@property (nullable, readwrite, nonatomic, copy) MTL4FunctionDescriptor *meshFunctionDescriptor;
@property (nullable, readwrite, nonatomic, copy) MTL4FunctionDescriptor *fragmentFunctionDescriptor;
@property (readwrite, nonatomic) NSUInteger maxTotalThreadsPerObjectThreadgroup;
@property (readwrite, nonatomic) NSUInteger maxTotalThreadsPerMeshThreadgroup;
@property (readwrite, nonatomic) MTLSize requiredThreadsPerObjectThreadgroup;
@property (readwrite, nonatomic) MTLSize requiredThreadsPerMeshThreadgroup;
@property (readwrite, nonatomic) BOOL objectThreadgroupSizeIsMultipleOfThreadExecutionWidth;
@property (readwrite, nonatomic) BOOL meshThreadgroupSizeIsMultipleOfThreadExecutionWidth;
@property (readwrite, nonatomic) NSUInteger payloadMemoryLength;
@property (readwrite, nonatomic) NSUInteger maxTotalThreadgroupsPerMeshGrid;
@property (readwrite, nonatomic) NSUInteger rasterSampleCount;
@property (readwrite, nonatomic) MTL4AlphaToCoverageState alphaToCoverageState;
@property (readwrite, nonatomic) MTL4AlphaToOneState alphaToOneState;
@property (readwrite, nonatomic, getter=isRasterizationEnabled) BOOL rasterizationEnabled;
@property (readwrite, nonatomic) NSUInteger maxVertexAmplificationCount;
@property (readonly) MTL4RenderPipelineColorAttachmentDescriptorArray *colorAttachments;
@property (null_resettable, copy, nonatomic) MTL4StaticLinkingDescriptor *objectStaticLinkingDescriptor;
@property (null_resettable, copy, nonatomic) MTL4StaticLinkingDescriptor *meshStaticLinkingDescriptor;
@property (null_resettable, copy, nonatomic) MTL4StaticLinkingDescriptor *fragmentStaticLinkingDescriptor;
@property (readwrite, nonatomic) BOOL supportObjectBinaryLinking;
@property (readwrite, nonatomic) BOOL supportMeshBinaryLinking;
@property (readwrite, nonatomic) BOOL supportFragmentBinaryLinking;
@property (readwrite, nonatomic) MTL4LogicalToPhysicalColorAttachmentMappingState colorAttachmentMappingState;
@property (readwrite, nonatomic) MTL4IndirectCommandBufferSupportState supportIndirectCommandBuffers;
- (void)reset;
@end

API_AVAILABLE(ios(26.0))
@interface MTL4SpecializedFunctionDescriptor : MTL4FunctionDescriptor
@property (nullable, copy, readwrite, nonatomic) MTL4FunctionDescriptor *functionDescriptor;
@property (nullable, copy, atomic) NSString *specializedName;
@property (nullable, copy, nonatomic) MTLFunctionConstantValues *constantValues;
@end

API_AVAILABLE(ios(26.0))
@interface MTL4StitchedFunctionDescriptor : MTL4FunctionDescriptor
@property (nullable, copy, nonatomic) MTLFunctionStitchingGraph *functionGraph;
@property (nullable, copy, nonatomic) NSArray<MTL4FunctionDescriptor *> *functionDescriptors;
@end

API_AVAILABLE(ios(26.0))
@interface MTL4LibraryFunctionDescriptor : MTL4FunctionDescriptor
@property (nullable, copy, atomic) NSString *name;
@property (nullable, readwrite, nonatomic, retain) id<MTLLibrary> library;
@end


API_AVAILABLE(ios(17.0))
typedef NS_ENUM(NSInteger, MTLCurveType) {
    MTLCurveTypeRound = 0,
    MTLCurveTypeFlat  = 1,
};

API_AVAILABLE(ios(17.0))
typedef NS_ENUM(NSInteger, MTLCurveBasis) {
    MTLCurveBasisBSpline   = 0,
    MTLCurveBasisCatmullRom = 1,
    MTLCurveBasisLinear     = 2,
    MTLCurveBasisBezier     = 3,
};

API_AVAILABLE(ios(17.0))
typedef NS_ENUM(NSInteger, MTLCurveEndCaps) {
    MTLCurveEndCapsNone   = 0,
    MTLCurveEndCapsDisk   = 1,
    MTLCurveEndCapsSphere = 2,
};

API_AVAILABLE(ios(18.0))
typedef NS_ENUM(NSInteger, MTLMatrixLayout) {
    MTLMatrixLayoutColumnMajor = 0,
    MTLMatrixLayoutRowMajor    = 1,
};

API_AVAILABLE(ios(26.0))
typedef uint64_t MTLGPUAddress;

typedef struct MTL4BufferRange {
    MTLGPUAddress bufferAddress;
    uint64_t length;
} MTL4BufferRange;

API_AVAILABLE(ios(26.0))
@interface MTL4AccelerationStructureGeometryDescriptor : NSObject <NSCopying>
@property (nonatomic) NSUInteger intersectionFunctionTableOffset;
@property (nonatomic) BOOL opaque;
@property (nonatomic) BOOL allowDuplicateIntersectionFunctionInvocation;
@property (nonatomic, copy, nullable) NSString *label;
@property (nonatomic) MTL4BufferRange primitiveDataBuffer;
@property (nonatomic) NSUInteger primitiveDataStride;
@property (nonatomic) NSUInteger primitiveDataElementSize;
@end

API_AVAILABLE(ios(26.0))
@interface MTL4AccelerationStructureTriangleGeometryDescriptor : MTL4AccelerationStructureGeometryDescriptor
@property (nonatomic) MTL4BufferRange vertexBuffer;
@property (nonatomic) MTLAttributeFormat vertexFormat;
@property (nonatomic) NSUInteger vertexStride;
@property (nonatomic) MTL4BufferRange indexBuffer;
@property (nonatomic) MTLIndexType indexType;
@property (nonatomic) NSUInteger triangleCount;
@property (nonatomic) MTL4BufferRange transformationMatrixBuffer;
@property (nonatomic) MTLMatrixLayout transformationMatrixLayout;
@end

API_AVAILABLE(ios(26.0))
@interface MTL4AccelerationStructureBoundingBoxGeometryDescriptor : MTL4AccelerationStructureGeometryDescriptor
@property (nonatomic) MTL4BufferRange boundingBoxBuffer;
@property (nonatomic) NSUInteger boundingBoxStride;
@property (nonatomic) NSUInteger boundingBoxCount;
@end

API_AVAILABLE(ios(26.0))
@interface MTL4AccelerationStructureCurveGeometryDescriptor : MTL4AccelerationStructureGeometryDescriptor
@property (nonatomic) MTL4BufferRange controlPointBuffer;
@property (nonatomic) NSUInteger controlPointCount;
@property (nonatomic) NSUInteger controlPointStride;
@property (nonatomic) MTLAttributeFormat controlPointFormat;
@property (nonatomic) MTL4BufferRange radiusBuffer;
@property (nonatomic) MTLAttributeFormat radiusFormat;
@property (nonatomic) NSUInteger radiusStride;
@property (nonatomic) MTL4BufferRange indexBuffer;
@property (nonatomic) MTLIndexType indexType;
@property (nonatomic) NSUInteger segmentCount;
@property (nonatomic) NSUInteger segmentControlPointCount;
@property (nonatomic) MTLCurveType curveType;
@property (nonatomic) MTLCurveBasis curveBasis;
@property (nonatomic) MTLCurveEndCaps curveEndCaps;
@end

API_AVAILABLE(ios(26.0))
@interface MTL4AccelerationStructureMotionTriangleGeometryDescriptor : MTL4AccelerationStructureGeometryDescriptor
@property (nonatomic) MTL4BufferRange vertexBuffers;
@property (nonatomic) MTLAttributeFormat vertexFormat;
@property (nonatomic) NSUInteger vertexStride;
@property (nonatomic) MTL4BufferRange indexBuffer;
@property (nonatomic) MTLIndexType indexType;
@property (nonatomic) NSUInteger triangleCount;
@property (nonatomic) MTL4BufferRange transformationMatrixBuffer;
@property (nonatomic) MTLMatrixLayout transformationMatrixLayout;
@end

API_AVAILABLE(ios(26.0))
@interface MTL4AccelerationStructureMotionBoundingBoxGeometryDescriptor : MTL4AccelerationStructureGeometryDescriptor
@property (nonatomic) MTL4BufferRange boundingBoxBuffers;
@property (nonatomic) NSUInteger boundingBoxStride;
@property (nonatomic) NSUInteger boundingBoxCount;
@end

API_AVAILABLE(ios(26.0))
@interface MTL4AccelerationStructureMotionCurveGeometryDescriptor : MTL4AccelerationStructureGeometryDescriptor
@property (nonatomic) MTL4BufferRange controlPointBuffers;
@property (nonatomic) NSUInteger controlPointCount;
@property (nonatomic) NSUInteger controlPointStride;
@property (nonatomic) MTLAttributeFormat controlPointFormat;
@property (nonatomic) MTL4BufferRange radiusBuffers;
@property (nonatomic) MTLAttributeFormat radiusFormat;
@property (nonatomic) NSUInteger radiusStride;
@property (nonatomic) MTL4BufferRange indexBuffer;
@property (nonatomic) MTLIndexType indexType;
@property (nonatomic) NSUInteger segmentCount;
@property (nonatomic) NSUInteger segmentControlPointCount;
@property (nonatomic) MTLCurveType curveType;
@property (nonatomic) MTLCurveBasis curveBasis;
@property (nonatomic) MTLCurveEndCaps curveEndCaps;
@end


API_AVAILABLE(ios(26.0))
typedef NS_ENUM(NSInteger, MTLVisibilityResultType) {
    MTLVisibilityResultTypeReset     = 0,
    MTLVisibilityResultTypeAccumulate = 1,
};

API_AVAILABLE(ios(26.0))
@interface MTL4RenderPassDescriptor : NSObject <NSCopying>
@property (readonly) MTLRenderPassColorAttachmentDescriptorArray *colorAttachments;
@property (copy, nonatomic, null_resettable) MTLRenderPassDepthAttachmentDescriptor *depthAttachment;
@property (copy, nonatomic, null_resettable) MTLRenderPassStencilAttachmentDescriptor *stencilAttachment;
@property (nonatomic) NSUInteger renderTargetArrayLength;
@property (nonatomic) NSUInteger imageblockSampleLength;
@property (nonatomic) NSUInteger threadgroupMemoryLength;
@property (nonatomic) NSUInteger tileWidth;
@property (nonatomic) NSUInteger tileHeight;
@property (nonatomic) NSUInteger defaultRasterSampleCount;
@property (nonatomic) NSUInteger renderTargetWidth;
@property (nonatomic) NSUInteger renderTargetHeight;
@property (nullable, nonatomic, strong) id<MTLRasterizationRateMap> rasterizationRateMap;
@property (nullable, nonatomic, strong) id<MTLBuffer> visibilityResultBuffer;
@property (nonatomic) MTLVisibilityResultType visibilityResultType;
- (void)setSamplePositions:(const MTLSamplePosition * _Nullable)positions count:(NSUInteger)count;
- (NSUInteger)getSamplePositions:(MTLSamplePosition * _Nullable)positions count:(NSUInteger)count;
@property (nonatomic) BOOL supportColorAttachmentMapping;
@end

@protocol MTLLogState;

API_AVAILABLE(ios(26.0))
@interface MTL4CommandQueueDescriptor : NSObject <NSCopying>
@property (nullable, copy, nonatomic) NSString *label;
@property (nullable, nonatomic, assign) dispatch_queue_t feedbackQueue;
@end

API_AVAILABLE(ios(26.0))
@interface MTL4CommandBufferOptions : NSObject <NSCopying>
@property (readwrite, nonatomic, nullable, retain) id<MTLLogState> logState;
@end

#endif

NS_ASSUME_NONNULL_END
