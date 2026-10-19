#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <objc/runtime.h>
#import "CharonMetal26Types.h"

// THE ACCELERATION STRUCTURE GEOMETRY DESCRIPTORS of Metal 4, and they are the same kind of thing as
// the sixteen classes in MTL4Descriptors26.m: plain data holders that say what a geometry is built FROM
// and ask the device nothing.
//
// EVERY DEFAULT BELOW IS APPLE'S OWN, measured against a fresh object of Apple's class, and two of them
// are the ones a guess gets wrong:
//
//   * the base's allowDuplicateIntersectionFunctionInvocation is YES on a fresh object, not NO;
//   * the triangle's vertexFormat is MTLVertexFormatFloat3 - the enumeration's 30 - and the curve's
//     controlPointFormat is the same 30 while its radiusFormat is 28, MTLVertexFormatFloat, ONE component;
//   * a triangle's indexType is MTLIndexTypeUInt32, the enumeration's 1, not its own zero;
//   * a bounding box's stride is 24 and not 0.
//
// The measurement is tests/backports/host/metal-census/descriptors26.sh, which asks both sides.
//
// WHAT A RAY TRACING UNIT WOULD DO WITH ONE OF THESE IS NOT HERE, and that is the same half
// facts/Metal/Metal16Absence.md records for the 16.0 family: this port vends no acceleration structure
// and no ray tracing unit, so an application that fills one gets an object it can read, copy and
// compare - and no object to hand it to. facts/Metal/Descriptors26.md carries that forward and every
// row's `effect` says it.

// THE BASE'S SEVEN MEMBERS, compared by every subclass as well, because a subclass's value is its
// shape AND what it inherits. A helper that emits the comparison keeps the seven in one place: a
// subclass that spelled them out would be seven places to forget one, and a forgotten member is an
// equality that says two different geometries are the same.
static BOOL CharonMetal4GeometryBaseEqual(MTL4AccelerationStructureGeometryDescriptor *mine,
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

static NSUInteger CharonMetal4GeometryBaseHash(MTL4AccelerationStructureGeometryDescriptor *mine)
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

// Two of these are Apple's own and not this file's choice: the duplicate-invocation flag is YES on a
// fresh object, and the primitive data range is {0, 0} - not (uint64_t)-1, which the header says means
// "to the end of the buffer".
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
    return CharonMetal4GeometryBaseEqual(self, object);
}

