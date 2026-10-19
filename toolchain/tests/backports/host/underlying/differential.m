#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import "check.h"
#import "underlying-cases.h"

@interface CharonHostCharonOperationScheduler : NSObject
- (instancetype)initWithDispatchQueue:(dispatch_queue_t)queue owner:(NSOperationQueue *)owner;
@property (nonatomic, readonly) dispatch_queue_t dispatchQueue;
@property (nonatomic) BOOL suspended;
@property (nonatomic) NSInteger maxConcurrentOperationCount;
- (void)addOperation:(NSOperation *)operation;
- (NSArray *)operations;
- (NSUInteger)operationCount;
- (void)cancelAllOperations;
- (void)waitUntilAllOperationsAreFinished;
@end

@interface PortQueue : NSOperationQueue
@end

@implementation PortQueue {
    CharonHostCharonOperationScheduler *_scheduler;
    NSString *_name;
}

- (instancetype)init
{
    if ((self = [super init]))
        _scheduler = nil;
    return self;
}

- (dispatch_queue_t)underlyingQueue
{
    return _scheduler.dispatchQueue;
}

- (void)setUnderlyingQueue:(dispatch_queue_t)underlyingQueue
{
    if (self.operationCount)
        [NSException raise:NSInvalidArgumentException format:@"*** -[NSOperationQueue setUnderlyingQueue:]: operation queue must be empty in order to change underlying dispatch queue"];
    BOOL suspended = self.isSuspended;
    NSInteger limit = self.maxConcurrentOperationCount;
    if (!underlyingQueue) {
        _scheduler = nil;
        return;
    }
    _scheduler = [[CharonHostCharonOperationScheduler alloc] initWithDispatchQueue:underlyingQueue owner:self];
    _scheduler.suspended = suspended;
    _scheduler.maxConcurrentOperationCount = limit;
}

- (void)addOperation:(NSOperation *)operation
{
    if (_scheduler)
        [_scheduler addOperation:operation];
    else
        [super addOperation:operation];
}

- (void)addOperations:(NSArray *)operations waitUntilFinished:(BOOL)wait
{
    if (!_scheduler) {
        [super addOperations:operations waitUntilFinished:wait];
        return;
    }
    for (NSOperation *operation in operations)
        [_scheduler addOperation:operation];
    if (wait)
        for (NSOperation *operation in operations)
            [operation waitUntilFinished];
}

- (void)addOperationWithBlock:(void (^)(void))block
{
    if (_scheduler)
        [_scheduler addOperation:[NSBlockOperation blockOperationWithBlock:block]];
    else
        [super addOperationWithBlock:block];
}

- (NSArray *)operations
{
    return _scheduler ? [_scheduler operations] : [super operations];
}

- (NSUInteger)operationCount
{
    return _scheduler ? [_scheduler operationCount] : [super operationCount];
}

- (void)cancelAllOperations
{
    if (_scheduler)
        [_scheduler cancelAllOperations];
    else
        [super cancelAllOperations];
}

- (void)waitUntilAllOperationsAreFinished
{
    if (_scheduler)
        [_scheduler waitUntilAllOperationsAreFinished];
    else
        [super waitUntilAllOperationsAreFinished];
}

- (void)setSuspended:(BOOL)suspended
{
    [super setSuspended:suspended];
    _scheduler.suspended = suspended;
}

- (void)setMaxConcurrentOperationCount:(NSInteger)count
{
    [super setMaxConcurrentOperationCount:count];
    _scheduler.maxConcurrentOperationCount = count;
}

@end

int main(int argc, char **argv)
{
    @autoreleasepool {
        NSMutableDictionary *system = [NSMutableDictionary dictionary], *port = [NSMutableDictionary dictionary];
        underlying_run(^NSOperationQueue *{ return [[NSOperationQueue alloc] init]; }, ^(NSString *name, NSString *value) { system[name] = value; });
        underlying_run(^NSOperationQueue *{ return [[PortQueue alloc] init]; }, ^(NSString *name, NSString *value) { port[name] = value; });
        for (NSString *name in [system.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
            printf("%s: %s\n", name.UTF8String, [system[name] UTF8String]);
            CHECK_EQUAL(port[name], system[name], name.UTF8String);
        }
        if (argc > 1) {
            NSData *data = [NSJSONSerialization dataWithJSONObject:system options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys error:NULL];
            [data writeToFile:@(argv[1]) atomically:YES];
        }
        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
        return charon_failures;
    }
}
