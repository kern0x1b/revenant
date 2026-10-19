#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <objc/runtime.h>
#import "RevenantMetal26Types.h"

static BOOL RevenantMetal4GeometryBaseEqual(MTL4AccelerationStructureGeometryDescriptor *mine,
                                          MTL4AccelerationStructureGeometryDescriptor *theirs)
{
    if (mine.intersectionFunctionTableOffset != theirs.intersectionFunctionTableOffset) return NO;
    if (mine.opaque != theirs.opaque) return NO;
    if (mine.allowDuplicateIntersectionFunctionInvocation != theirs.allowDuplicateIntersectionFunctionInvocation) return NO;
    if (mine.label != theirs.label && ![mine.label isEqual:theirs.label]) return NO;
    if (mine.primitiveDataBuffer.bufferAddress != theirs.primitiveDataBuffer.bufferAddress) return NO;
    if (mine.primitiveDataBuffer.length != theirs.primitiveDataBuffer.length) return NO;
    if (mine.primitiveDataStride != theirs.primitiveDataStride) return NO;
    if (mine.primitiveDataElementSize != theirs.primitiveDataElementSize) return NO;
    return YES;
}

static NSUInteger RevenantMetal4GeometryBaseHash(MTL4AccelerationStructureGeometryDescriptor *mine)
{
    NSUInteger hash = (NSUInteger)object_getClass(mine);
    hash = hash * 31u + (uint32_t)mine.intersectionFunctionTableOffset;
    hash = hash * 31u + (uint32_t)mine.opaque;
    hash = hash * 31u + (uint32_t)mine.allowDuplicateIntersectionFunctionInvocation;
    hash = hash * 31u + (uint32_t)[mine.label hash];
    hash = hash * 31u + (uint32_t)mine.primitiveDataBuffer.bufferAddress;
    hash = hash * 31u + (uint32_t)mine.primitiveDataBuffer.length;
    hash = hash * 31u + (uint32_t)mine.primitiveDataStride;
    hash = hash * 31u + (uint32_t)mine.primitiveDataElementSize;
    return hash;
}

@implementation MTL4AccelerationStructureGeometryDescriptor {
    NSUInteger _intersectionFunctionTableOffset;
    BOOL _opaque;
    BOOL _allowDuplicateIntersectionFunctionInvocation;
    NSString *_label;
    MTL4BufferRange _primitiveDataBuffer;
    NSUInteger _primitiveDataStride;
    NSUInteger _primitiveDataElementSize;
}

@synthesize intersectionFunctionTableOffset = _intersectionFunctionTableOffset;
@synthesize opaque = _opaque;
@synthesize allowDuplicateIntersectionFunctionInvocation = _allowDuplicateIntersectionFunctionInvocation;
@synthesize label = _label;
@synthesize primitiveDataBuffer = _primitiveDataBuffer;
@synthesize primitiveDataStride = _primitiveDataStride;
@synthesize primitiveDataElementSize = _primitiveDataElementSize;

- (void)setLabel:(NSString *)label
{
    _label = [label copy];
}

- (instancetype)init
{
    if ((self = [super init])) {
        _allowDuplicateIntersectionFunctionInvocation = YES;
        _primitiveDataBuffer.bufferAddress = 0;
        _primitiveDataBuffer.length = 0;
    }
    return self;
}

- (BOOL)isEqual:(id)object
{
    if (self == object) return YES;
    if (![object isKindOfClass:[MTL4AccelerationStructureGeometryDescriptor class]]) return NO;
    return RevenantMetal4GeometryBaseEqual(self, object);
}

- (NSUInteger)hash
{
    return RevenantMetal4GeometryBaseHash(self);
}

