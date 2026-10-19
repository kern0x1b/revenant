#import <MetalKit/MetalKit.h>
#import <Metal/Metal.h>
#import <ModelIO/ModelIO.h>

#include <string.h>

// MTKMesh's three supporting types, which MetalKit's MTKModel.h declares and the port was missing:
// an allocator that hands out buffers, a buffer that is a window onto one of them, and a submesh that
// says which part of a mesh a draw covers.
//
// The header states the shape of all three and the port follows it. MTKMeshBufferAllocator's
// initWithDevice: is "The designated initializer for this class" and its device is "used to create
// buffers" (@property device), so the allocator holds the device and every buffer it makes comes from
// it. MTKMeshBuffer's -init is NS_UNAVAILABLE with the header's own words - "Only an MTKMeshBuffer-
// Allocator object can initilize a MTKMeshBuffer object" - so there is no -init here either and the
// allocator is the only way one is made. Its length is "Size in bytes of the buffer allocation", its
// buffer is the "Metal Buffer backing vertex/index data", its offset is the "Byte offset of the data
// within the metal buffer", and its allocator is stored because the header says Model I/O needs it
// "for copy and relayout".

// One MTLBuffer per zone, which is what the header describes: a single buffer is allocated for each zone, and each zone
// could have many MTKMeshBuffers (@property zone). The port's buffers are CPU-resident,
// so a zone is one MTLBuffer and each buffer carved out of it is a window at its own offset - which is
// what the header says about many MTKMeshBuffers sharing one buffer at different offsets (@property buffer).
// The header already declares MTKMeshBuffer, so its initializer is added as a category rather than a
// second @interface: the header makes an allocator the only way to create an MTKMeshBuffer, so this is not public API.
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

// MDLMeshBufferZone: "The allocator that allocated this zone" (@property allocator).
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

// The next window in this zone: its own offset, its own length, and the used count moved on. The
// offset is the zone's business because two buffers from one zone must not overlap, which is what
// the header's point about many MTKMeshBuffers sharing one buffer at different offsets is about.
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

// MDLMeshBufferAllocator: a zone of the given capacity, backed by one MTLBuffer of that many bytes.
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

// A buffer from a zone: the zone's own buffer at the zone's current end, which is the offset the
// header's "each with its own offset" is about. A nil zone means a default zone of exactly this
// buffer's size, which is what the header's "in a default zone" says for the two methods above.
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
        return nil;  // MDLMeshBufferAllocator: the header's nil answer, for a request the given zone cannot satisfy
    // takeOffset:length: is the zone's own method, so the bump of its used count stays inside it
    return [own charonBufferTakingLength:length type:type];
}

// The port's MTLBuffer is CPU-resident and its contents are reachable through the pointer
// getBytes:, which is the path facts/Metal/Blits.md measures: a copy on this device is a copy on the
// CPU between the bytes of a buffer and the pixels of a texture. There is no replaceRegion: on a
// buffer in this port - it is a texture's member - so the bytes are written through it.
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

// MDLMeshBuffer's fill method fills data.length bytes of its data and will not write beyond the length of the buffer,
// with an offset giving the byte at which filling begins.
- (void)fillData:(NSData *)data offset:(NSUInteger)offset
{
    void *contents = [_charonBuffer contents];
    if (!contents || !data.length)
        return;
    NSUInteger room = _charonLength > offset ? _charonLength - offset : 0;
    memcpy((uint8_t *)contents + _charonOffset + offset, data.bytes, MIN(room, data.length));
}

// MDLMeshBuffer's -map is "CPU access to buffer's memory ... to read or modify a buffer's memory",
// and MDLMeshBufferMap says of its data pointer: "Data to be modified directly. NULL if buffer is
// not mapped". The port's buffer is CPU-resident, so it is always mapped and the pointer is the
// window's own bytes; the map object is what keeps it that way for as long as it exists.
- (MDLMeshBufferMap *)map
{
    void *contents = [_charonBuffer contents];
    // MDLMeshBufferMap's initializer is the one an implementor of the MDLMeshBuffer protocol calls to build the map and set up
    // unmapping on deallocation - initWithBytes:deallocator:. There is no
    // unmapping to arrange for here: the port's buffer is CPU-resident memory that is never mapped
    // and never unmapped, so the deallocator is nil rather than a lie about work that is not done.
    return [[MDLMeshBufferMap alloc] initWithBytes:contents ? (uint8_t *)contents + _charonOffset : NULL
                                            deallocator:nil];
}

// MDLMeshBuffer inherits NSCopying, and a copy of a window is a window onto the same bytes at the
// same offset - the header says that many MTKMeshBuffers may share one buffer, each with its own offset, and that the sharing is the point.
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
