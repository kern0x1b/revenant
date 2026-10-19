#import "CharonMetal.h"
#import "CharonMetalDebugGroups.h"

#pragma clang diagnostic ignored "-Wprotocol"
#pragma clang diagnostic ignored "-Wincomplete-implementation"

// The command queue and the command buffer of the port. The encoders of this port do their work as
// they are encoded (the OpenGL ES 2.0 calls and the CPU kernels run inside -[encoder draw...] and
// -[encoder dispatch...]), so a command buffer's work is already done when it is committed. What a
// commit still decides is the buffer's life as Metal reports it: it is scheduled, then completed, the
// handlers the application added run at those two points in that order, and the times the work
// started and ended are read from the same clock. facts/Metal/CommandBuffer.md is the whole of it.

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

// A buffer answers the times of its work only once it has completed, as Metal does: before that the
// work has not been timed, and an answer would be a number of a run that has not finished.
- (CFTimeInterval)charonStartTime
{
    return _status == MTLCommandBufferStatusCompleted ? _startTime : 0;
}

- (CFTimeInterval)charonEndTime
{
    return _status == MTLCommandBufferStatusCompleted ? _endTime : 0;
}

// The first encoder a buffer vends is where its work starts, since the port runs each command as it
// is encoded; a buffer that encodes nothing starts when it is committed.
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

// A handler added after the point it names has passed. Metal asserts here and the process aborts
// (measured on the host, facts/Metal/CommandBuffer.md), and an API must not abort its caller, so the
// port logs the mistake and calls the handler at once, which is the one call the caller can still get.
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

// A wait for a buffer that was never committed would block for ever in Metal, because nothing on this
// thread can commit it while it waits. The port says so instead of hanging the caller.
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

// The encoder of the port runs a workgroup as one thread per thread of the group, with a rendezvous
// of a mutex and a condition variable, because iOS 6 has no pthread_barrier and a group run one
// thread after another would let a thread past a barrier before its neighbours had written.
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