- (id)copyWithZone:(NSZone *)zone
{
    MTL4AccelerationStructureGeometryDescriptor *copy = [[MTL4AccelerationStructureGeometryDescriptor alloc] init];
    copy.intersectionFunctionTableOffset = self.intersectionFunctionTableOffset;
    copy.opaque = self.opaque;
    copy.allowDuplicateIntersectionFunctionInvocation = self.allowDuplicateIntersectionFunctionInvocation;
    copy.label = self.label;
    copy.primitiveDataBuffer = self.primitiveDataBuffer;
    copy.primitiveDataStride = self.primitiveDataStride;
    copy.primitiveDataElementSize = self.primitiveDataElementSize;
    return copy;
}

@end

enum { RevenantMetal4Float3 = 30, RevenantMetal4Float1 = 28 };

@implementation MTL4AccelerationStructureTriangleGeometryDescriptor {
    MTL4BufferRange _vertexBuffer;
    MTLAttributeFormat _vertexFormat;
    NSUInteger _vertexStride;
    MTL4BufferRange _indexBuffer;
    MTLIndexType _indexType;
    NSUInteger _triangleCount;
    MTL4BufferRange _transformationMatrixBuffer;
    MTLMatrixLayout _transformationMatrixLayout;
}

@synthesize vertexBuffer = _vertexBuffer;
@synthesize vertexFormat = _vertexFormat;
@synthesize vertexStride = _vertexStride;
@synthesize indexBuffer = _indexBuffer;
@synthesize indexType = _indexType;
@synthesize triangleCount = _triangleCount;
@synthesize transformationMatrixBuffer = _transformationMatrixBuffer;
@synthesize transformationMatrixLayout = _transformationMatrixLayout;

- (instancetype)init
{
    if ((self = [super init])) {
        _vertexFormat = (MTLAttributeFormat)RevenantMetal4Float3;
        _indexType = MTLIndexTypeUInt32;
    }
    return self;
}

- (BOOL)isEqual:(id)object
{
    if (self == object) return YES;
    if (![object isKindOfClass:[MTL4AccelerationStructureTriangleGeometryDescriptor class]]) return NO;
    if (!RevenantMetal4GeometryBaseEqual(self, object)) return NO;
    if (_vertexBuffer.bufferAddress != ((MTL4AccelerationStructureTriangleGeometryDescriptor *)object).vertexBuffer.bufferAddress) return NO;
    if (_vertexBuffer.length != ((MTL4AccelerationStructureTriangleGeometryDescriptor *)object).vertexBuffer.length) return NO;
    if (_vertexFormat != ((MTL4AccelerationStructureTriangleGeometryDescriptor *)object).vertexFormat) return NO;
    if (_vertexStride != ((MTL4AccelerationStructureTriangleGeometryDescriptor *)object).vertexStride) return NO;
    if (_indexBuffer.bufferAddress != ((MTL4AccelerationStructureTriangleGeometryDescriptor *)object).indexBuffer.bufferAddress) return NO;
    if (_indexBuffer.length != ((MTL4AccelerationStructureTriangleGeometryDescriptor *)object).indexBuffer.length) return NO;
    if (_indexType != ((MTL4AccelerationStructureTriangleGeometryDescriptor *)object).indexType) return NO;
    if (_triangleCount != ((MTL4AccelerationStructureTriangleGeometryDescriptor *)object).triangleCount) return NO;
    if (_transformationMatrixBuffer.bufferAddress != ((MTL4AccelerationStructureTriangleGeometryDescriptor *)object).transformationMatrixBuffer.bufferAddress) return NO;
    if (_transformationMatrixBuffer.length != ((MTL4AccelerationStructureTriangleGeometryDescriptor *)object).transformationMatrixBuffer.length) return NO;
    if (_transformationMatrixLayout != ((MTL4AccelerationStructureTriangleGeometryDescriptor *)object).transformationMatrixLayout) return NO;
    return YES;
}

