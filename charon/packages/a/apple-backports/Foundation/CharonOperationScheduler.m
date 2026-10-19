#import "CharonOperationScheduler.h"

NSString *const CharonCurrentOperationQueueKey = @"CharonCurrentOperationQueue";

@implementation CharonOperationScheduler {
@private
    dispatch_queue_t _queue;
    __weak NSOperationQueue *_owner;
    NSCondition *_condition;
    NSMutableArray *_pending;
    NSMutableArray *_running;
    NSMutableArray *_arrival;
    BOOL _suspended;
    NSInteger _maxConcurrent;
}

- (instancetype)initWithDispatchQueue:(dispatch_queue_t)queue owner:(NSOperationQueue *)owner
{
    if ((self = [super init])) {
        _queue = queue;
#if !OS_OBJECT_USE_OBJC
        dispatch_retain(_queue);
#endif
        _owner = owner;
        _condition = [[NSCondition alloc] init];
        _pending = [NSMutableArray array];
        _running = [NSMutableArray array];
        _arrival = [NSMutableArray array];
        _maxConcurrent = NSOperationQueueDefaultMaxConcurrentOperationCount;
    }
    return self;
}

- (void)dealloc
{
#if !OS_OBJECT_USE_OBJC
    dispatch_release(_queue);
#endif
}

- (dispatch_queue_t)dispatchQueue
{
    return _queue;
}

- (BOOL)suspended
{
    [_condition lock];
    BOOL value = _suspended;
    [_condition unlock];
    return value;
}

- (void)setSuspended:(BOOL)suspended
{
    [_condition lock];
    _suspended = suspended;
    [_condition unlock];
    [self pump];
}

- (NSInteger)maxConcurrentOperationCount
{
    [_condition lock];
    NSInteger value = _maxConcurrent;
    [_condition unlock];
    return value;
}

- (void)setMaxConcurrentOperationCount:(NSInteger)count
{
    [_condition lock];
    _maxConcurrent = count;
    [_condition unlock];
    [self pump];
}

- (void)addOperation:(NSOperation *)operation
{
    if (operation.isFinished)
        [NSException raise:NSInvalidArgumentException format:@"*** -[NSOperationQueue addOperation:]: operation is finished and cannot be enqueued"];
    [operation addObserver:self forKeyPath:@"isFinished" options:0 context:NULL];
    [operation addObserver:self forKeyPath:@"isReady" options:0 context:NULL];
    [_condition lock];
    [_pending addObject:operation];
    [_arrival addObject:operation];
    [_condition unlock];
    [self pump];
}

- (NSArray *)operations
{
    [_condition lock];
    NSMutableArray *found = [NSMutableArray array];
    for (NSOperation *operation in _arrival)
        if (!operation.isFinished)
            [found addObject:operation];
    [_condition unlock];
    return found;
}

- (NSUInteger)operationCount
{
    return [self operations].count;
}

- (void)cancelAllOperations
{
    [_condition lock];
    NSArray *all = [_arrival copy];
    [_condition unlock];
    for (NSOperation *operation in all)
        [operation cancel];
    [self pump];
}

- (void)waitUntilAllOperationsAreFinished
{
    [_condition lock];
    while (_pending.count || _running.count)
        [_condition wait];
    [_condition unlock];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    [self pump];
}

- (NSOperation *)nextStartable
{
    NSOperation *best = nil;
    for (NSOperation *operation in _pending) {
        if (!operation.isReady && !operation.isCancelled)
            continue;
        if (!best || operation.queuePriority > best.queuePriority)
            best = operation;
    }
    return best;
}

- (void)pump
{
    NSMutableArray *starting = [NSMutableArray array];
    NSMutableArray *forgotten = [NSMutableArray array];
    [_condition lock];
    for (NSOperation *operation in [_running copy]) {
        if (operation.isFinished) {
            [_running removeObjectIdenticalTo:operation];
            [_arrival removeObjectIdenticalTo:operation];
            [forgotten addObject:operation];
        }
    }
    for (NSOperation *operation in [_pending copy]) {
        if (operation.isFinished) {
            [_pending removeObjectIdenticalTo:operation];
            [_arrival removeObjectIdenticalTo:operation];
            [forgotten addObject:operation];
        }
    }
    NSInteger limit = _maxConcurrent < 0 ? NSIntegerMax : _maxConcurrent;
    while (!_suspended && (NSInteger)_running.count < limit) {
        NSOperation *next = [self nextStartable];
        if (!next)
            break;
        [_pending removeObjectIdenticalTo:next];
        [_running addObject:next];
        [starting addObject:next];
    }
    if (!_pending.count && !_running.count)
        [_condition broadcast];
    [_condition unlock];
    for (NSOperation *operation in forgotten) {
        [operation removeObserver:self forKeyPath:@"isFinished"];
        [operation removeObserver:self forKeyPath:@"isReady"];
    }
    for (NSOperation *operation in starting) {
        NSOperationQueue *owner = _owner;
        dispatch_async(_queue, ^{
            NSMutableDictionary *thread = [[NSThread currentThread] threadDictionary];
            id previous = thread[CharonCurrentOperationQueueKey];
            if (owner)
                thread[CharonCurrentOperationQueueKey] = owner;
            [operation start];
            if (previous)
                thread[CharonCurrentOperationQueueKey] = previous;
            else
                [thread removeObjectForKey:CharonCurrentOperationQueueKey];
            [self pump];
        });
    }
}

@end
