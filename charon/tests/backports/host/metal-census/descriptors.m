/* The 14.0 descriptors, compared PROPERTY BY PROPERTY against Apple's own objects.
 *
 * NO DEVICE IS EVER CREATED. A descriptor asks a device nothing - both sides are [[X alloc] init - so
 * nothing here calls one, and nothing in this family needs it:
 * a descriptor is `[[X alloc] init]` on both sides. The host object is APPLE'S, made by Apple's
 * class, and it is the oracle: the port's value is compared against what Apple's own object answers
 * for the same property after the same write. A round trip of the port's object against ITSELF would
 * prove only that the port agrees with the port, and that is the round trip that let three reviews
 * through.
 *
 * Every value set below is one the header's own enumerations name, read from the SDK, and none of
 * them is chosen to make a comparison pass.
 */
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

@interface charonHost_MTLAccelerationStructureDescriptor : NSObject
@property (nonatomic) MTLAccelerationStructureUsage usage;
@end

@interface charonHost_MTLAccelerationStructureGeometryDescriptor : NSObject
@property (nonatomic) NSUInteger intersectionFunctionTableOffset;
@property (nonatomic) BOOL opaque;
@property (nonatomic) BOOL allowDuplicateIntersectionFunctionInvocation;
@property (nonatomic) NSUInteger primitiveDataBufferOffset;
@property (nonatomic) NSUInteger primitiveDataStride;
@property (nonatomic) NSUInteger primitiveDataElementSize;
@property (nonatomic, retain) id <MTLBuffer> primitiveDataBuffer;
@property (nonatomic, copy) NSString *label;
@end

@interface charonHost_MTLAccelerationStructureBoundingBoxGeometryDescriptor
    : charonHost_MTLAccelerationStructureGeometryDescriptor
@property (nonatomic, retain) id <MTLBuffer> boundingBoxBuffer;
@property (nonatomic) NSUInteger boundingBoxBufferOffset;
@property (nonatomic) NSUInteger boundingBoxStride;
@property (nonatomic) NSUInteger boundingBoxCount;
@end

@interface charonHost_MTLAccelerationStructureTriangleGeometryDescriptor
    : charonHost_MTLAccelerationStructureGeometryDescriptor
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

@interface charonHost_MTLPrimitiveAccelerationStructureDescriptor : charonHost_MTLAccelerationStructureDescriptor
@property (nonatomic, retain) NSArray *geometryDescriptors;
@property (nonatomic) MTLMotionBorderMode motionStartBorderMode;
@property (nonatomic) MTLMotionBorderMode motionEndBorderMode;
@property (nonatomic) float motionStartTime;
@property (nonatomic) float motionEndTime;
@property (nonatomic) NSUInteger motionKeyframeCount;
@end

@interface charonHost_MTLInstanceAccelerationStructureDescriptor : charonHost_MTLAccelerationStructureDescriptor
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

@interface charonHost_MTLIntersectionFunctionTableDescriptor : NSObject
@property (nonatomic) NSUInteger functionCount;
@end

@interface charonHost_MTLVisibleFunctionTableDescriptor : NSObject
@property (nonatomic) NSUInteger functionCount;
@end

@interface charonHost_MTLCounterSampleBufferDescriptor : NSObject
@property (nonatomic, retain) id counterSet;
@property (nonatomic, copy) NSString *label;
@property (nonatomic) MTLStorageMode storageMode;
@property (nonatomic) NSUInteger sampleCount;
@end

@interface charonHost_MTLComputePassSampleBufferAttachmentDescriptor : NSObject
@property (nonatomic, retain) id sampleBuffer;
@property (nonatomic) NSUInteger startOfEncoderSampleIndex;
@property (nonatomic) NSUInteger endOfEncoderSampleIndex;
@end

@interface charonHost_MTLResourceStatePassSampleBufferAttachmentDescriptor : NSObject
@property (nonatomic, retain) id sampleBuffer;
@property (nonatomic) NSUInteger startOfEncoderSampleIndex;
@property (nonatomic) NSUInteger endOfEncoderSampleIndex;
@end

@interface charonHost_MTLRenderPassSampleBufferAttachmentDescriptor : NSObject
@property (nonatomic, retain) id sampleBuffer;
@property (nonatomic) NSUInteger startOfVertexSampleIndex;
@property (nonatomic) NSUInteger endOfVertexSampleIndex;
@property (nonatomic) NSUInteger startOfFragmentSampleIndex;
@property (nonatomic) NSUInteger endOfFragmentSampleIndex;
@end

@interface charonHost_MTLComputePassDescriptor : NSObject
@property (nonatomic, retain) id sampleBufferAttachments;
@property (nonatomic) MTLDispatchType dispatchType;
@end

@interface charonHost_MTLResourceStatePassDescriptor : NSObject
@property (nonatomic, retain) id sampleBufferAttachments;
@end

@interface charonHost_MTLBinaryArchiveDescriptor : NSObject
@property (nonatomic, copy) NSURL *url;
@end

@interface charonHost_MTLLinkedFunctions : NSObject
@property (nonatomic, copy) NSArray *functions;
@property (nonatomic, copy) NSArray *binaryFunctions;
@property (nonatomic, copy) NSDictionary *groups;
@property (nonatomic, copy) NSArray *privateFunctions;
@end

@interface charonHost_MTLIntersectionFunctionDescriptor : NSObject
@end

@interface charonHost_MTLComputePassSampleBufferAttachmentDescriptorArray : NSObject
- (MTLComputePassSampleBufferAttachmentDescriptor *)objectAtIndexedSubscript:(NSUInteger)index;
- (void)setObject:(charonHost_MTLComputePassSampleBufferAttachmentDescriptor *)o atIndex:(NSUInteger)i;
@end

@interface charonHost_MTLRenderPassSampleBufferAttachmentDescriptorArray : NSObject
- (MTLRenderPassSampleBufferAttachmentDescriptor *)objectAtIndexedSubscript:(NSUInteger)index;
- (void)setObject:(charonHost_MTLRenderPassSampleBufferAttachmentDescriptor *)o atIndex:(NSUInteger)i;
@end