- (NSUInteger)hash
{
    NSUInteger hash = RevenantMetal4GeometryBaseHash(self);
    hash = hash * 31u + (uint32_t)_vertexBuffer.bufferAddress;
    hash = hash * 31u + (uint32_t)_vertexBuffer.length;
    hash = hash * 31u + (uint32_t)_vertexFormat;
    hash = hash * 31u + (uint32_t)_vertexStride;
    hash = hash * 31u + (uint32_t)_indexBuffer.bufferAddress;
    hash = hash * 31u + (uint32_t)_indexBuffer.length;
    hash = hash * 31u + (uint32_t)_indexType;
    hash = hash * 31u + (uint32_t)_triangleCount;
    hash = hash * 31u + (uint32_t)_transformationMatrixBuffer.bufferAddress;
    hash = hash * 31u + (uint32_t)_transformationMatrixBuffer.length;
    hash = hash * 31u + (uint32_t)_transformationMatrixLayout;
    return hash;
}

- (id)copyWithZone:(NSZone *)zone
{
    MTL4AccelerationStructureTriangleGeometryDescriptor *copy = [[MTL4AccelerationStructureTriangleGeometryDescriptor alloc] init];
    copy.intersectionFunctionTableOffset = self.intersectionFunctionTableOffset;
    copy.opaque = self.opaque;
    copy.allowDuplicateIntersectionFunctionInvocation = self.allowDuplicateIntersectionFunctionInvocation;
    copy.label = self.label;
    copy.primitiveDataBuffer = self.primitiveDataBuffer;
    copy.primitiveDataStride = self.primitiveDataStride;
    copy.primitiveDataElementSize = self.primitiveDataElementSize;
    copy.vertexBuffer = self.vertexBuffer;
    copy.vertexFormat = self.vertexFormat;
    copy.vertexStride = self.vertexStride;
    copy.indexBuffer = self.indexBuffer;
    copy.indexType = self.indexType;
    copy.triangleCount = self.triangleCount;
    copy.transformationMatrixBuffer = self.transformationMatrixBuffer;
    copy.transformationMatrixLayout = self.transformationMatrixLayout;
    return copy;
}

@end

@implementation MTL4AccelerationStructureBoundingBoxGeometryDescriptor {
    MTL4BufferRange _boundingBoxBuffer;
    NSUInteger _boundingBoxStride;
    NSUInteger _boundingBoxCount;
}

@synthesize boundingBoxBuffer = _boundingBoxBuffer;
@synthesize boundingBoxStride = _boundingBoxStride;
@synthesize boundingBoxCount = _boundingBoxCount;

- (instancetype)init
{
    if ((self = [super init]))
        _boundingBoxStride = 24;
    return self;
}

- (BOOL)isEqual:(id)object
{
    if (self == object) return YES;
    if (![object isKindOfClass:[MTL4AccelerationStructureBoundingBoxGeometryDescriptor class]]) return NO;
    if (!RevenantMetal4GeometryBaseEqual(self, object)) return NO;
    if (_boundingBoxBuffer.bufferAddress != ((MTL4AccelerationStructureBoundingBoxGeometryDescriptor *)object).boundingBoxBuffer.bufferAddress) return NO;
    if (_boundingBoxBuffer.length != ((MTL4AccelerationStructureBoundingBoxGeometryDescriptor *)object).boundingBoxBuffer.length) return NO;
    if (_boundingBoxStride != ((MTL4AccelerationStructureBoundingBoxGeometryDescriptor *)object).boundingBoxStride) return NO;
    if (_boundingBoxCount != ((MTL4AccelerationStructureBoundingBoxGeometryDescriptor *)object).boundingBoxCount) return NO;
    return YES;
}

- (NSUInteger)hash
{
    NSUInteger hash = RevenantMetal4GeometryBaseHash(self);
    hash = hash * 31u + (uint32_t)_boundingBoxBuffer.bufferAddress;
    hash = hash * 31u + (uint32_t)_boundingBoxBuffer.length;
    hash = hash * 31u + (uint32_t)_boundingBoxStride;
    hash = hash * 31u + (uint32_t)_boundingBoxCount;
    return hash;
}

