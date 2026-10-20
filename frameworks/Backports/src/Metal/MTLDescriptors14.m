#import "RevenantMetal.h"
#import <Metal/Metal.h>

#pragma clang diagnostic ignored "-Wprotocol"
#pragma clang diagnostic ignored "-Wincomplete-implementation"

#pragma mark - the acceleration-structure family

@implementation MTLAccelerationStructureDescriptor
@synthesize usage = _usage;
@end

@implementation MTLAccelerationStructureGeometryDescriptor
@synthesize intersectionFunctionTableOffset = _intersectionFunctionTableOffset;
@synthesize opaque = _opaque;
@synthesize allowDuplicateIntersectionFunctionInvocation = _allowDuplicate;
@synthesize primitiveDataBufferOffset = _primitiveDataBufferOffset;
@synthesize primitiveDataStride = _primitiveDataStride;
@synthesize primitiveDataElementSize = _primitiveDataElementSize;
@synthesize primitiveDataBuffer = _primitiveDataBuffer;
@synthesize label = _label;
- (instancetype)init
{
    if ((self = [super init]))
        _allowDuplicate = YES;
    return self;
}
@end

@implementation MTLAccelerationStructureBoundingBoxGeometryDescriptor
@synthesize boundingBoxBuffer = _boundingBoxBuffer;
@synthesize boundingBoxBufferOffset = _boundingBoxBufferOffset;
@synthesize boundingBoxStride = _boundingBoxStride;
@synthesize boundingBoxCount = _boundingBoxCount;
- (instancetype)init
{
    if ((self = [super init]))
        _boundingBoxStride = 24;
    return self;
}
@end

@implementation MTLAccelerationStructureTriangleGeometryDescriptor
@synthesize vertexBuffer = _vertexBuffer;
@synthesize indexBuffer = _indexBuffer;
@synthesize transformationMatrixBuffer = _transformationMatrixBuffer;
@synthesize vertexBufferOffset = _vertexBufferOffset;
@synthesize vertexFormat = _vertexFormat;
- (instancetype)init
{
    if ((self = [super init]))
        _vertexFormat = MTLAttributeFormatFloat3;
    return self;
}
@synthesize vertexStride = _vertexStride;
@synthesize indexBufferOffset = _indexBufferOffset;
@synthesize indexType = _indexType;
@synthesize triangleCount = _triangleCount;
@synthesize transformationMatrixBufferOffset = _transformationMatrixBufferOffset;
@end

@implementation MTLPrimitiveAccelerationStructureDescriptor
@synthesize geometryDescriptors = _geometryDescriptors;
@synthesize motionStartBorderMode = _motionStartBorderMode;
@synthesize motionEndBorderMode = _motionEndBorderMode;
@synthesize motionStartTime = _motionStartTime;
@synthesize motionEndTime = _motionEndTime;
@synthesize motionKeyframeCount = _motionKeyframeCount;
- (instancetype)init
{
    if ((self = [super init])) {
        _motionEndTime = 1.0f;
        _motionKeyframeCount = 1;
    }
    return self;
}
@end

@implementation MTLInstanceAccelerationStructureDescriptor
- (instancetype)init
{
    if ((self = [super init]))
        _instanceDescriptorStride = 64;
    return self;
}
@synthesize instanceDescriptorBuffer = _instanceDescriptorBuffer;
@synthesize motionTransformBuffer = _motionTransformBuffer;
@synthesize instancedAccelerationStructures = _instancedAccelerationStructures;
@synthesize instanceDescriptorBufferOffset = _instanceDescriptorBufferOffset;
@synthesize instanceDescriptorStride = _instanceDescriptorStride;
@synthesize instanceCount = _instanceCount;
@synthesize instanceDescriptorType = _instanceDescriptorType;
@synthesize motionTransformBufferOffset = _motionTransformBufferOffset;
@synthesize motionTransformCount = _motionTransformCount;
@end

#pragma mark - the two ray-tracing function tables

@implementation MTLIntersectionFunctionTableDescriptor
@synthesize functionCount = _functionCount;
@end

@implementation MTLVisibleFunctionTableDescriptor
@synthesize functionCount = _functionCount;
@end

#pragma mark - the counter-sample descriptors

@implementation MTLCounterSampleBufferDescriptor
@synthesize counterSet = _counterSet;
@synthesize label = _label;
@synthesize storageMode = _storageMode;
- (instancetype)init
{
    if ((self = [super init]))
        _storageMode = MTLStorageModeShared;
    return self;
}
@synthesize sampleCount = _sampleCount;
@end

@implementation MTLComputePassSampleBufferAttachmentDescriptor
- (instancetype)init
{
    if ((self = [super init])) {
        _startOfEncoderSampleIndex = MTLCounterDontSample;
        _endOfEncoderSampleIndex = MTLCounterDontSample;
    }
    return self;
}
@synthesize sampleBuffer = _sampleBuffer;
@synthesize startOfEncoderSampleIndex = _startOfEncoderSampleIndex;
@synthesize endOfEncoderSampleIndex = _endOfEncoderSampleIndex;
@end

@implementation MTLResourceStatePassSampleBufferAttachmentDescriptor
- (instancetype)init
{
    if ((self = [super init])) {
        _startOfEncoderSampleIndex = MTLCounterDontSample;
        _endOfEncoderSampleIndex = MTLCounterDontSample;
    }
    return self;
}
@synthesize sampleBuffer = _sampleBuffer;
@synthesize startOfEncoderSampleIndex = _startOfEncoderSampleIndex;
@synthesize endOfEncoderSampleIndex = _endOfEncoderSampleIndex;
@end