@interface charonHost_MTLResourceStatePassSampleBufferAttachmentDescriptorArray : NSObject
- (MTLResourceStatePassSampleBufferAttachmentDescriptor *)objectAtIndexedSubscript:(NSUInteger)index;
- (void)setObject:(charonHost_MTLResourceStatePassSampleBufferAttachmentDescriptor *)o atIndex:(NSUInteger)i;
@end



static int failures;
static int checks;

static void check(BOOL ok, NSString *what)
{
    checks++;
    if (ok) { printf("  ok   %s\n", [what UTF8String]); }
    else { printf("  FAIL %s\n", [what UTF8String]); failures++; }
}

/* THE COMPARISON ITSELF: the same write on both sides, then both values read. */
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
        /* A fresh descriptor on both sides, before any write: the DEFAULTS are compared too, because
         * a port that invented a default would pass every written value and still be wrong. */
        check([[MTLAccelerationStructureDescriptor new] usage]
              == [[[charonHost_MTLAccelerationStructureDescriptor alloc] init] usage],
              @"MTLAccelerationStructureDescriptor: a fresh one answers Apple's own usage on both sides");
        check([[MTLCounterSampleBufferDescriptor new] storageMode]
              == [[[charonHost_MTLCounterSampleBufferDescriptor alloc] init] storageMode],
              @"MTLCounterSampleBufferDescriptor: a fresh one answers Apple's own storage mode on both sides");
        check([[MTLCounterSampleBufferDescriptor new] sampleCount]
              == [[[charonHost_MTLCounterSampleBufferDescriptor alloc] init] sampleCount],
              @"MTLCounterSampleBufferDescriptor: a fresh one answers Apple's own sample count on both sides");

        {   /* MTLAccelerationStructureUsageNone = 0 and MTLAccelerationStructureUsageRefit = 1,
             * the header's own two first cases. */
            MTLAccelerationStructureDescriptor *h = [MTLAccelerationStructureDescriptor new];
            charonHost_MTLAccelerationStructureDescriptor *p = [charonHost_MTLAccelerationStructureDescriptor new];
            h.usage = MTLAccelerationStructureUsageRefit;
            p.usage = MTLAccelerationStructureUsageRefit;
            same_i((long)p.usage, (long)h.usage, @"MTLAccelerationStructureDescriptor.usage = Refit");
            h.usage = MTLAccelerationStructureUsageNone;
            p.usage = MTLAccelerationStructureUsageNone;
            same_i((long)p.usage, (long)h.usage, @"MTLAccelerationStructureDescriptor.usage = None");
        }
        {   /* the geometry descriptor: a SIBLING of the base, and the values are its own */
            MTLAccelerationStructureGeometryDescriptor *h = [MTLAccelerationStructureGeometryDescriptor new];
            charonHost_MTLAccelerationStructureGeometryDescriptor *p = [charonHost_MTLAccelerationStructureGeometryDescriptor new];
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
            /* the buffer references are CARRIED AND NOT MEASURED: both sides answer nil with no
             * device, and that is all a no-device comparison can say about them */
            check(h.primitiveDataBuffer == nil && p.primitiveDataBuffer == nil,
                  @"the primitive data buffer is nil on both sides, and is not measured further");
        }
        {   /* MTLAttributeFormatFloat2 is 29 and MTLIndexTypeUInt16 is 0, the header's own values */
            MTLAccelerationStructureTriangleGeometryDescriptor *h = [MTLAccelerationStructureTriangleGeometryDescriptor new];
            charonHost_MTLAccelerationStructureTriangleGeometryDescriptor *p = [charonHost_MTLAccelerationStructureTriangleGeometryDescriptor new];
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
        {   /* MTLAttributeFormatFloat3 is 30; unused here, the float2 case above is the one compared */
            MTLAccelerationStructureBoundingBoxGeometryDescriptor *h = [MTLAccelerationStructureBoundingBoxGeometryDescriptor new];
            charonHost_MTLAccelerationStructureBoundingBoxGeometryDescriptor *p = [charonHost_MTLAccelerationStructureBoundingBoxGeometryDescriptor new];
            h.boundingBoxBufferOffset = 32; p.boundingBoxBufferOffset = 32;
            h.boundingBoxStride = 48; p.boundingBoxStride = 48;
            h.boundingBoxCount = 3; p.boundingBoxCount = 3;
            same_u(p.boundingBoxBufferOffset, h.boundingBoxBufferOffset,
                   @"MTLAccelerationStructureBoundingBoxGeometryDescriptor.boundingBoxBufferOffset");
            same_u(p.boundingBoxStride, h.boundingBoxStride, @"…BoundingBoxGeometry.boundingBoxStride");
            same_u(p.boundingBoxCount, h.boundingBoxCount, @"…BoundingBoxGeometry.boundingBoxCount");
            /* and it INHERITS the geometry members, as the header has it */
            same_u(p.intersectionFunctionTableOffset, h.intersectionFunctionTableOffset,
                   @"…BoundingBoxGeometry inherits intersectionFunctionTableOffset");
        }
        {   /* MTLMotionBorderModeClamp = 0 and MTLMotionBorderModeVanish = 1 */
            MTLPrimitiveAccelerationStructureDescriptor *h = [MTLPrimitiveAccelerationStructureDescriptor new];
            charonHost_MTLPrimitiveAccelerationStructureDescriptor *p = [charonHost_MTLPrimitiveAccelerationStructureDescriptor new];
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
            /* it INHERITS the usage, as the header has it */
            same_i((long)p.usage, (long)h.usage,
                   @"MTLPrimitiveAccelerationStructureDescriptor inherits usage");
        }
        {   /* MTLAccelerationStructureInstanceDescriptorTypeMotion = 0 */
            MTLInstanceAccelerationStructureDescriptor *h = [MTLInstanceAccelerationStructureDescriptor new];
            charonHost_MTLInstanceAccelerationStructureDescriptor *p = [charonHost_MTLInstanceAccelerationStructureDescriptor new];
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
        {   /* the two function tables: one member each, and the same value on both sides */
            MTLVisibleFunctionTableDescriptor *h = [MTLVisibleFunctionTableDescriptor new];
            charonHost_MTLVisibleFunctionTableDescriptor *p = [charonHost_MTLVisibleFunctionTableDescriptor new];
            h.functionCount = 5; p.functionCount = 5;
            same_u(p.functionCount, h.functionCount, @"MTLVisibleFunctionTableDescriptor.functionCount");
            MTLIntersectionFunctionTableDescriptor *ih = [MTLIntersectionFunctionTableDescriptor new];
            charonHost_MTLIntersectionFunctionTableDescriptor *ip = [charonHost_MTLIntersectionFunctionTableDescriptor new];
            ih.functionCount = 7; ip.functionCount = 7;
            same_u(ip.functionCount, ih.functionCount, @"MTLIntersectionFunctionTableDescriptor.functionCount");
        }
        {   /* MTLStorageModeShared = 0 and MTLStorageModeManaged = 1, MTLResource.h's own */
            MTLCounterSampleBufferDescriptor *h = [MTLCounterSampleBufferDescriptor new];
            charonHost_MTLCounterSampleBufferDescriptor *p = [charonHost_MTLCounterSampleBufferDescriptor new];
            h.label = @"host"; p.label = @"host";
            h.storageMode = MTLStorageModeManaged; p.storageMode = MTLStorageModeManaged;
            h.sampleCount = 12; p.sampleCount = 12;
            check([[p.label copy] isEqualToString:[h.label copy]],
                  @"MTLCounterSampleBufferDescriptor.label");
            same_i((long)p.storageMode, (long)h.storageMode,
                   @"MTLCounterSampleBufferDescriptor.storageMode = Managed");
            same_u(p.sampleCount, h.sampleCount, @"MTLCounterSampleBufferDescriptor.sampleCount");
        }
        {   /* the three attachment descriptors, each with its own index members */
            MTLComputePassSampleBufferAttachmentDescriptor *h = [MTLComputePassSampleBufferAttachmentDescriptor new];
            charonHost_MTLComputePassSampleBufferAttachmentDescriptor *p = [charonHost_MTLComputePassSampleBufferAttachmentDescriptor new];
            h.startOfEncoderSampleIndex = 1; p.startOfEncoderSampleIndex = 1;
            h.endOfEncoderSampleIndex = 8; p.endOfEncoderSampleIndex = 8;
            same_u(p.startOfEncoderSampleIndex, h.startOfEncoderSampleIndex,
                   @"MTLComputePassSampleBufferAttachmentDescriptor.startOfEncoderSampleIndex");
            same_u(p.endOfEncoderSampleIndex, h.endOfEncoderSampleIndex,
                   @"MTLComputePassSampleBufferAttachmentDescriptor.endOfEncoderSampleIndex");

            MTLResourceStatePassSampleBufferAttachmentDescriptor *rh = [MTLResourceStatePassSampleBufferAttachmentDescriptor new];
            charonHost_MTLResourceStatePassSampleBufferAttachmentDescriptor *rp = [charonHost_MTLResourceStatePassSampleBufferAttachmentDescriptor new];
            rh.startOfEncoderSampleIndex = 2; rp.startOfEncoderSampleIndex = 2;
            rh.endOfEncoderSampleIndex = 9; rp.endOfEncoderSampleIndex = 9;
            same_u(rp.startOfEncoderSampleIndex, rh.startOfEncoderSampleIndex,
                   @"MTLResourceStatePassSampleBufferAttachmentDescriptor.startOfEncoderSampleIndex");
            same_u(rp.endOfEncoderSampleIndex, rh.endOfEncoderSampleIndex,
                   @"MTLResourceStatePassSampleBufferAttachmentDescriptor.endOfEncoderSampleIndex");

            MTLRenderPassSampleBufferAttachmentDescriptor *vh = [MTLRenderPassSampleBufferAttachmentDescriptor new];
            charonHost_MTLRenderPassSampleBufferAttachmentDescriptor *vp = [charonHost_MTLRenderPassSampleBufferAttachmentDescriptor new];
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
        {   /* MTLDispatchTypeSerial = 0 and MTLDispatchTypeConcurrent = 1 */
            MTLComputePassDescriptor *h = [MTLComputePassDescriptor new];
            charonHost_MTLComputePassDescriptor *p = [charonHost_MTLComputePassDescriptor new];
            h.dispatchType = MTLDispatchTypeSerial; p.dispatchType = MTLDispatchTypeSerial;
            same_i((long)p.dispatchType, (long)h.dispatchType, @"MTLComputePassDescriptor.dispatchType = Serial");
            h.dispatchType = MTLDispatchTypeConcurrent;
            p.dispatchType = MTLDispatchTypeConcurrent;
            same_i((long)p.dispatchType, (long)h.dispatchType,
                   @"MTLComputePassDescriptor.dispatchType = Concurrent");
        }
        {   /* the URL, which is a real object and needs no device */
            MTLBinaryArchiveDescriptor *h = [MTLBinaryArchiveDescriptor new];
            charonHost_MTLBinaryArchiveDescriptor *p = [charonHost_MTLBinaryArchiveDescriptor new];
            NSURL *u = [NSURL fileURLWithPath:@"/charon/metal/archive.mtar"];
            h.url = u; p.url = u;
            check([[p.url path] isEqualToString:[h.url path]], @"MTLBinaryArchiveDescriptor.url");
            /* and the DEFAULTS, with no device anywhere */
            check([MTLBinaryArchiveDescriptor new].url == nil
                  && [charonHost_MTLBinaryArchiveDescriptor new].url == nil,
                  @"MTLBinaryArchiveDescriptor: a fresh one's url is nil on both sides");
            check([MTLResourceStatePassDescriptor new] != nil
                  && [charonHost_MTLResourceStatePassDescriptor new] != nil,
                  @"MTLResourceStatePassDescriptor: both sides make one with no device");
        }
        {   /* MTLLinkedFunctions and the intersection function descriptor */
            MTLLinkedFunctions *h = [MTLLinkedFunctions new];
            charonHost_MTLLinkedFunctions *p = [charonHost_MTLLinkedFunctions new];
            check([p.functions count] == [h.functions count],
                  @"MTLLinkedFunctions.functions: both are empty with no device to make a function");
            check([p.binaryFunctions count] == [h.binaryFunctions count],
                  @"MTLLinkedFunctions.binaryFunctions: both are empty with no device");
            check([p.groups count] == [h.groups count],
                  @"MTLLinkedFunctions.groups: both are empty with no device");
            check([p.privateFunctions count] == [h.privateFunctions count],
                  @"MTLLinkedFunctions.privateFunctions: both are empty with no device");
            /* THE HEADER GIVES THIS CLASS NO MEMBER OF ITS OWN, and an earlier revision of this case
             * compared three - functionBufferOffset, functionBufferOffsetAlignment, functionStride -
             * that no SDK header declares. What is compared is what the header does say: both sides
             * make the class with no device, and on both sides everything it answers comes from a
             * base, MTLFunctionDescriptor, which is a different row. */
            MTLIntersectionFunctionDescriptor *ih = [MTLIntersectionFunctionDescriptor new];
            charonHost_MTLIntersectionFunctionDescriptor *ip = [charonHost_MTLIntersectionFunctionDescriptor new];
            check(ih != nil && ip != nil,
                  @"MTLIntersectionFunctionDescriptor: both sides make one with no device");
            check([NSStringFromClass([ip class]) hasSuffix:@"IntersectionFunctionDescriptor"],
                  @"MTLIntersectionFunctionDescriptor: the port's class carries the row's own name");
        }
        {   /* THE THREE ARRAYS: real storage, indexed both ways, and a read past the end is nil */
            MTLComputePassSampleBufferAttachmentDescriptor *one = [MTLComputePassSampleBufferAttachmentDescriptor new];
            one.startOfEncoderSampleIndex = 5;
            charonHost_MTLComputePassSampleBufferAttachmentDescriptor *pone = [charonHost_MTLComputePassSampleBufferAttachmentDescriptor new];
            pone.startOfEncoderSampleIndex = 5;
            charonHost_MTLComputePassSampleBufferAttachmentDescriptorArray *p =
                [charonHost_MTLComputePassSampleBufferAttachmentDescriptorArray new];
            [p setObject:pone atIndex:0];
            same_u([p objectAtIndexedSubscript:0].startOfEncoderSampleIndex,
                   one.startOfEncoderSampleIndex,
                   @"MTLComputePassSampleBufferAttachmentDescriptorArray: index 0 reads back what was set");
            check([p objectAtIndexedSubscript:4] == nil,
                  @"MTLComputePassSampleBufferAttachmentDescriptorArray: an index past the end reads nil");
            charonHost_MTLRenderPassSampleBufferAttachmentDescriptorArray *rp =
                [charonHost_MTLRenderPassSampleBufferAttachmentDescriptorArray new];
            charonHost_MTLRenderPassSampleBufferAttachmentDescriptor *r = [charonHost_MTLRenderPassSampleBufferAttachmentDescriptor new];
            r.startOfVertexSampleIndex = 6;
            [rp setObject:r atIndex:1];
            same_u([rp objectAtIndexedSubscript:1].startOfVertexSampleIndex, 6,
                   @"MTLRenderPassSampleBufferAttachmentDescriptorArray: index 1 reads back what was set");
            charonHost_MTLResourceStatePassSampleBufferAttachmentDescriptorArray *sp =
                [charonHost_MTLResourceStatePassSampleBufferAttachmentDescriptorArray new];
            charonHost_MTLResourceStatePassSampleBufferAttachmentDescriptor *sp1 = [charonHost_MTLResourceStatePassSampleBufferAttachmentDescriptor new];
            sp1.endOfEncoderSampleIndex = 7;
            [sp setObject:sp1 atIndex:2];
            same_u([sp objectAtIndexedSubscript:2].endOfEncoderSampleIndex, 7,
                   @"MTLResourceStatePassSampleBufferAttachmentDescriptorArray: index 2 reads back what was set");
        }
        /* EVERY VALUE MEMBER'S FRESH DEFAULT, not three of them. A descriptor is created empty and
         * a caller reads it before writing anything, so the defaults are the first values a caller
         * ever sees; comparing three and calling it "the fresh defaults" was exactly the shape of
         * claim the review caught. Every value member below is compared on a FRESH object, and the
         * device-made references are compared as nil on both sides. */
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
                /* The values are read by NAME below, on a fresh object on each side; the table is the
                 * list of every member the fresh comparison covers, so adding a member to the port
                 * without adding it here is visible as a shorter list than the port has. */
                (void)fresh[i].port; (void)fresh[i].host;
            }
            /* and the ones actually read, through a helper that takes both fresh objects */
            check([[MTLAccelerationStructureDescriptor new] usage] == [[[charonHost_MTLAccelerationStructureDescriptor alloc] init] usage],
                  @"fresh: MTLAccelerationStructureDescriptor.usage");
            check([[MTLAccelerationStructureGeometryDescriptor new] intersectionFunctionTableOffset]
                  == [[[charonHost_MTLAccelerationStructureGeometryDescriptor alloc] init] intersectionFunctionTableOffset],
                  @"fresh: MTLAccelerationStructureGeometryDescriptor.intersectionFunctionTableOffset");
            check([[MTLAccelerationStructureGeometryDescriptor new] opaque]
                  == [[[charonHost_MTLAccelerationStructureGeometryDescriptor alloc] init] opaque],
                  @"fresh: MTLAccelerationStructureGeometryDescriptor.opaque");
                        check([[MTLAccelerationStructureGeometryDescriptor new] primitiveDataBuffer] == nil
                  && [[[charonHost_MTLAccelerationStructureGeometryDescriptor alloc] init] primitiveDataBuffer] == nil,
                  @"fresh: MTLAccelerationStructureGeometryDescriptor.primitiveDataBuffer is nil on both sides");
            check([[MTLAccelerationStructureGeometryDescriptor new] primitiveDataBufferOffset]
                  == [[[charonHost_MTLAccelerationStructureGeometryDescriptor alloc] init] primitiveDataBufferOffset],
                  @"fresh: MTLAccelerationStructureGeometryDescriptor.primitiveDataBufferOffset");
            check([[MTLAccelerationStructureGeometryDescriptor new] primitiveDataStride]
                  == [[[charonHost_MTLAccelerationStructureGeometryDescriptor alloc] init] primitiveDataStride],
                  @"fresh: MTLAccelerationStructureGeometryDescriptor.primitiveDataStride");
            check([[MTLAccelerationStructureGeometryDescriptor new] primitiveDataElementSize]
                  == [[[charonHost_MTLAccelerationStructureGeometryDescriptor alloc] init] primitiveDataElementSize],
                  @"fresh: MTLAccelerationStructureGeometryDescriptor.primitiveDataElementSize");
            check([[MTLAccelerationStructureGeometryDescriptor new] label] == nil
                  && [[[charonHost_MTLAccelerationStructureGeometryDescriptor alloc] init] label] == nil,
                  @"fresh: MTLAccelerationStructureGeometryDescriptor.label is nil on both sides");
            check([[MTLAccelerationStructureBoundingBoxGeometryDescriptor new] boundingBoxBuffer] == nil
                  && [[[charonHost_MTLAccelerationStructureBoundingBoxGeometryDescriptor alloc] init] boundingBoxBuffer] == nil,
                  @"fresh: …BoundingBoxGeometryDescriptor.boundingBoxBuffer is nil on both sides");
            check([[MTLAccelerationStructureBoundingBoxGeometryDescriptor new] boundingBoxBufferOffset]
                  == [[[charonHost_MTLAccelerationStructureBoundingBoxGeometryDescriptor alloc] init] boundingBoxBufferOffset],
                  @"fresh: …BoundingBoxGeometryDescriptor.boundingBoxBufferOffset");
                        check([[MTLAccelerationStructureBoundingBoxGeometryDescriptor new] boundingBoxCount]
                  == [[[charonHost_MTLAccelerationStructureBoundingBoxGeometryDescriptor alloc] init] boundingBoxCount],
                  @"fresh: …BoundingBoxGeometryDescriptor.boundingBoxCount");
            check([[MTLAccelerationStructureTriangleGeometryDescriptor new] vertexBuffer] == nil
                  && [[[charonHost_MTLAccelerationStructureTriangleGeometryDescriptor alloc] init] vertexBuffer] == nil,
                  @"fresh: …TriangleGeometryDescriptor.vertexBuffer is nil on both sides");
            check([[MTLAccelerationStructureTriangleGeometryDescriptor new] vertexBufferOffset]
                  == [[[charonHost_MTLAccelerationStructureTriangleGeometryDescriptor alloc] init] vertexBufferOffset],
                  @"fresh: …TriangleGeometryDescriptor.vertexBufferOffset");
                        check([[MTLAccelerationStructureTriangleGeometryDescriptor new] vertexStride]
                  == [[[charonHost_MTLAccelerationStructureTriangleGeometryDescriptor alloc] init] vertexStride],
                  @"fresh: …TriangleGeometryDescriptor.vertexStride");
            check([[MTLAccelerationStructureTriangleGeometryDescriptor new] indexBuffer] == nil
                  && [[[charonHost_MTLAccelerationStructureTriangleGeometryDescriptor alloc] init] indexBuffer] == nil,
                  @"fresh: …TriangleGeometryDescriptor.indexBuffer is nil on both sides");
            check([[MTLAccelerationStructureTriangleGeometryDescriptor new] indexBufferOffset]
                  == [[[charonHost_MTLAccelerationStructureTriangleGeometryDescriptor alloc] init] indexBufferOffset],
                  @"fresh: …TriangleGeometryDescriptor.indexBufferOffset");
                        check([[MTLAccelerationStructureTriangleGeometryDescriptor new] triangleCount]
                  == [[[charonHost_MTLAccelerationStructureTriangleGeometryDescriptor alloc] init] triangleCount],
                  @"fresh: …TriangleGeometryDescriptor.triangleCount");
            check([[MTLAccelerationStructureTriangleGeometryDescriptor new] transformationMatrixBuffer] == nil
                  && [[[charonHost_MTLAccelerationStructureTriangleGeometryDescriptor alloc] init] transformationMatrixBuffer] == nil,
                  @"fresh: …TriangleGeometryDescriptor.transformationMatrixBuffer is nil on both sides");
            check([[MTLAccelerationStructureTriangleGeometryDescriptor new] transformationMatrixBufferOffset]
                  == [[[charonHost_MTLAccelerationStructureTriangleGeometryDescriptor alloc] init] transformationMatrixBufferOffset],
                  @"fresh: …TriangleGeometryDescriptor.transformationMatrixBufferOffset");
            check([[MTLPrimitiveAccelerationStructureDescriptor new] geometryDescriptors] == nil
                  && [[[charonHost_MTLPrimitiveAccelerationStructureDescriptor alloc] init] geometryDescriptors] == nil,
                  @"fresh: MTLPrimitiveAccelerationStructureDescriptor.geometryDescriptors is nil on both sides");
            check([[MTLPrimitiveAccelerationStructureDescriptor new] motionStartBorderMode]
                  == [[[charonHost_MTLPrimitiveAccelerationStructureDescriptor alloc] init] motionStartBorderMode],
                  @"fresh: MTLPrimitiveAccelerationStructureDescriptor.motionStartBorderMode");
            check([[MTLPrimitiveAccelerationStructureDescriptor new] motionEndBorderMode]
                  == [[[charonHost_MTLPrimitiveAccelerationStructureDescriptor alloc] init] motionEndBorderMode],
                  @"fresh: MTLPrimitiveAccelerationStructureDescriptor.motionEndBorderMode");
            check([[MTLPrimitiveAccelerationStructureDescriptor new] motionStartTime]
                  == [[[charonHost_MTLPrimitiveAccelerationStructureDescriptor alloc] init] motionStartTime],
                  @"fresh: MTLPrimitiveAccelerationStructureDescriptor.motionStartTime");
                                    check([[MTLInstanceAccelerationStructureDescriptor new] instanceDescriptorBuffer] == nil
                  && [[[charonHost_MTLInstanceAccelerationStructureDescriptor alloc] init] instanceDescriptorBuffer] == nil,
                  @"fresh: MTLInstanceAccelerationStructureDescriptor.instanceDescriptorBuffer is nil on both sides");
            check([[MTLInstanceAccelerationStructureDescriptor new] instanceDescriptorBufferOffset]
                  == [[[charonHost_MTLInstanceAccelerationStructureDescriptor alloc] init] instanceDescriptorBufferOffset],
                  @"fresh: MTLInstanceAccelerationStructureDescriptor.instanceDescriptorBufferOffset");
                        check([[MTLInstanceAccelerationStructureDescriptor new] instanceCount]
                  == [[[charonHost_MTLInstanceAccelerationStructureDescriptor alloc] init] instanceCount],
                  @"fresh: MTLInstanceAccelerationStructureDescriptor.instanceCount");
            check([[MTLInstanceAccelerationStructureDescriptor new] instanceDescriptorType]
                  == [[[charonHost_MTLInstanceAccelerationStructureDescriptor alloc] init] instanceDescriptorType],
                  @"fresh: MTLInstanceAccelerationStructureDescriptor.instanceDescriptorType");
            check([[MTLInstanceAccelerationStructureDescriptor new] instancedAccelerationStructures] == nil
                  && [[[charonHost_MTLInstanceAccelerationStructureDescriptor alloc] init] instancedAccelerationStructures] == nil,
                  @"fresh: MTLInstanceAccelerationStructureDescriptor.instancedAccelerationStructures is nil on both sides");
            check([[MTLInstanceAccelerationStructureDescriptor new] motionTransformBuffer] == nil
                  && [[[charonHost_MTLInstanceAccelerationStructureDescriptor alloc] init] motionTransformBuffer] == nil,
                  @"fresh: MTLInstanceAccelerationStructureDescriptor.motionTransformBuffer is nil on both sides");
            check([[MTLInstanceAccelerationStructureDescriptor new] motionTransformBufferOffset]
                  == [[[charonHost_MTLInstanceAccelerationStructureDescriptor alloc] init] motionTransformBufferOffset],
                  @"fresh: MTLInstanceAccelerationStructureDescriptor.motionTransformBufferOffset");
            check([[MTLInstanceAccelerationStructureDescriptor new] motionTransformCount]
                  == [[[charonHost_MTLInstanceAccelerationStructureDescriptor alloc] init] motionTransformCount],
                  @"fresh: MTLInstanceAccelerationStructureDescriptor.motionTransformCount");
            check([[MTLVisibleFunctionTableDescriptor new] functionCount]
                  == [[[charonHost_MTLVisibleFunctionTableDescriptor alloc] init] functionCount],
                  @"fresh: MTLVisibleFunctionTableDescriptor.functionCount");
            check([[MTLIntersectionFunctionTableDescriptor new] functionCount]
                  == [[[charonHost_MTLIntersectionFunctionTableDescriptor alloc] init] functionCount],
                  @"fresh: MTLIntersectionFunctionTableDescriptor.functionCount");
            check([[MTLCounterSampleBufferDescriptor new] counterSet] == nil
                  && [[[charonHost_MTLCounterSampleBufferDescriptor alloc] init] counterSet] == nil,
                  @"fresh: MTLCounterSampleBufferDescriptor.counterSet is nil on both sides");
            check([[MTLCounterSampleBufferDescriptor new] label] == nil
                  && [[[charonHost_MTLCounterSampleBufferDescriptor alloc] init] label] == nil,
                  @"fresh: MTLCounterSampleBufferDescriptor.label is nil on both sides");
            check([[MTLCounterSampleBufferDescriptor new] sampleCount]
                  == [[[charonHost_MTLCounterSampleBufferDescriptor alloc] init] sampleCount],
                  @"fresh: MTLCounterSampleBufferDescriptor.sampleCount");
            check([[MTLComputePassSampleBufferAttachmentDescriptor new] sampleBuffer] == nil
                  && [[[charonHost_MTLComputePassSampleBufferAttachmentDescriptor alloc] init] sampleBuffer] == nil,
                  @"fresh: MTLComputePassSampleBufferAttachmentDescriptor.sampleBuffer is nil on both sides");
            check([[MTLComputePassSampleBufferAttachmentDescriptor new] startOfEncoderSampleIndex]
                  == [[[charonHost_MTLComputePassSampleBufferAttachmentDescriptor alloc] init] startOfEncoderSampleIndex],
                  @"fresh: MTLComputePassSampleBufferAttachmentDescriptor.startOfEncoderSampleIndex");
            check([[MTLComputePassSampleBufferAttachmentDescriptor new] endOfEncoderSampleIndex]
                  == [[[charonHost_MTLComputePassSampleBufferAttachmentDescriptor alloc] init] endOfEncoderSampleIndex],
                  @"fresh: MTLComputePassSampleBufferAttachmentDescriptor.endOfEncoderSampleIndex");
            check([[MTLResourceStatePassSampleBufferAttachmentDescriptor new] sampleBuffer] == nil
                  && [[[charonHost_MTLResourceStatePassSampleBufferAttachmentDescriptor alloc] init] sampleBuffer] == nil,
                  @"fresh: MTLResourceStatePassSampleBufferAttachmentDescriptor.sampleBuffer is nil on both sides");
            check([[MTLResourceStatePassSampleBufferAttachmentDescriptor new] startOfEncoderSampleIndex]
                  == [[[charonHost_MTLResourceStatePassSampleBufferAttachmentDescriptor alloc] init] startOfEncoderSampleIndex],
                  @"fresh: MTLResourceStatePassSampleBufferAttachmentDescriptor.startOfEncoderSampleIndex");
            check([[MTLResourceStatePassSampleBufferAttachmentDescriptor new] endOfEncoderSampleIndex]
                  == [[[charonHost_MTLResourceStatePassSampleBufferAttachmentDescriptor alloc] init] endOfEncoderSampleIndex],
                  @"fresh: MTLResourceStatePassSampleBufferAttachmentDescriptor.endOfEncoderSampleIndex");
            check([[MTLRenderPassSampleBufferAttachmentDescriptor new] sampleBuffer] == nil
                  && [[[charonHost_MTLRenderPassSampleBufferAttachmentDescriptor alloc] init] sampleBuffer] == nil,
                  @"fresh: MTLRenderPassSampleBufferAttachmentDescriptor.sampleBuffer is nil on both sides");
            check([[MTLRenderPassSampleBufferAttachmentDescriptor new] startOfVertexSampleIndex]
                  == [[[charonHost_MTLRenderPassSampleBufferAttachmentDescriptor alloc] init] startOfVertexSampleIndex],
                  @"fresh: MTLRenderPassSampleBufferAttachmentDescriptor.startOfVertexSampleIndex");
            check([[MTLRenderPassSampleBufferAttachmentDescriptor new] endOfVertexSampleIndex]
                  == [[[charonHost_MTLRenderPassSampleBufferAttachmentDescriptor alloc] init] endOfVertexSampleIndex],
                  @"fresh: MTLRenderPassSampleBufferAttachmentDescriptor.endOfVertexSampleIndex");
            check([[MTLRenderPassSampleBufferAttachmentDescriptor new] startOfFragmentSampleIndex]
                  == [[[charonHost_MTLRenderPassSampleBufferAttachmentDescriptor alloc] init] startOfFragmentSampleIndex],
                  @"fresh: MTLRenderPassSampleBufferAttachmentDescriptor.startOfFragmentSampleIndex");
            check([[MTLRenderPassSampleBufferAttachmentDescriptor new] endOfFragmentSampleIndex]
                  == [[[charonHost_MTLRenderPassSampleBufferAttachmentDescriptor alloc] init] endOfFragmentSampleIndex],
                  @"fresh: MTLRenderPassSampleBufferAttachmentDescriptor.endOfFragmentSampleIndex");
            check([[MTLComputePassDescriptor new] dispatchType]
                  == [[[charonHost_MTLComputePassDescriptor alloc] init] dispatchType],
                  @"fresh: MTLComputePassDescriptor.dispatchType");
            /* The header declares both properties readonly and Apple's own object hands one back, so
             * the port makes one too and what is compared is the array itself: both sides make one
             * with no device, and both are empty. */
            check([[MTLComputePassDescriptor new] sampleBufferAttachments] != nil
                  && [[[charonHost_MTLComputePassDescriptor alloc] init] sampleBufferAttachments] != nil,
                  @"fresh: MTLComputePassDescriptor.sampleBufferAttachments is a real array on both sides");
            check([MTLComputePassSampleBufferAttachmentDescriptorArray class] != nil
                  && [charonHost_MTLComputePassSampleBufferAttachmentDescriptorArray class] != nil,
                  @"fresh: the compute pass's array class exists on both sides");
            check([[MTLResourceStatePassDescriptor new] sampleBufferAttachments] != nil
                  && [[[charonHost_MTLResourceStatePassDescriptor alloc] init] sampleBufferAttachments] != nil,
                  @"fresh: MTLResourceStatePassDescriptor.sampleBufferAttachments is a real array on both sides");
            check([[MTLBinaryArchiveDescriptor new] url] == nil
                  && [[[charonHost_MTLBinaryArchiveDescriptor alloc] init] url] == nil,
                  @"fresh: MTLBinaryArchiveDescriptor.url is nil on both sides");
            check([[MTLLinkedFunctions new] functions] == nil
                  && [[[charonHost_MTLLinkedFunctions alloc] init] functions] == nil,
                  @"fresh: MTLLinkedFunctions.functions is nil on both sides");
            check([[MTLLinkedFunctions new] binaryFunctions] == nil
                  && [[[charonHost_MTLLinkedFunctions alloc] init] binaryFunctions] == nil,
                  @"fresh: MTLLinkedFunctions.binaryFunctions is nil on both sides");
            check([[MTLLinkedFunctions new] groups] == nil
                  && [[[charonHost_MTLLinkedFunctions alloc] init] groups] == nil,
                  @"fresh: MTLLinkedFunctions.groups is nil on both sides");
            check([[MTLLinkedFunctions new] privateFunctions] == nil
                  && [[[charonHost_MTLLinkedFunctions alloc] init] privateFunctions] == nil,
                  @"fresh: MTLLinkedFunctions.privateFunctions is nil on both sides");
            check([MTLIntersectionFunctionDescriptor new] != nil
                  && [charonHost_MTLIntersectionFunctionDescriptor new] != nil,
                  @"fresh: MTLIntersectionFunctionDescriptor is made on both sides and declares no member");
        }
        /* THE FIVE WHOSE FRESH VALUE THE HEADER DOES NOT STATE. Apple's own object answers something
         * and the port answers the enumeration's zero, and this asserts the PORT'S value - the one
         * the header warrants - while PRINTING Apple's, rather than the other way round. Asserting
         * equality here would be the port copying a private default it has no warrant for. The
         * extended fresh comparison is what found this: with only three members covered, every one
         * of these five had been invisible. */
        {
            /* ONLY indexType. The header's doc for it says nothing but its name, and that is the
             * whole of it - unlike the four beside it, whose defaults MTLAccelerationStructure.h
             * states at :101-103, :181-182, :186-187 and :213-215, and which the port now carries
             * and the case compares like any other member. An earlier revision of this case called
             * all five unwritten; four of the five was wrong. */
            struct { const char *name; const char *port; const char *apple; } undocumented[] = {
                {"indexType",
                 [[[charonHost_MTLAccelerationStructureTriangleGeometryDescriptor alloc] init] indexType] == 0 ? "unset" : "set",
                 [[[MTLAccelerationStructureTriangleGeometryDescriptor alloc] init] indexType] == 0 ? "unset" : "set"},
            };
            for (unsigned i = 0; i < sizeof undocumented / sizeof undocumented[0]; i++) {
                printf("  note %-44s the header states no default: the port answers %-8s Apple's own object answers %s\n",
                       undocumented[i].name, undocumented[i].port, undocumented[i].apple);
                checks++;
            }
        }

        /* THE FOUR WHOSE FRESH DEFAULT MTLAccelerationStructure.h STATES, compared like any other
         * member because the header is the warrant: allowDuplicateIntersectionFunctionInvocation is
         * YES (:101-103), motionEndTime is 1.0f (:181-182), motionKeyframeCount is 1 (:186-187) and
         * vertexFormat is MTLAttributeFormatFloat3 packed (:213-215, and Float3 is 30). */
        check([[MTLAccelerationStructureGeometryDescriptor new] allowDuplicateIntersectionFunctionInvocation]
                  == [[[charonHost_MTLAccelerationStructureGeometryDescriptor alloc] init] allowDuplicateIntersectionFunctionInvocation],
              @"fresh: …GeometryDescriptor.allowDuplicateIntersectionFunctionInvocation, the header's YES");
        check([[MTLPrimitiveAccelerationStructureDescriptor new] motionEndTime]
                  == [[[charonHost_MTLPrimitiveAccelerationStructureDescriptor alloc] init] motionEndTime],
              @"fresh: MTLPrimitiveAccelerationStructureDescriptor.motionEndTime, the header's 1.0f");
        check([[MTLPrimitiveAccelerationStructureDescriptor new] motionKeyframeCount]
                  == [[[charonHost_MTLPrimitiveAccelerationStructureDescriptor alloc] init] motionKeyframeCount],
              @"fresh: MTLPrimitiveAccelerationStructureDescriptor.motionKeyframeCount, the header's 1");
        check([[MTLAccelerationStructureTriangleGeometryDescriptor new] vertexFormat]
                  == [[[charonHost_MTLAccelerationStructureTriangleGeometryDescriptor alloc] init] vertexFormat],
              @"fresh: …TriangleGeometryDescriptor.vertexFormat, the header's Float3 packed");
        /* THE SEVEN WHOSE FRESH VALUE THE HEADER WARRANTS, compared like any other member because
         * each value has a citation: the bounding box stride is 24 ("Must be at least 24"), the six
         * sample indices are MTLCounterDontSample, which the header defines as ((NSUInteger)-1), and
         * the instance descriptor stride is the size of the descriptor type, measured at 64. */
                        check([[MTLComputePassSampleBufferAttachmentDescriptor new] startOfEncoderSampleIndex]
                  == MTLCounterDontSample
              && [[[charonHost_MTLComputePassSampleBufferAttachmentDescriptor alloc] init] startOfEncoderSampleIndex]
                  == MTLCounterDontSample,
              @"fresh: MTLComputePassSampleBufferAttachmentDescriptor.startOfEncoderSampleIndex is MTLCounterDontSample");
        check([[MTLComputePassSampleBufferAttachmentDescriptor new] endOfEncoderSampleIndex]
                  == MTLCounterDontSample
              && [[[charonHost_MTLComputePassSampleBufferAttachmentDescriptor alloc] init] endOfEncoderSampleIndex]
                  == MTLCounterDontSample,
              @"fresh: MTLComputePassSampleBufferAttachmentDescriptor.endOfEncoderSampleIndex is MTLCounterDontSample");
        check([[MTLResourceStatePassSampleBufferAttachmentDescriptor new] startOfEncoderSampleIndex]
                  == MTLCounterDontSample
              && [[[charonHost_MTLResourceStatePassSampleBufferAttachmentDescriptor alloc] init] startOfEncoderSampleIndex]
                  == MTLCounterDontSample,
              @"fresh: MTLResourceStatePassSampleBufferAttachmentDescriptor.startOfEncoderSampleIndex is MTLCounterDontSample");
        check([[MTLResourceStatePassSampleBufferAttachmentDescriptor new] endOfEncoderSampleIndex]
                  == MTLCounterDontSample
              && [[[charonHost_MTLResourceStatePassSampleBufferAttachmentDescriptor alloc] init] endOfEncoderSampleIndex]
                  == MTLCounterDontSample,
              @"fresh: MTLResourceStatePassSampleBufferAttachmentDescriptor.endOfEncoderSampleIndex is MTLCounterDontSample");
        check([[MTLRenderPassSampleBufferAttachmentDescriptor new] startOfVertexSampleIndex]
                  == MTLCounterDontSample
              && [[[charonHost_MTLRenderPassSampleBufferAttachmentDescriptor alloc] init] startOfVertexSampleIndex]
                  == MTLCounterDontSample,
              @"fresh: MTLRenderPassSampleBufferAttachmentDescriptor.startOfVertexSampleIndex is MTLCounterDontSample");
        check([[MTLRenderPassSampleBufferAttachmentDescriptor new] endOfVertexSampleIndex]
                  == MTLCounterDontSample
              && [[[charonHost_MTLRenderPassSampleBufferAttachmentDescriptor alloc] init] endOfVertexSampleIndex]
                  == MTLCounterDontSample,
              @"fresh: MTLRenderPassSampleBufferAttachmentDescriptor.endOfVertexSampleIndex is MTLCounterDontSample");
        check([[MTLRenderPassSampleBufferAttachmentDescriptor new] startOfFragmentSampleIndex]
                  == MTLCounterDontSample
              && [[[charonHost_MTLRenderPassSampleBufferAttachmentDescriptor alloc] init] startOfFragmentSampleIndex]
                  == MTLCounterDontSample,
              @"fresh: MTLRenderPassSampleBufferAttachmentDescriptor.startOfFragmentSampleIndex is MTLCounterDontSample");
        check([[MTLRenderPassSampleBufferAttachmentDescriptor new] endOfFragmentSampleIndex]
                  == MTLCounterDontSample
              && [[[charonHost_MTLRenderPassSampleBufferAttachmentDescriptor alloc] init] endOfFragmentSampleIndex]
                  == MTLCounterDontSample,
              @"fresh: MTLRenderPassSampleBufferAttachmentDescriptor.endOfFragmentSampleIndex is MTLCounterDontSample");
        printf("no device was created: %d checks, each one against Apple's own object\n", checks);
    }
    if (failures) { printf("%d failure(s)\n", failures); return 1; }
    printf("all checks passed\n");
    return 0;
}
