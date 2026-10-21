#import "RevenantMetal.h"

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

@implementation RevenantMetalHeap (Placement)

- (MTLHeapType)type
{
    return [self revenantType];
}

- (MTLHazardTrackingMode)hazardTrackingMode
{
    return [self revenantHazardTracking];
}

- (MTLResourceOptions)resourceOptions
{
    MTLStorageMode mode = [self revenantStorageMode];
    if (mode == MTLStorageModeShared)
        return MTLResourceStorageModeShared;
    if (mode == MTLStorageModePrivate)
        return MTLResourceStorageModePrivate;
    return (MTLResourceOptions)mode;
}

- (id<MTLBuffer>)newBufferWithLength:(NSUInteger)length options:(MTLResourceOptions)options offset:(NSUInteger)offset
{
    if (![self revenantPlace:length atOffset:offset error:NULL])
        return nil;
    return [[RevenantMetalBuffer alloc] initWithHeap:self offset:offset length:length];
}

- (id<MTLTexture>)newTextureWithDescriptor:(MTLTextureDescriptor *)descriptor offset:(NSUInteger)offset
{
    RevenantMetalTexture *texture = [[RevenantMetalTexture alloc] initWithDescriptor:descriptor];
    if (!texture)
        return nil;
    NSUInteger bytes = [texture revenantStorageSize];
    if (bytes && ![self revenantPlace:bytes atOffset:offset error:NULL])
        return nil;
    [texture revenantSetHeap:self offset:offset];
    return texture;
}

@end

@implementation RevenantMetalEncoder (HeapStages)

- (void)useHeap:(id<MTLHeap>)heap stages:(MTLRenderStages)stages
{
    [self revenantUseHeaps:&heap count:1];
}

- (void)useHeaps:(const id<MTLHeap> __nonnull[])heaps count:(NSUInteger)count stages:(MTLRenderStages)stages
{
    [self revenantUseHeaps:heaps count:count];
}

@end