- (NSUInteger)hash
{
    return CharonMetal4GeometryBaseHash(self);
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

// THE SIX SHAPES, and each one's own members over the base's seven. The three motion ones are the same
// shapes with a second buffer per vertex, because a moving vertex has a position and a velocity; the
// header spells that with a plural and this file keeps the spelling.

// THE TWO FORMATS, by the enumeration's own values, and the second one is the case a reader would not
// guess: the fresh triangle and the fresh curve's CONTROL POINT read 30, which is MTLVertexFormatFloat3
// - a position - and the fresh curve's RADIUS reads 28, which is MTLVertexFormatFloat, ONE component,
// because a radius is one number. (It is not 29, MTLVertexFormatFloat2: the differential's first
// assertion for it said Float2 and was wrong, and the measurement corrected the assertion.)
enum { CharonMetal4Float3 = 30, CharonMetal4Float1 = 28 };

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

// MTLVertexFormatFloat3 and MTLIndexTypeUInt32 are Apple's own fresh values, measured.
- (instancetype)init
{
    if ((self = [super init])) {
        _vertexFormat = (MTLAttributeFormat)CharonMetal4Float3;
        _indexType = MTLIndexTypeUInt32;
    }
    return self;
}

- (BOOL)isEqual:(id)object
{
    if (self == object) return YES;
    if (![object isKindOfClass:[MTL4AccelerationStructureTriangleGeometryDescriptor class]]) return NO;
    if (!CharonMetal4GeometryBaseEqual(self, object)) return NO;
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
    NSUInteger hash = CharonMetal4GeometryBaseHash(self);
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

// 24 is Apple's own fresh stride, measured - a bounding box is three float32s, which is what the
// number is, and a zero here would be a geometry of no boxes.
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
    if (!CharonMetal4GeometryBaseEqual(self, object)) return NO;
    if (_boundingBoxBuffer.bufferAddress != ((MTL4AccelerationStructureBoundingBoxGeometryDescriptor *)object).boundingBoxBuffer.bufferAddress) return NO;
    if (_boundingBoxBuffer.length != ((MTL4AccelerationStructureBoundingBoxGeometryDescriptor *)object).boundingBoxBuffer.length) return NO;
    if (_boundingBoxStride != ((MTL4AccelerationStructureBoundingBoxGeometryDescriptor *)object).boundingBoxStride) return NO;
    if (_boundingBoxCount != ((MTL4AccelerationStructureBoundingBoxGeometryDescriptor *)object).boundingBoxCount) return NO;
    return YES;
}

- (NSUInteger)hash
{
    NSUInteger hash = CharonMetal4GeometryBaseHash(self);
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

// THE CURVE, which is the biggest of the six: fourteen members over the base's seven, and the three
// curve enumerations are this port's own transcription in CharonMetal26Types.h.
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

// The two formats are Apple's own and they are not the same: a control point is a float3 and a radius
// is a float, measured.
- (instancetype)init
{
    if ((self = [super init])) {
        _controlPointFormat = (MTLAttributeFormat)CharonMetal4Float3;
        _radiusFormat = (MTLAttributeFormat)CharonMetal4Float1;
    }
    return self;
}

- (BOOL)isEqual:(id)object
{
    if (self == object) return YES;
    if (![object isKindOfClass:[MTL4AccelerationStructureCurveGeometryDescriptor class]]) return NO;
    if (!CharonMetal4GeometryBaseEqual(self, object)) return NO;
    MTL4AccelerationStructureCurveGeometryDescriptor *theirs = object;
#define CharonMetal4SameRange(field) \
    if (_##field.bufferAddress != theirs.field.bufferAddress) return NO; \
    if (_##field.length != theirs.field.length) return NO;
#define CharonMetal4Same(field) if (_##field != theirs.field) return NO;
    CharonMetal4SameRange(controlPointBuffer)
    CharonMetal4Same(controlPointCount)
    CharonMetal4Same(controlPointStride)
    CharonMetal4Same(controlPointFormat)
    CharonMetal4SameRange(radiusBuffer)
    CharonMetal4Same(radiusFormat)
    CharonMetal4Same(radiusStride)
    CharonMetal4SameRange(indexBuffer)
    CharonMetal4Same(indexType)
    CharonMetal4Same(segmentCount)
    CharonMetal4Same(segmentControlPointCount)
    CharonMetal4Same(curveType)
    CharonMetal4Same(curveBasis)
    CharonMetal4Same(curveEndCaps)
#undef CharonMetal4SameRange
#undef CharonMetal4Same
    return YES;
}

- (NSUInteger)hash
{
    NSUInteger hash = CharonMetal4GeometryBaseHash(self);
#define CharonMetal4HashRange(field) \
    hash = hash * 31u + (uint32_t)_##field.bufferAddress; hash = hash * 31u + (uint32_t)_##field.length;
#define CharonMetal4Hash(field) hash = hash * 31u + (uint32_t)_##field;
    CharonMetal4HashRange(controlPointBuffer)
    CharonMetal4Hash(controlPointCount)
    CharonMetal4Hash(controlPointStride)
    CharonMetal4Hash(controlPointFormat)
    CharonMetal4HashRange(radiusBuffer)
    CharonMetal4Hash(radiusFormat)
    CharonMetal4Hash(radiusStride)
    CharonMetal4HashRange(indexBuffer)
    CharonMetal4Hash(indexType)
    CharonMetal4Hash(segmentCount)
    CharonMetal4Hash(segmentControlPointCount)
    CharonMetal4Hash(curveType)
    CharonMetal4Hash(curveBasis)
    CharonMetal4Hash(curveEndCaps)
#undef CharonMetal4HashRange
#undef CharonMetal4Hash
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

// THE THREE MOTION ONES, which are the same shapes with a second buffer per vertex. They keep the
// header's plural spelling - vertexBuffers, boundingBoxBuffers, controlPointBuffers - and their
// defaults are their shape's own: a motion triangle's vertexFormat is float3 as a triangle's is, and
// Apple's fresh motion bounding box reads the same 24 stride.
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
        _vertexFormat = (MTLAttributeFormat)CharonMetal4Float3;
        _indexType = MTLIndexTypeUInt32;
    }
    return self;
}

- (BOOL)isEqual:(id)object
{
    if (self == object) return YES;
    if (![object isKindOfClass:[MTL4AccelerationStructureMotionTriangleGeometryDescriptor class]]) return NO;
    if (!CharonMetal4GeometryBaseEqual(self, object)) return NO;
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
    NSUInteger hash = CharonMetal4GeometryBaseHash(self);
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
    if (!CharonMetal4GeometryBaseEqual(self, object)) return NO;
    MTL4AccelerationStructureMotionBoundingBoxGeometryDescriptor *theirs = object;
    if (_boundingBoxBuffers.bufferAddress != theirs.boundingBoxBuffers.bufferAddress) return NO;
    if (_boundingBoxBuffers.length != theirs.boundingBoxBuffers.length) return NO;
    if (_boundingBoxStride != theirs.boundingBoxStride) return NO;
    if (_boundingBoxCount != theirs.boundingBoxCount) return NO;
    return YES;
}

- (NSUInteger)hash
{
    NSUInteger hash = CharonMetal4GeometryBaseHash(self);
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
        _controlPointFormat = (MTLAttributeFormat)CharonMetal4Float3;
        _radiusFormat = (MTLAttributeFormat)CharonMetal4Float1;
    }
    return self;
}

- (BOOL)isEqual:(id)object
{
    if (self == object) return YES;
    if (![object isKindOfClass:[MTL4AccelerationStructureMotionCurveGeometryDescriptor class]]) return NO;
    if (!CharonMetal4GeometryBaseEqual(self, object)) return NO;
    MTL4AccelerationStructureMotionCurveGeometryDescriptor *theirs = object;
#define CharonMetal4SameRange(field) \
    if (_##field.bufferAddress != theirs.field.bufferAddress) return NO; \
    if (_##field.length != theirs.field.length) return NO;
#define CharonMetal4Same(field) if (_##field != theirs.field) return NO;
    CharonMetal4SameRange(controlPointBuffers)
    CharonMetal4Same(controlPointCount)
    CharonMetal4Same(controlPointStride)
    CharonMetal4Same(controlPointFormat)
    CharonMetal4SameRange(radiusBuffers)
    CharonMetal4Same(radiusFormat)
    CharonMetal4Same(radiusStride)
    CharonMetal4SameRange(indexBuffer)
    CharonMetal4Same(indexType)
    CharonMetal4Same(segmentCount)
    CharonMetal4Same(segmentControlPointCount)
    CharonMetal4Same(curveType)
    CharonMetal4Same(curveBasis)
    CharonMetal4Same(curveEndCaps)
#undef CharonMetal4SameRange
#undef CharonMetal4Same
    return YES;
}

- (NSUInteger)hash
{
    NSUInteger hash = CharonMetal4GeometryBaseHash(self);
#define CharonMetal4HashRange(field) \
    hash = hash * 31u + (uint32_t)_##field.bufferAddress; hash = hash * 31u + (uint32_t)_##field.length;
#define CharonMetal4Hash(field) hash = hash * 31u + (uint32_t)_##field;
    CharonMetal4HashRange(controlPointBuffers)
    CharonMetal4Hash(controlPointCount)
    CharonMetal4Hash(controlPointStride)
    CharonMetal4Hash(controlPointFormat)
    CharonMetal4HashRange(radiusBuffers)
    CharonMetal4Hash(radiusFormat)
    CharonMetal4Hash(radiusStride)
    CharonMetal4HashRange(indexBuffer)
    CharonMetal4Hash(indexType)
    CharonMetal4Hash(segmentCount)
    CharonMetal4Hash(segmentControlPointCount)
    CharonMetal4Hash(curveType)
    CharonMetal4Hash(curveBasis)
    CharonMetal4Hash(curveEndCaps)
#undef CharonMetal4HashRange
#undef CharonMetal4Hash
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