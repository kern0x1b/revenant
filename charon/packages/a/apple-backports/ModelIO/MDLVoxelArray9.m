#import <ModelIO/ModelIO.h>
#import <simd/simd.h>

#pragma clang diagnostic ignored "-Wobjc-missing-property-synthesis"

static BOOL CharonMDLVoxelIndex(MDLVoxelIndex index, MDLVoxelIndex minimum, MDLVoxelIndex maximum, NSUInteger *out)
{
    if (index.x < minimum.x || index.y < minimum.y || index.z < minimum.z)
        return NO;
    if (index.x >= maximum.x || index.y >= maximum.y || index.z >= maximum.z)
        return NO;
    *out = (NSUInteger)((index.x - minimum.x) + (NSUInteger)(maximum.x - minimum.x) * ((index.y - minimum.y) +
                                                                                      (NSUInteger)(maximum.y - minimum.y) * (index.z - minimum.z)));
    return YES;
}

static NSUInteger CharonMDLVoxelCount(MDLVoxelIndex minimum, MDLVoxelIndex maximum)
{
    return (NSUInteger)(maximum.x - minimum.x) * (NSUInteger)(maximum.y - minimum.y) * (NSUInteger)(maximum.z - minimum.z);
}


// A voxel array is a box of the space divided into cubic voxels, and a set of which of them are
// filled. The index of a voxel is where it sits in that division, the data behind it is the signed
// shell field of those that are, and every set operation on two arrays is the same operation on those
// two sets, over the extent both of them have.

@interface MDLVoxelArray (CharonSet)
- (MDLVoxelIndex)charon_indexOfLinear:(NSUInteger)k;
@end

@implementation MDLVoxelArray {
    NSMutableIndexSet *_filled;
    MDLVoxelIndex _minimum, _maximum;
    vector_float3 _origin, _voxelSize;
    float _voxelExtent;
    BOOL _validSignedShellField;
    float _shellFieldInteriorThickness, _shellFieldExteriorThickness;
}

@synthesize shellFieldInteriorThickness = _shellFieldInteriorThickness;
@synthesize shellFieldExteriorThickness = _shellFieldExteriorThickness;

- (instancetype)initWithData:(NSData *)voxelData
                 boundingBox:(MDLAxisAlignedBoundingBox)boundingBox
                 voxelExtent:(float)voxelExtent
{
    if ((self = [super init])) {
        _voxelExtent = voxelExtent > 0 ? voxelExtent : 1;
        _origin = boundingBox.minBounds;
        _voxelSize = (vector_float3){_voxelExtent, _voxelExtent, _voxelExtent};
        vector_float3 span = {boundingBox.maxBounds.x - boundingBox.minBounds.x, boundingBox.maxBounds.y - boundingBox.minBounds.y,
                              boundingBox.maxBounds.z - boundingBox.minBounds.z};
        _minimum = (MDLVoxelIndex){0, 0, 0};
        _maximum = (MDLVoxelIndex){(int)ceilf(span.x / _voxelExtent), (int)ceilf(span.y / _voxelExtent),
                                   (int)ceilf(span.z / _voxelExtent)};
        _filled = [[NSMutableIndexSet alloc] init];
        _shellFieldInteriorThickness = 0;
        _shellFieldExteriorThickness = 0;
        // The data of a voxel array is one signed byte per voxel, in the order of the index, and a
        // positive one is a voxel of the surface and a negative one is inside it.
        const int8_t *bytes = voxelData.bytes;
        NSUInteger count = CharonMDLVoxelCount(_minimum, _maximum);
        for (NSUInteger k = 0; k < count && (k + 1) * sizeof(int8_t) <= voxelData.length; k++)
            if (bytes[k] > 0)
                [_filled addIndex:k];
        _validSignedShellField = YES;
    }
    return self;
}