@implementation MTLRenderPassSampleBufferAttachmentDescriptor
- (instancetype)init
{
    if ((self = [super init])) {
        _startOfVertexSampleIndex = MTLCounterDontSample;
        _endOfVertexSampleIndex = MTLCounterDontSample;
        _startOfFragmentSampleIndex = MTLCounterDontSample;
        _endOfFragmentSampleIndex = MTLCounterDontSample;
    }
    return self;
}
@synthesize sampleBuffer = _sampleBuffer;
@synthesize startOfVertexSampleIndex = _startOfVertexSampleIndex;
@synthesize endOfVertexSampleIndex = _endOfVertexSampleIndex;
@synthesize startOfFragmentSampleIndex = _startOfFragmentSampleIndex;
@synthesize endOfFragmentSampleIndex = _endOfFragmentSampleIndex;
@end


@class MTLComputePassSampleBufferAttachmentDescriptorArray;
@class MTLResourceStatePassSampleBufferAttachmentDescriptorArray;

#pragma mark - the pass descriptors and the binary archive


@implementation MTLBinaryArchiveDescriptor
@synthesize url = _url;
@end

#pragma mark - the attachment arrays, and the two remaining descriptors

@interface MTLComputePassSampleBufferAttachmentDescriptorArray ()
{
    NSMutableArray *_attachments;
}
@end

@implementation MTLComputePassSampleBufferAttachmentDescriptorArray
- (instancetype)init
{
    if ((self = [super init]))
        _attachments = [[NSMutableArray alloc] init];
    return self;
}
- (MTLComputePassSampleBufferAttachmentDescriptor *)objectAtIndexedSubscript:(NSUInteger)index
{
    return index < [_attachments count] ? [_attachments objectAtIndex:index] : nil;
}
- (void)setObject:(nullable MTLComputePassSampleBufferAttachmentDescriptor *)attachment
          atIndex:(NSUInteger)index
{
    while ([_attachments count] <= index) { [_attachments addObject:[NSNull null]]; }
    [_attachments replaceObjectAtIndex:index withObject:(attachment ? (id)attachment : (id)[NSNull null])];
    if (!attachment) { [_attachments removeObjectAtIndex:index]; [_attachments addObject:[NSNull null]]; }
}
@end

@interface MTLRenderPassSampleBufferAttachmentDescriptorArray ()
{
    NSMutableArray *_attachments;
}
@end

@implementation MTLRenderPassSampleBufferAttachmentDescriptorArray
- (instancetype)init
{
    if ((self = [super init]))
        _attachments = [[NSMutableArray alloc] init];
    return self;
}
- (MTLRenderPassSampleBufferAttachmentDescriptor *)objectAtIndexedSubscript:(NSUInteger)index
{
    return index < [_attachments count] ? [_attachments objectAtIndex:index] : nil;
}
- (void)setObject:(nullable MTLRenderPassSampleBufferAttachmentDescriptor *)attachment
          atIndex:(NSUInteger)index
{
    while ([_attachments count] <= index) { [_attachments addObject:[NSNull null]]; }
    [_attachments replaceObjectAtIndex:index withObject:(attachment ? (id)attachment : (id)[NSNull null])];
    if (!attachment) { [_attachments removeObjectAtIndex:index]; [_attachments addObject:[NSNull null]]; }
}
@end

@interface MTLResourceStatePassSampleBufferAttachmentDescriptorArray ()
{
    NSMutableArray *_attachments;
}
@end

@implementation MTLResourceStatePassSampleBufferAttachmentDescriptorArray
- (instancetype)init
{
    if ((self = [super init]))
        _attachments = [[NSMutableArray alloc] init];
    return self;
}
- (MTLResourceStatePassSampleBufferAttachmentDescriptor *)objectAtIndexedSubscript:(NSUInteger)index
{
    return index < [_attachments count] ? [_attachments objectAtIndex:index] : nil;
}
- (void)setObject:(nullable MTLResourceStatePassSampleBufferAttachmentDescriptor *)attachment
          atIndex:(NSUInteger)index
{
    while ([_attachments count] <= index) { [_attachments addObject:[NSNull null]]; }
    [_attachments replaceObjectAtIndex:index withObject:(attachment ? (id)attachment : (id)[NSNull null])];
    if (!attachment) { [_attachments removeObjectAtIndex:index]; [_attachments addObject:[NSNull null]]; }
}
@end

@implementation MTLLinkedFunctions
@synthesize functions = _functions;
@synthesize binaryFunctions = _binaryFunctions;
@synthesize groups = _groups;
@synthesize privateFunctions = _privateFunctions;
@end

@implementation MTLIntersectionFunctionDescriptor
@end

@interface MTLComputePassDescriptor ()
{
    MTLComputePassSampleBufferAttachmentDescriptorArray *_sampleBufferAttachments;
}
@end

@implementation MTLComputePassDescriptor
@synthesize dispatchType = _dispatchType;
@synthesize sampleBufferAttachments = _sampleBufferAttachments;
- (instancetype)init
{
    if ((self = [super init]))
        _sampleBufferAttachments = [[MTLComputePassSampleBufferAttachmentDescriptorArray alloc] init];
    return self;
}
@end

@interface MTLResourceStatePassDescriptor ()
{
    MTLResourceStatePassSampleBufferAttachmentDescriptorArray *_sampleBufferAttachments;
}
@end

@implementation MTLResourceStatePassDescriptor
@synthesize sampleBufferAttachments = _sampleBufferAttachments;
- (instancetype)init
{
    if ((self = [super init]))
        _sampleBufferAttachments = [[MTLResourceStatePassSampleBufferAttachmentDescriptorArray alloc] init];
    return self;
}
@end
