#import <ModelIO/ModelIO.h>

#pragma clang diagnostic ignored "-Wobjc-missing-property-synthesis"

static NSUInteger CharonMDLIndexSize(MDLIndexBitDepth depth)
{
    switch (depth) {
        case MDLIndexBitDepthUInt8:
            return 1;
        case MDLIndexBitDepthUInt16:
            return 2;
        case MDLIndexBitDepthUInt32:
            return 4;
        default:
            return 0;
    }
}

@implementation MDLSubmesh {
    id<MDLMeshBuffer> _indexBuffer;
    NSUInteger _indexCount;
    MDLIndexBitDepth _indexType;
    MDLGeometryType _geometryType;
    MDLMaterial *_material;
    MDLSubmeshTopology *_topology;
    NSString *_name;
}

@synthesize indexBuffer = _indexBuffer;
@synthesize indexCount = _indexCount;
@synthesize indexType = _indexType;
@synthesize geometryType = _geometryType;
@synthesize material = _material;
@synthesize topology = _topology;
@synthesize name = _name;

- (instancetype)initWithName:(NSString *)name
                 indexBuffer:(id<MDLMeshBuffer>)indexBuffer
                  indexCount:(NSUInteger)indexCount
                   indexType:(MDLIndexBitDepth)indexType
                geometryType:(MDLGeometryType)geometryType
                    material:(MDLMaterial *)material
                    topology:(MDLSubmeshTopology *)topology
{
    if ((self = [super init])) {
        _name = [name copy];
        _indexBuffer = indexBuffer;
        _indexCount = indexCount;
        _indexType = indexType;
        _geometryType = geometryType;
        _material = material;
        _topology = topology;
    }
    return self;
}

- (instancetype)initWithName:(NSString *)name
                 indexBuffer:(id<MDLMeshBuffer>)indexBuffer
                  indexCount:(NSUInteger)indexCount
                   indexType:(MDLIndexBitDepth)indexType
                geometryType:(MDLGeometryType)geometryType
                    material:(MDLMaterial *)material
{
    return [self initWithName:name indexBuffer:indexBuffer indexCount:indexCount indexType:indexType geometryType:geometryType
                      material:material topology:nil];
}

- (instancetype)initWithIndexBuffer:(id<MDLMeshBuffer>)indexBuffer
                         indexCount:(NSUInteger)indexCount
                          indexType:(MDLIndexBitDepth)indexType
                       geometryType:(MDLGeometryType)geometryType
                           material:(MDLMaterial *)material
{
    return [self initWithName:@"" indexBuffer:indexBuffer indexCount:indexCount indexType:indexType geometryType:geometryType
                      material:material topology:nil];
}

- (void)dealloc
{
}

- (id<MDLMeshBuffer>)indexBufferAsIndexType:(MDLIndexBitDepth)indexType
{
    if (indexType == _indexType)
        return _indexBuffer;
    NSUInteger from = CharonMDLIndexSize(_indexType), to = CharonMDLIndexSize(indexType);
    if (!from || !to || !_indexBuffer)
        return nil;
    NSUInteger wanted = to * _indexCount;
    id<MDLMeshBuffer> buffer = [_indexBuffer.allocator newBuffer:wanted type:MDLMeshBufferTypeIndex];
    if (!buffer)
        buffer = [[MDLMeshBufferData alloc] initWithType:MDLMeshBufferTypeIndex length:wanted];
    if (!buffer)
        return nil;
    NSMutableData *out = [NSMutableData dataWithLength:wanted];
    uint8_t *source = [_indexBuffer map].bytes, *target = out.mutableBytes;
    for (NSUInteger k = 0; k < _indexCount; k++) {
        uint32_t value = 0;
        memcpy(&value, source + k * from, from);
        if (to == 2) {
            uint16_t narrow = (uint16_t)value;
            memcpy(target + k * to, &narrow, to);
        } else {
            memcpy(target + k * to, &value, to);
        }
    }
    [buffer fillData:out offset:0];
    return buffer;
}

- (instancetype)initWithMDLSubmesh:(MDLSubmesh *)submesh indexType:(MDLIndexBitDepth)indexType geometryType:(MDLGeometryType)geometryType
{
    if (!submesh)
        return nil;
    id<MDLMeshBuffer> buffer = [submesh indexBufferAsIndexType:indexType];
    if (!buffer)
        return nil;
    return [self initWithName:submesh.name indexBuffer:buffer indexCount:submesh.indexCount indexType:indexType
                   geometryType:geometryType material:submesh.material];
}

@end

@implementation MDLSubmeshTopology {
    id<MDLMeshBuffer> _faceTopology;
    NSUInteger _faceCount;
    id<MDLMeshBuffer> _vertexCreaseIndices;
    id<MDLMeshBuffer> _vertexCreases;
    NSUInteger _vertexCreaseCount;
    id<MDLMeshBuffer> _edgeCreaseIndices;
    id<MDLMeshBuffer> _edgeCreases;
    NSUInteger _edgeCreaseCount;
    id<MDLMeshBuffer> _holes;
    NSUInteger _holeCount;
}

@synthesize faceTopology = _faceTopology;
@synthesize faceCount = _faceCount;
@synthesize vertexCreaseIndices = _vertexCreaseIndices;
@synthesize vertexCreases = _vertexCreases;
@synthesize vertexCreaseCount = _vertexCreaseCount;
@synthesize edgeCreaseIndices = _edgeCreaseIndices;
@synthesize edgeCreases = _edgeCreases;
@synthesize edgeCreaseCount = _edgeCreaseCount;
@synthesize holes = _holes;
@synthesize holeCount = _holeCount;

- (instancetype)initWithSubmesh:(MDLSubmesh *)submesh
{
    if ((self = [super init])) {
        _faceTopology = submesh.indexBuffer;
        switch (submesh.geometryType) {
            case MDLGeometryTypeTriangles:
            case MDLGeometryTypeTriangleStrips:
                _faceCount = submesh.indexCount / 3;
                break;
            case MDLGeometryTypeQuads:
                _faceCount = submesh.indexCount / 4;
                break;
            case MDLGeometryTypePoints:
            case MDLGeometryTypeLines:
            case MDLGeometryTypeVariableTopology:
                _faceCount = submesh.indexCount;
                break;
        }
    }
    return self;
}

- (void)dealloc
{
}

@end
