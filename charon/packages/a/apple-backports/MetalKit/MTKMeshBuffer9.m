#import <MetalKit/MetalKit.h>
#import <Metal/Metal.h>
#import <ModelIO/ModelIO.h>

#include <string.h>

@interface MTKMeshBuffer (CharonAllocator)
- (instancetype)initWithBuffer:(id<MTLBuffer>)buffer
                        offset:(NSUInteger)offset
                        length:(NSUInteger)length
                         zone:(id<MDLMeshBufferZone>)zone
                         type:(MDLMeshBufferType)type
                    allocator:(MTKMeshBufferAllocator *)allocator;
@end

@interface MTKMeshBufferZone : NSObject <MDLMeshBufferZone>
{
    id<MTLBuffer> _charonBuffer;
    NSUInteger _charonCapacity;
    NSUInteger _charonUsed;
    MTKMeshBufferAllocator *_charonAllocator;
}
@property (nonatomic, readonly) id<MTLBuffer> buffer;
@property (nonatomic, readonly) NSUInteger capacity;
@property (nonatomic, readonly) NSUInteger used;
- (MTKMeshBufferAllocator *)allocator;
- (instancetype)initWithBuffer:(id<MTLBuffer>)buffer capacity:(NSUInteger)capacity allocator:(MTKMeshBufferAllocator *)allocator;
- (id<MDLMeshBuffer>)charonBufferTakingLength:(NSUInteger)length type:(MDLMeshBufferType)type;
@end

@implementation MTKMeshBufferZone

- (id<MTLBuffer>)buffer
{
    return _charonBuffer;
}

- (NSUInteger)capacity
{
    return _charonCapacity;
}

- (NSUInteger)used
{
    return _charonUsed;
}

- (MTKMeshBufferAllocator *)allocator
{
    return _charonAllocator;
}

- (instancetype)initWithBuffer:(id<MTLBuffer>)buffer capacity:(NSUInteger)capacity allocator:(MTKMeshBufferAllocator *)allocator
{
    if ((self = [super init])) {
        _charonBuffer = buffer;
        _charonCapacity = capacity;
        _charonUsed = 0;
        _charonAllocator = allocator;
    }
    return self;
}

- (id<MDLMeshBuffer>)charonBufferTakingLength:(NSUInteger)length type:(MDLMeshBufferType)type
{
    NSUInteger offset = _charonUsed;
    _charonUsed += length;
    return [[MTKMeshBuffer alloc] initWithBuffer:_charonBuffer
                                         offset:offset
                                         length:length
                                           zone:self
                                           type:type
                                      allocator:_charonAllocator];
}

@end

@implementation MTKMeshBufferAllocator
{
    id<MTLDevice> _charonDevice;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device
{
    if ((self = [super init]))
        _charonDevice = device;
    return self;
}

- (id<MTLDevice>)device
{
    return _charonDevice;
}

- (id<MDLMeshBufferZone>)newZone:(NSUInteger)capacity
{
    id<MTLBuffer> buffer = [_charonDevice newBufferWithLength:capacity options:0];
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
        return [(MTKMeshBufferZone *)zone charonBufferTakingLength:length type:type];
    }
    MTKMeshBufferZone *own = (MTKMeshBufferZone *)zone;
    if (own.used + length > own.capacity)
        return nil;
    return [own charonBufferTakingLength:length type:type];
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
    id<MTLBuffer> _charonBuffer;
    MTKMeshBufferAllocator *_charonAllocator;
    id<MDLMeshBufferZone> _charonZone;
    NSUInteger _charonOffset;
    NSUInteger _charonLength;
    MDLMeshBufferType _charonType;
}

- (instancetype)initWithBuffer:(id<MTLBuffer>)buffer
                        offset:(NSUInteger)offset
                        length:(NSUInteger)length
                         zone:(id<MDLMeshBufferZone>)zone
                         type:(MDLMeshBufferType)type
                    allocator:(MTKMeshBufferAllocator *)allocator
{
    if ((self = [super init])) {
        _charonBuffer = buffer;
        _charonOffset = offset;
        _charonLength = length;
        _charonZone = zone;
        _charonType = type;
        _charonAllocator = allocator;
    }
    return self;
}

- (NSUInteger)length
{
    return _charonLength;
}

- (MTKMeshBufferAllocator *)allocator
{
    return _charonAllocator;
}

- (id<MDLMeshBufferZone>)zone
{
    return _charonZone;
}

- (id<MTLBuffer>)buffer
{
    return _charonBuffer;
}

- (NSUInteger)offset
{
    return _charonOffset;
}

- (MDLMeshBufferType)type
{
    return _charonType;
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
    void *contents = [_charonBuffer contents];
    if (!contents || !data.length)
        return;
    NSUInteger room = _charonLength > offset ? _charonLength - offset : 0;
    memcpy((uint8_t *)contents + _charonOffset + offset, data.bytes, MIN(room, data.length));
}

- (MDLMeshBufferMap *)map
{
    void *contents = [_charonBuffer contents];
    return [[MDLMeshBufferMap alloc] initWithBytes:contents ? (uint8_t *)contents + _charonOffset : NULL
                                            deallocator:nil];
}

- (id)copyWithZone:(NSZone *)zone
{
    (void)zone;
    return [[MTKMeshBuffer alloc] initWithBuffer:_charonBuffer
                                         offset:_charonOffset
                                         length:_charonLength
                                           zone:_charonZone
                                           type:_charonType
                                      allocator:_charonAllocator];
}

@end

@implementation MTKSubmesh
{
    MTKMesh *_charonMesh;
    NSUInteger _charonIndex;
    NSUInteger _charonVertexStart;
    NSUInteger _charonVertexCount;
    NSUInteger _charonIndexStart;
    NSUInteger _charonIndexCount;
    MTLIndexType _charonIndexType;
    MTLPrimitiveType _charonPrimitiveType;
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
        _charonMesh = mesh;
        _charonIndex = submesh;
        _charonVertexStart = vertexStart;
        _charonVertexCount = vertexCount;
        _charonIndexStart = indexStart;
        _charonIndexCount = indexCount;
        _charonIndexType = indexType;
        _charonPrimitiveType = primitiveType;
    }
    return self;
}

- (MTKMesh *)mesh
{
    return _charonMesh;
}

- (NSUInteger)submeshIndex
{
    return _charonIndex;
}

- (NSUInteger)vertexStart
{
    return _charonVertexStart;
}

- (NSUInteger)vertexCount
{
    return _charonVertexCount;
}

- (NSUInteger)indexStart
{
    return _charonIndexStart;
}

- (NSUInteger)indexCount
{
    return _charonIndexCount;
}

- (MTLIndexType)indexType
{
    return _charonIndexType;
}

- (MTLPrimitiveType)primitiveType
{
    return _charonPrimitiveType;
}

@end
