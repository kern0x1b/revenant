#import <ModelIO/ModelIO.h>
#import <simd/simd.h>

#pragma clang diagnostic ignored "-Wobjc-missing-property-synthesis"

typedef struct {
    vector_float3 position;
    vector_float3 normal;
    vector_float2 uv;
} RevenantMDLVertex;

static NSUInteger RevenantMDLVertexComponentSize(MDLVertexFormat format)
{
    switch (format & 0xFF0000) {
        case MDLVertexFormatUCharBits:
        case MDLVertexFormatCharBits:
        case MDLVertexFormatUCharNormalizedBits:
        case MDLVertexFormatCharNormalizedBits:
            return 1;
        case MDLVertexFormatUShortBits:
        case MDLVertexFormatShortBits:
        case MDLVertexFormatUShortNormalizedBits:
        case MDLVertexFormatShortNormalizedBits:
        case MDLVertexFormatHalfBits:
            return 2;
        default:
            return 4;
    }
}

static void RevenantMDLBounds(MDLAxisAlignedBoundingBox *box, vector_float3 point)
{
    float low[3], high[3], p[3];
    low[0] = box->minBounds.x, low[1] = box->minBounds.y, low[2] = box->minBounds.z;
    high[0] = box->maxBounds.x, high[1] = box->maxBounds.y, high[2] = box->maxBounds.z;
    p[0] = point.x, p[1] = point.y, p[2] = point.z;
    box->minBounds = (vector_float3){low[0] < p[0] ? low[0] : p[0], low[1] < p[1] ? low[1] : p[1],
                                    low[2] < p[2] ? low[2] : p[2]};
    box->maxBounds = (vector_float3){high[0] > p[0] ? high[0] : p[0], high[1] > p[1] ? high[1] : p[1],
                                    high[2] > p[2] ? high[2] : p[2]};
}

@implementation MDLVertexAttributeData {
    MDLMeshBufferMap *_map;
    void *_dataStart;
    NSUInteger _stride;
    MDLVertexFormat _format;
}

@synthesize map = _map;
@synthesize dataStart = _dataStart;
@synthesize stride = _stride;
@synthesize format = _format;

- (void)dealloc
{
}

@end

@implementation MDLMesh {
    MDLVertexDescriptor *_descriptor;
    NSUInteger _vertexCount;
    NSArray<id<MDLMeshBuffer>> *_vertexBuffers;
    NSMutableArray<MDLSubmesh *> *_submeshes;
    id<MDLMeshBufferAllocator> _allocator;
}

@synthesize vertexDescriptor = _descriptor;
@synthesize vertexCount = _vertexCount;
@synthesize vertexBuffers = _vertexBuffers;
@synthesize submeshes = _submeshes;
@synthesize allocator = _allocator;

