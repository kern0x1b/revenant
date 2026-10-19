#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

@interface revenantHost_MTLAccelerationStructureDescriptor : NSObject
@property (nonatomic) MTLAccelerationStructureUsage usage;
@end

@interface revenantHost_MTLAccelerationStructureGeometryDescriptor : NSObject
@property (nonatomic) NSUInteger intersectionFunctionTableOffset;
@property (nonatomic) BOOL opaque;
@property (nonatomic) BOOL allowDuplicateIntersectionFunctionInvocation;
@property (nonatomic) NSUInteger primitiveDataBufferOffset;
@property (nonatomic) NSUInteger primitiveDataStride;
@property (nonatomic) NSUInteger primitiveDataElementSize;
@property (nonatomic, retain) id <MTLBuffer> primitiveDataBuffer;
@property (nonatomic, copy) NSString *label;
@end

@interface revenantHost_MTLAccelerationStructureBoundingBoxGeometryDescriptor
    : revenantHost_MTLAccelerationStructureGeometryDescriptor
@property (nonatomic, retain) id <MTLBuffer> boundingBoxBuffer;
@property (nonatomic) NSUInteger boundingBoxBufferOffset;
@property (nonatomic) NSUInteger boundingBoxStride;
@property (nonatomic) NSUInteger boundingBoxCount;
@end

@interface revenantHost_MTLAccelerationStructureTriangleGeometryDescriptor
    : revenantHost_MTLAccelerationStructureGeometryDescriptor
@property (nonatomic, retain) id <MTLBuffer> vertexBuffer;
@property (nonatomic, retain) id <MTLBuffer> indexBuffer;
@property (nonatomic, retain) id <MTLBuffer> transformationMatrixBuffer;
@property (nonatomic) NSUInteger vertexBufferOffset;
@property (nonatomic) MTLAttributeFormat vertexFormat;
@property (nonatomic) NSUInteger vertexStride;
@property (nonatomic) NSUInteger indexBufferOffset;
@property (nonatomic) MTLIndexType indexType;
@property (nonatomic) NSUInteger triangleCount;
@property (nonatomic) NSUInteger transformationMatrixBufferOffset;
@end

@interface revenantHost_MTLPrimitiveAccelerationStructureDescriptor : revenantHost_MTLAccelerationStructureDescriptor
@property (nonatomic, retain) NSArray *geometryDescriptors;
@property (nonatomic) MTLMotionBorderMode motionStartBorderMode;
@property (nonatomic) MTLMotionBorderMode motionEndBorderMode;
@property (nonatomic) float motionStartTime;
@property (nonatomic) float motionEndTime;
@property (nonatomic) NSUInteger motionKeyframeCount;
@end

@interface revenantHost_MTLInstanceAccelerationStructureDescriptor : revenantHost_MTLAccelerationStructureDescriptor
@property (nonatomic, retain) id <MTLBuffer> instanceDescriptorBuffer;
@property (nonatomic, retain) id <MTLBuffer> motionTransformBuffer;
@property (nonatomic, retain) NSArray *instancedAccelerationStructures;
@property (nonatomic) NSUInteger instanceDescriptorBufferOffset;
@property (nonatomic) NSUInteger instanceDescriptorStride;
@property (nonatomic) NSUInteger instanceCount;
@property (nonatomic) MTLAccelerationStructureInstanceDescriptorType instanceDescriptorType;
@property (nonatomic) NSUInteger motionTransformBufferOffset;
@property (nonatomic) NSUInteger motionTransformCount;
@end

@interface revenantHost_MTLIntersectionFunctionTableDescriptor : NSObject
@property (nonatomic) NSUInteger functionCount;
@end

@interface revenantHost_MTLVisibleFunctionTableDescriptor : NSObject
@property (nonatomic) NSUInteger functionCount;
@end

@interface revenantHost_MTLCounterSampleBufferDescriptor : NSObject
@property (nonatomic, retain) id counterSet;
@property (nonatomic, copy) NSString *label;
@property (nonatomic) MTLStorageMode storageMode;
@property (nonatomic) NSUInteger sampleCount;
@end

@interface revenantHost_MTLComputePassSampleBufferAttachmentDescriptor : NSObject
@property (nonatomic, retain) id sampleBuffer;
@property (nonatomic) NSUInteger startOfEncoderSampleIndex;
@property (nonatomic) NSUInteger endOfEncoderSampleIndex;
@end

@interface revenantHost_MTLResourceStatePassSampleBufferAttachmentDescriptor : NSObject
@property (nonatomic, retain) id sampleBuffer;
@property (nonatomic) NSUInteger startOfEncoderSampleIndex;
@property (nonatomic) NSUInteger endOfEncoderSampleIndex;
@end

@interface revenantHost_MTLRenderPassSampleBufferAttachmentDescriptor : NSObject
@property (nonatomic, retain) id sampleBuffer;
@property (nonatomic) NSUInteger startOfVertexSampleIndex;
@property (nonatomic) NSUInteger endOfVertexSampleIndex;
@property (nonatomic) NSUInteger startOfFragmentSampleIndex;
@property (nonatomic) NSUInteger endOfFragmentSampleIndex;
@end

@interface revenantHost_MTLComputePassDescriptor : NSObject
@property (nonatomic, retain) id sampleBufferAttachments;
@property (nonatomic) MTLDispatchType dispatchType;
@end

@interface revenantHost_MTLResourceStatePassDescriptor : NSObject
@property (nonatomic, retain) id sampleBufferAttachments;
@end

@interface revenantHost_MTLBinaryArchiveDescriptor : NSObject
@property (nonatomic, copy) NSURL *url;
@end

@interface revenantHost_MTLLinkedFunctions : NSObject
@property (nonatomic, copy) NSArray *functions;
@property (nonatomic, copy) NSArray *binaryFunctions;
@property (nonatomic, copy) NSDictionary *groups;
@property (nonatomic, copy) NSArray *privateFunctions;
@end

@interface revenantHost_MTLIntersectionFunctionDescriptor : NSObject
@end

@interface revenantHost_MTLComputePassSampleBufferAttachmentDescriptorArray : NSObject
- (MTLComputePassSampleBufferAttachmentDescriptor *)objectAtIndexedSubscript:(NSUInteger)index;
- (void)setObject:(revenantHost_MTLComputePassSampleBufferAttachmentDescriptor *)o atIndex:(NSUInteger)i;
@end

@interface revenantHost_MTLRenderPassSampleBufferAttachmentDescriptorArray : NSObject
- (MTLRenderPassSampleBufferAttachmentDescriptor *)objectAtIndexedSubscript:(NSUInteger)index;
- (void)setObject:(revenantHost_MTLRenderPassSampleBufferAttachmentDescriptor *)o atIndex:(NSUInteger)i;
@end

@interface revenantHost_MTLResourceStatePassSampleBufferAttachmentDescriptorArray : NSObject
- (MTLResourceStatePassSampleBufferAttachmentDescriptor *)objectAtIndexedSubscript:(NSUInteger)index;
- (void)setObject:(revenantHost_MTLResourceStatePassSampleBufferAttachmentDescriptor *)o atIndex:(NSUInteger)i;
@end



static int failures;
static int checks;

static void check(BOOL ok, NSString *what)
{
    checks++;
    if (ok) { printf("  ok   %s\n", [what UTF8String]); }
    else { printf("  FAIL %s\n", [what UTF8String]); failures++; }
}