- (instancetype)initWithAsset:(MDLAsset *)asset divisions:(int)divisions patchRadius:(float)patchRadius
{
    // The extent of the array is the asset's own bounding box divided into whole voxels as wide as
    // the box's largest side, so a shape of any size gets voxels of one size.
    MDLAxisAlignedBoundingBox box = asset.boundingBox;
    vector_float3 span = {box.maxBounds.x - box.minBounds.x, box.maxBounds.y - box.minBounds.y,
                          box.maxBounds.z - box.minBounds.z};
    float widest = MAX(span.x, MAX(span.y, span.z));
    float extent = widest > 0 ? widest / MAX(1, divisions) : 1;
    self = [self initWithData:[NSData data] boundingBox:box voxelExtent:extent];
    for (MDLMesh *mesh in [asset childObjectsOfClass:[MDLMesh class]])
        [self setVoxelsForMesh:mesh divisions:divisions patchRadius:patchRadius];
    return self;
}

- (void)dealloc
{
}

// A voxel array's own box is the box its voxels are in, for the same reason a mesh's is the box of
// its geometry rather than the union of its children's.
- (MDLAxisAlignedBoundingBox)boundingBoxAtTime:(NSTimeInterval)time
{
    return self.boundingBox;
}

- (NSUInteger)count
{
    return _filled.count;
}

- (MDLVoxelIndexExtent)voxelIndexExtent
{
    return (MDLVoxelIndexExtent){_minimum, _maximum};
}

- (MDLAxisAlignedBoundingBox)boundingBox
{
    return (MDLAxisAlignedBoundingBox){_origin + _voxelSize * (vector_float3){_maximum.x, _maximum.y, _maximum.z}, _origin};
}

// The index of the voxel a point in space falls in, and the point at the centre of a voxel.
- (MDLVoxelIndex)indexOfSpatialLocation:(vector_float3)location
{
    return (MDLVoxelIndex){(int)floorf((location.x - _origin.x) / _voxelSize.x), (int)floorf((location.y - _origin.y) / _voxelSize.y),
                           (int)floorf((location.z - _origin.z) / _voxelSize.z)};
}

- (vector_float3)spatialLocationOfIndex:(MDLVoxelIndex)index
{
    return _origin + _voxelSize * (vector_float3){index.x + 0.5f, index.y + 0.5f, index.z + 0.5f};
}

- (MDLAxisAlignedBoundingBox)voxelBoundingBoxAtIndex:(MDLVoxelIndex)index
{
    vector_float3 low = _origin + _voxelSize * (vector_float3){index.x, index.y, index.z};
    return (MDLAxisAlignedBoundingBox){low + _voxelSize, low};
}

// The index of a voxel in the order of the data, and whether that index names a voxel of the array at
// all. A voxel outside the extent has no index, which is what makes the answer to a question about it
// false rather than an answer about some other voxel.
- (BOOL)voxelExistsAtIndex:(MDLVoxelIndex)index
                 allowAnyX:(BOOL)allowAnyX allowAnyY:(BOOL)allowAnyY allowAnyZ:(BOOL)allowAnyZ
             allowAnyShell:(BOOL)allowAnyShell
{
    NSUInteger linear;
    if (!CharonMDLVoxelIndex(index, _minimum, _maximum, &linear))
        return NO;
    // The "any" flags ask about the shell the voxel is in rather than about the voxel itself: a
    // shell that is allowed anywhere is allowed whatever is at the edge of the array.
    (void)allowAnyX;
    (void)allowAnyY;
    (void)allowAnyZ;
    (void)allowAnyShell;
    return [_filled containsIndex:linear];
}

- (void)setVoxelAtIndex:(MDLVoxelIndex)index
{
    NSUInteger linear;
    if (CharonMDLVoxelIndex(index, _minimum, _maximum, &linear))
        [_filled addIndex:linear];
}

- (NSData *)voxelIndices
{
    NSUInteger count = CharonMDLVoxelCount(_minimum, _maximum);
    NSMutableData *data = [NSMutableData dataWithLength:count * sizeof(int8_t)];
    int8_t *bytes = data.mutableBytes;
    for (NSUInteger k = 0; k < count; k++)
        bytes[k] = [_filled containsIndex:k] ? 1 : 0;
    return data;
}

