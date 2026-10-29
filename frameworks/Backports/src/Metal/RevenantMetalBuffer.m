#import "RevenantMetal.h"

#pragma clang diagnostic ignored "-Wprotocol"
#pragma clang diagnostic ignored "-Wincomplete-implementation"

@implementation RevenantMetalBuffer {
    void *_bytes;
    NSUInteger _length;
    __strong RevenantMetalHeap *_heap;
    NSUInteger _heapOffset;
    MTLPurgeableState _purgeableState;
}

@synthesize label;

- (instancetype)initWithLength:(NSUInteger)length bytes:(const void *)bytes
{
    if ((self = [super init])) {
        _length = length;
        _bytes = calloc(1, length ? length : 1);
        if (bytes)
            memcpy(_bytes, bytes, length);
    }
    return self;
}

- (instancetype)initWithHeap:(RevenantMetalHeap *)heap offset:(NSUInteger)offset length:(NSUInteger)length
{
    if ((self = [super init])) {
        _heap = heap;
        _heapOffset = offset;
        _length = length;
        _bytes = (uint8_t *)[heap revenantBytesAtOffset:offset];
    }
    return self;
}

- (id<MTLHeap>)heap
{
    return _heap;
}

- (NSUInteger)heapOffset
{
    return _heapOffset;
}

- (void)dealloc
{
    if (!_heap)
        free(_bytes);
}

- (void *)bytes
{
    return _bytes;
}

- (void *)contents
{
    return _bytes;
}

- (id<MTLTexture>)newTextureWithDescriptor:(MTLTextureDescriptor *)descriptor offset:(NSUInteger)offset bytesPerRow:(NSUInteger)bytesPerRow
{
    NSLog(@"Metal: a texture on a buffer's bytes is not supported: the buffer's storage cannot be mapped into OpenGL ES in place");
    return nil;
}

- (NSUInteger)length
{
    return _length;
}

- (id<MTLDevice>)device
{
    return [RevenantMetalDevice shared];
}

- (MTLResourceOptions)resourceOptions
{
    return MTLResourceStorageModeShared;
}

- (MTLStorageMode)storageMode
{
    return MTLStorageModeShared;
}

- (MTLCPUCacheMode)cpuCacheMode
{
    return MTLCPUCacheModeDefaultCache;
}

- (void)didModifyRange:(NSRange)range
{
}

- (MTLPurgeableState)setPurgeableState:(MTLPurgeableState)state
{
    MTLPurgeableState previous = _purgeableState ?: MTLPurgeableStateNonVolatile;
    if (state != MTLPurgeableStateKeepCurrent)
        _purgeableState = state;
    return previous;
}


- (NSUInteger)allocatedSize
{
    return [self length];
}

- (MTLHazardTrackingMode)hazardTrackingMode
{
    return MTLHazardTrackingModeUntracked;
}

- (BOOL)isAliasable
{
    return NO;
}

- (void)makeAliasable
{
}
@end
