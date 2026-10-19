#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static char RevenantQueueStateKey;
static char RevenantOperationPreparedKey;

__attribute__((visibility("hidden")))
@interface RevenantBarrierGate : NSOperation
- (void)finish;
- (void)revenant_wait;
@end

@implementation RevenantBarrierGate {
    NSCondition *_condition;
    BOOL _done;
}

- (instancetype)init
{
    if ((self = [super init]))
        _condition = [[NSCondition alloc] init];
    return self;
}

- (BOOL)isConcurrent
{
    return YES;
}

- (BOOL)isAsynchronous
{
    return YES;
}

- (BOOL)isExecuting
{
    return NO;
}

- (BOOL)isFinished
{
    [_condition lock];
    BOOL done = _done;
    [_condition unlock];
    return done;
}

- (void)finish
{
    [self willChangeValueForKey:@"isFinished"];
    [_condition lock];
    _done = YES;
    [_condition broadcast];
    [_condition unlock];
    [self didChangeValueForKey:@"isFinished"];
}

- (void)revenant_wait
{
    [_condition lock];
    while (!_done)
        [_condition wait];
    [_condition unlock];
}

@end

__attribute__((visibility("hidden")))
@interface RevenantQueueState : NSObject {
@package
    NSMutableArray *_gates;
    NSProgress *_progress;
}
@end

@implementation RevenantQueueState

- (instancetype)init
{
    if ((self = [super init]))
        _gates = [NSMutableArray array];
    return self;
}

@end

static NSOperationQueue *revenant_tick_queue(void)
{
    static NSOperationQueue *queue;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        queue = [[NSOperationQueue alloc] init];
        queue.maxConcurrentOperationCount = 1;
        queue.name = @"revenant.operationqueue.progress";
    });
    return queue;
}

static RevenantQueueState *revenant_queue_state(NSOperationQueue *queue, BOOL create)
{
    @synchronized (queue) {
        RevenantQueueState *state = objc_getAssociatedObject(queue, &RevenantQueueStateKey);
        if (!state && create) {
            state = [[RevenantQueueState alloc] init];
            objc_setAssociatedObject(queue, &RevenantQueueStateKey, state, OBJC_ASSOCIATION_RETAIN);
        }
        return state;
    }
}

static void revenant_queue_count(RevenantQueueState *state, NSOperation *operation)
{
    NSProgress *progress = state->_progress;
    NSBlockOperation *tick = [NSBlockOperation blockOperationWithBlock:^{
        if (!operation.isCancelled && progress.totalUnitCount > 0)
            progress.completedUnitCount += 1;
    }];
    [tick addDependency:operation];
    [revenant_tick_queue() addOperation:tick];
}

static void revenant_queue_prepare(NSOperationQueue *queue, NSOperation *operation)
{
    RevenantQueueState *state = revenant_queue_state(queue, NO);
    if (!state || objc_getAssociatedObject(operation, &RevenantOperationPreparedKey))
        return;
    RevenantBarrierGate *gate = nil;
    @synchronized (state) {
        gate = state->_gates.lastObject;
    }
    if (gate && !operation.isExecuting && !operation.isFinished)
        [operation addDependency:gate];
    if (state->_progress)
        revenant_queue_count(state, operation);
    objc_setAssociatedObject(operation, &RevenantOperationPreparedKey, @YES, OBJC_ASSOCIATION_RETAIN);
}

static void revenant_queue_hook(SEL selector, IMP (^make)(IMP original, SEL selector))
{
    Class cls = [NSOperationQueue class];
    Method method = class_getInstanceMethod(cls, selector);
    if (!method)
        return;
    class_replaceMethod(cls, selector, make(method_getImplementation(method), selector), method_getTypeEncoding(method));
}

