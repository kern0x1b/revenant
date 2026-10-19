#import "CharonMetal.h"

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

@implementation CharonMetalHeap (Placement)

- (MTLHeapType)type
{
    return [self charonType];
}

- (MTLHazardTrackingMode)hazardTrackingMode
{
    return [self charonHazardTracking];
}

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
