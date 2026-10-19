#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import "RevenantMetal.h"
#import "RevenantMetal26Types.h"
#import "RevenantMetalProtocols.h"

@interface RevenantMetal4CommandQueue : NSObject <MTL4CommandQueue>
@property (atomic, readonly) NSString *label;
- (void)revenantSetLabel:(NSString *)label;
- (void)addResidencySet:(id)residencySet;
- (void)removeResidencySet:(id)residencySet;
- (void)addResidencySets:(const id *)sets count:(NSUInteger)count;
- (void)removeResidencySets:(const id *)sets count:(NSUInteger)count;
- (void)updateBufferMappings:(id<MTLBuffer>)buffer heap:(id<MTLHeap>)heap
                  operations:(const MTL4UpdateSparseBufferMappingOperation *)operations count:(NSUInteger)count;
- (void)updateTextureMappings:(id<MTLTexture>)texture heap:(id<MTLHeap>)heap
                   operations:(const MTL4UpdateSparseTextureMappingOperation *)operations count:(NSUInteger)count;
- (void)copyBufferMappingsFromBuffer:(id<MTLBuffer>)source toBuffer:(id<MTLBuffer>)destination
                           operations:(const MTL4CopySparseBufferMappingOperation *)operations count:(NSUInteger)count;
- (void)copyTextureMappingsFromTexture:(id<MTLTexture>)source toTexture:(id<MTLTexture>)destination
                              operations:(const MTL4CopySparseTextureMappingOperation *)operations count:(NSUInteger)count;
- (void)waitForDrawable:(id<MTLDrawable>)drawable;
- (void)waitForEvent:(id)event value:(uint64_t)value;
- (void)signalEvent:(id)event value:(uint64_t)value;
- (void)signalDrawable:(id<MTLDrawable>)drawable;
@end

NSString *RevenantMetal4SparseBufferUpdateRefusal(BOOL bufferIsPlacementSparse, BOOL heapPresent, BOOL heapIsPlacement, BOOL mappingMode);
NSString *RevenantMetal4SparseBufferCopyRefusal(BOOL sourceIsPlacementSparse, BOOL destinationIsPlacementSparse);
NSString *RevenantMetal4SparseTextureUpdateRefusal(BOOL textureIsPlacementSparse, BOOL heapPresent, BOOL heapIsPlacement, BOOL mappingMode);
NSString *RevenantMetal4SparseTextureCopyRefusal(BOOL sourceIsPlacementSparse, BOOL destinationIsPlacementSparse);

static BOOL RevenantMetal4IsPlacementSparse(id resource)
{
    return [resource respondsToSelector:NSSelectorFromString(@"placementSparsePageSize")];
}

static void RevenantMetal4RaiseSparseRefusal(NSString *reason)
{
    [NSException raise:NSInternalInconsistencyException
                format:@"%@", reason ?: @"a sparse mapping is not performed on this device: no resource of this port is placement sparse"];
}

@implementation RevenantMetal4CommandQueue {
    RevenantMetalQueue *_queue;
    NSString *_label;
}

- (instancetype)init
{
    if ((self = [super init]))
        _queue = [[RevenantMetalQueue alloc] init];
    return self;
}

- (id<MTLDevice>)device
{
    return [_queue device];
}

- (NSString *)label
{
    return _label;
}

- (void)revenantSetLabel:(NSString *)label
{
    _label = [label copy];
}

- (void)addResidencySet:(id)residencySet
{
    (void)residencySet;
}

- (void)removeResidencySet:(id)residencySet
{
    (void)residencySet;
}

- (void)addResidencySets:(const id *)sets count:(NSUInteger)count
{
    (void)sets;
    (void)count;
}

- (void)removeResidencySets:(const id *)sets count:(NSUInteger)count
{
    (void)sets;
    (void)count;
}

