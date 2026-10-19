#import "CharonMetal.h"

#pragma clang diagnostic ignored "-Wprotocol"
#pragma clang diagnostic ignored "-Wincomplete-implementation"

@implementation CharonMetalBuffer {
    void *_bytes;
    NSUInteger _length;
    __strong CharonMetalHeap *_heap;
    NSUInteger _heapOffset;
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

// A buffer of a heap is a view into the heap's allocation: its bytes are the heap's, the heap is
// held for as long as the view is, and the heap frees the bytes when the last view is gone.
- (instancetype)initWithHeap:(CharonMetalHeap *)heap offset:(NSUInteger)offset length:(NSUInteger)length
{
    if ((self = [super init])) {
        _heap = heap;
        _heapOffset = offset;
        _length = length;
        _bytes = (uint8_t *)[heap charonBytesAtOffset:offset];
    }
    return self;
}

// MTLResource's own properties, answered as the SDK declares them: the heap the resource was created
// from, nil when it was not created from one, and the offset inside it.
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

- (NSUInteger)length
{
    return _length;
}

- (id<MTLDevice>)device
{
    return [CharonMetalDevice shared];
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

- (BOOL)setPurgeableState:(MTLPurgeableState)state
{
    return NO;
}


// The four MTLResource members this class did not carry, each with the value the header's own
// documentation points at for this port. They are cheap and none of them needs a measurement: each is
// a property of a CPU-resident buffer this port already knows the size of, or a question about
// aliasing a device has no heap for.

// allocatedSize (MTLResource.h, iOS 11.0) is the size of the allocation. A buffer here is a window
// onto ONE MTLBuffer's bytes, and the window's own length is what the port already answers, so the
// allocation it lives in is at least that and the honest value is the window's length rather than a
// larger number nobody here can know.
- (NSUInteger)allocatedSize
{
    return [self length];
}

// hazardTrackingMode, with MTLHazardTrackingMode's own cases (MTLResource.h:97-99): Default = 0,
// Untracked = 1, Tracked = 2. The port dispatches a buffer's work on the CPU and joins the threads
// of a workgroup with a mutex and a condition variable before the dispatch is encoded
// (facts/Metal/Compute.md), so the hazard is resolved by that join and not by a tracked range - which
// is the header's own UNTRACKED.
- (MTLHazardTrackingMode)hazardTrackingMode
{
    return MTLHazardTrackingModeUntracked;
}

// isAliasable and makeAliasable are about sharing one allocation under two resources. This device
// runs OpenGL ES 2.0 through a port that maps a buffer onto a range of the one system memory it has,
// and two textures over the same range would be two names for one copy of bytes the shader would then
// write twice - so the answer is NO, and it is the header's own question answered for this port.
- (BOOL)isAliasable
{
    return NO;
}

- (void)makeAliasable
{
    // MTLResource.h:78 declares "-(void) makeAliasable" with NO argument, and it is VOID, not BOOL:
    // whether the call SUCCEEDED is what isAliasable answers, which is the pair of members the header
    // gives. Nothing happens here, and isAliasable says NO because nothing did.
}
@end