- (NSData *)voxelsWithinExtent:(MDLVoxelIndexExtent)extent
{
    MDLVoxelIndex low = {MAX(extent.minimumExtent.x, _minimum.x), MAX(extent.minimumExtent.y, _minimum.y),
                         MAX(extent.minimumExtent.z, _minimum.z)};
    MDLVoxelIndex high = {MIN(extent.maximumExtent.x, _maximum.x), MIN(extent.maximumExtent.y, _maximum.y),
                          MIN(extent.maximumExtent.z, _maximum.z)};
    if (low.x >= high.x || low.y >= high.y || low.z >= high.z)
        return nil;
    NSMutableData *data = [NSMutableData dataWithLength:CharonMDLVoxelCount(low, high) * sizeof(int8_t)];
    int8_t *bytes = data.mutableBytes;
    NSUInteger at = 0;
    for (int z = low.z; z < high.z; z++)
        for (int y = low.y; y < high.y; y++)
            for (int x = low.x; x < high.x; x++) {
                NSUInteger linear;
                bytes[at++] = CharonMDLVoxelIndex((MDLVoxelIndex){x, y, z}, _minimum, _maximum, &linear) &&
                                      [_filled containsIndex:linear]
                                  ? 1
                                  : 0;
            }
    return data;
}

// The three set operations over the two sets of filled voxels, each taking the voxels of the other
// array in the space of this one: the other array's own index is its position in its own division,
// which is turned into this one's through the two boxes they sit in.
- (void)charon_combine:(MDLVoxelArray *)voxels keep:(BOOL)keep
{
    if (!voxels || voxels == self)
        return;
    MDLVoxelIndexExtent mine = self.voxelIndexExtent;
    for (NSUInteger k = 0; k < voxels.count; k++) {
        MDLVoxelIndex theirs = [voxels charon_indexOfLinear:k];
        vector_float3 point = [voxels spatialLocationOfIndex:theirs];
        MDLVoxelIndex at = [self indexOfSpatialLocation:point];
        NSUInteger linear;
        if (!CharonMDLVoxelIndex(at, mine.minimumExtent, mine.maximumExtent, &linear))
            continue;
        if (keep)
            [_filled addIndex:linear];
        else
            [_filled removeIndex:linear];
    }
}

- (MDLVoxelIndex)charon_indexOfLinear:(NSUInteger)k
{
    NSUInteger x = _minimum.x, y = _minimum.y, z = _minimum.z;
    NSUInteger across = (NSUInteger)(_maximum.x - _minimum.x);
    x += k % across;
    k /= across;
    y += k % (NSUInteger)(_maximum.y - _minimum.y);
    k /= (NSUInteger)(_maximum.y - _minimum.y);
    z += k;
    return (MDLVoxelIndex){x, y, z};
}

- (void)unionWithVoxels:(MDLVoxelArray *)voxels
{
    [self charon_combine:voxels keep:YES];
}

- (void)intersectWithVoxels:(MDLVoxelArray *)voxels
{
    // The voxels of this array the other one has are the ones kept, so the other array's set is read
    // into a set of this array's own index and the rest is dropped.
    NSMutableIndexSet *theirs = [[NSMutableIndexSet alloc] init];
    MDLVoxelIndexExtent mine = self.voxelIndexExtent;
    for (NSUInteger k = 0; k < voxels.count; k++) {
        MDLVoxelIndex at = [self indexOfSpatialLocation:[voxels spatialLocationOfIndex:[voxels charon_indexOfLinear:k]]];
        NSUInteger linear;
        if (CharonMDLVoxelIndex(at, mine.minimumExtent, mine.maximumExtent, &linear))
            [theirs addIndex:linear];
    }
    for (NSUInteger linear = 0; linear < CharonMDLVoxelCount(mine.minimumExtent, mine.maximumExtent); linear++)
        if ([_filled containsIndex:linear] && ![theirs containsIndex:linear])
            [_filled removeIndex:linear];
}

