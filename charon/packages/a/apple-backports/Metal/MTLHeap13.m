#import "CharonMetal.h"

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

// The 13.0 members: a heap's type, hazard tracking and resource options, the two offset-taking
// allocations a placement heap exists for, and the encoders' staged form of naming heaps.
//
// A resource placed at an offset the application chose is a view into the heap's bytes at that
// offset, so `usedSize` reaches past it and the next automatic allocation starts after it, and two
// placements that overlap are the application's own doing: Metal leaves that undefined, and so does
// the port, except that the second one is refused when it does not fit.
//
// `stages` says which stages of a pipeline may read the heaps, and this port has one stage set: a
// command is a call into OpenGL ES 2.0 that has already been made, so every heap is visible to
// every stage and the mask changes nothing. facts/Metal/Heaps.md says so rather than leaving the
// argument ignored silently.
//
// The heap descriptor is the SDK's own class, so `type`, `resourceOptions` and the rest are its own
// properties with its own storage: there is nothing for the port to write here.

@implementation CharonMetalHeap (Placement)

- (MTLHeapType)type
{
    return [self charonType];
}

- (MTLHazardTrackingMode)hazardTrackingMode
{
    return [self charonHazardTracking];
}

// The heap's storage mode as a resource's options say it, which is the same mask: a heap created
// shared makes shared resources and a private heap makes private ones. MTLStorageModeManaged is
// macOS only - Apple's header marks it unavailable on iOS - so there is no case for it here.
- (MTLResourceOptions)resourceOptions
{
    MTLStorageMode mode = [self charonStorageMode];
    if (mode == MTLStorageModeShared)
        return MTLResourceStorageModeShared;
    if (mode == MTLStorageModePrivate)
        return MTLResourceStorageModePrivate;
    return (MTLResourceOptions)mode;
}

- (id<MTLBuffer>)newBufferWithLength:(NSUInteger)length options:(MTLResourceOptions)options offset:(NSUInteger)offset
{
    if (![self charonPlace:length atOffset:offset error:NULL])
        return nil;
    return [[CharonMetalBuffer alloc] initWithHeap:self offset:offset length:length];
}

- (id<MTLTexture>)newTextureWithDescriptor:(MTLTextureDescriptor *)descriptor offset:(NSUInteger)offset
{
    CharonMetalTexture *texture = [[CharonMetalTexture alloc] initWithDescriptor:descriptor];
    if (!texture)
        return nil;
    NSUInteger bytes = [texture charonStorageSize];
    if (bytes && ![self charonPlace:bytes atOffset:offset error:NULL])
        return nil;
    [texture charonSetHeap:self offset:offset];
    return texture;
}

@end

@implementation CharonMetalEncoder (HeapStages)

- (void)useHeap:(id<MTLHeap>)heap stages:(MTLRenderStages)stages
{
    [self charonUseHeaps:&heap count:1];
}

- (void)useHeaps:(const id<MTLHeap> __nonnull[])heaps count:(NSUInteger)count stages:(MTLRenderStages)stages
{
    [self charonUseHeaps:heaps count:count];
}

@end
