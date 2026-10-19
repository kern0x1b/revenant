#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static char CharonQueueStateKey;
static char CharonOperationPreparedKey;

__attribute__((visibility("hidden")))
@interface CharonBarrierGate : NSOperation
- (void)finish;
- (void)charon_wait;
@end

@implementation CharonBarrierGate {
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

- (void)charon_wait
{
    [_condition lock];
    while (!_done)
        [_condition wait];
    [_condition unlock];
}

@end

__attribute__((visibility("hidden")))
@interface CharonQueueState : NSObject {
@package
    NSMutableArray *_gates;
    NSProgress *_progress;
}
@end

@implementation CharonQueueState

- (instancetype)init
{
    if ((self = [super init]))
        _gates = [NSMutableArray array];
    return self;
}

@end

static NSOperationQueue *charon_tick_queue(void)
{
    static NSOperationQueue *queue;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        queue = [[NSOperationQueue alloc] init];
        queue.maxConcurrentOperationCount = 1;
        queue.name = @"charon.operationqueue.progress";
    });
    return queue;
}

static CharonQueueState *charon_queue_state(NSOperationQueue *queue, BOOL create)
{
    @synchronized (queue) {
        CharonQueueState *state = objc_getAssociatedObject(queue, &CharonQueueStateKey);
        if (!state && create) {
            state = [[CharonQueueState alloc] init];
            objc_setAssociatedObject(queue, &CharonQueueStateKey, state, OBJC_ASSOCIATION_RETAIN);
        }
        return state;
    }
}

static void charon_queue_count(CharonQueueState *state, NSOperation *operation)
{
    NSProgress *progress = state->_progress;
    NSBlockOperation *tick = [NSBlockOperation blockOperationWithBlock:^{
        if (!operation.isCancelled && progress.totalUnitCount > 0)
            progress.completedUnitCount += 1;
    }];
    [tick addDependency:operation];
    [charon_tick_queue() addOperation:tick];
}

static void charon_queue_prepare(NSOperationQueue *queue, NSOperation *operation)
{
    CharonQueueState *state = charon_queue_state(queue, NO);
    if (!state || objc_getAssociatedObject(operation, &CharonOperationPreparedKey))
        return;
    CharonBarrierGate *gate = nil;
    @synchronized (state) {
        gate = state->_gates.lastObject;
    }
    if (gate && !operation.isExecuting && !operation.isFinished)
        [operation addDependency:gate];
    if (state->_progress)
        charon_queue_count(state, operation);
    objc_setAssociatedObject(operation, &CharonOperationPreparedKey, @YES, OBJC_ASSOCIATION_RETAIN);
}

static void charon_queue_hook(SEL selector, IMP (^make)(IMP original, SEL selector))
{
    Class cls = [NSOperationQueue class];
    Method method = class_getInstanceMethod(cls, selector);
    if (!method)
        return;
    class_replaceMethod(cls, selector, make(method_getImplementation(method), selector), method_getTypeEncoding(method));
}

static void charon_queue_install(void)
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        charon_queue_hook(@selector(addOperation:), ^IMP(IMP original, SEL selector) {
            return imp_implementationWithBlock(^(NSOperationQueue *queue, NSOperation *operation) {
                charon_queue_prepare(queue, operation);
                ((void (*)(id, SEL, id))original)(queue, selector, operation);
            });
        });
        charon_queue_hook(@selector(addOperations:waitUntilFinished:), ^IMP(IMP original, SEL selector) {
            return imp_implementationWithBlock(^(NSOperationQueue *queue, NSArray *operations, BOOL wait) {
                for (NSOperation *operation in operations)
                    charon_queue_prepare(queue, operation);
                ((void (*)(id, SEL, id, BOOL))original)(queue, selector, operations, wait);
            });
        });
        charon_queue_hook(@selector(addOperationWithBlock:), ^IMP(IMP original, SEL selector) {
            return imp_implementationWithBlock(^(NSOperationQueue *queue, void (^block)(void)) {
                CharonQueueState *state = charon_queue_state(queue, NO);
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
        charon_queue_hook(@selector(cancelAllOperations), ^IMP(IMP original, SEL selector) {
            return imp_implementationWithBlock(^(NSOperationQueue *queue) {
                CharonQueueState *state = charon_queue_state(queue, NO);
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
        charon_queue_hook(@selector(waitUntilAllOperationsAreFinished), ^IMP(IMP original, SEL selector) {
            return imp_implementationWithBlock(^(NSOperationQueue *queue) {
                ((void (*)(id, SEL))original)(queue, selector);
                CharonQueueState *state = charon_queue_state(queue, NO);
                for (;;) {
                    CharonBarrierGate *gate = nil;
                    if (state) {
                        @synchronized (state) {
                            gate = state->_gates.lastObject;
                        }
                    }
                    if (!gate)
                        return;
                    [gate charon_wait];
                    ((void (*)(id, SEL))original)(queue, selector);
                }
            });
        });
    });
}

@implementation NSOperationQueue (CharonBarrier)

- (void)addBarrierBlock:(void (^)(void))barrier
{
    if (!barrier)
        [NSException raise:NSInvalidArgumentException format:@"*** -[NSOperationQueue addBarrierBlock:]: block cannot be nil"];
    charon_queue_install();
    CharonQueueState *state = charon_queue_state(self, YES);
    void (^block)(void) = [barrier copy];
    CharonBarrierGate *gate = [[CharonBarrierGate alloc] init];
    NSArray *waits;
    CharonBarrierGate *previous;
    @synchronized (state) {
        waits = [[self operations] copy];
        previous = state->_gates.lastObject;
        [state->_gates addObject:gate];
    }
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        for (NSOperation *operation in waits)
            [operation waitUntilFinished];
        [previous charon_wait];
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
    CharonQueueState *state = charon_queue_state(self, YES);
    NSProgress *created = nil;
    @synchronized (state) {
        if (state->_progress)
            return state->_progress;
        created = [NSProgress discreteProgressWithTotalUnitCount:0];
        created.cancellable = YES;
        created.pausable = NO;
        state->_progress = created;
    }
    charon_queue_install();
    for (NSOperation *operation in [self operations])
        charon_queue_prepare(self, operation);
    return created;
}

@end
