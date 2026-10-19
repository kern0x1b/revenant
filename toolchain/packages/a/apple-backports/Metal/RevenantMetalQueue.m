#import "CharonMetal.h"
#import "CharonMetalDebugGroups.h"

#pragma clang diagnostic ignored "-Wprotocol"
#pragma clang diagnostic ignored "-Wincomplete-implementation"

@implementation CharonMetalQueue

@synthesize label;

- (id<MTLDevice>)device
{
    return [CharonMetalDevice shared];
}

- (id<MTLCommandBuffer>)commandBuffer
{
    return [self charonCommandBufferRetainingReferences:YES errorOptions:MTLCommandBufferErrorOptionNone];
}

- (id<MTLCommandBuffer>)commandBufferWithUnretainedReferences
{
    return [self charonCommandBufferRetainingReferences:NO errorOptions:MTLCommandBufferErrorOptionNone];
}

- (id<MTLCommandBuffer>)charonCommandBufferRetainingReferences:(BOOL)retaining errorOptions:(MTLCommandBufferErrorOption)options
{
    return (id<MTLCommandBuffer>)[[CharonMetalCommandBuffer alloc] initWithQueue:self retainingReferences:retaining errorOptions:options];
}

@end

@implementation CharonMetalCommandBuffer {
    CharonMetalQueue *_queue;
    BOOL _retainingReferences;
    MTLCommandBufferErrorOption _errorOptions;
    id<MTLDrawable> _drawable;
    NSMutableArray *_scheduled;
    NSMutableArray *_completed;
    NSMutableArray *_groups;
    MTLCommandBufferStatus _status;
    NSError *_error;
    CFTimeInterval _startTime;
    CFTimeInterval _endTime;
}

@synthesize label;

- (instancetype)init
{
    return [self initWithQueue:nil retainingReferences:YES errorOptions:MTLCommandBufferErrorOptionNone];
}

- (instancetype)initWithQueue:(CharonMetalQueue *)queue retainingReferences:(BOOL)retaining errorOptions:(MTLCommandBufferErrorOption)options
{
    if ((self = [super init])) {
        _queue = queue;
        _retainingReferences = retaining;
        _errorOptions = options;
        _scheduled = [NSMutableArray array];
        _completed = [NSMutableArray array];
        _groups = [NSMutableArray array];
        _status = MTLCommandBufferStatusNotEnqueued;
    }
    return self;
}

- (id<MTLDevice>)device
{
    return [CharonMetalDevice shared];
}

- (id<MTLCommandQueue>)commandQueue
{
    return (id<MTLCommandQueue>)_queue;
}

- (MTLCommandBufferStatus)status
{
    return _status;
}

- (NSError *)error
{
    return _error;
}

- (BOOL)retainedReferences
{
    return _retainingReferences;
}

- (MTLCommandBufferErrorOption)charonErrorOptions
{
    return _errorOptions;
}

- (CFTimeInterval)charonStartTime
{
    return _status == MTLCommandBufferStatusCompleted ? _startTime : 0;
}

- (CFTimeInterval)charonEndTime
{
    return _status == MTLCommandBufferStatusCompleted ? _endTime : 0;
}

- (void)charonBeginWork
{
    if (!_startTime)
        _startTime = CACurrentMediaTime();
}

- (void)enqueue
{
    if (_status == MTLCommandBufferStatusNotEnqueued)
        _status = MTLCommandBufferStatusEnqueued;
}

- (void)commit
{
    if (_status != MTLCommandBufferStatusNotEnqueued && _status != MTLCommandBufferStatusEnqueued) {
        NSLog(@"Metal: a command buffer is committed once, and this one was committed already (status %ld)", (long)_status);
        return;
    }
    _status = MTLCommandBufferStatusCommitted;
    CharonMetalDevice *device = [CharonMetalDevice shared];
    [device acquire];
    [self charonBeginWork];
    if (_drawable)
        [_drawable present];
    glFlush();
    [device relinquish];
    _endTime = CACurrentMediaTime();
    _status = MTLCommandBufferStatusScheduled;
    for (void (^handler)(id<MTLCommandBuffer>) in _scheduled)
        handler(self);
    _status = MTLCommandBufferStatusCompleted;
    for (void (^handler)(id<MTLCommandBuffer>) in _completed)
        handler(self);
}

- (void)addScheduledHandler:(MTLCommandBufferHandler)block
{
    if (_status >= MTLCommandBufferStatusScheduled) {
        NSLog(@"Metal: a scheduled handler was added after the command buffer was committed; Metal aborts there, the port calls it now");
        block(self);
        return;
    }
    [_scheduled addObject:[block copy]];
}

- (void)addCompletedHandler:(MTLCommandBufferHandler)block
{
    if (_status == MTLCommandBufferStatusCompleted) {
        NSLog(@"Metal: a completed handler was added after the command buffer was committed; Metal aborts there, the port calls it now");
        block(self);
        return;
    }
    [_completed addObject:[block copy]];
}

- (void)presentDrawable:(id<MTLDrawable>)drawable
{
    _drawable = drawable;
}

- (void)presentDrawable:(id<MTLDrawable>)drawable atTime:(CFTimeInterval)presentationTime
{
    _drawable = drawable;
}

- (void)presentDrawable:(id<MTLDrawable>)drawable afterMinimumDuration:(CFTimeInterval)duration
{
    _drawable = drawable;
}

- (void)waitUntilScheduled
{
    if (_status < MTLCommandBufferStatusCommitted)
        NSLog(@"Metal: waitUntilScheduled on a command buffer that was never committed: it would wait for ever");
}

- (void)waitUntilCompleted
{
    if (_status < MTLCommandBufferStatusCommitted) {
        NSLog(@"Metal: waitUntilCompleted on a command buffer that was never committed: it would wait for ever");
        return;
    }
    CharonMetalDevice *device = [CharonMetalDevice shared];
    [device acquire];
    glFinish();
    [device relinquish];
}

- (void)charonPushDebugGroup:(NSString *)name
{
    CharonMetalPushDebugGroup(_groups, name);
}

- (void)charonPopDebugGroup
{
    CharonMetalPopDebugGroup(_groups, self);
}

- (id<MTLComputeCommandEncoder>)computeCommandEncoder
{
    [self charonBeginWork];
    return (id<MTLComputeCommandEncoder>)[[CharonMetalComputeEncoder alloc] init];
}

- (id<MTLBlitCommandEncoder>)blitCommandEncoder
{
    [self charonBeginWork];
    return (id<MTLBlitCommandEncoder>)[[CharonMetalBlitEncoder alloc] init];
}

- (id<MTLRenderCommandEncoder>)renderCommandEncoderWithDescriptor:(MTLRenderPassDescriptor *)renderPassDescriptor
{
    [self charonBeginWork];
    return (id<MTLRenderCommandEncoder>)[[CharonMetalEncoder alloc] initWithDescriptor:renderPassDescriptor];
}

@end
