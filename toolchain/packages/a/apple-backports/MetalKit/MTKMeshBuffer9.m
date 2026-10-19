#import <MetalKit/MetalKit.h>
#import <Metal/Metal.h>
#import <ModelIO/ModelIO.h>

#include <string.h>

@interface MTKMeshBuffer (RevenantAllocator)
- (instancetype)initWithBuffer:(id<MTLBuffer>)buffer
                        offset:(NSUInteger)offset
                        length:(NSUInteger)length
                         zone:(id<MDLMeshBufferZone>)zone
                         type:(MDLMeshBufferType)type
                    allocator:(MTKMeshBufferAllocator *)allocator;
@end

@interface MTKMeshBufferZone : NSObject <MDLMeshBufferZone>
{
    id<MTLBuffer> _revenantBuffer;
    NSUInteger _revenantCapacity;
    NSUInteger _revenantUsed;
    MTKMeshBufferAllocator *_revenantAllocator;
}
@property (nonatomic, readonly) id<MTLBuffer> buffer;
@property (nonatomic, readonly) NSUInteger capacity;
@property (nonatomic, readonly) NSUInteger used;
- (MTKMeshBufferAllocator *)allocator;
- (instancetype)initWithBuffer:(id<MTLBuffer>)buffer capacity:(NSUInteger)capacity allocator:(MTKMeshBufferAllocator *)allocator;
- (id<MDLMeshBuffer>)revenantBufferTakingLength:(NSUInteger)length type:(MDLMeshBufferType)type;
@end

@implementation MTKMeshBufferZone

- (id<MTLBuffer>)buffer
{
    return _revenantBuffer;
}

- (NSUInteger)capacity
{
    return _revenantCapacity;
}

- (NSUInteger)used
{
    return _revenantUsed;
}

- (MTKMeshBufferAllocator *)allocator
{
    return _revenantAllocator;
}

- (instancetype)initWithBuffer:(id<MTLBuffer>)buffer capacity:(NSUInteger)capacity allocator:(MTKMeshBufferAllocator *)allocator
{
    if ((self = [super init])) {
        _revenantBuffer = buffer;
        _revenantCapacity = capacity;
        _revenantUsed = 0;
        _revenantAllocator = allocator;
    }
    return self;
}

- (id<MDLMeshBuffer>)revenantBufferTakingLength:(NSUInteger)length type:(MDLMeshBufferType)type
{
    NSUInteger offset = _revenantUsed;
    _revenantUsed += length;
    return [[MTKMeshBuffer alloc] initWithBuffer:_revenantBuffer
                                         offset:offset
                                         length:length
                                           zone:self
                                           type:type
                                      allocator:_revenantAllocator];
}

@end

