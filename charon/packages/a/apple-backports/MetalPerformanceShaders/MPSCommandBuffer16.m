// MPSCommandBuffer, from the header of the SDK of iOS 16.4. One object per release: the band machinery keeps an
// object whole or drops it whole, so a file here carries the API of exactly one release.

#import "CharonMPS.h"

#pragma clang diagnostic ignored "-Wprotocol"
#pragma clang diagnostic ignored "-Wincomplete-implementation"

id<MTLDevice> MPSGetPreferredDevice(MPSDeviceOptions options)
{
    // The release walks its devices and returns the first that matches the options. This port has one
    // device and no removable or low-power choice among several, so the options have nothing to
    // choose between and the one device is the preferred one. MPSDeviceOptionsDefault is 0, and a
    // caller may pass any combination; none of them names a device this port does not have.
    (void)options;
    return MTLCreateSystemDefaultDevice();
}// -commitAndContinue arrived in iOS 14 and the SDK this package compiles against names it on
// MPSCommandBuffer but not on MTLCommandBuffer, so a wrapped command buffer is asked for it through
// this. The release forwards the message when the wrapped buffer has one and commits otherwise.
@protocol CharonMPSCommitAndContinuing <NSObject>
- (void)commitAndContinue;
@end
// The debug group, buffer label and memory barrier surface of MTLCommandBuffer arrived after the
// SDK this package compiles against declares it, so the wrapped buffer is asked for each of them
// through this, and a buffer that has none of them is not asked at all.
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
    // The header marks -init unavailable, so there is no command buffer to make without one to wrap.
    // This port answers a caller that reaches it anyway the way it answers every other unusable
    // request: nil, and a line in the log that says which initialiser is the one to use.
    NSLog(@"MPSCommandBuffer: -init makes no command buffer; use +commandBufferWithCommandBuffer: or -initWithCommandBuffer:");
    return nil;
}

- (id<MTLCommandBuffer>)commandBuffer
{
    return _buffer;
}

- (id<MTLCommandBuffer>)rootCommandBuffer
{
    // MPSCommandBuffers may wrap MPSCommandBuffers, so the root is the bottom of that stack.
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
    // The release warms its heap cache with a heap of at least this size. Every temporary matrix,
    // vector, image and state in this port is a device buffer made when its -data is asked for, and
    // the device's own allocator is what a heap here would be, so there is nothing to pre-warm: the
    // storage is the storage the device would have given the heap's sub-allocation.
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