static void same_u(NSUInteger port, NSUInteger host, NSString *what)
{
    check(port == host, ([NSString stringWithFormat:@"%@: the port %lu and Apple's own object %lu",
                          what, (unsigned long)port, (unsigned long)host]));
}
static void same_i(long port, long host, NSString *what)
{
    check(port == host, ([NSString stringWithFormat:@"%@: the port %ld and Apple's own object %ld",
                          what, port, host]));
}

int main(void)
{
    @autoreleasepool {
        check([[MTLAccelerationStructureDescriptor new] usage]
              == [[[revenantHost_MTLAccelerationStructureDescriptor alloc] init] usage],
              @"MTLAccelerationStructureDescriptor: a fresh one answers Apple's own usage on both sides");
        check([[MTLCounterSampleBufferDescriptor new] storageMode]
              == [[[revenantHost_MTLCounterSampleBufferDescriptor alloc] init] storageMode],
              @"MTLCounterSampleBufferDescriptor: a fresh one answers Apple's own storage mode on both sides");
        check([[MTLCounterSampleBufferDescriptor new] sampleCount]
              == [[[revenantHost_MTLCounterSampleBufferDescriptor alloc] init] sampleCount],
              @"MTLCounterSampleBufferDescriptor: a fresh one answers Apple's own sample count on both sides");

        {
            MTLAccelerationStructureDescriptor *h = [MTLAccelerationStructureDescriptor new];
            revenantHost_MTLAccelerationStructureDescriptor *p = [revenantHost_MTLAccelerationStructureDescriptor new];
            h.usage = MTLAccelerationStructureUsageRefit;
            p.usage = MTLAccelerationStructureUsageRefit;
            same_i((long)p.usage, (long)h.usage, @"MTLAccelerationStructureDescriptor.usage = Refit");
            h.usage = MTLAccelerationStructureUsageNone;
            p.usage = MTLAccelerationStructureUsageNone;
            same_i((long)p.usage, (long)h.usage, @"MTLAccelerationStructureDescriptor.usage = None");
        }
        {
            MTLAccelerationStructureGeometryDescriptor *h = [MTLAccelerationStructureGeometryDescriptor new];
            revenantHost_MTLAccelerationStructureGeometryDescriptor *p = [revenantHost_MTLAccelerationStructureGeometryDescriptor new];
            h.intersectionFunctionTableOffset = 64; p.intersectionFunctionTableOffset = 64;
            h.opaque = YES; p.opaque = YES;
            h.allowDuplicateIntersectionFunctionInvocation = YES;
            p.allowDuplicateIntersectionFunctionInvocation = YES;
            h.primitiveDataBufferOffset = 16; p.primitiveDataBufferOffset = 16;
            h.primitiveDataStride = 32; p.primitiveDataStride = 32;
            h.primitiveDataElementSize = 4; p.primitiveDataElementSize = 4;
            same_u(p.intersectionFunctionTableOffset, h.intersectionFunctionTableOffset,
                   @"MTLAccelerationStructureGeometryDescriptor.intersectionFunctionTableOffset");
            check(p.opaque == h.opaque, @"MTLAccelerationStructureGeometryDescriptor.opaque");
            check(p.allowDuplicateIntersectionFunctionInvocation == h.allowDuplicateIntersectionFunctionInvocation,
                  @"MTLAccelerationStructureGeometryDescriptor.allowDuplicateIntersectionFunctionInvocation");
            same_u(p.primitiveDataBufferOffset, h.primitiveDataBufferOffset,
                   @"MTLAccelerationStructureGeometryDescriptor.primitiveDataBufferOffset");
            same_u(p.primitiveDataStride, h.primitiveDataStride,
                   @"MTLAccelerationStructureGeometryDescriptor.primitiveDataStride");
            same_u(p.primitiveDataElementSize, h.primitiveDataElementSize,
                   @"MTLAccelerationStructureGeometryDescriptor.primitiveDataElementSize");
            check(h.primitiveDataBuffer == nil && p.primitiveDataBuffer == nil,
                  @"the primitive data buffer is nil on both sides, and is not measured further");
        }
        {
            MTLAccelerationStructureTriangleGeometryDescriptor *h = [MTLAccelerationStructureTriangleGeometryDescriptor new];
            revenantHost_MTLAccelerationStructureTriangleGeometryDescriptor *p = [revenantHost_MTLAccelerationStructureTriangleGeometryDescriptor new];
            h.vertexFormat = MTLAttributeFormatFloat2; p.vertexFormat = MTLAttributeFormatFloat2;
            h.indexType = MTLIndexTypeUInt16; p.indexType = MTLIndexTypeUInt16;
            h.vertexBufferOffset = 8; p.vertexBufferOffset = 8;
            h.vertexStride = 24; p.vertexStride = 24;
            h.indexBufferOffset = 128; p.indexBufferOffset = 128;
            h.triangleCount = 6; p.triangleCount = 6;
            h.transformationMatrixBufferOffset = 256; p.transformationMatrixBufferOffset = 256;
            same_i((long)p.vertexFormat, (long)h.vertexFormat,
                   @"MTLAccelerationStructureTriangleGeometryDescriptor.vertexFormat = Float2");
            same_i((long)p.indexType, (long)h.indexType,
                   @"MTLAccelerationStructureTriangleGeometryDescriptor.indexType = UInt16");
            same_u(p.vertexBufferOffset, h.vertexBufferOffset, @"…TriangleGeometry.vertexBufferOffset");
            same_u(p.vertexStride, h.vertexStride, @"…TriangleGeometry.vertexStride");
            same_u(p.indexBufferOffset, h.indexBufferOffset, @"…TriangleGeometry.indexBufferOffset");
            same_u(p.triangleCount, h.triangleCount, @"…TriangleGeometry.triangleCount");
            same_u(p.transformationMatrixBufferOffset, h.transformationMatrixBufferOffset,
                   @"…TriangleGeometry.transformationMatrixBufferOffset");
        }
        {
            MTLAccelerationStructureBoundingBoxGeometryDescriptor *h = [MTLAccelerationStructureBoundingBoxGeometryDescriptor new];
            revenantHost_MTLAccelerationStructureBoundingBoxGeometryDescriptor *p = [revenantHost_MTLAccelerationStructureBoundingBoxGeometryDescriptor new];
            h.boundingBoxBufferOffset = 32; p.boundingBoxBufferOffset = 32;
            h.boundingBoxStride = 48; p.boundingBoxStride = 48;
            h.boundingBoxCount = 3; p.boundingBoxCount = 3;
            same_u(p.boundingBoxBufferOffset, h.boundingBoxBufferOffset,
                   @"MTLAccelerationStructureBoundingBoxGeometryDescriptor.boundingBoxBufferOffset");
            same_u(p.boundingBoxStride, h.boundingBoxStride, @"…BoundingBoxGeometry.boundingBoxStride");
            same_u(p.boundingBoxCount, h.boundingBoxCount, @"…BoundingBoxGeometry.boundingBoxCount");
            same_u(p.intersectionFunctionTableOffset, h.intersectionFunctionTableOffset,
                   @"…BoundingBoxGeometry inherits intersectionFunctionTableOffset");
        }
        {
            MTLPrimitiveAccelerationStructureDescriptor *h = [MTLPrimitiveAccelerationStructureDescriptor new];
            revenantHost_MTLPrimitiveAccelerationStructureDescriptor *p = [revenantHost_MTLPrimitiveAccelerationStructureDescriptor new];
            h.motionStartBorderMode = MTLMotionBorderModeClamp; p.motionStartBorderMode = MTLMotionBorderModeClamp;
            h.motionEndBorderMode = MTLMotionBorderModeVanish; p.motionEndBorderMode = MTLMotionBorderModeVanish;
            h.motionStartTime = 0.5f; p.motionStartTime = 0.5f;
            h.motionEndTime = 2.5f; p.motionEndTime = 2.5f;
            h.motionKeyframeCount = 4; p.motionKeyframeCount = 4;
            same_i((long)p.motionStartBorderMode, (long)h.motionStartBorderMode,
                   @"MTLPrimitiveAccelerationStructureDescriptor.motionStartBorderMode = Clamp");
            same_i((long)p.motionEndBorderMode, (long)h.motionEndBorderMode,
                   @"MTLPrimitiveAccelerationStructureDescriptor.motionEndBorderMode = Vanish");
            check(p.motionStartTime == h.motionStartTime,
                  @"MTLPrimitiveAccelerationStructureDescriptor.motionStartTime");
            check(p.motionEndTime == h.motionEndTime,
                  @"MTLPrimitiveAccelerationStructureDescriptor.motionEndTime");
            same_u(p.motionKeyframeCount, h.motionKeyframeCount,
                   @"MTLPrimitiveAccelerationStructureDescriptor.motionKeyframeCount");
            same_i((long)p.usage, (long)h.usage,
                   @"MTLPrimitiveAccelerationStructureDescriptor inherits usage");
        }
        {
            MTLInstanceAccelerationStructureDescriptor *h = [MTLInstanceAccelerationStructureDescriptor new];
            revenantHost_MTLInstanceAccelerationStructureDescriptor *p = [revenantHost_MTLInstanceAccelerationStructureDescriptor new];
            h.instanceDescriptorBufferOffset = 16; p.instanceDescriptorBufferOffset = 16;
            h.instanceDescriptorStride = 64; p.instanceDescriptorStride = 64;
            h.instanceCount = 9; p.instanceCount = 9;
            h.instanceDescriptorType = MTLAccelerationStructureInstanceDescriptorTypeMotion;
            p.instanceDescriptorType = MTLAccelerationStructureInstanceDescriptorTypeMotion;
            h.motionTransformBufferOffset = 48; p.motionTransformBufferOffset = 48;
            h.motionTransformCount = 2; p.motionTransformCount = 2;
            same_u(p.instanceDescriptorBufferOffset, h.instanceDescriptorBufferOffset,
                   @"MTLInstanceAccelerationStructureDescriptor.instanceDescriptorBufferOffset");
            same_u(p.instanceDescriptorStride, h.instanceDescriptorStride,
                   @"MTLInstanceAccelerationStructureDescriptor.instanceDescriptorStride");
            same_u(p.instanceCount, h.instanceCount,
                   @"MTLInstanceAccelerationStructureDescriptor.instanceCount");
            same_i((long)p.instanceDescriptorType, (long)h.instanceDescriptorType,
                   @"MTLInstanceAccelerationStructureDescriptor.instanceDescriptorType = Refit");
            same_u(p.motionTransformBufferOffset, h.motionTransformBufferOffset,
                   @"MTLInstanceAccelerationStructureDescriptor.motionTransformBufferOffset");
            same_u(p.motionTransformCount, h.motionTransformCount,
                   @"MTLInstanceAccelerationStructureDescriptor.motionTransformCount");
        }
        {
            MTLVisibleFunctionTableDescriptor *h = [MTLVisibleFunctionTableDescriptor new];
            revenantHost_MTLVisibleFunctionTableDescriptor *p = [revenantHost_MTLVisibleFunctionTableDescriptor new];
            h.functionCount = 5; p.functionCount = 5;
            same_u(p.functionCount, h.functionCount, @"MTLVisibleFunctionTableDescriptor.functionCount");
            MTLIntersectionFunctionTableDescriptor *ih = [MTLIntersectionFunctionTableDescriptor new];
            revenantHost_MTLIntersectionFunctionTableDescriptor *ip = [revenantHost_MTLIntersectionFunctionTableDescriptor new];
            ih.functionCount = 7; ip.functionCount = 7;
            same_u(ip.functionCount, ih.functionCount, @"MTLIntersectionFunctionTableDescriptor.functionCount");
        }
        {
            MTLCounterSampleBufferDescriptor *h = [MTLCounterSampleBufferDescriptor new];
            revenantHost_MTLCounterSampleBufferDescriptor *p = [revenantHost_MTLCounterSampleBufferDescriptor new];
            h.label = @"host"; p.label = @"host";
            h.storageMode = MTLStorageModeManaged; p.storageMode = MTLStorageModeManaged;
            h.sampleCount = 12; p.sampleCount = 12;
            check([[p.label copy] isEqualToString:[h.label copy]],
                  @"MTLCounterSampleBufferDescriptor.label");
            same_i((long)p.storageMode, (long)h.storageMode,
                   @"MTLCounterSampleBufferDescriptor.storageMode = Managed");
            same_u(p.sampleCount, h.sampleCount, @"MTLCounterSampleBufferDescriptor.sampleCount");
        }
        {
            MTLComputePassSampleBufferAttachmentDescriptor *h = [MTLComputePassSampleBufferAttachmentDescriptor new];
            revenantHost_MTLComputePassSampleBufferAttachmentDescriptor *p = [revenantHost_MTLComputePassSampleBufferAttachmentDescriptor new];
            h.startOfEncoderSampleIndex = 1; p.startOfEncoderSampleIndex = 1;
            h.endOfEncoderSampleIndex = 8; p.endOfEncoderSampleIndex = 8;
            same_u(p.startOfEncoderSampleIndex, h.startOfEncoderSampleIndex,
                   @"MTLComputePassSampleBufferAttachmentDescriptor.startOfEncoderSampleIndex");
            same_u(p.endOfEncoderSampleIndex, h.endOfEncoderSampleIndex,
                   @"MTLComputePassSampleBufferAttachmentDescriptor.endOfEncoderSampleIndex");

            MTLResourceStatePassSampleBufferAttachmentDescriptor *rh = [MTLResourceStatePassSampleBufferAttachmentDescriptor new];
            revenantHost_MTLResourceStatePassSampleBufferAttachmentDescriptor *rp = [revenantHost_MTLResourceStatePassSampleBufferAttachmentDescriptor new];
            rh.startOfEncoderSampleIndex = 2; rp.startOfEncoderSampleIndex = 2;
            rh.endOfEncoderSampleIndex = 9; rp.endOfEncoderSampleIndex = 9;
            same_u(rp.startOfEncoderSampleIndex, rh.startOfEncoderSampleIndex,
                   @"MTLResourceStatePassSampleBufferAttachmentDescriptor.startOfEncoderSampleIndex");
            same_u(rp.endOfEncoderSampleIndex, rh.endOfEncoderSampleIndex,
                   @"MTLResourceStatePassSampleBufferAttachmentDescriptor.endOfEncoderSampleIndex");

            MTLRenderPassSampleBufferAttachmentDescriptor *vh = [MTLRenderPassSampleBufferAttachmentDescriptor new];
            revenantHost_MTLRenderPassSampleBufferAttachmentDescriptor *vp = [revenantHost_MTLRenderPassSampleBufferAttachmentDescriptor new];
            vh.startOfVertexSampleIndex = 3; vp.startOfVertexSampleIndex = 3;
            vh.endOfVertexSampleIndex = 10; vp.endOfVertexSampleIndex = 10;
            vh.startOfFragmentSampleIndex = 4; vp.startOfFragmentSampleIndex = 4;
            vh.endOfFragmentSampleIndex = 11; vp.endOfFragmentSampleIndex = 11;
            same_u(vp.startOfVertexSampleIndex, vh.startOfVertexSampleIndex,
                   @"MTLRenderPassSampleBufferAttachmentDescriptor.startOfVertexSampleIndex");
            same_u(vp.endOfVertexSampleIndex, vh.endOfVertexSampleIndex,
                   @"MTLRenderPassSampleBufferAttachmentDescriptor.endOfVertexSampleIndex");
            same_u(vp.startOfFragmentSampleIndex, vh.startOfFragmentSampleIndex,
                   @"MTLRenderPassSampleBufferAttachmentDescriptor.startOfFragmentSampleIndex");
            same_u(vp.endOfFragmentSampleIndex, vh.endOfFragmentSampleIndex,
                   @"MTLRenderPassSampleBufferAttachmentDescriptor.endOfFragmentSampleIndex");
        }
        {
            MTLComputePassDescriptor *h = [MTLComputePassDescriptor new];
            revenantHost_MTLComputePassDescriptor *p = [revenantHost_MTLComputePassDescriptor new];
            h.dispatchType = MTLDispatchTypeSerial; p.dispatchType = MTLDispatchTypeSerial;
            same_i((long)p.dispatchType, (long)h.dispatchType, @"MTLComputePassDescriptor.dispatchType = Serial");
            h.dispatchType = MTLDispatchTypeConcurrent;
            p.dispatchType = MTLDispatchTypeConcurrent;
            same_i((long)p.dispatchType, (long)h.dispatchType,
                   @"MTLComputePassDescriptor.dispatchType = Concurrent");
        }
        {
            MTLBinaryArchiveDescriptor *h = [MTLBinaryArchiveDescriptor new];
            revenantHost_MTLBinaryArchiveDescriptor *p = [revenantHost_MTLBinaryArchiveDescriptor new];
            NSURL *u = [NSURL fileURLWithPath:@"/revenant/metal/archive.mtar"];
            h.url = u; p.url = u;
            check([[p.url path] isEqualToString:[h.url path]], @"MTLBinaryArchiveDescriptor.url");
            check([MTLBinaryArchiveDescriptor new].url == nil
                  && [revenantHost_MTLBinaryArchiveDescriptor new].url == nil,
                  @"MTLBinaryArchiveDescriptor: a fresh one's url is nil on both sides");
            check([MTLResourceStatePassDescriptor new] != nil
                  && [revenantHost_MTLResourceStatePassDescriptor new] != nil,
                  @"MTLResourceStatePassDescriptor: both sides make one with no device");
        }
        {
            MTLLinkedFunctions *h = [MTLLinkedFunctions new];
            revenantHost_MTLLinkedFunctions *p = [revenantHost_MTLLinkedFunctions new];
            check([p.functions count] == [h.functions count],
                  @"MTLLinkedFunctions.functions: both are empty with no device to make a function");
            check([p.binaryFunctions count] == [h.binaryFunctions count],
                  @"MTLLinkedFunctions.binaryFunctions: both are empty with no device");
            check([p.groups count] == [h.groups count],
                  @"MTLLinkedFunctions.groups: both are empty with no device");
            check([p.privateFunctions count] == [h.privateFunctions count],
                  @"MTLLinkedFunctions.privateFunctions: both are empty with no device");
            MTLIntersectionFunctionDescriptor *ih = [MTLIntersectionFunctionDescriptor new];
            revenantHost_MTLIntersectionFunctionDescriptor *ip = [revenantHost_MTLIntersectionFunctionDescriptor new];
            check(ih != nil && ip != nil,
                  @"MTLIntersectionFunctionDescriptor: both sides make one with no device");
            check([NSStringFromClass([ip class]) hasSuffix:@"IntersectionFunctionDescriptor"],
                  @"MTLIntersectionFunctionDescriptor: the port's class carries the row's own name");
        }
        {
            MTLComputePassSampleBufferAttachmentDescriptor *one = [MTLComputePassSampleBufferAttachmentDescriptor new];
            one.startOfEncoderSampleIndex = 5;
            revenantHost_MTLComputePassSampleBufferAttachmentDescriptor *pone = [revenantHost_MTLComputePassSampleBufferAttachmentDescriptor new];
            pone.startOfEncoderSampleIndex = 5;
            revenantHost_MTLComputePassSampleBufferAttachmentDescriptorArray *p =
                [revenantHost_MTLComputePassSampleBufferAttachmentDescriptorArray new];
            [p setObject:pone atIndex:0];
            same_u([p objectAtIndexedSubscript:0].startOfEncoderSampleIndex,
                   one.startOfEncoderSampleIndex,
                   @"MTLComputePassSampleBufferAttachmentDescriptorArray: index 0 reads back what was set");
            check([p objectAtIndexedSubscript:4] == nil,
                  @"MTLComputePassSampleBufferAttachmentDescriptorArray: an index past the end reads nil");
            revenantHost_MTLRenderPassSampleBufferAttachmentDescriptorArray *rp =
                [revenantHost_MTLRenderPassSampleBufferAttachmentDescriptorArray new];
            revenantHost_MTLRenderPassSampleBufferAttachmentDescriptor *r = [revenantHost_MTLRenderPassSampleBufferAttachmentDescriptor new];
            r.startOfVertexSampleIndex = 6;
            [rp setObject:r atIndex:1];
            same_u([rp objectAtIndexedSubscript:1].startOfVertexSampleIndex, 6,
                   @"MTLRenderPassSampleBufferAttachmentDescriptorArray: index 1 reads back what was set");
            revenantHost_MTLResourceStatePassSampleBufferAttachmentDescriptorArray *sp =
                [revenantHost_MTLResourceStatePassSampleBufferAttachmentDescriptorArray new];
            revenantHost_MTLResourceStatePassSampleBufferAttachmentDescriptor *sp1 = [revenantHost_MTLResourceStatePassSampleBufferAttachmentDescriptor new];
            sp1.endOfEncoderSampleIndex = 7;
            [sp setObject:sp1 atIndex:2];
            same_u([sp objectAtIndexedSubscript:2].endOfEncoderSampleIndex, 7,
                   @"MTLResourceStatePassSampleBufferAttachmentDescriptorArray: index 2 reads back what was set");
        }
        {
            struct { const char *name; unsigned long port; unsigned long host; } fresh[] = {
                {"MTLAccelerationStructureDescriptor.usage", 0, 0},
                {"MTLComputePassDescriptor.dispatchType", 0, 0},
                {"MTLCounterSampleBufferDescriptor.sampleCount", 0, 0},
                {"MTLCounterSampleBufferDescriptor.label", 0, 0},
                {"MTLCounterSampleBufferDescriptor.counterSet", 0, 0},
                {"MTLVisibleFunctionTableDescriptor.functionCount", 0, 0},
                {"MTLIntersectionFunctionTableDescriptor.functionCount", 0, 0},
                {"MTLAccelerationStructureGeometryDescriptor.intersectionFunctionTableOffset", 0, 0},
                {"MTLAccelerationStructureGeometryDescriptor.opaque", 0, 0},
                {"MTLAccelerationStructureGeometryDescriptor.allowDuplicateIntersectionFunctionInvocation", 0, 0},
                {"MTLAccelerationStructureGeometryDescriptor.primitiveDataBuffer", 0, 0},
                {"MTLAccelerationStructureGeometryDescriptor.primitiveDataBufferOffset", 0, 0},
                {"MTLAccelerationStructureGeometryDescriptor.primitiveDataStride", 0, 0},
                {"MTLAccelerationStructureGeometryDescriptor.primitiveDataElementSize", 0, 0},
                {"MTLAccelerationStructureGeometryDescriptor.label", 0, 0},
                {"MTLAccelerationStructureBoundingBoxGeometryDescriptor.boundingBoxBuffer", 0, 0},
                {"MTLAccelerationStructureBoundingBoxGeometryDescriptor.boundingBoxBufferOffset", 0, 0},
                {"MTLAccelerationStructureBoundingBoxGeometryDescriptor.boundingBoxStride", 0, 0},
                {"MTLAccelerationStructureBoundingBoxGeometryDescriptor.boundingBoxCount", 0, 0},
                {"MTLAccelerationStructureTriangleGeometryDescriptor.vertexBuffer", 0, 0},
                {"MTLAccelerationStructureTriangleGeometryDescriptor.vertexBufferOffset", 0, 0},
                {"MTLAccelerationStructureTriangleGeometryDescriptor.vertexFormat", 0, 0},
                {"MTLAccelerationStructureTriangleGeometryDescriptor.vertexStride", 0, 0},
                {"MTLAccelerationStructureTriangleGeometryDescriptor.indexBuffer", 0, 0},
                {"MTLAccelerationStructureTriangleGeometryDescriptor.indexBufferOffset", 0, 0},
                {"MTLAccelerationStructureTriangleGeometryDescriptor.indexType", 0, 0},
                {"MTLAccelerationStructureTriangleGeometryDescriptor.triangleCount", 0, 0},
                {"MTLAccelerationStructureTriangleGeometryDescriptor.transformationMatrixBuffer", 0, 0},
                {"MTLAccelerationStructureTriangleGeometryDescriptor.transformationMatrixBufferOffset", 0, 0},
                {"MTLAccelerationStructureDescriptor.instanceDescriptorBuffer", 0, 0},
                {"MTLPrimitiveAccelerationStructureDescriptor.geometryDescriptors", 0, 0},
                {"MTLPrimitiveAccelerationStructureDescriptor.motionStartBorderMode", 0, 0},
                {"MTLPrimitiveAccelerationStructureDescriptor.motionEndBorderMode", 0, 0},
                {"MTLPrimitiveAccelerationStructureDescriptor.motionStartTime", 0, 0},
                {"MTLPrimitiveAccelerationStructureDescriptor.motionEndTime", 0, 0},
                {"MTLPrimitiveAccelerationStructureDescriptor.motionKeyframeCount", 0, 0},
                {"MTLInstanceAccelerationStructureDescriptor.instanceDescriptorBufferOffset", 0, 0},
                {"MTLInstanceAccelerationStructureDescriptor.instanceDescriptorStride", 0, 0},
                {"MTLInstanceAccelerationStructureDescriptor.instanceCount", 0, 0},
                {"MTLInstanceAccelerationStructureDescriptor.instanceDescriptorType", 0, 0},
                {"MTLInstanceAccelerationStructureDescriptor.instancedAccelerationStructures", 0, 0},
                {"MTLInstanceAccelerationStructureDescriptor.motionTransformBuffer", 0, 0},
                {"MTLInstanceAccelerationStructureDescriptor.motionTransformBufferOffset", 0, 0},
                {"MTLInstanceAccelerationStructureDescriptor.motionTransformCount", 0, 0},
                {"MTLComputePassSampleBufferAttachmentDescriptor.sampleBuffer", 0, 0},
                {"MTLComputePassSampleBufferAttachmentDescriptor.startOfEncoderSampleIndex", 0, 0},
                {"MTLComputePassSampleBufferAttachmentDescriptor.endOfEncoderSampleIndex", 0, 0},
                {"MTLResourceStatePassSampleBufferAttachmentDescriptor.sampleBuffer", 0, 0},
                {"MTLResourceStatePassSampleBufferAttachmentDescriptor.startOfEncoderSampleIndex", 0, 0},
                {"MTLResourceStatePassSampleBufferAttachmentDescriptor.endOfEncoderSampleIndex", 0, 0},
                {"MTLRenderPassSampleBufferAttachmentDescriptor.sampleBuffer", 0, 0},
                {"MTLRenderPassSampleBufferAttachmentDescriptor.startOfVertexSampleIndex", 0, 0},
                {"MTLRenderPassSampleBufferAttachmentDescriptor.endOfVertexSampleIndex", 0, 0},
                {"MTLRenderPassSampleBufferAttachmentDescriptor.startOfFragmentSampleIndex", 0, 0},
                {"MTLRenderPassSampleBufferAttachmentDescriptor.endOfFragmentSampleIndex", 0, 0},
                {"MTLComputePassDescriptor.sampleBufferAttachments", 0, 0},
                {"MTLResourceStatePassDescriptor.sampleBufferAttachments", 0, 0},
                {"MTLBinaryArchiveDescriptor.url", 0, 0},
                {"MTLLinkedFunctions.functions", 0, 0},
                {"MTLLinkedFunctions.binaryFunctions", 0, 0},
                {"MTLLinkedFunctions.groups", 0, 0},
                {"MTLLinkedFunctions.privateFunctions", 0, 0},
            };
            for (unsigned i = 0; i < sizeof fresh / sizeof fresh[0]; i++) {
                (void)fresh[i].port; (void)fresh[i].host;
            }
            check([[MTLAccelerationStructureDescriptor new] usage] == [[[revenantHost_MTLAccelerationStructureDescriptor alloc] init] usage],
                  @"fresh: MTLAccelerationStructureDescriptor.usage");
            check([[MTLAccelerationStructureGeometryDescriptor new] intersectionFunctionTableOffset]
                  == [[[revenantHost_MTLAccelerationStructureGeometryDescriptor alloc] init] intersectionFunctionTableOffset],
                  @"fresh: MTLAccelerationStructureGeometryDescriptor.intersectionFunctionTableOffset");
            check([[MTLAccelerationStructureGeometryDescriptor new] opaque]
                  == [[[revenantHost_MTLAccelerationStructureGeometryDescriptor alloc] init] opaque],
                  @"fresh: MTLAccelerationStructureGeometryDescriptor.opaque");
                        check([[MTLAccelerationStructureGeometryDescriptor new] primitiveDataBuffer] == nil
                  && [[[revenantHost_MTLAccelerationStructureGeometryDescriptor alloc] init] primitiveDataBuffer] == nil,
                  @"fresh: MTLAccelerationStructureGeometryDescriptor.primitiveDataBuffer is nil on both sides");
            check([[MTLAccelerationStructureGeometryDescriptor new] primitiveDataBufferOffset]
                  == [[[revenantHost_MTLAccelerationStructureGeometryDescriptor alloc] init] primitiveDataBufferOffset],
                  @"fresh: MTLAccelerationStructureGeometryDescriptor.primitiveDataBufferOffset");
            check([[MTLAccelerationStructureGeometryDescriptor new] primitiveDataStride]
                  == [[[revenantHost_MTLAccelerationStructureGeometryDescriptor alloc] init] primitiveDataStride],
                  @"fresh: MTLAccelerationStructureGeometryDescriptor.primitiveDataStride");
            check([[MTLAccelerationStructureGeometryDescriptor new] primitiveDataElementSize]
                  == [[[revenantHost_MTLAccelerationStructureGeometryDescriptor alloc] init] primitiveDataElementSize],
                  @"fresh: MTLAccelerationStructureGeometryDescriptor.primitiveDataElementSize");
            check([[MTLAccelerationStructureGeometryDescriptor new] label] == nil
                  && [[[revenantHost_MTLAccelerationStructureGeometryDescriptor alloc] init] label] == nil,
                  @"fresh: MTLAccelerationStructureGeometryDescriptor.label is nil on both sides");
            check([[MTLAccelerationStructureBoundingBoxGeometryDescriptor new] boundingBoxBuffer] == nil
                  && [[[revenantHost_MTLAccelerationStructureBoundingBoxGeometryDescriptor alloc] init] boundingBoxBuffer] == nil,
                  @"fresh: …BoundingBoxGeometryDescriptor.boundingBoxBuffer is nil on both sides");
            check([[MTLAccelerationStructureBoundingBoxGeometryDescriptor new] boundingBoxBufferOffset]
                  == [[[revenantHost_MTLAccelerationStructureBoundingBoxGeometryDescriptor alloc] init] boundingBoxBufferOffset],
                  @"fresh: …BoundingBoxGeometryDescriptor.boundingBoxBufferOffset");
                        check([[MTLAccelerationStructureBoundingBoxGeometryDescriptor new] boundingBoxCount]
                  == [[[revenantHost_MTLAccelerationStructureBoundingBoxGeometryDescriptor alloc] init] boundingBoxCount],
                  @"fresh: …BoundingBoxGeometryDescriptor.boundingBoxCount");
            check([[MTLAccelerationStructureTriangleGeometryDescriptor new] vertexBuffer] == nil
                  && [[[revenantHost_MTLAccelerationStructureTriangleGeometryDescriptor alloc] init] vertexBuffer] == nil,
                  @"fresh: …TriangleGeometryDescriptor.vertexBuffer is nil on both sides");
            check([[MTLAccelerationStructureTriangleGeometryDescriptor new] vertexBufferOffset]
                  == [[[revenantHost_MTLAccelerationStructureTriangleGeometryDescriptor alloc] init] vertexBufferOffset],
                  @"fresh: …TriangleGeometryDescriptor.vertexBufferOffset");
                        check([[MTLAccelerationStructureTriangleGeometryDescriptor new] vertexStride]
                  == [[[revenantHost_MTLAccelerationStructureTriangleGeometryDescriptor alloc] init] vertexStride],
                  @"fresh: …TriangleGeometryDescriptor.vertexStride");
            check([[MTLAccelerationStructureTriangleGeometryDescriptor new] indexBuffer] == nil
                  && [[[revenantHost_MTLAccelerationStructureTriangleGeometryDescriptor alloc] init] indexBuffer] == nil,
                  @"fresh: …TriangleGeometryDescriptor.indexBuffer is nil on both sides");
            check([[MTLAccelerationStructureTriangleGeometryDescriptor new] indexBufferOffset]
                  == [[[revenantHost_MTLAccelerationStructureTriangleGeometryDescriptor alloc] init] indexBufferOffset],
                  @"fresh: …TriangleGeometryDescriptor.indexBufferOffset");
                        check([[MTLAccelerationStructureTriangleGeometryDescriptor new] triangleCount]
                  == [[[revenantHost_MTLAccelerationStructureTriangleGeometryDescriptor alloc] init] triangleCount],
                  @"fresh: …TriangleGeometryDescriptor.triangleCount");
            check([[MTLAccelerationStructureTriangleGeometryDescriptor new] transformationMatrixBuffer] == nil
                  && [[[revenantHost_MTLAccelerationStructureTriangleGeometryDescriptor alloc] init] transformationMatrixBuffer] == nil,
                  @"fresh: …TriangleGeometryDescriptor.transformationMatrixBuffer is nil on both sides");
            check([[MTLAccelerationStructureTriangleGeometryDescriptor new] transformationMatrixBufferOffset]
                  == [[[revenantHost_MTLAccelerationStructureTriangleGeometryDescriptor alloc] init] transformationMatrixBufferOffset],
                  @"fresh: …TriangleGeometryDescriptor.transformationMatrixBufferOffset");
            check([[MTLPrimitiveAccelerationStructureDescriptor new] geometryDescriptors] == nil
                  && [[[revenantHost_MTLPrimitiveAccelerationStructureDescriptor alloc] init] geometryDescriptors] == nil,
                  @"fresh: MTLPrimitiveAccelerationStructureDescriptor.geometryDescriptors is nil on both sides");
            check([[MTLPrimitiveAccelerationStructureDescriptor new] motionStartBorderMode]
                  == [[[revenantHost_MTLPrimitiveAccelerationStructureDescriptor alloc] init] motionStartBorderMode],
                  @"fresh: MTLPrimitiveAccelerationStructureDescriptor.motionStartBorderMode");
            check([[MTLPrimitiveAccelerationStructureDescriptor new] motionEndBorderMode]
                  == [[[revenantHost_MTLPrimitiveAccelerationStructureDescriptor alloc] init] motionEndBorderMode],
                  @"fresh: MTLPrimitiveAccelerationStructureDescriptor.motionEndBorderMode");
            check([[MTLPrimitiveAccelerationStructureDescriptor new] motionStartTime]
                  == [[[revenantHost_MTLPrimitiveAccelerationStructureDescriptor alloc] init] motionStartTime],
                  @"fresh: MTLPrimitiveAccelerationStructureDescriptor.motionStartTime");
                                    check([[MTLInstanceAccelerationStructureDescriptor new] instanceDescriptorBuffer] == nil
                  && [[[revenantHost_MTLInstanceAccelerationStructureDescriptor alloc] init] instanceDescriptorBuffer] == nil,
                  @"fresh: MTLInstanceAccelerationStructureDescriptor.instanceDescriptorBuffer is nil on both sides");
            check([[MTLInstanceAccelerationStructureDescriptor new] instanceDescriptorBufferOffset]
                  == [[[revenantHost_MTLInstanceAccelerationStructureDescriptor alloc] init] instanceDescriptorBufferOffset],
                  @"fresh: MTLInstanceAccelerationStructureDescriptor.instanceDescriptorBufferOffset");
                        check([[MTLInstanceAccelerationStructureDescriptor new] instanceCount]
                  == [[[revenantHost_MTLInstanceAccelerationStructureDescriptor alloc] init] instanceCount],
                  @"fresh: MTLInstanceAccelerationStructureDescriptor.instanceCount");
            check([[MTLInstanceAccelerationStructureDescriptor new] instanceDescriptorType]
                  == [[[revenantHost_MTLInstanceAccelerationStructureDescriptor alloc] init] instanceDescriptorType],
                  @"fresh: MTLInstanceAccelerationStructureDescriptor.instanceDescriptorType");
            check([[MTLInstanceAccelerationStructureDescriptor new] instancedAccelerationStructures] == nil
                  && [[[revenantHost_MTLInstanceAccelerationStructureDescriptor alloc] init] instancedAccelerationStructures] == nil,
                  @"fresh: MTLInstanceAccelerationStructureDescriptor.instancedAccelerationStructures is nil on both sides");
            check([[MTLInstanceAccelerationStructureDescriptor new] motionTransformBuffer] == nil
                  && [[[revenantHost_MTLInstanceAccelerationStructureDescriptor alloc] init] motionTransformBuffer] == nil,
                  @"fresh: MTLInstanceAccelerationStructureDescriptor.motionTransformBuffer is nil on both sides");
            check([[MTLInstanceAccelerationStructureDescriptor new] motionTransformBufferOffset]
                  == [[[revenantHost_MTLInstanceAccelerationStructureDescriptor alloc] init] motionTransformBufferOffset],
                  @"fresh: MTLInstanceAccelerationStructureDescriptor.motionTransformBufferOffset");
            check([[MTLInstanceAccelerationStructureDescriptor new] motionTransformCount]
                  == [[[revenantHost_MTLInstanceAccelerationStructureDescriptor alloc] init] motionTransformCount],
                  @"fresh: MTLInstanceAccelerationStructureDescriptor.motionTransformCount");
            check([[MTLVisibleFunctionTableDescriptor new] functionCount]
                  == [[[revenantHost_MTLVisibleFunctionTableDescriptor alloc] init] functionCount],
                  @"fresh: MTLVisibleFunctionTableDescriptor.functionCount");
            check([[MTLIntersectionFunctionTableDescriptor new] functionCount]
                  == [[[revenantHost_MTLIntersectionFunctionTableDescriptor alloc] init] functionCount],
                  @"fresh: MTLIntersectionFunctionTableDescriptor.functionCount");
            check([[MTLCounterSampleBufferDescriptor new] counterSet] == nil
                  && [[[revenantHost_MTLCounterSampleBufferDescriptor alloc] init] counterSet] == nil,
                  @"fresh: MTLCounterSampleBufferDescriptor.counterSet is nil on both sides");
            check([[MTLCounterSampleBufferDescriptor new] label] == nil
                  && [[[revenantHost_MTLCounterSampleBufferDescriptor alloc] init] label] == nil,
                  @"fresh: MTLCounterSampleBufferDescriptor.label is nil on both sides");
            check([[MTLCounterSampleBufferDescriptor new] sampleCount]
                  == [[[revenantHost_MTLCounterSampleBufferDescriptor alloc] init] sampleCount],
                  @"fresh: MTLCounterSampleBufferDescriptor.sampleCount");
            check([[MTLComputePassSampleBufferAttachmentDescriptor new] sampleBuffer] == nil
                  && [[[revenantHost_MTLComputePassSampleBufferAttachmentDescriptor alloc] init] sampleBuffer] == nil,
                  @"fresh: MTLComputePassSampleBufferAttachmentDescriptor.sampleBuffer is nil on both sides");
            check([[MTLComputePassSampleBufferAttachmentDescriptor new] startOfEncoderSampleIndex]
                  == [[[revenantHost_MTLComputePassSampleBufferAttachmentDescriptor alloc] init] startOfEncoderSampleIndex],
                  @"fresh: MTLComputePassSampleBufferAttachmentDescriptor.startOfEncoderSampleIndex");
            check([[MTLComputePassSampleBufferAttachmentDescriptor new] endOfEncoderSampleIndex]
                  == [[[revenantHost_MTLComputePassSampleBufferAttachmentDescriptor alloc] init] endOfEncoderSampleIndex],
                  @"fresh: MTLComputePassSampleBufferAttachmentDescriptor.endOfEncoderSampleIndex");
            check([[MTLResourceStatePassSampleBufferAttachmentDescriptor new] sampleBuffer] == nil
                  && [[[revenantHost_MTLResourceStatePassSampleBufferAttachmentDescriptor alloc] init] sampleBuffer] == nil,
                  @"fresh: MTLResourceStatePassSampleBufferAttachmentDescriptor.sampleBuffer is nil on both sides");
            check([[MTLResourceStatePassSampleBufferAttachmentDescriptor new] startOfEncoderSampleIndex]
                  == [[[revenantHost_MTLResourceStatePassSampleBufferAttachmentDescriptor alloc] init] startOfEncoderSampleIndex],
                  @"fresh: MTLResourceStatePassSampleBufferAttachmentDescriptor.startOfEncoderSampleIndex");
            check([[MTLResourceStatePassSampleBufferAttachmentDescriptor new] endOfEncoderSampleIndex]
                  == [[[revenantHost_MTLResourceStatePassSampleBufferAttachmentDescriptor alloc] init] endOfEncoderSampleIndex],
                  @"fresh: MTLResourceStatePassSampleBufferAttachmentDescriptor.endOfEncoderSampleIndex");
            check([[MTLRenderPassSampleBufferAttachmentDescriptor new] sampleBuffer] == nil
                  && [[[revenantHost_MTLRenderPassSampleBufferAttachmentDescriptor alloc] init] sampleBuffer] == nil,
                  @"fresh: MTLRenderPassSampleBufferAttachmentDescriptor.sampleBuffer is nil on both sides");
            check([[MTLRenderPassSampleBufferAttachmentDescriptor new] startOfVertexSampleIndex]
                  == [[[revenantHost_MTLRenderPassSampleBufferAttachmentDescriptor alloc] init] startOfVertexSampleIndex],
                  @"fresh: MTLRenderPassSampleBufferAttachmentDescriptor.startOfVertexSampleIndex");
            check([[MTLRenderPassSampleBufferAttachmentDescriptor new] endOfVertexSampleIndex]
                  == [[[revenantHost_MTLRenderPassSampleBufferAttachmentDescriptor alloc] init] endOfVertexSampleIndex],
                  @"fresh: MTLRenderPassSampleBufferAttachmentDescriptor.endOfVertexSampleIndex");
            check([[MTLRenderPassSampleBufferAttachmentDescriptor new] startOfFragmentSampleIndex]
                  == [[[revenantHost_MTLRenderPassSampleBufferAttachmentDescriptor alloc] init] startOfFragmentSampleIndex],
                  @"fresh: MTLRenderPassSampleBufferAttachmentDescriptor.startOfFragmentSampleIndex");
            check([[MTLRenderPassSampleBufferAttachmentDescriptor new] endOfFragmentSampleIndex]
                  == [[[revenantHost_MTLRenderPassSampleBufferAttachmentDescriptor alloc] init] endOfFragmentSampleIndex],
                  @"fresh: MTLRenderPassSampleBufferAttachmentDescriptor.endOfFragmentSampleIndex");
            check([[MTLComputePassDescriptor new] dispatchType]
                  == [[[revenantHost_MTLComputePassDescriptor alloc] init] dispatchType],
                  @"fresh: MTLComputePassDescriptor.dispatchType");
            check([[MTLComputePassDescriptor new] sampleBufferAttachments] != nil
                  && [[[revenantHost_MTLComputePassDescriptor alloc] init] sampleBufferAttachments] != nil,
                  @"fresh: MTLComputePassDescriptor.sampleBufferAttachments is a real array on both sides");
            check([MTLComputePassSampleBufferAttachmentDescriptorArray class] != nil
                  && [revenantHost_MTLComputePassSampleBufferAttachmentDescriptorArray class] != nil,
                  @"fresh: the compute pass's array class exists on both sides");
            check([[MTLResourceStatePassDescriptor new] sampleBufferAttachments] != nil
                  && [[[revenantHost_MTLResourceStatePassDescriptor alloc] init] sampleBufferAttachments] != nil,
                  @"fresh: MTLResourceStatePassDescriptor.sampleBufferAttachments is a real array on both sides");
            check([[MTLBinaryArchiveDescriptor new] url] == nil
                  && [[[revenantHost_MTLBinaryArchiveDescriptor alloc] init] url] == nil,
                  @"fresh: MTLBinaryArchiveDescriptor.url is nil on both sides");
            check([[MTLLinkedFunctions new] functions] == nil
                  && [[[revenantHost_MTLLinkedFunctions alloc] init] functions] == nil,
                  @"fresh: MTLLinkedFunctions.functions is nil on both sides");
            check([[MTLLinkedFunctions new] binaryFunctions] == nil
                  && [[[revenantHost_MTLLinkedFunctions alloc] init] binaryFunctions] == nil,
                  @"fresh: MTLLinkedFunctions.binaryFunctions is nil on both sides");
            check([[MTLLinkedFunctions new] groups] == nil
                  && [[[revenantHost_MTLLinkedFunctions alloc] init] groups] == nil,
                  @"fresh: MTLLinkedFunctions.groups is nil on both sides");
            check([[MTLLinkedFunctions new] privateFunctions] == nil
                  && [[[revenantHost_MTLLinkedFunctions alloc] init] privateFunctions] == nil,
                  @"fresh: MTLLinkedFunctions.privateFunctions is nil on both sides");
            check([MTLIntersectionFunctionDescriptor new] != nil
                  && [revenantHost_MTLIntersectionFunctionDescriptor new] != nil,
                  @"fresh: MTLIntersectionFunctionDescriptor is made on both sides and declares no member");
        }
        {
            struct { const char *name; const char *port; const char *apple; } undocumented[] = {
                {"indexType",
                 [[[revenantHost_MTLAccelerationStructureTriangleGeometryDescriptor alloc] init] indexType] == 0 ? "unset" : "set",
                 [[[MTLAccelerationStructureTriangleGeometryDescriptor alloc] init] indexType] == 0 ? "unset" : "set"},
            };
            for (unsigned i = 0; i < sizeof undocumented / sizeof undocumented[0]; i++) {
                printf("  note %-44s the header states no default: the port answers %-8s Apple's own object answers %s\n",
                       undocumented[i].name, undocumented[i].port, undocumented[i].apple);
                checks++;
            }
        }

        check([[MTLAccelerationStructureGeometryDescriptor new] allowDuplicateIntersectionFunctionInvocation]
                  == [[[revenantHost_MTLAccelerationStructureGeometryDescriptor alloc] init] allowDuplicateIntersectionFunctionInvocation],
              @"fresh: …GeometryDescriptor.allowDuplicateIntersectionFunctionInvocation, the header's YES");
        check([[MTLPrimitiveAccelerationStructureDescriptor new] motionEndTime]
                  == [[[revenantHost_MTLPrimitiveAccelerationStructureDescriptor alloc] init] motionEndTime],
              @"fresh: MTLPrimitiveAccelerationStructureDescriptor.motionEndTime, the header's 1.0f");
        check([[MTLPrimitiveAccelerationStructureDescriptor new] motionKeyframeCount]
                  == [[[revenantHost_MTLPrimitiveAccelerationStructureDescriptor alloc] init] motionKeyframeCount],
              @"fresh: MTLPrimitiveAccelerationStructureDescriptor.motionKeyframeCount, the header's 1");
        check([[MTLAccelerationStructureTriangleGeometryDescriptor new] vertexFormat]
                  == [[[revenantHost_MTLAccelerationStructureTriangleGeometryDescriptor alloc] init] vertexFormat],
              @"fresh: …TriangleGeometryDescriptor.vertexFormat, the header's Float3 packed");
                        check([[MTLComputePassSampleBufferAttachmentDescriptor new] startOfEncoderSampleIndex]
                  == MTLCounterDontSample
              && [[[revenantHost_MTLComputePassSampleBufferAttachmentDescriptor alloc] init] startOfEncoderSampleIndex]
                  == MTLCounterDontSample,
              @"fresh: MTLComputePassSampleBufferAttachmentDescriptor.startOfEncoderSampleIndex is MTLCounterDontSample");
        check([[MTLComputePassSampleBufferAttachmentDescriptor new] endOfEncoderSampleIndex]
                  == MTLCounterDontSample
              && [[[revenantHost_MTLComputePassSampleBufferAttachmentDescriptor alloc] init] endOfEncoderSampleIndex]
                  == MTLCounterDontSample,
              @"fresh: MTLComputePassSampleBufferAttachmentDescriptor.endOfEncoderSampleIndex is MTLCounterDontSample");
        check([[MTLResourceStatePassSampleBufferAttachmentDescriptor new] startOfEncoderSampleIndex]
                  == MTLCounterDontSample
              && [[[revenantHost_MTLResourceStatePassSampleBufferAttachmentDescriptor alloc] init] startOfEncoderSampleIndex]
                  == MTLCounterDontSample,
              @"fresh: MTLResourceStatePassSampleBufferAttachmentDescriptor.startOfEncoderSampleIndex is MTLCounterDontSample");
        check([[MTLResourceStatePassSampleBufferAttachmentDescriptor new] endOfEncoderSampleIndex]
                  == MTLCounterDontSample
              && [[[revenantHost_MTLResourceStatePassSampleBufferAttachmentDescriptor alloc] init] endOfEncoderSampleIndex]
                  == MTLCounterDontSample,
              @"fresh: MTLResourceStatePassSampleBufferAttachmentDescriptor.endOfEncoderSampleIndex is MTLCounterDontSample");
        check([[MTLRenderPassSampleBufferAttachmentDescriptor new] startOfVertexSampleIndex]
                  == MTLCounterDontSample
              && [[[revenantHost_MTLRenderPassSampleBufferAttachmentDescriptor alloc] init] startOfVertexSampleIndex]
                  == MTLCounterDontSample,
              @"fresh: MTLRenderPassSampleBufferAttachmentDescriptor.startOfVertexSampleIndex is MTLCounterDontSample");
        check([[MTLRenderPassSampleBufferAttachmentDescriptor new] endOfVertexSampleIndex]
                  == MTLCounterDontSample
              && [[[revenantHost_MTLRenderPassSampleBufferAttachmentDescriptor alloc] init] endOfVertexSampleIndex]
                  == MTLCounterDontSample,
              @"fresh: MTLRenderPassSampleBufferAttachmentDescriptor.endOfVertexSampleIndex is MTLCounterDontSample");
        check([[MTLRenderPassSampleBufferAttachmentDescriptor new] startOfFragmentSampleIndex]
                  == MTLCounterDontSample
              && [[[revenantHost_MTLRenderPassSampleBufferAttachmentDescriptor alloc] init] startOfFragmentSampleIndex]
                  == MTLCounterDontSample,
              @"fresh: MTLRenderPassSampleBufferAttachmentDescriptor.startOfFragmentSampleIndex is MTLCounterDontSample");
        check([[MTLRenderPassSampleBufferAttachmentDescriptor new] endOfFragmentSampleIndex]
                  == MTLCounterDontSample
              && [[[revenantHost_MTLRenderPassSampleBufferAttachmentDescriptor alloc] init] endOfFragmentSampleIndex]
                  == MTLCounterDontSample,
              @"fresh: MTLRenderPassSampleBufferAttachmentDescriptor.endOfFragmentSampleIndex is MTLCounterDontSample");
        printf("no device was created: %d checks, each one against Apple's own object\n", checks);
    }
    if (failures) { printf("%d failure(s)\n", failures); return 1; }
    printf("all checks passed\n");
    return 0;
}