@implementation MTKMeshBufferAllocator
{
    id<MTLDevice> _revenantDevice;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device
{
    if ((self = [super init]))
        _revenantDevice = device;
    return self;
}

- (id<MTLDevice>)device
{
    return _revenantDevice;
}

- (id<MDLMeshBufferZone>)newZone:(NSUInteger)capacity
{
    id<MTLBuffer> buffer = [_revenantDevice newBufferWithLength:capacity options:0];
    if (!buffer)
        return nil;
    return [[MTKMeshBufferZone alloc] initWithBuffer:buffer capacity:capacity allocator:self];
}

- (id<MDLMeshBufferZone>)newZoneForBuffersWithSize:(NSArray<NSNumber *> *)sizes andType:(NSArray<NSNumber *> *)types
{
    NSUInteger capacity = 0;
    for (NSNumber *size in sizes)
        capacity += size.unsignedIntegerValue;
    (void)types;
    return [self newZone:capacity];
}

- (id<MDLMeshBuffer>)newBuffer:(NSUInteger)length type:(MDLMeshBufferType)type
{
    return [self newBufferFromZone:nil length:length type:type];
}

- (id<MDLMeshBuffer>)newBufferWithData:(NSData *)data type:(MDLMeshBufferType)type
{
    return [self newBufferFromZone:nil data:data type:type];
}

- (id<MDLMeshBuffer>)newBufferFromZone:(id<MDLMeshBufferZone>)zone length:(NSUInteger)length type:(MDLMeshBufferType)type
{
    if (!zone) {
        zone = [self newZone:length];
        if (!zone)
            return nil;
        return [(MTKMeshBufferZone *)zone revenantBufferTakingLength:length type:type];
    }
    MTKMeshBufferZone *own = (MTKMeshBufferZone *)zone;
    if (own.used + length > own.capacity)
        return nil;
    return [own revenantBufferTakingLength:length type:type];
}

- (id<MDLMeshBuffer>)newBufferFromZone:(id<MDLMeshBufferZone>)zone data:(NSData *)data type:(MDLMeshBufferType)type
{
    MTKMeshBuffer *buffer = (MTKMeshBuffer *)[self newBufferFromZone:zone length:data.length type:type];
    if (buffer && data.length) {
        void *contents = [buffer.buffer contents];
        if (contents)
            memcpy((uint8_t *)contents + buffer.offset, data.bytes, data.length);
    }
    return buffer;
}

@end

@implementation MTKMeshBuffer
{
    id<MTLBuffer> _revenantBuffer;
    MTKMeshBufferAllocator *_revenantAllocator;
    id<MDLMeshBufferZone> _revenantZone;
    NSUInteger _revenantOffset;
    NSUInteger _revenantLength;
    MDLMeshBufferType _revenantType;
}

- (instancetype)initWithBuffer:(id<MTLBuffer>)buffer
                        offset:(NSUInteger)offset
                        length:(NSUInteger)length
                         zone:(id<MDLMeshBufferZone>)zone
                         type:(MDLMeshBufferType)type
                    allocator:(MTKMeshBufferAllocator *)allocator
{
    if ((self = [super init])) {
        _revenantBuffer = buffer;
        _revenantOffset = offset;
        _revenantLength = length;
        _revenantZone = zone;
        _revenantType = type;
        _revenantAllocator = allocator;
    }
    return self;
}

- (NSUInteger)length
{
    return _revenantLength;
}

- (MTKMeshBufferAllocator *)allocator
{
    return _revenantAllocator;
}

- (id<MDLMeshBufferZone>)zone
{
    return _revenantZone;
}

- (id<MTLBuffer>)buffer
{
    return _revenantBuffer;
}

- (NSUInteger)offset
{
    return _revenantOffset;
}

- (MDLMeshBufferType)type
{
    return _revenantType;
}

- (NSString *)name
{
    return @"";
}

- (void)setName:(NSString *)name
{
    (void)name;
}

- (void)fillData:(NSData *)data offset:(NSUInteger)offset
{
    void *contents = [_revenantBuffer contents];
    if (!contents || !data.length)
        return;
    NSUInteger room = _revenantLength > offset ? _revenantLength - offset : 0;
    memcpy((uint8_t *)contents + _revenantOffset + offset, data.bytes, MIN(room, data.length));
}

- (MDLMeshBufferMap *)map
{
    void *contents = [_revenantBuffer contents];
    return [[MDLMeshBufferMap alloc] initWithBytes:contents ? (uint8_t *)contents + _revenantOffset : NULL
                                            deallocator:nil];
}

- (id)copyWithZone:(NSZone *)zone
{
    (void)zone;
    return [[MTKMeshBuffer alloc] initWithBuffer:_revenantBuffer
                                         offset:_revenantOffset
                                         length:_revenantLength
                                           zone:_revenantZone
                                           type:_revenantType
                                      allocator:_revenantAllocator];
}

@end

@implementation MTKSubmesh
{
    MTKMesh *_revenantMesh;
    NSUInteger _revenantIndex;
    NSUInteger _revenantVertexStart;
    NSUInteger _revenantVertexCount;
    NSUInteger _revenantIndexStart;
    NSUInteger _revenantIndexCount;
    MTLIndexType _revenantIndexType;
    MTLPrimitiveType _revenantPrimitiveType;
}

- (instancetype)initWithMesh:(MTKMesh *)mesh
                   submesh:(NSUInteger)submesh
               vertexStart:(NSUInteger)vertexStart
               vertexCount:(NSUInteger)vertexCount
                indexStart:(NSUInteger)indexStart
                indexCount:(NSUInteger)indexCount
                  indexType:(MTLIndexType)indexType
              primitiveType:(MTLPrimitiveType)primitiveType
{
    if ((self = [super init])) {
        _revenantMesh = mesh;
        _revenantIndex = submesh;
        _revenantVertexStart = vertexStart;
        _revenantVertexCount = vertexCount;
        _revenantIndexStart = indexStart;
        _revenantIndexCount = indexCount;
        _revenantIndexType = indexType;
        _revenantPrimitiveType = primitiveType;
    }
    return self;
}

- (MTKMesh *)mesh
{
    return _revenantMesh;
}

- (NSUInteger)submeshIndex
{
    return _revenantIndex;
}

- (NSUInteger)vertexStart
{
    return _revenantVertexStart;
}

- (NSUInteger)vertexCount
{
    return _revenantVertexCount;
}

- (NSUInteger)indexStart
{
    return _revenantIndexStart;
}

- (NSUInteger)indexCount
{
    return _revenantIndexCount;
}

- (MTLIndexType)indexType
{
    return _revenantIndexType;
}

- (MTLPrimitiveType)primitiveType
{
    return _revenantPrimitiveType;
}

@end
