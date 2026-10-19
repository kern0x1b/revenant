#import <Foundation/Foundation.h>
#import <objc/message.h>
#import "check.h"

static NSString *host_selector(NSString *name)
{
    return [@"charonHost" stringByAppendingString:[[name substringToIndex:1].uppercaseString stringByAppendingString:[name substringFromIndex:1]]];
}

static NSMutableArray *events;
static NSLock *lock;

static void note(NSString *text)
{
    [lock lock];
    [events addObject:text];
    [lock unlock];
}

static NSString *drain(NSTimeInterval wait)
{
    [NSThread sleepForTimeInterval:wait];
    [lock lock];
    NSString *joined = [events componentsJoinedByString:@","];
    [events removeAllObjects];
    [lock unlock];
    return joined;
}

static void barrier(NSOperationQueue *queue, BOOL port, void (^block)(void))
{
    if (port)
        ((void (*)(id, SEL, id))objc_msgSend)(queue, NSSelectorFromString(host_selector(@"addBarrierBlock:")), block);
    else
        [queue addBarrierBlock:block];
}

static NSProgress *progress(NSOperationQueue *queue, BOOL port)
{
    return port ? ((id (*)(id, SEL))objc_msgSend)(queue, NSSelectorFromString(host_selector(@"progress"))) : queue.progress;
}

