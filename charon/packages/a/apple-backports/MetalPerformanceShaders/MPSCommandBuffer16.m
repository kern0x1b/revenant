#import "CharonMPS.h"

#pragma clang diagnostic ignored "-Wprotocol"
#pragma clang diagnostic ignored "-Wincomplete-implementation"

id<MTLDevice> MPSGetPreferredDevice(MPSDeviceOptions options)
{
    (void)options;
    return MTLCreateSystemDefaultDevice();
}
@protocol CharonMPSCommitAndContinuing <NSObject>
- (void)commitAndContinue;
@end
@protocol CharonMPSCommandBufferDebugging <NSObject>
- (void)setDebugMarker:(NSString *)string;
- (void)insertDebugMarker:(NSString *)string;
- (NSArray<NSString *> *)bufferLabels;
- (void)setBufferLabels:(NSArray<NSString *> *)labels;
- (MTLRenderPassDescriptor *)currentRenderPassDescriptor;
- (void)memoryBarrierWithResources:(NSArray<id<MTLResource>> *)resources;
@end

@implementation MPSCommandBuffer {
    id<MTLCommandBuffer> _buffer;
    MPSPredicate *_predicate;
    id<MPSHeapProvider> _heapProvider;
}

@synthesize label;

+ (instancetype)commandBufferWithCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
{
    return [[self alloc] initWithCommandBuffer:commandBuffer];
}

+ (instancetype)commandBufferFromCommandQueue:(id<MTLCommandQueue>)commandQueue
{
    return [[self alloc] initWithCommandBuffer:[commandQueue commandBuffer]];
}

- (instancetype)initWithCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
{
    if ((self = [super init])) {
        _buffer = commandBuffer;
    }
    return self;
}

- (instancetype)init
{
    NSLog(@"MPSCommandBuffer: -init makes no command buffer; use +commandBufferWithCommandBuffer: or -initWithCommandBuffer:");
    return nil;
}

- (id<MTLCommandBuffer>)commandBuffer
{
    return _buffer;
}

- (id<MTLCommandBuffer>)rootCommandBuffer
{
    id<MTLCommandBuffer> root = _buffer;
    while ([root isKindOfClass:[MPSCommandBuffer class]])
        root = [(MPSCommandBuffer *)root commandBuffer];
    return root;
}

- (MPSPredicate *)predicate
{
    return _predicate;
}

- (void)setPredicate:(MPSPredicate *)predicate
{
    _predicate = predicate;
}

- (id<MPSHeapProvider>)heapProvider
{
    return _heapProvider;
}

- (void)setHeapProvider:(id<MPSHeapProvider>)heapProvider
{
    _heapProvider = heapProvider;
}

- (void)commitAndContinue
{
    if ([_buffer respondsToSelector:@selector(commitAndContinue)])
        [(id<CharonMPSCommitAndContinuing>)_buffer commitAndContinue];
    else
        [_buffer commit];
}

- (void)prefetchHeapForWorkloadSize:(size_t)size
{
    (void)size;
}

- (id<MTLDevice>)device
{
    return [_buffer device];
}

- (id<MTLCommandQueue>)commandQueue
{
    return [_buffer commandQueue];
}

- (BOOL)retainedReferences
{
    return [_buffer retainedReferences];
}

- (MTLCommandBufferErrorOption)errorOptions
{
    return [_buffer errorOptions];
}

- (NSString *)label
{
    return [_buffer label];
}

- (void)setLabel:(NSString *)label
{
    [_buffer setLabel:label];
}

- (CFTimeInterval)kernelStartTime
{
    return [_buffer kernelStartTime];
}

- (CFTimeInterval)kernelEndTime
{
    return [_buffer kernelEndTime];
}

- (id<MTLLogContainer>)logs
{
    return [_buffer logs];
}

- (CFTimeInterval)GPUStartTime
{
    return [_buffer GPUStartTime];
}

- (CFTimeInterval)GPUEndTime
{
    return [_buffer GPUEndTime];
}

- (MTLCommandBufferStatus)status
{
    return [_buffer status];
}

- (NSError *)error
{
    return [_buffer error];
}

- (void)enqueue
{
    [_buffer enqueue];
}

- (void)commit
{
    [_buffer commit];
}

- (void)addScheduledHandler:(MTLCommandBufferHandler)block
{
    [_buffer addScheduledHandler:block];
}

- (void)addCompletedHandler:(MTLCommandBufferHandler)block
{
    [_buffer addCompletedHandler:block];
}

- (void)presentDrawable:(id<MTLDrawable>)drawable
{
    [_buffer presentDrawable:drawable];
}

- (void)presentDrawable:(id<MTLDrawable>)drawable atTime:(CFTimeInterval)presentationTime
{
    [_buffer presentDrawable:drawable atTime:presentationTime];
}

- (void)presentDrawable:(id<MTLDrawable>)drawable afterMinimumDuration:(CFTimeInterval)duration
{
    [_buffer presentDrawable:drawable afterMinimumDuration:duration];
}

- (void)waitUntilScheduled
{
    [_buffer waitUntilScheduled];
}

- (void)waitUntilCompleted
{
    [_buffer waitUntilCompleted];
}

- (void)pushDebugGroup:(NSString *)string
{
    [_buffer pushDebugGroup:string];
}

- (void)popDebugGroup
{
    [_buffer popDebugGroup];
}

- (void)setDebugMarker:(NSString *)string
{
    if ([_buffer respondsToSelector:@selector(setDebugMarker:)])
        [(id<CharonMPSCommandBufferDebugging>)_buffer setDebugMarker:string];
}

- (void)insertDebugMarker:(NSString *)string
{
    if ([_buffer respondsToSelector:@selector(insertDebugMarker:)])
        [(id<CharonMPSCommandBufferDebugging>)_buffer insertDebugMarker:string];
}

- (NSArray<NSString *> *)bufferLabels
{
    if ([_buffer respondsToSelector:@selector(bufferLabels)])
        return [(id<CharonMPSCommandBufferDebugging>)_buffer bufferLabels];
    return nil;
}

- (void)setBufferLabels:(NSArray<NSString *> *)labels
{
    if ([_buffer respondsToSelector:@selector(setBufferLabels:)])
        [(id<CharonMPSCommandBufferDebugging>)_buffer setBufferLabels:labels];
}

- (MTLRenderPassDescriptor *)currentRenderPassDescriptor
{
    if ([_buffer respondsToSelector:@selector(currentRenderPassDescriptor)])
        return [(id<CharonMPSCommandBufferDebugging>)_buffer currentRenderPassDescriptor];
    return nil;
}

- (void)memoryBarrierWithResources:(NSArray<id<MTLResource>> *)resources
{
    if ([_buffer respondsToSelector:@selector(memoryBarrierWithResources:)])
        [(id<CharonMPSCommandBufferDebugging>)_buffer memoryBarrierWithResources:resources];
}

@end