- (instancetype)initWithBufferAllocator:(id<MDLMeshBufferAllocator>)bufferAllocator
{
    if ((self = [super init])) {
        _allocator = bufferAllocator;
        _descriptor = [[MDLVertexDescriptor alloc] init];
        _vertexBuffers = [[NSArray alloc] init];
        _submeshes = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)dealloc
{
}

- (instancetype)initWithVertexBuffers:(NSArray<id<MDLMeshBuffer>> *)vertexBuffers
                          vertexCount:(NSUInteger)vertexCount
                           descriptor:(MDLVertexDescriptor *)descriptor
                            submeshes:(NSArray<MDLSubmesh *> *)submeshes
{
    if ((self = [self initWithBufferAllocator:vertexBuffers.count ? vertexBuffers[0].allocator : nil])) {
        _vertexBuffers = [vertexBuffers copy];
        _vertexCount = vertexCount;
        if (descriptor) {
            _descriptor = [descriptor copy];
        }
        [_submeshes addObjectsFromArray:submeshes ?: @[]];
    }
    return self;
}

- (instancetype)initWithVertexBuffer:(id<MDLMeshBuffer>)vertexBuffer
                         vertexCount:(NSUInteger)vertexCount
                          descriptor:(MDLVertexDescriptor *)descriptor
                           submeshes:(NSArray<MDLSubmesh *> *)submeshes
{
    return [self initWithVertexBuffers:vertexBuffer ? @[vertexBuffer] : @[] vertexCount:vertexCount descriptor:descriptor
                             submeshes:submeshes];
}

- (MDLVertexAttributeData *)vertexAttributeDataForAttributeNamed:(NSString *)name asFormat:(MDLVertexFormat)format
{
    MDLVertexAttribute *attribute = [_descriptor attributeNamed:name];
    if (!attribute || attribute.format == MDLVertexFormatInvalid)
        return nil;
    if (attribute.bufferIndex >= _vertexBuffers.count)
        return nil;
    id<MDLMeshBuffer> buffer = _vertexBuffers[attribute.bufferIndex];
    NSUInteger layoutStride = attribute.bufferIndex < _descriptor.layouts.count ? _descriptor.layouts[attribute.bufferIndex].stride : 0;
    MDLMeshBufferMap *map = [buffer map];
    uint8_t *base = map.bytes;
    if (!base)
        return nil;
    NSUInteger to = RevenantMDLVertexComponentSize(format) * (format & 0x1F);
    if (!layoutStride)
        return nil;
    MDLVertexAttributeData *data = [[MDLVertexAttributeData alloc] init];
    data.format = format;
    if (format == attribute.format) {
        data.map = map;
        data.stride = layoutStride;
        data.dataStart = base + attribute.offset;
        return data;
    }
    data.stride = to;
    NSMutableData *out = [NSMutableData dataWithLength:_vertexCount * data.stride];
    for (NSUInteger vertex = 0; vertex < _vertexCount; vertex++) {
        uint8_t *source = base + vertex * layoutStride + attribute.offset;
        uint8_t *target = out.mutableBytes + vertex * data.stride;
        for (NSUInteger component = 0; component < (attribute.format & 0x1F); component++) {
            float value = 0;
            switch (RevenantMDLVertexComponentSize(attribute.format)) {
                case 1: {
                    uint8_t raw = source[component];
                    value = (attribute.format & 0xF0000) == MDLVertexFormatUCharNormalizedBits ? raw / 255.0f : (float)raw;
                    break;
                }
                case 2: {
                    uint16_t raw = 0;
                    memcpy(&raw, source + component * 2, 2);
                    value = (attribute.format & 0xF0000) == MDLVertexFormatUShortNormalizedBits ? raw / 65535.0f : (float)raw;
                    break;
                }
                default: {
                    float raw = 0;
                    memcpy(&raw, source + component * 4, 4);
                    value = raw;
                    break;
                }
            }
            memcpy(target + component * RevenantMDLVertexComponentSize(format), &value, RevenantMDLVertexComponentSize(format));
        }
    }
    data.map = [[MDLMeshBufferMap alloc] initWithBytes:out.mutableBytes deallocator:nil];
    data.dataStart = out.mutableBytes;
    return data;
}

- (MDLVertexAttributeData *)vertexAttributeDataForAttributeNamed:(NSString *)name
{
    MDLVertexAttribute *attribute = [_descriptor attributeNamed:name];
    return [self vertexAttributeDataForAttributeNamed:name asFormat:attribute.format];
}

- (MDLAxisAlignedBoundingBox)boundingBox
{
    MDLAxisAlignedBoundingBox box = {{-INFINITY, -INFINITY, -INFINITY}, {INFINITY, INFINITY, INFINITY}};
    MDLVertexAttributeData *positions = [self vertexAttributeDataForAttributeNamed:MDLVertexAttributePosition
                                                                        asFormat:MDLVertexFormatFloat3];
    if (positions) {
        for (NSUInteger vertex = 0; vertex < _vertexCount; vertex++) {
            vector_float3 position = *(vector_float3 *)((uint8_t *)positions.dataStart + vertex * positions.stride);
            RevenantMDLBounds(&box, position);
        }
    }
    if (box.minBounds[0] > box.maxBounds[0]) {
        box.minBounds = (vector_float3){0, 0, 0};
        box.maxBounds = (vector_float3){0, 0, 0};
    }
    return box;
}

- (MDLAxisAlignedBoundingBox)boundingBoxAtTime:(NSTimeInterval)time
{
    return self.boundingBox;
}

- (void)addAttributeWithName:(NSString *)name format:(MDLVertexFormat)format
{
    MDLVertexAttribute *attribute = [[MDLVertexAttribute alloc] initWithName:name format:format offset:0 bufferIndex:0];
    [_descriptor addOrReplaceAttribute:attribute];
}

- (void)addAttributeWithName:(NSString *)name
                     format:(MDLVertexFormat)format
                       type:(NSString *)type
                       data:(NSData *)data
                     stride:(NSInteger)stride
                       time:(NSTimeInterval)time
{
    NSUInteger length = data.length;
    id<MDLMeshBuffer> buffer = [_allocator newBuffer:length type:MDLMeshBufferTypeVertex];
    if (!buffer)
        return;
    [buffer fillData:data offset:0];
    NSUInteger index = _vertexBuffers.count;
    _vertexBuffers = [_vertexBuffers arrayByAddingObject:buffer];
    if (index >= _descriptor.layouts.count)
        [self addAttributeWithName:name format:format];
    else
        _descriptor.layouts[index].stride = stride > 0 ? (NSUInteger)stride : length;
    MDLVertexAttribute *attribute = [[MDLVertexAttribute alloc] initWithName:name format:format offset:0 bufferIndex:index];
    attribute.time = time;
    [_descriptor addOrReplaceAttribute:attribute];
}

- (void)addAttributeWithName:(NSString *)name
                     format:(MDLVertexFormat)format
                       type:(NSString *)type
                       data:(NSData *)data
                     stride:(NSInteger)stride
{
    [self addAttributeWithName:name format:format type:type data:data stride:stride time:0];
}

- (void)replaceAttributeNamed:(NSString *)name withData:(MDLVertexAttributeData *)newData
{
    MDLVertexAttribute *attribute = [_descriptor attributeNamed:name];
    if (!attribute || attribute.bufferIndex >= _vertexBuffers.count)
        return;
    id<MDLMeshBuffer> buffer = _vertexBuffers[attribute.bufferIndex];
    NSMutableData *data = [NSMutableData dataWithLength:buffer.length];
    for (NSUInteger vertex = 0; vertex < _vertexCount; vertex++) {
        NSUInteger at = attribute.offset + vertex * newData.stride;
        if (at + newData.stride > data.length)
            break;
        memcpy(data.mutableBytes + at, (uint8_t *)newData.dataStart + vertex * newData.stride, newData.stride);
    }
    [buffer fillData:data offset:0];
}

- (void)updateAttributeNamed:(NSString *)name withData:(MDLVertexAttributeData *)newData
{
    MDLVertexAttribute *attribute = [_descriptor attributeNamed:name];
    if (!attribute || attribute.bufferIndex >= _vertexBuffers.count)
        return;
    id<MDLMeshBuffer> buffer = _vertexBuffers[attribute.bufferIndex];
    for (NSUInteger vertex = 0; vertex < _vertexCount; vertex++) {
        NSUInteger at = attribute.offset + vertex * newData.stride;
        if (at + newData.stride > buffer.length)
            break;
        [buffer fillData:[NSData dataWithBytes:(uint8_t *)newData.dataStart + vertex * newData.stride length:newData.stride] offset:at];
    }
}

- (void)removeAttributeNamed:(NSString *)name
{
    [_descriptor removeAttributeNamed:name];
}

@end