static NSString *scenario(int which, BOOL port)
{
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [events removeAllObjects];
    switch (which) {
    case 0: {
        queue.maxConcurrentOperationCount = 4;
        for (int index = 0; index < 3; index++)
            [queue addOperationWithBlock:^{ [NSThread sleepForTimeInterval:0.05]; note(@"a"); }];
        barrier(queue, port, ^{ note(@"|"); [NSThread sleepForTimeInterval:0.05]; note(@"|"); });
        for (int index = 0; index < 3; index++)
            [queue addOperationWithBlock:^{ note(@"b"); }];
        return drain(0.6);
    }
    case 1: {
        queue.suspended = YES;
        [queue addOperationWithBlock:^{ note(@"op1"); }];
        barrier(queue, port, ^{ note(@"bar"); });
        [queue addOperationWithBlock:^{ note(@"op3"); }];
        [NSThread sleepForTimeInterval:0.2];
        note(@"resume");
        queue.suspended = NO;
        [queue waitUntilAllOperationsAreFinished];
        note(@"waited");
        return drain(0.3);
    }
    case 2: {
        queue.suspended = YES;
        barrier(queue, port, ^{ note(@"bar"); });
        [queue addOperationWithBlock:^{ note(@"op"); }];
        [NSThread sleepForTimeInterval:0.2];
        note(@"resume");
        queue.suspended = NO;
        [queue waitUntilAllOperationsAreFinished];
        note(@"waited");
        return drain(0.3);
    }
    case 3: {
        queue.suspended = YES;
        [queue addOperationWithBlock:^{ note(@"op1"); }];
        barrier(queue, port, ^{ note(@"bar"); });
        [queue addOperationWithBlock:^{ note(@"op3"); }];
        note([NSString stringWithFormat:@"count=%lu", (unsigned long)queue.operationCount]);
        [queue cancelAllOperations];
        queue.suspended = NO;
        [queue waitUntilAllOperationsAreFinished];
        return drain(0.4);
    }
    case 4: {
        queue.maxConcurrentOperationCount = 1;
        [queue addOperationWithBlock:^{ [NSThread sleepForTimeInterval:0.05]; note(@"x"); }];
        barrier(queue, port, ^{ note(@"bar"); });
        [queue addOperations:@[[NSBlockOperation blockOperationWithBlock:^{ note(@"w"); }]] waitUntilFinished:YES];
        return drain(0.2);
    }
    case 5: {
        __block NSString *thread = @"?";
        barrier(queue, port, ^{ thread = [NSThread isMainThread] ? @"main" : @"other"; note([NSString stringWithFormat:@"queue=%d", [NSOperationQueue currentQueue] == queue]); });
        [NSThread sleepForTimeInterval:0.2];
        note(thread);
        return drain(0.1);
    }
    case 6: {
        queue.maxConcurrentOperationCount = 4;
        for (int index = 0; index < 2; index++)
            [queue addOperationWithBlock:^{ [NSThread sleepForTimeInterval:0.05]; note(@"p"); }];
        barrier(queue, port, ^{ note(@"B1"); });
        barrier(queue, port, ^{ note(@"B2"); });
        [queue addOperationWithBlock:^{ note(@"q"); }];
        return drain(0.5);
    }
    case 7: {
        NSProgress *p = progress(queue, port);
        note([NSString stringWithFormat:@"same=%d total=%lld done=%lld ind=%d", p == progress(queue, port), p.totalUnitCount, p.completedUnitCount, p.indeterminate]);
        queue.suspended = YES;
        for (int index = 0; index < 3; index++)
            [queue addOperationWithBlock:^{}];
        p.totalUnitCount = 10;
        queue.suspended = NO;
        [queue waitUntilAllOperationsAreFinished];
        [NSThread sleepForTimeInterval:0.15];
        note([NSString stringWithFormat:@"total=%lld done=%lld", p.totalUnitCount, p.completedUnitCount]);
        NSOperation *cancelled = [NSBlockOperation blockOperationWithBlock:^{}];
        queue.suspended = YES;
        [queue addOperation:cancelled];
        [cancelled cancel];
        [queue addOperationWithBlock:^{}];
        queue.suspended = NO;
        [queue waitUntilAllOperationsAreFinished];
        [NSThread sleepForTimeInterval:0.15];
        note([NSString stringWithFormat:@"after cancelled done=%lld", p.completedUnitCount]);
        return drain(0.1);
    }
    case 8: {
        [queue addOperationWithBlock:^{}];
        [queue addOperationWithBlock:^{}];
        [queue waitUntilAllOperationsAreFinished];
        NSProgress *p = progress(queue, port);
        p.totalUnitCount = 5;
        [queue addOperationWithBlock:^{}];
        [queue waitUntilAllOperationsAreFinished];
        [NSThread sleepForTimeInterval:0.15];
        note([NSString stringWithFormat:@"late progress done=%lld", p.completedUnitCount]);
        NSOperationQueue *other = [[NSOperationQueue alloc] init];
        NSProgress *q = progress(other, port);
        [other addOperationWithBlock:^{}];
        [other waitUntilAllOperationsAreFinished];
        [NSThread sleepForTimeInterval:0.1];
        note([NSString stringWithFormat:@"no total done=%lld", q.completedUnitCount]);
        return drain(0.1);
    }
    default: {
        queue.suspended = YES;
        NSBlockOperation *first = [NSBlockOperation blockOperationWithBlock:^{ note(@"first"); }];
        [queue addOperation:first];
        barrier(queue, port, ^{ note(@"bar"); });
        NSBlockOperation *after = [NSBlockOperation blockOperationWithBlock:^{ note(@"after"); }];
        [queue addOperation:after];
        note([NSString stringWithFormat:@"deps=%lu ops=%lu", (unsigned long)first.dependencies.count, (unsigned long)queue.operations.count]);
        queue.suspended = NO;
        [queue waitUntilAllOperationsAreFinished];
        return drain(0.3);
    }
    }
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        events = [NSMutableArray array];
        lock = [[NSLock alloc] init];
        NSArray *names = @[@"a barrier waits for what came before and holds what comes after", @"a barrier behind an operation of a suspended queue waits for it", @"a barrier of a suspended queue with nothing before it runs at once", @"cancelling all operations cancels a barrier not yet run",
                           @"waiting for a queue waits for its barrier", @"a barrier does not run on the main thread nor as an operation of the queue", @"two barriers run one after the other", @"a queue's progress counts the operations that finish once it has a total",
                           @"only the operations that finish after the progress exists are counted", @"a barrier is not an operation of the queue"];
        for (int which = 0; which < 10; which++) {
            NSMutableSet *outcomes = [NSMutableSet set];
            NSString *a = nil, *b = nil;
            for (int round = 0; round < 3; round++) {
                a = scenario(which, YES);
                b = scenario(which, NO);
                [outcomes addObject:[a isEqualToString:b] ? @"same" : [NSString stringWithFormat:@"port [%@] system [%@]", a, b]];
            }
            BOOL same = outcomes.count == 1 && [outcomes containsObject:@"same"];
            if (!same && which == 0) {
                NSString *sortedA = [[[a componentsSeparatedByString:@","] sortedArrayUsingSelector:@selector(compare:)] componentsJoinedByString:@","];
                NSString *sortedB = [[[b componentsSeparatedByString:@","] sortedArrayUsingSelector:@selector(compare:)] componentsJoinedByString:@","];
                same = [sortedA isEqualToString:sortedB] && [a rangeOfString:@"a,a,a,|,|,b"].location != NSNotFound;
            }
            if (!same)
                printf("  scenario %d\n     port   %s\n     system %s\n", which, a.UTF8String, b.UTF8String);
            charon_check(same, [names[which] UTF8String], [NSString stringWithFormat:@"port [%@] system [%@]", a, b]);
        }
    }
    printf("checks=%d failures=%d\n", charon_checks, charon_failures);
    return charon_failures;
}
