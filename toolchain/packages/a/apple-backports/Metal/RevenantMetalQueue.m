#import "RevenantMetal.h"
#import "RevenantMetalDebugGroups.h"

#pragma clang diagnostic ignored "-Wprotocol"
#pragma clang diagnostic ignored "-Wincomplete-implementation"

@implementation RevenantMetalQueue

@synthesize label;

- (id<MTLDevice>)device
{
    return [RevenantMetalDevice shared];
}

- (id<MTLCommandBuffer>)commandBuffer
{
    return [self revenantCommandBufferRetainingReferences:YES errorOptions:MTLCommandBufferErrorOptionNone];
}

- (id<MTLCommandBuffer>)commandBufferWithUnretainedReferences
{
    return [self revenantCommandBufferRetainingReferences:NO errorOptions:MTLCommandBufferErrorOptionNone];
}

- (id<MTLCommandBuffer>)revenantCommandBufferRetainingReferences:(BOOL)retaining errorOptions:(MTLCommandBufferErrorOption)options
{
    return (id<MTLCommandBuffer>)[[RevenantMetalCommandBuffer alloc] initWithQueue:self retainingReferences:retaining errorOptions:options];
}

@end

@implementation RevenantMetalCommandBuffer {
    RevenantMetalQueue *_queue;
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

- (instancetype)initWithQueue:(RevenantMetalQueue *)queue retainingReferences:(BOOL)retaining errorOptions:(MTLCommandBufferErrorOption)options
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
    return [RevenantMetalDevice shared];
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

- (MTLCommandBufferErrorOption)revenantErrorOptions
{
    return _errorOptions;
}

- (CFTimeInterval)revenantStartTime
{
    return _status == MTLCommandBufferStatusCompleted ? _startTime : 0;
}

- (CFTimeInterval)revenantEndTime
{
    return _status == MTLCommandBufferStatusCompleted ? _endTime : 0;
}

- (void)revenantBeginWork
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
    RevenantMetalDevice *device = [RevenantMetalDevice shared];
    [device acquire];
    [self revenantBeginWork];
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
    RevenantMetalDevice *device = [RevenantMetalDevice shared];
    [device acquire];
    glFinish();
    [device relinquish];
}

- (void)revenantPushDebugGroup:(NSString *)name
{
    RevenantMetalPushDebugGroup(_groups, name);
}

- (void)revenantPopDebugGroup
{
    RevenantMetalPopDebugGroup(_groups, self);
}

- (id<MTLComputeCommandEncoder>)computeCommandEncoder
{
    [self revenantBeginWork];
    return (id<MTLComputeCommandEncoder>)[[RevenantMetalComputeEncoder alloc] init];
}

- (id<MTLBlitCommandEncoder>)blitCommandEncoder
{
    [self revenantBeginWork];
    return (id<MTLBlitCommandEncoder>)[[RevenantMetalBlitEncoder alloc] init];
}

- (id<MTLRenderCommandEncoder>)renderCommandEncoderWithDescriptor:(MTLRenderPassDescriptor *)renderPassDescriptor
{
    [self revenantBeginWork];
    return (id<MTLRenderCommandEncoder>)[[RevenantMetalEncoder alloc] initWithDescriptor:renderPassDescriptor];
}

@end
