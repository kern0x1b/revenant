#import "RevenantMetal.h"

#pragma clang diagnostic ignored "-Wprotocol"
#pragma clang diagnostic ignored "-Wincomplete-implementation"

const NSUInteger RevenantMetalHeapAlignment = 256;

@implementation RevenantMetalHeap {
    uint8_t *_bytes;
    NSUInteger _size;
    NSUInteger _used;
    NSUInteger _allocated;
    MTLHeapType _type;
    MTLHazardTrackingMode _hazardTracking;
    MTLPurgeableState _purgeableState;
    MTLStorageMode _storageMode;
    MTLCPUCacheMode _cpuCacheMode;
}

@synthesize label;

- (instancetype)initWithDescriptor:(MTLHeapDescriptor *)descriptor error:(NSError **)error
{
    if ((NSUInteger)descriptor.type == (NSUInteger)MTLHeapTypeSparse) {
        if (error)
            *error = RevenantMetalError(11, @"a sparse heap maps its pages in on demand, and one allocation of the size asked for does not; use an automatic or a placement heap");
        return nil;
    }
    if (!descriptor.size) {
        if (error)
            *error = RevenantMetalError(12, @"a heap descriptor of zero bytes has nothing to take a resource out of");
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
                *error = RevenantMetalError(13, @"the heap's allocation of its size could not be made");
            return nil;
        }
    }
    return self;
}

- (void)dealloc
{
    free(_bytes);
}

- (void *)revenantBytesAtOffset:(NSUInteger)offset
{
    return _bytes + offset;
}

- (id<MTLDevice>)device
{
    return [RevenantMetalDevice shared];
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

- (NSUInteger)revenantAligned:(NSUInteger)offset
{
    NSUInteger remainder = offset % RevenantMetalHeapAlignment;
    return remainder ? offset + (RevenantMetalHeapAlignment - remainder) : offset;
}

- (NSUInteger)maxAvailableSizeWithAlignment:(NSUInteger)alignment
{
    NSUInteger step = alignment ? alignment : RevenantMetalHeapAlignment;
    NSUInteger remainder = _used % step;
    NSUInteger start = remainder ? _used + (step - remainder) : _used;
    if (start > _size)
        return 0;
    NSUInteger available = _size - start;
    return available - available % step;
}

- (BOOL)revenantReserve:(NSUInteger)length atOffset:(NSUInteger *)offset error:(NSError **)error
{
    if (_type == (MTLHeapType)MTLHeapTypePlacement) {
        NSError *why = RevenantMetalError(14, @"a placement heap is placed by the application: ask for an offset");
        NSLog(@"Metal: %@", why.localizedDescription);
        if (error)
            *error = why;
        return NO;
    }
    NSUInteger start = [self revenantAligned:_used];
    if (start > _size || length > _size - start) {
        NSError *why = RevenantMetalError(15, [NSString stringWithFormat:@"the heap has %lu of its %lu bytes left, and a resource of %lu at the alignment it hands out does not fit",
                                              (unsigned long)(_size > start ? _size - start : 0), (unsigned long)_size, (unsigned long)length]);
        NSLog(@"Metal: %@", why.localizedDescription);
        if (error)
            *error = why;
        return NO;
    }
    if (offset)
        *offset = start;
    [self revenantDidAllocate:length];
    return YES;
}

- (NSUInteger)revenantAllocated
{
    return _allocated;
}

- (MTLHeapType)revenantType
{
    return _type;
}

- (MTLHazardTrackingMode)revenantHazardTracking
{
    return _hazardTracking;
}

- (MTLStorageMode)revenantStorageMode
{
    return _storageMode;
}

- (void)revenantDidAllocate:(NSUInteger)length
{
    _used = [self revenantAligned:_used] + [self revenantAligned:length];
    _allocated += length;
}

- (BOOL)revenantPlace:(NSUInteger)length atOffset:(NSUInteger)offset error:(NSError **)error
{
    if (offset % RevenantMetalHeapAlignment) {
        NSError *why = RevenantMetalError(16, [NSString stringWithFormat:@"an offset of %lu into a heap is a multiple of the heap's alignment of 256 bytes", (unsigned long)offset]);
        NSLog(@"Metal: %@", why.localizedDescription);
        if (error)
            *error = why;
        return NO;
    }
    if (offset > _size || length > _size - offset) {
        NSError *why = RevenantMetalError(15, [NSString stringWithFormat:@"the heap has %lu of its %lu bytes left at offset %lu, and a resource of %lu does not fit",
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
    if (![self revenantReserve:length atOffset:&offset error:NULL])
        return nil;
    return [[RevenantMetalBuffer alloc] initWithHeap:self offset:offset length:length];
}

- (id<MTLTexture>)newTextureWithDescriptor:(MTLTextureDescriptor *)descriptor
{
    RevenantMetalTexture *texture = [[RevenantMetalTexture alloc] initWithDescriptor:descriptor];
    if (!texture)
        return nil;
    NSUInteger bytes = [texture revenantStorageSize];
    NSUInteger offset = 0;
    if (bytes && ![self revenantReserve:bytes atOffset:&offset error:NULL])
        return nil;
    [texture revenantSetHeap:self offset:offset];
    NSLog(@"Metal: a texture taken out of a heap at offset %lu of %lu bytes has its own pixels, not the heap's: an OpenGL ES 2.0 texture is copied into and cannot be backed by memory the heap hands out (facts/Metal/Heaps.md)",
          (unsigned long)offset, (unsigned long)bytes);
    return texture;
}

- (MTLPurgeableState)setPurgeableState:(MTLPurgeableState)state
{
    MTLPurgeableState previous = _purgeableState ?: MTLPurgeableStateNonVolatile;
    if (state != MTLPurgeableStateKeepCurrent)
        _purgeableState = state;
    return previous;
}

@end

@interface RevenantMetalDevice (Heap)
@end

@implementation RevenantMetalDevice (Heap)

- (id<MTLHeap>)newHeapWithDescriptor:(MTLHeapDescriptor *)descriptor
{
    return (id<MTLHeap>)[[RevenantMetalHeap alloc] initWithDescriptor:descriptor error:NULL];
}

@end