static void revenant_queue_install(void)
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        revenant_queue_hook(@selector(addOperation:), ^IMP(IMP original, SEL selector) {
            return imp_implementationWithBlock(^(NSOperationQueue *queue, NSOperation *operation) {
                revenant_queue_prepare(queue, operation);
                ((void (*)(id, SEL, id))original)(queue, selector, operation);
            });
        });
        revenant_queue_hook(@selector(addOperations:waitUntilFinished:), ^IMP(IMP original, SEL selector) {
            return imp_implementationWithBlock(^(NSOperationQueue *queue, NSArray *operations, BOOL wait) {
                for (NSOperation *operation in operations)
                    revenant_queue_prepare(queue, operation);
                ((void (*)(id, SEL, id, BOOL))original)(queue, selector, operations, wait);
            });
        });
        revenant_queue_hook(@selector(addOperationWithBlock:), ^IMP(IMP original, SEL selector) {
            return imp_implementationWithBlock(^(NSOperationQueue *queue, void (^block)(void)) {
                RevenantQueueState *state = revenant_queue_state(queue, NO);
                BOOL tracked = NO;
                if (state) {
                    @synchronized (state) {
                        tracked = state->_gates.count || state->_progress;
                    }
                }
                if (!tracked) {
                    ((void (*)(id, SEL, id))original)(queue, selector, block);
                    return;
                }
                [queue addOperation:[NSBlockOperation blockOperationWithBlock:block]];
            });
        });
        revenant_queue_hook(@selector(cancelAllOperations), ^IMP(IMP original, SEL selector) {
            return imp_implementationWithBlock(^(NSOperationQueue *queue) {
                RevenantQueueState *state = revenant_queue_state(queue, NO);
                NSArray *gates = nil;
                if (state) {
                    @synchronized (state) {
                        gates = [state->_gates copy];
                    }
                }
                for (NSOperation *gate in gates)
                    [gate cancel];
                ((void (*)(id, SEL))original)(queue, selector);
            });
        });
        revenant_queue_hook(@selector(waitUntilAllOperationsAreFinished), ^IMP(IMP original, SEL selector) {
            return imp_implementationWithBlock(^(NSOperationQueue *queue) {
                ((void (*)(id, SEL))original)(queue, selector);
                RevenantQueueState *state = revenant_queue_state(queue, NO);
                for (;;) {
                    RevenantBarrierGate *gate = nil;
                    if (state) {
                        @synchronized (state) {
                            gate = state->_gates.lastObject;
                        }
                    }
                    if (!gate)
                        return;
                    [gate revenant_wait];
                    ((void (*)(id, SEL))original)(queue, selector);
                }
            });
        });
    });
}

@implementation NSOperationQueue (RevenantBarrier)

- (void)addBarrierBlock:(void (^)(void))barrier
{
    if (!barrier)
        [NSException raise:NSInvalidArgumentException format:@"*** -[NSOperationQueue addBarrierBlock:]: block cannot be nil"];
    revenant_queue_install();
    RevenantQueueState *state = revenant_queue_state(self, YES);
    void (^block)(void) = [barrier copy];
    RevenantBarrierGate *gate = [[RevenantBarrierGate alloc] init];
    NSArray *waits;
    RevenantBarrierGate *previous;
    @synchronized (state) {
        waits = [[self operations] copy];
        previous = state->_gates.lastObject;
        [state->_gates addObject:gate];
    }
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        for (NSOperation *operation in waits)
            [operation waitUntilFinished];
        [previous revenant_wait];
        if (!gate.isCancelled)
            block();
        @synchronized (state) {
            [state->_gates removeObjectIdenticalTo:gate];
        }
        [gate finish];
    });
}

- (NSProgress *)progress
{
    RevenantQueueState *state = revenant_queue_state(self, YES);
    NSProgress *created = nil;
    @synchronized (state) {
        if (state->_progress)
            return state->_progress;
        created = [NSProgress discreteProgressWithTotalUnitCount:0];
        created.cancellable = YES;
        created.pausable = NO;
        state->_progress = created;
    }
    revenant_queue_install();
    for (NSOperation *operation in [self operations])
        revenant_queue_prepare(self, operation);
    return created;
}

@end