- (id)copyWithZone:(NSZone *)zone
{
    MTL4AccelerationStructureBoundingBoxGeometryDescriptor *copy = [[MTL4AccelerationStructureBoundingBoxGeometryDescriptor alloc] init];
    copy.intersectionFunctionTableOffset = self.intersectionFunctionTableOffset;
    copy.opaque = self.opaque;
    copy.allowDuplicateIntersectionFunctionInvocation = self.allowDuplicateIntersectionFunctionInvocation;
    copy.label = self.label;
    copy.primitiveDataBuffer = self.primitiveDataBuffer;
    copy.primitiveDataStride = self.primitiveDataStride;
    copy.primitiveDataElementSize = self.primitiveDataElementSize;
    copy.boundingBoxBuffer = self.boundingBoxBuffer;
    copy.boundingBoxStride = self.boundingBoxStride;
    copy.boundingBoxCount = self.boundingBoxCount;
    return copy;
}

@end

@implementation MTL4AccelerationStructureCurveGeometryDescriptor {
    MTL4BufferRange _controlPointBuffer;
    NSUInteger _controlPointCount;
    NSUInteger _controlPointStride;
    MTLAttributeFormat _controlPointFormat;
    MTL4BufferRange _radiusBuffer;
    MTLAttributeFormat _radiusFormat;
    NSUInteger _radiusStride;
    MTL4BufferRange _indexBuffer;
    MTLIndexType _indexType;
    NSUInteger _segmentCount;
    NSUInteger _segmentControlPointCount;
    MTLCurveType _curveType;
    MTLCurveBasis _curveBasis;
    MTLCurveEndCaps _curveEndCaps;
}

@synthesize controlPointBuffer = _controlPointBuffer;
@synthesize controlPointCount = _controlPointCount;
@synthesize controlPointStride = _controlPointStride;
@synthesize controlPointFormat = _controlPointFormat;
@synthesize radiusBuffer = _radiusBuffer;
@synthesize radiusFormat = _radiusFormat;
@synthesize radiusStride = _radiusStride;
@synthesize indexBuffer = _indexBuffer;
@synthesize indexType = _indexType;
@synthesize segmentCount = _segmentCount;
@synthesize segmentControlPointCount = _segmentControlPointCount;
@synthesize curveType = _curveType;
@synthesize curveBasis = _curveBasis;
@synthesize curveEndCaps = _curveEndCaps;

- (instancetype)init
{
    if ((self = [super init])) {
        _controlPointFormat = (MTLAttributeFormat)RevenantMetal4Float3;
        _radiusFormat = (MTLAttributeFormat)RevenantMetal4Float1;
    }
    return self;
}

