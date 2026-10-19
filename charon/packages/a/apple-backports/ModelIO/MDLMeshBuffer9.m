#import <ModelIO/ModelIO.h>

#pragma clang diagnostic ignored "-Wobjc-missing-property-synthesis"

// A mesh buffer is the memory one attribute or one index range of a mesh lives in. The buffers here
// are backed by an NSMutableData, which is what the port's own allocator hands out and what every
// mesh the port builds or reads ends up holding: a real addressable range of the length the mesh says
// it has, copyable, and mappable.

@interface MDLMeshBufferZoneDefault ()
- (void)charon_setCapacity:(NSUInteger)capacity allocator:(id<MDLMeshBufferAllocator>)allocator;
@end

@implementation MDLMeshBufferMap {
    void *_bytes;
    void (^_deallocator)(void);
}

- (instancetype)initWithBytes:(void *)bytes deallocator:(void (^)(void))deallocator
{
    if ((self = [super init])) {
        _bytes = bytes;
        _deallocator = [deallocator copy];
    }
    return self;
}

- (void)dealloc
{
    if (_deallocator)
        _deallocator();
}

- (void *)bytes
{
    return _bytes;
}

@end
@implementation MDLMeshBufferData {
    NSMutableData *_data;
    id<MDLMeshBufferAllocator> _allocator;
    id<MDLMeshBufferZone> _zone;
    MDLMeshBufferType _type;
}

- (instancetype)initWithType:(MDLMeshBufferType)type length:(NSUInteger)length
{
    // A buffer of that length and nothing written into it yet holds the zero bytes of that length, so
    // its length and its map are true before the mesh writes into it.
    return [self initWithType:type data:[NSMutableData dataWithLength:length]];
}

- (instancetype)initWithType:(MDLMeshBufferType)type data:(NSData *)data
{
    if ((self = [super init])) {
        _type = type;
        _data = [data mutableCopy];
    }
    return self;
}

- (void)dealloc
{
}

- (NSData *)data
{
    return _data;
}

- (NSUInteger)length
{
    return _data.length;
}

- (id<MDLMeshBufferAllocator>)allocator
{
    return _allocator;
}

- (id<MDLMeshBufferZone>)zone
{
    return _zone;
}

- (MDLMeshBufferType)type
{
    return _type;
}

- (void)fillData:(NSData *)data offset:(NSUInteger)offset
{
    if (!data || offset + data.length > _data.length)
        return;
    [_data replaceBytesInRange:NSMakeRange(offset, data.length) withBytes:data.bytes length:data.length];
}

- (MDLMeshBufferMap *)map
{
    return [[MDLMeshBufferMap alloc] initWithBytes:_data.mutableBytes deallocator:nil];
}

- (id)copyWithZone:(NSZone *)zone
{
    MDLMeshBufferData *copy = [[[self class] allocWithZone:zone] initWithType:_type data:_data];
    [copy charon_setAllocator:_allocator zone:_zone];
    return copy;
}

// What the allocator writes into a buffer it has just made, so a buffer carries the allocator that
// made it and the zone it was made out of.
- (void)charon_setAllocator:(id<MDLMeshBufferAllocator>)allocator zone:(id<MDLMeshBufferZone>)zone
{
    if (_allocator != allocator) {
        _allocator = allocator;
    }
    if (_zone != zone) {
        _zone = zone;
    }
}

@end
@implementation MDLMeshBufferDataAllocator

- (id<MDLMeshBufferZone>)newZone:(NSUInteger)capacity
{
    MDLMeshBufferZoneDefault *zone = [[MDLMeshBufferZoneDefault alloc] init];
    [zone charon_setCapacity:capacity allocator:self];
    return zone;
}

- (id<MDLMeshBufferZone>)newZoneForBuffersWithSize:(NSArray<NSNumber *> *)sizes andType:(NSArray<NSNumber *> *)types
{
    NSUInteger total = 0;
    for (NSNumber *size in sizes)
        total += size.unsignedIntegerValue;
    return [self newZone:total];
}

- (id<MDLMeshBuffer>)newBuffer:(NSUInteger)length type:(MDLMeshBufferType)type
{
    return [self newBufferFromZone:nil data:[NSMutableData dataWithLength:length] type:type];
}

- (id<MDLMeshBuffer>)newBufferWithData:(NSData *)data type:(MDLMeshBufferType)type
{
    return [self newBufferFromZone:nil data:data type:type];
}

- (id<MDLMeshBuffer>)newBufferFromZone:(id<MDLMeshBufferZone>)zone length:(NSUInteger)length type:(MDLMeshBufferType)type
{
    if (zone && length > zone.capacity)
        return nil;
    return [self newBufferFromZone:zone data:[NSMutableData dataWithLength:length] type:type];
}

- (id<MDLMeshBuffer>)newBufferFromZone:(id<MDLMeshBufferZone>)zone data:(NSData *)data type:(MDLMeshBufferType)type
{
    // A zone the port did not make is not one the port can account for, and a buffer asked for out of
    // a zone with less room than it needs is not one it can make, so both are nil.
    if (zone && ![zone isKindOfClass:[MDLMeshBufferZoneDefault class]])
        return nil;
    if (zone && data.length > zone.capacity)
        return nil;
    MDLMeshBufferData *buffer = [[MDLMeshBufferData alloc] initWithType:type data:data];
    [buffer charon_setAllocator:self zone:zone];
    return buffer;
}

@end