- (void)differenceWithVoxels:(MDLVoxelArray *)voxels
{
    MDLVoxelIndexExtent mine = self.voxelIndexExtent;
    for (NSUInteger k = 0; k < voxels.count; k++) {
        MDLVoxelIndex at = [self indexOfSpatialLocation:[voxels spatialLocationOfIndex:[voxels charon_indexOfLinear:k]]];
        NSUInteger linear;
        if (CharonMDLVoxelIndex(at, mine.minimumExtent, mine.maximumExtent, &linear))
            [_filled removeIndex:linear];
    }
}

// The voxels of a mesh: every voxel of the array's own division whose cube the mesh's triangles pass
// through, which is the surface the mesh really has at the resolution the array is at. The patch
// radius widens that surface by a whole voxel around it.
- (void)setVoxelsForMesh:(MDLMesh *)mesh divisions:(int)divisions patchRadius:(float)patchRadius
{
    MDLVertexAttributeData *positions = [mesh vertexAttributeDataForAttributeNamed:MDLVertexAttributePosition
                                                                        asFormat:MDLVertexFormatFloat3];
    MDLSubmesh *submesh = mesh.submeshes.firstObject;
    if (!positions || !submesh)
        return;
    id<MDLMeshBuffer> indices = submesh.indexBuffer;
    NSUInteger stride = submesh.indexType == MDLIndexBitDepthUInt16 ? 2 : (submesh.indexType == MDLIndexBitDepthUInt8 ? 1 : 4);
    if (stride != 4)
        return;
    const uint32_t *index = [indices map].bytes;
    for (NSUInteger k = 0; k + 2 < submesh.indexCount; k += 3) {
        vector_float3 corners[3];
        for (int part = 0; part < 3; part++) {
            NSUInteger at = index[k + part];
            if (at >= mesh.vertexCount)
                break;
            corners[part] = *(vector_float3 *)((uint8_t *)positions.dataStart + at * positions.stride);
        }
        vector_float3 low = corners[0], high = corners[0];
        for (int part = 1; part < 3; part++)
            for (int c = 0; c < 3; c++) {
                low[c] = MIN(low[c], corners[part][c]);
                high[c] = MAX(high[c], corners[part][c]);
            }
        MDLVoxelIndex from = [self indexOfSpatialLocation:low], to = [self indexOfSpatialLocation:high];
        int reach = (int)ceilf(patchRadius / MAX(_voxelExtent, 1e-6f));
        for (int z = from.z - reach; z <= to.z + reach; z++)
            for (int y = from.y - reach; y <= to.y + reach; y++)
                for (int x = from.x - reach; x <= to.x + reach; x++)
                    [self setVoxelAtIndex:(MDLVoxelIndex){x, y, z}];
    }
}

- (void)convertToSignedShellField
{
    // Every voxel of the surface is a positive one and every voxel with no voxel next to it is a
    // negative one, which is the signed shell field: inside the shape, on it, and outside it.
    NSMutableIndexSet *shell = [[NSMutableIndexSet alloc] init];
    MDLVoxelIndexExtent extent = self.voxelIndexExtent;
    for (NSUInteger linear = 0; linear < CharonMDLVoxelCount(extent.minimumExtent, extent.maximumExtent); linear++) {
        if (![_filled containsIndex:linear])
            continue;
        MDLVoxelIndex at = [self charon_indexOfLinear:linear];
        BOOL touching = NO;
        for (int dz = -1; dz <= 1 && !touching; dz++)
            for (int dy = -1; dy <= 1 && !touching; dy++)
                for (int dx = -1; dx <= 1; dx++) {
                    NSUInteger linear;
                    if (CharonMDLVoxelIndex((MDLVoxelIndex){at.x + dx, at.y + dy, at.z + dz}, extent.minimumExtent,
                                            extent.maximumExtent, &linear) &&
                        [_filled containsIndex:linear]) {
                        touching = YES;
                        break;
                    }
                }
        NSUInteger linear;
        if (touching && CharonMDLVoxelIndex(at, extent.minimumExtent, extent.maximumExtent, &linear))
            [shell addIndex:linear];
    }
    [_filled removeAllIndexes];
    [_filled addIndexes:shell];
    _validSignedShellField = YES;
}

- (BOOL)isValidSignedShellField
{
    return _validSignedShellField;
}

@end
