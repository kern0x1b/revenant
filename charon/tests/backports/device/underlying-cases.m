#import <Foundation/Foundation.h>
#import "underlying-cases.h"

static const void *UnderlyingKey = &UnderlyingKey;

@interface UnderlyingAsync : NSOperation {
    BOOL _executing;
    BOOL _finished;
}
@property (nonatomic, copy) void (^body)(void);
@end

@implementation UnderlyingAsync
- (BOOL)isAsynchronous { return YES; }
- (BOOL)isConcurrent { return YES; }
- (BOOL)isExecuting { return _executing; }
- (BOOL)isFinished { return _finished; }
- (void)start
{
    [self willChangeValueForKey:@"isExecuting"];
    _executing = YES;
    [self didChangeValueForKey:@"isExecuting"];
    if (self.body)
        self.body();
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(40 * NSEC_PER_MSEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self willChangeValueForKey:@"isExecuting"];
        [self willChangeValueForKey:@"isFinished"];
        self->_executing = NO;
        self->_finished = YES;
        [self didChangeValueForKey:@"isExecuting"];
        [self didChangeValueForKey:@"isFinished"];
    });
}
@end

static void wait_ms(int milliseconds)
{
    usleep(milliseconds * 1000);
}

static NSString *exception_text(void (^block)(void))
{
    @try {
        block();
    } @catch (NSException *exception) {
        return [NSString stringWithFormat:@"%@ | %@", exception.name, exception.reason];
    }
    return @"none";
}

