#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import "CharonMetal.h"
#import "CharonMetal26Types.h"
#import "CharonMetalProtocols.h"

@interface CharonMetal4CommandQueue : NSObject <MTL4CommandQueue>
@property (atomic, readonly) NSString *label;
- (void)charonSetLabel:(NSString *)label;
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

NSString *CharonMetal4SparseBufferUpdateRefusal(BOOL bufferIsPlacementSparse, BOOL heapPresent, BOOL heapIsPlacement, BOOL mappingMode);
NSString *CharonMetal4SparseBufferCopyRefusal(BOOL sourceIsPlacementSparse, BOOL destinationIsPlacementSparse);
NSString *CharonMetal4SparseTextureUpdateRefusal(BOOL textureIsPlacementSparse, BOOL heapPresent, BOOL heapIsPlacement, BOOL mappingMode);
NSString *CharonMetal4SparseTextureCopyRefusal(BOOL sourceIsPlacementSparse, BOOL destinationIsPlacementSparse);

static BOOL CharonMetal4IsPlacementSparse(id resource)
{
    return [resource respondsToSelector:NSSelectorFromString(@"placementSparsePageSize")];
}

static void CharonMetal4RaiseSparseRefusal(NSString *reason)
{
    [NSException raise:NSInternalInconsistencyException
                format:@"%@", reason ?: @"a sparse mapping is not performed on this device: no resource of this port is placement sparse"];
}

@implementation CharonMetal4CommandQueue {
    CharonMetalQueue *_queue;
    NSString *_label;
}

- (instancetype)init
{
    if ((self = [super init]))
        _queue = [[CharonMetalQueue alloc] init];
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

- (void)charonSetLabel:(NSString *)label
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
    CharonMetal4RaiseSparseRefusal(CharonMetal4SparseBufferUpdateRefusal(CharonMetal4IsPlacementSparse(buffer), heap != nil,
                                                                         heap != nil && heap.type == MTLHeapTypePlacement,
                                                                         YES));
}

- (void)updateTextureMappings:(id<MTLTexture>)texture heap:(id<MTLHeap>)heap
                   operations:(const MTL4UpdateSparseTextureMappingOperation *)operations count:(NSUInteger)count
{
    CharonMetal4RaiseSparseRefusal(CharonMetal4SparseTextureUpdateRefusal(CharonMetal4IsPlacementSparse(texture), heap != nil,
                                                                           heap != nil && heap.type == MTLHeapTypePlacement,
                                                                           YES));
}

- (void)copyBufferMappingsFromBuffer:(id<MTLBuffer>)source toBuffer:(id<MTLBuffer>)destination
                           operations:(const MTL4CopySparseBufferMappingOperation *)operations count:(NSUInteger)count
{
    CharonMetal4RaiseSparseRefusal(CharonMetal4SparseBufferCopyRefusal(CharonMetal4IsPlacementSparse(source),
                                                                       CharonMetal4IsPlacementSparse(destination)));
}

- (void)copyTextureMappingsFromTexture:(id<MTLTexture>)source toTexture:(id<MTLTexture>)destination
                              operations:(const MTL4CopySparseTextureMappingOperation *)operations count:(NSUInteger)count
{
    CharonMetal4RaiseSparseRefusal(CharonMetal4SparseTextureCopyRefusal(CharonMetal4IsPlacementSparse(source),
                                                                        CharonMetal4IsPlacementSparse(destination)));
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
    if ([event isKindOfClass:[CharonMetalSharedEvent class]]) {
        [(CharonMetalSharedEvent *)event setSignaledValue:value];
        return;
    }
    NSLog(@"Metal: -signalEvent:value: was given a %@ and not one of this port's events, and a signalled value set on it would be a value nothing else could ever read",
          NSStringFromClass([event class]));
}

- (void)waitForEvent:(id)event value:(uint64_t)value
{
    if ([event isKindOfClass:[CharonMetalSharedEvent class]]) {
        [(CharonMetalSharedEvent *)event charonWaitForValue:value];
        return;
    }
    NSLog(@"Metal: -waitForEvent:value: was given a %@ and not one of this port's events, and there is no signalled value on it to wait for",
          NSStringFromClass([event class]));
}

@end

@interface CharonMetalDevice (CharonMetal4CommandQueue26)
- (id)newMTL4CommandQueue;
- (id)newMTL4CommandQueueWithDescriptor:(MTL4CommandQueueDescriptor *)descriptor error:(NSError **)error;
@end

@implementation CharonMetalDevice (CharonMetal4CommandQueue26)

- (id)newMTL4CommandQueue
{
    return [[CharonMetal4CommandQueue alloc] init];
}

- (id)newMTL4CommandQueueWithDescriptor:(MTL4CommandQueueDescriptor *)descriptor error:(NSError **)error
{
    CharonMetal4CommandQueue *queue = [[CharonMetal4CommandQueue alloc] init];
    [queue charonSetLabel:descriptor.label];
    return queue;
}

@end

@interface MTLCaptureManager (CharonMetal4CaptureScope26)
- (id)newCaptureScopeWithMTL4CommandQueue:(id)commandQueue;
@end

@implementation MTLCaptureManager (CharonMetal4CaptureScope26)

- (id)newCaptureScopeWithMTL4CommandQueue:(id)commandQueue
{
    return [self newCaptureScopeWithCommandQueue:(id<MTLCommandQueue>)commandQueue];
}

@end
