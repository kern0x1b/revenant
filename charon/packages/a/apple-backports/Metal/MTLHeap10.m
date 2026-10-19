#import "CharonMetal.h"

#pragma clang diagnostic ignored "-Wprotocol"
#pragma clang diagnostic ignored "-Wincomplete-implementation"

const NSUInteger CharonMetalHeapAlignment = 256;

@implementation CharonMetalHeap {
    uint8_t *_bytes;
    NSUInteger _size;
    NSUInteger _used;
    NSUInteger _allocated;
    MTLHeapType _type;
    MTLHazardTrackingMode _hazardTracking;
    MTLStorageMode _storageMode;
    MTLCPUCacheMode _cpuCacheMode;
}

@synthesize label;

- (instancetype)initWithDescriptor:(MTLHeapDescriptor *)descriptor error:(NSError **)error
{
    if ((NSUInteger)descriptor.type == (NSUInteger)MTLHeapTypeSparse) {
        if (error)
            *error = CharonMetalError(11, @"a sparse heap maps its pages in on demand, and one allocation of the size asked for does not; use an automatic or a placement heap");
        return nil;
    }
    if (!descriptor.size) {
        if (error)
            *error = CharonMetalError(12, @"a heap descriptor of zero bytes has nothing to take a resource out of");
        return nil;
    }
    if ((self = [super init])) {
        _size = descriptor.size;
        _type = descriptor.type;
        _hazardTracking = descriptor.hazardTrackingMode;
        _storageMode = descriptor.storageMode;
        _cpuCacheMode = descriptor.cpuCacheMode;
        _bytes = calloc(1, _size);
        if (!_bytes) {
            if (error)
                *error = CharonMetalError(13, @"the heap's allocation of its size could not be made");
            return nil;
        }
    }
    return self;
}

- (void)dealloc
{
    free(_bytes);
}

- (void *)charonBytesAtOffset:(NSUInteger)offset
{
    return _bytes + offset;
}

- (id<MTLDevice>)device
{
    return [CharonMetalDevice shared];
}

- (NSUInteger)size
{
    return _size;
}

- (NSUInteger)usedSize
{
    return _used;
}

- (MTLStorageMode)storageMode
{
    return _storageMode;
}

- (MTLCPUCacheMode)cpuCacheMode
{
    return _cpuCacheMode;
}

- (NSUInteger)charonAligned:(NSUInteger)offset
{
    NSUInteger remainder = offset % CharonMetalHeapAlignment;
    return remainder ? offset + (CharonMetalHeapAlignment - remainder) : offset;
}

- (NSUInteger)maxAvailableSizeWithAlignment:(NSUInteger)alignment
{
    NSUInteger step = alignment ? alignment : CharonMetalHeapAlignment;
    NSUInteger remainder = _used % step;
    NSUInteger start = remainder ? _used + (step - remainder) : _used;
    if (start > _size)
        return 0;
    NSUInteger available = _size - start;
    return available - available % step;
}

- (BOOL)charonReserve:(NSUInteger)length atOffset:(NSUInteger *)offset error:(NSError **)error
{
    if (_type == (MTLHeapType)MTLHeapTypePlacement) {
        NSError *why = CharonMetalError(14, @"a placement heap is placed by the application: ask for an offset");
        NSLog(@"Metal: %@", why.localizedDescription);
        if (error)
            *error = why;
        return NO;
    }
    NSUInteger start = [self charonAligned:_used];
    if (start > _size || length > _size - start) {
        NSError *why = CharonMetalError(15, [NSString stringWithFormat:@"the heap has %lu of its %lu bytes left, and a resource of %lu at the alignment it hands out does not fit",
                                              (unsigned long)(_size > start ? _size - start : 0), (unsigned long)_size, (unsigned long)length]);
        NSLog(@"Metal: %@", why.localizedDescription);
        if (error)
            *error = why;
        return NO;
    }
    if (offset)
        *offset = start;
    [self charonDidAllocate:length];
    return YES;
}

- (NSUInteger)charonAllocated
{
    return _allocated;
}

- (MTLHeapType)charonType
{
    return _type;
}

- (MTLHazardTrackingMode)charonHazardTracking
{
    return _hazardTracking;
}

- (MTLStorageMode)charonStorageMode
{
    return _storageMode;
}

- (void)charonDidAllocate:(NSUInteger)length
{
    _used = [self charonAligned:_used] + [self charonAligned:length];
    _allocated += length;
}

- (BOOL)charonPlace:(NSUInteger)length atOffset:(NSUInteger)offset error:(NSError **)error
{
    if (offset % CharonMetalHeapAlignment) {
        NSError *why = CharonMetalError(16, [NSString stringWithFormat:@"an offset of %lu into a heap is a multiple of the heap's alignment of 256 bytes", (unsigned long)offset]);
        NSLog(@"Metal: %@", why.localizedDescription);
        if (error)
            *error = why;
        return NO;
    }
    if (offset > _size || length > _size - offset) {
        NSError *why = CharonMetalError(15, [NSString stringWithFormat:@"the heap has %lu of its %lu bytes left at offset %lu, and a resource of %lu does not fit",
                                              (unsigned long)(offset < _size ? _size - offset : 0), (unsigned long)_size, (unsigned long)offset, (unsigned long)length]);
        NSLog(@"Metal: %@", why.localizedDescription);
        if (error)
            *error = why;
        return NO;
    }
    if (offset + length > _used)
        _used = offset + length;
    _allocated += length;
    return YES;
}

- (id<MTLBuffer>)newBufferWithLength:(NSUInteger)length options:(MTLResourceOptions)options
{
    NSUInteger offset = 0;
    if (![self charonReserve:length atOffset:&offset error:NULL])
        return nil;
    return [[CharonMetalBuffer alloc] initWithHeap:self offset:offset length:length];
}

- (id<MTLTexture>)newTextureWithDescriptor:(MTLTextureDescriptor *)descriptor
{
    CharonMetalTexture *texture = [[CharonMetalTexture alloc] initWithDescriptor:descriptor];
    if (!texture)
        return nil;
    NSUInteger bytes = [texture charonStorageSize];
    NSUInteger offset = 0;
    if (bytes && ![self charonReserve:bytes atOffset:&offset error:NULL])
        return nil;
    [texture charonSetHeap:self offset:offset];
    NSLog(@"Metal: a texture taken out of a heap at offset %lu of %lu bytes has its own pixels, not the heap's: an OpenGL ES 2.0 texture is copied into and cannot be backed by memory the heap hands out (facts/Metal/Heaps.md)",
          (unsigned long)offset, (unsigned long)bytes);
    return texture;
}

- (BOOL)setPurgeableState:(MTLPurgeableState)state
{
    return NO;
}

@end

@interface CharonMetalDevice (Heap)
@end

@implementation CharonMetalDevice (Heap)

- (id<MTLHeap>)newHeapWithDescriptor:(MTLHeapDescriptor *)descriptor
{
    return (id<MTLHeap>)[[CharonMetalHeap alloc] initWithDescriptor:descriptor error:NULL];
}

@end