- (BOOL)isEqual:(id)object
{
    if (self == object) return YES;
    if (![object isKindOfClass:[MTL4AccelerationStructureCurveGeometryDescriptor class]]) return NO;
    if (!RevenantMetal4GeometryBaseEqual(self, object)) return NO;
    MTL4AccelerationStructureCurveGeometryDescriptor *theirs = object;
#define RevenantMetal4SameRange(field) \
    if (_##field.bufferAddress != theirs.field.bufferAddress) return NO; \
    if (_##field.length != theirs.field.length) return NO;
#define RevenantMetal4Same(field) if (_##field != theirs.field) return NO;
    RevenantMetal4SameRange(controlPointBuffer)
    RevenantMetal4Same(controlPointCount)
    RevenantMetal4Same(controlPointStride)
    RevenantMetal4Same(controlPointFormat)
    RevenantMetal4SameRange(radiusBuffer)
    RevenantMetal4Same(radiusFormat)
    RevenantMetal4Same(radiusStride)
    RevenantMetal4SameRange(indexBuffer)
    RevenantMetal4Same(indexType)
    RevenantMetal4Same(segmentCount)
    RevenantMetal4Same(segmentControlPointCount)
    RevenantMetal4Same(curveType)
    RevenantMetal4Same(curveBasis)
    RevenantMetal4Same(curveEndCaps)
#undef RevenantMetal4SameRange
#undef RevenantMetal4Same
    return YES;
}

- (NSUInteger)hash
{
    NSUInteger hash = RevenantMetal4GeometryBaseHash(self);
#define RevenantMetal4HashRange(field) \
    hash = hash * 31u + (uint32_t)_##field.bufferAddress; hash = hash * 31u + (uint32_t)_##field.length;
#define RevenantMetal4Hash(field) hash = hash * 31u + (uint32_t)_##field;
    RevenantMetal4HashRange(controlPointBuffer)
    RevenantMetal4Hash(controlPointCount)
    RevenantMetal4Hash(controlPointStride)
    RevenantMetal4Hash(controlPointFormat)
    RevenantMetal4HashRange(radiusBuffer)
    RevenantMetal4Hash(radiusFormat)
    RevenantMetal4Hash(radiusStride)
    RevenantMetal4HashRange(indexBuffer)
    RevenantMetal4Hash(indexType)
    RevenantMetal4Hash(segmentCount)
    RevenantMetal4Hash(segmentControlPointCount)
    RevenantMetal4Hash(curveType)
    RevenantMetal4Hash(curveBasis)
    RevenantMetal4Hash(curveEndCaps)
#undef RevenantMetal4HashRange
#undef RevenantMetal4Hash
    return hash;
}

- (id)copyWithZone:(NSZone *)zone
{
    MTL4AccelerationStructureCurveGeometryDescriptor *copy = [[MTL4AccelerationStructureCurveGeometryDescriptor alloc] init];
    copy.intersectionFunctionTableOffset = self.intersectionFunctionTableOffset;
    copy.opaque = self.opaque;
    copy.allowDuplicateIntersectionFunctionInvocation = self.allowDuplicateIntersectionFunctionInvocation;
    copy.label = self.label;
    copy.primitiveDataBuffer = self.primitiveDataBuffer;
    copy.primitiveDataStride = self.primitiveDataStride;
    copy.primitiveDataElementSize = self.primitiveDataElementSize;
    copy.controlPointBuffer = self.controlPointBuffer;
    copy.controlPointCount = self.controlPointCount;
    copy.controlPointStride = self.controlPointStride;
    copy.controlPointFormat = self.controlPointFormat;
    copy.radiusBuffer = self.radiusBuffer;
    copy.radiusFormat = self.radiusFormat;
    copy.radiusStride = self.radiusStride;
    copy.indexBuffer = self.indexBuffer;
    copy.indexType = self.indexType;
    copy.segmentCount = self.segmentCount;
    copy.segmentControlPointCount = self.segmentControlPointCount;
    copy.curveType = self.curveType;
    copy.curveBasis = self.curveBasis;
    copy.curveEndCaps = self.curveEndCaps;
    return copy;
}

@end

@implementation MTL4AccelerationStructureMotionTriangleGeometryDescriptor {
    MTL4BufferRange _vertexBuffers;
    MTLAttributeFormat _vertexFormat;
    NSUInteger _vertexStride;
    MTL4BufferRange _indexBuffer;
    MTLIndexType _indexType;
    NSUInteger _triangleCount;
    MTL4BufferRange _transformationMatrixBuffer;
    MTLMatrixLayout _transformationMatrixLayout;
}

@synthesize vertexBuffers = _vertexBuffers;
@synthesize vertexFormat = _vertexFormat;
@synthesize vertexStride = _vertexStride;
@synthesize indexBuffer = _indexBuffer;
@synthesize indexType = _indexType;
@synthesize triangleCount = _triangleCount;
@synthesize transformationMatrixBuffer = _transformationMatrixBuffer;
@synthesize transformationMatrixLayout = _transformationMatrixLayout;

- (instancetype)init
{
    if ((self = [super init])) {
        _vertexFormat = (MTLAttributeFormat)RevenantMetal4Float3;
        _indexType = MTLIndexTypeUInt32;
    }
    return self;
}

- (BOOL)isEqual:(id)object
{
    if (self == object) return YES;
    if (![object isKindOfClass:[MTL4AccelerationStructureMotionTriangleGeometryDescriptor class]]) return NO;
    if (!RevenantMetal4GeometryBaseEqual(self, object)) return NO;
    MTL4AccelerationStructureMotionTriangleGeometryDescriptor *theirs = object;
    if (_vertexBuffers.bufferAddress != theirs.vertexBuffers.bufferAddress) return NO;
    if (_vertexBuffers.length != theirs.vertexBuffers.length) return NO;
    if (_vertexFormat != theirs.vertexFormat) return NO;
    if (_vertexStride != theirs.vertexStride) return NO;
    if (_indexBuffer.bufferAddress != theirs.indexBuffer.bufferAddress) return NO;
    if (_indexBuffer.length != theirs.indexBuffer.length) return NO;
    if (_indexType != theirs.indexType) return NO;
    if (_triangleCount != theirs.triangleCount) return NO;
    if (_transformationMatrixBuffer.bufferAddress != theirs.transformationMatrixBuffer.bufferAddress) return NO;
    if (_transformationMatrixBuffer.length != theirs.transformationMatrixBuffer.length) return NO;
    if (_transformationMatrixLayout != theirs.transformationMatrixLayout) return NO;
    return YES;
}

- (NSUInteger)hash
{
    NSUInteger hash = RevenantMetal4GeometryBaseHash(self);
    hash = hash * 31u + (uint32_t)_vertexBuffers.bufferAddress;
    hash = hash * 31u + (uint32_t)_vertexBuffers.length;
    hash = hash * 31u + (uint32_t)_vertexFormat;
    hash = hash * 31u + (uint32_t)_vertexStride;
    hash = hash * 31u + (uint32_t)_indexBuffer.bufferAddress;
    hash = hash * 31u + (uint32_t)_indexBuffer.length;
    hash = hash * 31u + (uint32_t)_indexType;
    hash = hash * 31u + (uint32_t)_triangleCount;
    hash = hash * 31u + (uint32_t)_transformationMatrixBuffer.bufferAddress;
    hash = hash * 31u + (uint32_t)_transformationMatrixBuffer.length;
    hash = hash * 31u + (uint32_t)_transformationMatrixLayout;
    return hash;
}

- (id)copyWithZone:(NSZone *)zone
{
    MTL4AccelerationStructureMotionTriangleGeometryDescriptor *copy = [[MTL4AccelerationStructureMotionTriangleGeometryDescriptor alloc] init];
    copy.intersectionFunctionTableOffset = self.intersectionFunctionTableOffset;
    copy.opaque = self.opaque;
    copy.allowDuplicateIntersectionFunctionInvocation = self.allowDuplicateIntersectionFunctionInvocation;
    copy.label = self.label;
    copy.primitiveDataBuffer = self.primitiveDataBuffer;
    copy.primitiveDataStride = self.primitiveDataStride;
    copy.primitiveDataElementSize = self.primitiveDataElementSize;
    copy.vertexBuffers = self.vertexBuffers;
    copy.vertexFormat = self.vertexFormat;
    copy.vertexStride = self.vertexStride;
    copy.indexBuffer = self.indexBuffer;
    copy.indexType = self.indexType;
    copy.triangleCount = self.triangleCount;
    copy.transformationMatrixBuffer = self.transformationMatrixBuffer;
    copy.transformationMatrixLayout = self.transformationMatrixLayout;
    return copy;
}

@end

@implementation MTL4AccelerationStructureMotionBoundingBoxGeometryDescriptor {
    MTL4BufferRange _boundingBoxBuffers;
    NSUInteger _boundingBoxStride;
    NSUInteger _boundingBoxCount;
}

@synthesize boundingBoxBuffers = _boundingBoxBuffers;
@synthesize boundingBoxStride = _boundingBoxStride;
@synthesize boundingBoxCount = _boundingBoxCount;

- (instancetype)init
{
    if ((self = [super init]))
        _boundingBoxStride = 24;
    return self;
}

- (BOOL)isEqual:(id)object
{
    if (self == object) return YES;
    if (![object isKindOfClass:[MTL4AccelerationStructureMotionBoundingBoxGeometryDescriptor class]]) return NO;
    if (!RevenantMetal4GeometryBaseEqual(self, object)) return NO;
    MTL4AccelerationStructureMotionBoundingBoxGeometryDescriptor *theirs = object;
    if (_boundingBoxBuffers.bufferAddress != theirs.boundingBoxBuffers.bufferAddress) return NO;
    if (_boundingBoxBuffers.length != theirs.boundingBoxBuffers.length) return NO;
    if (_boundingBoxStride != theirs.boundingBoxStride) return NO;
    if (_boundingBoxCount != theirs.boundingBoxCount) return NO;
    return YES;
}

- (NSUInteger)hash
{
    NSUInteger hash = RevenantMetal4GeometryBaseHash(self);
    hash = hash * 31u + (uint32_t)_boundingBoxBuffers.bufferAddress;
    hash = hash * 31u + (uint32_t)_boundingBoxBuffers.length;
    hash = hash * 31u + (uint32_t)_boundingBoxStride;
    hash = hash * 31u + (uint32_t)_boundingBoxCount;
    return hash;
}

- (id)copyWithZone:(NSZone *)zone
{
    MTL4AccelerationStructureMotionBoundingBoxGeometryDescriptor *copy = [[MTL4AccelerationStructureMotionBoundingBoxGeometryDescriptor alloc] init];
    copy.intersectionFunctionTableOffset = self.intersectionFunctionTableOffset;
    copy.opaque = self.opaque;
    copy.allowDuplicateIntersectionFunctionInvocation = self.allowDuplicateIntersectionFunctionInvocation;
    copy.label = self.label;
    copy.primitiveDataBuffer = self.primitiveDataBuffer;
    copy.primitiveDataStride = self.primitiveDataStride;
    copy.primitiveDataElementSize = self.primitiveDataElementSize;
    copy.boundingBoxBuffers = self.boundingBoxBuffers;
    copy.boundingBoxStride = self.boundingBoxStride;
    copy.boundingBoxCount = self.boundingBoxCount;
    return copy;
}

@end

@implementation MTL4AccelerationStructureMotionCurveGeometryDescriptor {
    MTL4BufferRange _controlPointBuffers;
    NSUInteger _controlPointCount;
    NSUInteger _controlPointStride;
    MTLAttributeFormat _controlPointFormat;
    MTL4BufferRange _radiusBuffers;
    MTLAttributeFormat _radiusFormat;
    NSUInteger _radiusStride;
    MTL4BufferRange _indexBuffer;
    MTLIndexType _indexType;
    NSUInteger _segmentCount;
    NSUInteger _segmentControlPointCount;
    MTLCurveType _curveType;
    MTLCurveBasis _curveBasis;
    MTLCurveEndCaps _curveEndCaps;
}

@synthesize controlPointBuffers = _controlPointBuffers;
@synthesize controlPointCount = _controlPointCount;
@synthesize controlPointStride = _controlPointStride;
@synthesize controlPointFormat = _controlPointFormat;
@synthesize radiusBuffers = _radiusBuffers;
@synthesize radiusFormat = _radiusFormat;
@synthesize radiusStride = _radiusStride;
@synthesize indexBuffer = _indexBuffer;
@synthesize indexType = _indexType;
@synthesize segmentCount = _segmentCount;
@synthesize segmentControlPointCount = _segmentControlPointCount;
@synthesize curveType = _curveType;
@synthesize curveBasis = _curveBasis;
@synthesize curveEndCaps = _curveEndCaps;

- (instancetype)init
{
    if ((self = [super init])) {
        _controlPointFormat = (MTLAttributeFormat)RevenantMetal4Float3;
        _radiusFormat = (MTLAttributeFormat)RevenantMetal4Float1;
    }
    return self;
}

- (BOOL)isEqual:(id)object
{
    if (self == object) return YES;
    if (![object isKindOfClass:[MTL4AccelerationStructureMotionCurveGeometryDescriptor class]]) return NO;
    if (!RevenantMetal4GeometryBaseEqual(self, object)) return NO;
    MTL4AccelerationStructureMotionCurveGeometryDescriptor *theirs = object;
#define RevenantMetal4SameRange(field) \
    if (_##field.bufferAddress != theirs.field.bufferAddress) return NO; \
    if (_##field.length != theirs.field.length) return NO;
#define RevenantMetal4Same(field) if (_##field != theirs.field) return NO;
    RevenantMetal4SameRange(controlPointBuffers)
    RevenantMetal4Same(controlPointCount)
    RevenantMetal4Same(controlPointStride)
    RevenantMetal4Same(controlPointFormat)
    RevenantMetal4SameRange(radiusBuffers)
    RevenantMetal4Same(radiusFormat)
    RevenantMetal4Same(radiusStride)
    RevenantMetal4SameRange(indexBuffer)
    RevenantMetal4Same(indexType)
    RevenantMetal4Same(segmentCount)
    RevenantMetal4Same(segmentControlPointCount)
    RevenantMetal4Same(curveType)
    RevenantMetal4Same(curveBasis)
    RevenantMetal4Same(curveEndCaps)
#undef RevenantMetal4SameRange
#undef RevenantMetal4Same
    return YES;
}

- (NSUInteger)hash
{
    NSUInteger hash = RevenantMetal4GeometryBaseHash(self);
#define RevenantMetal4HashRange(field) \
    hash = hash * 31u + (uint32_t)_##field.bufferAddress; hash = hash * 31u + (uint32_t)_##field.length;
#define RevenantMetal4Hash(field) hash = hash * 31u + (uint32_t)_##field;
    RevenantMetal4HashRange(controlPointBuffers)
    RevenantMetal4Hash(controlPointCount)
    RevenantMetal4Hash(controlPointStride)
    RevenantMetal4Hash(controlPointFormat)
    RevenantMetal4HashRange(radiusBuffers)
    RevenantMetal4Hash(radiusFormat)
    RevenantMetal4Hash(radiusStride)
    RevenantMetal4HashRange(indexBuffer)
    RevenantMetal4Hash(indexType)
    RevenantMetal4Hash(segmentCount)
    RevenantMetal4Hash(segmentControlPointCount)
    RevenantMetal4Hash(curveType)
    RevenantMetal4Hash(curveBasis)
    RevenantMetal4Hash(curveEndCaps)
#undef RevenantMetal4HashRange
#undef RevenantMetal4Hash
    return hash;
}

- (id)copyWithZone:(NSZone *)zone
{
    MTL4AccelerationStructureMotionCurveGeometryDescriptor *copy = [[MTL4AccelerationStructureMotionCurveGeometryDescriptor alloc] init];
    copy.intersectionFunctionTableOffset = self.intersectionFunctionTableOffset;
    copy.opaque = self.opaque;
    copy.allowDuplicateIntersectionFunctionInvocation = self.allowDuplicateIntersectionFunctionInvocation;
    copy.label = self.label;
    copy.primitiveDataBuffer = self.primitiveDataBuffer;
    copy.primitiveDataStride = self.primitiveDataStride;
    copy.primitiveDataElementSize = self.primitiveDataElementSize;
    copy.controlPointBuffers = self.controlPointBuffers;
    copy.controlPointCount = self.controlPointCount;
    copy.controlPointStride = self.controlPointStride;
    copy.controlPointFormat = self.controlPointFormat;
    copy.radiusBuffers = self.radiusBuffers;
    copy.radiusFormat = self.radiusFormat;
    copy.radiusStride = self.radiusStride;
    copy.indexBuffer = self.indexBuffer;
    copy.indexType = self.indexType;
    copy.segmentCount = self.segmentCount;
    copy.segmentControlPointCount = self.segmentControlPointCount;
    copy.curveType = self.curveType;
    copy.curveBasis = self.curveBasis;
    copy.curveEndCaps = self.curveEndCaps;
    return copy;
}

@end