void underlying_run(NSOperationQueue *(^make)(void), UnderlyingRecorder record)
{
    dispatch_queue_t serial = dispatch_queue_create("charon.underlying.serial", DISPATCH_QUEUE_SERIAL);
    dispatch_queue_set_specific(serial, UnderlyingKey, (void *)1, NULL);
    dispatch_queue_t global = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    NSLock *lock = [[NSLock alloc] init];

    NSOperationQueue *queue = make();
    record(@"default", [NSString stringWithFormat:@"%d max=%ld", queue.underlyingQueue == nil, (long)queue.maxConcurrentOperationCount]);
    queue.underlyingQueue = serial;
    record(@"set", [NSString stringWithFormat:@"%d max=%ld", queue.underlyingQueue == serial, (long)queue.maxConcurrentOperationCount]);
    __block int onQueue = 0;
    [queue addOperationWithBlock:^{ onQueue = dispatch_get_specific(UnderlyingKey) != NULL; }];
    [queue waitUntilAllOperationsAreFinished];
    record(@"runsOnQueue", [NSString stringWithFormat:@"%d", onQueue]);
    queue.underlyingQueue = nil;
    record(@"cleared", [NSString stringWithFormat:@"%d", queue.underlyingQueue == nil]);
    __block int native = 0;
    [queue addOperationWithBlock:^{ native = dispatch_get_specific(UnderlyingKey) != NULL ? 2 : 1; }];
    [queue waitUntilAllOperationsAreFinished];
    record(@"afterCleared", [NSString stringWithFormat:@"%d", native]);

    for (NSArray *setup in @[@[@"serial", @5], @[@"global2", @2], @[@"globalDefault", @-1]]) {
        NSOperationQueue *q = make();
        q.underlyingQueue = [setup[0] isEqualToString:@"serial"] ? serial : global;
        q.maxConcurrentOperationCount = [setup[1] integerValue];
        __block int running = 0, maxRunning = 0;
        for (int index = 0; index < 8; index++)
            [q addOperationWithBlock:^{
                [lock lock]; running++; if (running > maxRunning) maxRunning = running; [lock unlock];
                wait_ms(30);
                [lock lock]; running--; [lock unlock];
            }];
        [q waitUntilAllOperationsAreFinished];
        record([@"concurrency." stringByAppendingString:setup[0]], [setup[0] isEqualToString:@"globalDefault"] ? [NSString stringWithFormat:@"more=%d", maxRunning > 1] : [NSString stringWithFormat:@"%d", maxRunning]);
    }

    NSOperationQueue *busy = make();
    busy.suspended = YES;
    [busy addOperationWithBlock:^{}];
    record(@"setWithOperations", exception_text(^{ busy.underlyingQueue = serial; }));
    busy.suspended = NO;
    [busy waitUntilAllOperationsAreFinished];
    record(@"setAfterFinished", exception_text(^{ busy.underlyingQueue = serial; }));
    NSOperationQueue *running = make();
    [running addOperationWithBlock:^{ wait_ms(150); }];
    wait_ms(40);
    record(@"setWhileRunning", exception_text(^{ running.underlyingQueue = serial; }));
    [running waitUntilAllOperationsAreFinished];

    NSOperationQueue *ordered = make();
    ordered.underlyingQueue = serial;
    ordered.suspended = YES;
    NSMutableArray *order = [NSMutableArray array];
    NSBlockOperation *a = [NSBlockOperation blockOperationWithBlock:^{ @synchronized (order) { [order addObject:@"a"]; } }];
    NSBlockOperation *b = [NSBlockOperation blockOperationWithBlock:^{ @synchronized (order) { [order addObject:@"b"]; } }];
    NSBlockOperation *c = [NSBlockOperation blockOperationWithBlock:^{ @synchronized (order) { [order addObject:@"c"]; } }];
    NSBlockOperation *d = [NSBlockOperation blockOperationWithBlock:^{ @synchronized (order) { [order addObject:@"d"]; } }];
    b.queuePriority = NSOperationQueuePriorityHigh;
    c.queuePriority = NSOperationQueuePriorityLow;
    [a addDependency:d];
    [ordered addOperations:@[a, b, c, d] waitUntilFinished:NO];
    record(@"suspended", [NSString stringWithFormat:@"count=%lu operations=%lu suspended=%d ran=%lu", (unsigned long)ordered.operationCount, (unsigned long)ordered.operations.count, ordered.isSuspended, (unsigned long)order.count]);
    ordered.suspended = NO;
    [ordered waitUntilAllOperationsAreFinished];
    record(@"order", [order componentsJoinedByString:@""]);

    NSOperationQueue *cancelled = make();
    cancelled.underlyingQueue = serial;
    cancelled.suspended = YES;
    __block int ran = 0;
    NSBlockOperation *x = [NSBlockOperation blockOperationWithBlock:^{ ran++; }];
    [cancelled addOperation:x];
    [cancelled cancelAllOperations];
    cancelled.suspended = NO;
    [cancelled waitUntilAllOperationsAreFinished];
    record(@"cancel", [NSString stringWithFormat:@"ran=%d finished=%d cancelled=%d count=%lu", ran, x.isFinished, x.isCancelled, (unsigned long)cancelled.operationCount]);

    NSOperationQueue *counting = make();
    counting.underlyingQueue = serial;
    counting.name = @"counting";
    [counting addOperationWithBlock:^{ wait_ms(80); }];
    NSString *during = [NSString stringWithFormat:@"%lu %lu", (unsigned long)counting.operationCount, (unsigned long)counting.operations.count];
    [counting waitUntilAllOperationsAreFinished];
    record(@"counts", [NSString stringWithFormat:@"during=%@ after=%lu %lu name=%@", during, (unsigned long)counting.operationCount, (unsigned long)counting.operations.count, counting.name]);
    NSBlockOperation *done = [NSBlockOperation blockOperationWithBlock:^{}];
    [counting addOperation:done];
    [counting waitUntilAllOperationsAreFinished];
    record(@"addFinished", exception_text(^{ [counting addOperation:done]; }));

    NSOperationQueue *waiting = make();
    waiting.underlyingQueue = serial;
    NSMutableArray *finishing = [NSMutableArray array];
    NSBlockOperation *slow = [NSBlockOperation blockOperationWithBlock:^{ wait_ms(30); @synchronized (finishing) { [finishing addObject:@"slow"]; } }];
    NSBlockOperation *quick = [NSBlockOperation blockOperationWithBlock:^{ @synchronized (finishing) { [finishing addObject:@"quick"]; } }];
    [waiting addOperations:@[slow, quick] waitUntilFinished:YES];
    record(@"addOperationsWait", [finishing componentsJoinedByString:@","]);

    NSOperationQueue *held = make();
    held.underlyingQueue = global;
    held.maxConcurrentOperationCount = 1;
    NSMutableArray *starts = [NSMutableArray array];
    UnderlyingAsync *first = [[UnderlyingAsync alloc] init];
    first.body = ^{ @synchronized (starts) { [starts addObject:@"first"]; } };
    UnderlyingAsync *second = [[UnderlyingAsync alloc] init];
    second.body = ^{ @synchronized (starts) { [starts addObject:@"second"]; } };
    [held addOperation:first];
    [held addOperation:second];
    wait_ms(15);
    NSString *early = [starts componentsJoinedByString:@","];
    [held waitUntilAllOperationsAreFinished];
    record(@"asynchronous", [NSString stringWithFormat:@"early=%@ all=%@ finished=%d %d", early, [starts componentsJoinedByString:@","], first.isFinished, second.isFinished]);

    NSOperationQueue *limited = make();
    limited.underlyingQueue = global;
    limited.suspended = YES;
    limited.maxConcurrentOperationCount = 1;
    NSMutableArray *sequence = [NSMutableArray array];
    for (int index = 0; index < 4; index++)
        [limited addOperationWithBlock:^{ @synchronized (sequence) { [sequence addObject:@(index)]; } wait_ms(10); }];
    limited.suspended = NO;
    [limited waitUntilAllOperationsAreFinished];
    record(@"limitedOrder", [sequence componentsJoinedByString:@""]);
    limited.maxConcurrentOperationCount = 3;
    record(@"limitRead", [NSString stringWithFormat:@"%ld", (long)limited.maxConcurrentOperationCount]);

    NSOperationQueue *gate = make();
    gate.underlyingQueue = serial;
    gate.suspended = YES;
    __block int gated = 0;
    [gate addOperationWithBlock:^{ gated++; }];
    wait_ms(60);
    int whileSuspended = gated;
    gate.suspended = NO;
    [gate waitUntilAllOperationsAreFinished];
    record(@"suspend", [NSString stringWithFormat:@"before=%d after=%d", whileSuspended, gated]);
}