- (void)updateBufferMappings:(id<MTLBuffer>)buffer heap:(id<MTLHeap>)heap
                  operations:(const MTL4UpdateSparseBufferMappingOperation *)operations count:(NSUInteger)count
{
    RevenantMetal4RaiseSparseRefusal(RevenantMetal4SparseBufferUpdateRefusal(RevenantMetal4IsPlacementSparse(buffer), heap != nil,
                                                                         heap != nil && heap.type == MTLHeapTypePlacement,
                                                                         YES));
}

- (void)updateTextureMappings:(id<MTLTexture>)texture heap:(id<MTLHeap>)heap
                   operations:(const MTL4UpdateSparseTextureMappingOperation *)operations count:(NSUInteger)count
{
    RevenantMetal4RaiseSparseRefusal(RevenantMetal4SparseTextureUpdateRefusal(RevenantMetal4IsPlacementSparse(texture), heap != nil,
                                                                           heap != nil && heap.type == MTLHeapTypePlacement,
                                                                           YES));
}

- (void)copyBufferMappingsFromBuffer:(id<MTLBuffer>)source toBuffer:(id<MTLBuffer>)destination
                           operations:(const MTL4CopySparseBufferMappingOperation *)operations count:(NSUInteger)count
{
    RevenantMetal4RaiseSparseRefusal(RevenantMetal4SparseBufferCopyRefusal(RevenantMetal4IsPlacementSparse(source),
                                                                       RevenantMetal4IsPlacementSparse(destination)));
}

- (void)copyTextureMappingsFromTexture:(id<MTLTexture>)source toTexture:(id<MTLTexture>)destination
                              operations:(const MTL4CopySparseTextureMappingOperation *)operations count:(NSUInteger)count
{
    RevenantMetal4RaiseSparseRefusal(RevenantMetal4SparseTextureCopyRefusal(RevenantMetal4IsPlacementSparse(source),
                                                                        RevenantMetal4IsPlacementSparse(destination)));
}

- (void)waitForDrawable:(id<MTLDrawable>)drawable
{
    (void)drawable;
}

- (void)signalDrawable:(id<MTLDrawable>)drawable
{
    (void)drawable;
}

- (void)signalEvent:(id)event value:(uint64_t)value
{
    if ([event isKindOfClass:[RevenantMetalSharedEvent class]]) {
        [(RevenantMetalSharedEvent *)event setSignaledValue:value];
        return;
    }
    NSLog(@"Metal: -signalEvent:value: was given a %@ and not one of this port's events, and a signalled value set on it would be a value nothing else could ever read",
          NSStringFromClass([event class]));
}

- (void)waitForEvent:(id)event value:(uint64_t)value
{
    if ([event isKindOfClass:[RevenantMetalSharedEvent class]]) {
        [(RevenantMetalSharedEvent *)event revenantWaitForValue:value];
        return;
    }
    NSLog(@"Metal: -waitForEvent:value: was given a %@ and not one of this port's events, and there is no signalled value on it to wait for",
          NSStringFromClass([event class]));
}

@end

@interface RevenantMetalDevice (RevenantMetal4CommandQueue26)
- (id)newMTL4CommandQueue;
- (id)newMTL4CommandQueueWithDescriptor:(MTL4CommandQueueDescriptor *)descriptor error:(NSError **)error;
@end

@implementation RevenantMetalDevice (RevenantMetal4CommandQueue26)

- (id)newMTL4CommandQueue
{
    return [[RevenantMetal4CommandQueue alloc] init];
}

- (id)newMTL4CommandQueueWithDescriptor:(MTL4CommandQueueDescriptor *)descriptor error:(NSError **)error
{
    RevenantMetal4CommandQueue *queue = [[RevenantMetal4CommandQueue alloc] init];
    [queue revenantSetLabel:descriptor.label];
    return queue;
}

@end

@interface MTLCaptureManager (RevenantMetal4CaptureScope26)
- (id)newCaptureScopeWithMTL4CommandQueue:(id)commandQueue;
@end

@implementation MTLCaptureManager (RevenantMetal4CaptureScope26)

- (id)newCaptureScopeWithMTL4CommandQueue:(id)commandQueue
{
    return [self newCaptureScopeWithCommandQueue:(id<MTLCommandQueue>)commandQueue];
}

@end
