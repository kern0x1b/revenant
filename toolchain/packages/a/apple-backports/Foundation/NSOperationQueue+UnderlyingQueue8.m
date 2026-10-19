#import "CharonOperationScheduler.h"
#import <objc/runtime.h>

extern NSString *const CharonCurrentOperationQueueKey;

static const char charon_scheduler_key;

static CharonOperationScheduler *charon_scheduler(NSOperationQueue *queue)
{
    return objc_getAssociatedObject(queue, &charon_scheduler_key);
}

@implementation NSOperationQueue (CharonUnderlyingQueue)

- (dispatch_queue_t)underlyingQueue
{
    CharonOperationScheduler *scheduler = charon_scheduler(self);
    if (scheduler)
        return scheduler.dispatchQueue;
    return self == [NSOperationQueue mainQueue] ? dispatch_get_main_queue() : nil;
}

- (void)setUnderlyingQueue:(dispatch_queue_t)underlyingQueue
{
    if (self.operationCount)
        [NSException raise:NSInvalidArgumentException format:@"*** -[NSOperationQueue setUnderlyingQueue:]: operation queue must be empty in order to change underlying dispatch queue"];
    BOOL suspended = self.isSuspended;
    NSInteger limit = self.maxConcurrentOperationCount;
    if (!underlyingQueue) {
        objc_setAssociatedObject(self, &charon_scheduler_key, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return;
    }
    CharonOperationScheduler *scheduler = [[CharonOperationScheduler alloc] initWithDispatchQueue:underlyingQueue owner:self];
    scheduler.suspended = suspended;
    scheduler.maxConcurrentOperationCount = limit;
    objc_setAssociatedObject(self, &charon_scheduler_key, scheduler, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end

@interface CharonUnderlyingQueuePatch : NSObject
@end

@implementation CharonUnderlyingQueuePatch

+ (void)load
{
    if ([NSOperationQueue instancesRespondToSelector:@selector(underlyingQueue)])
        return;
    Class queue = [NSOperationQueue class];

    SEL add = @selector(addOperation:);
    void (*originalAdd)(id, SEL, id) = (void (*)(id, SEL, id))class_getMethodImplementation(queue, add);
    class_replaceMethod(queue, add, imp_implementationWithBlock(^(NSOperationQueue *self_, NSOperation *operation) {
        CharonOperationScheduler *scheduler = charon_scheduler(self_);
        if (scheduler)
            [scheduler addOperation:operation];
        else
            originalAdd(self_, add, operation);
    }), method_getTypeEncoding(class_getInstanceMethod(queue, add)));

    SEL addMany = @selector(addOperations:waitUntilFinished:);
    void (*originalMany)(id, SEL, id, BOOL) = (void (*)(id, SEL, id, BOOL))class_getMethodImplementation(queue, addMany);
    class_replaceMethod(queue, addMany, imp_implementationWithBlock(^(NSOperationQueue *self_, NSArray *operations, BOOL wait) {
        CharonOperationScheduler *scheduler = charon_scheduler(self_);
        if (!scheduler) {
            originalMany(self_, addMany, operations, wait);
            return;
        }
        for (NSOperation *operation in operations)
            [scheduler addOperation:operation];
        if (wait)
            for (NSOperation *operation in operations)
                [operation waitUntilFinished];
    }), method_getTypeEncoding(class_getInstanceMethod(queue, addMany)));

    SEL addBlock = @selector(addOperationWithBlock:);
    void (*originalBlock)(id, SEL, id) = (void (*)(id, SEL, id))class_getMethodImplementation(queue, addBlock);
    class_replaceMethod(queue, addBlock, imp_implementationWithBlock(^(NSOperationQueue *self_, void (^block)(void)) {
        CharonOperationScheduler *scheduler = charon_scheduler(self_);
        if (scheduler)
            [scheduler addOperation:[NSBlockOperation blockOperationWithBlock:block]];
        else
            originalBlock(self_, addBlock, block);
    }), method_getTypeEncoding(class_getInstanceMethod(queue, addBlock)));

    SEL operations = @selector(operations);
    NSArray *(*originalOperations)(id, SEL) = (NSArray *(*)(id, SEL))class_getMethodImplementation(queue, operations);
    class_replaceMethod(queue, operations, imp_implementationWithBlock(^NSArray *(NSOperationQueue *self_) {
        CharonOperationScheduler *scheduler = charon_scheduler(self_);
        return scheduler ? [scheduler operations] : originalOperations(self_, operations);
    }), method_getTypeEncoding(class_getInstanceMethod(queue, operations)));

    SEL count = @selector(operationCount);
    NSUInteger (*originalCount)(id, SEL) = (NSUInteger (*)(id, SEL))class_getMethodImplementation(queue, count);
    class_replaceMethod(queue, count, imp_implementationWithBlock(^NSUInteger(NSOperationQueue *self_) {
        CharonOperationScheduler *scheduler = charon_scheduler(self_);
        return scheduler ? [scheduler operationCount] : originalCount(self_, count);
    }), method_getTypeEncoding(class_getInstanceMethod(queue, count)));

    SEL cancel = @selector(cancelAllOperations);
    void (*originalCancel)(id, SEL) = (void (*)(id, SEL))class_getMethodImplementation(queue, cancel);
    class_replaceMethod(queue, cancel, imp_implementationWithBlock(^(NSOperationQueue *self_) {
        CharonOperationScheduler *scheduler = charon_scheduler(self_);
        if (scheduler)
            [scheduler cancelAllOperations];
        else
            originalCancel(self_, cancel);
    }), method_getTypeEncoding(class_getInstanceMethod(queue, cancel)));

    SEL wait = @selector(waitUntilAllOperationsAreFinished);
    void (*originalWait)(id, SEL) = (void (*)(id, SEL))class_getMethodImplementation(queue, wait);
    class_replaceMethod(queue, wait, imp_implementationWithBlock(^(NSOperationQueue *self_) {
        CharonOperationScheduler *scheduler = charon_scheduler(self_);
        if (scheduler)
            [scheduler waitUntilAllOperationsAreFinished];
        else
            originalWait(self_, wait);
    }), method_getTypeEncoding(class_getInstanceMethod(queue, wait)));

    SEL suspend = @selector(setSuspended:);
    void (*originalSuspend)(id, SEL, BOOL) = (void (*)(id, SEL, BOOL))class_getMethodImplementation(queue, suspend);
    class_replaceMethod(queue, suspend, imp_implementationWithBlock(^(NSOperationQueue *self_, BOOL suspended) {
        originalSuspend(self_, suspend, suspended);
        charon_scheduler(self_).suspended = suspended;
    }), method_getTypeEncoding(class_getInstanceMethod(queue, suspend)));

    SEL limit = @selector(setMaxConcurrentOperationCount:);
    void (*originalLimit)(id, SEL, NSInteger) = (void (*)(id, SEL, NSInteger))class_getMethodImplementation(queue, limit);
    class_replaceMethod(queue, limit, imp_implementationWithBlock(^(NSOperationQueue *self_, NSInteger value) {
        originalLimit(self_, limit, value);
        charon_scheduler(self_).maxConcurrentOperationCount = value;
    }), method_getTypeEncoding(class_getInstanceMethod(queue, limit)));

    SEL current = @selector(currentQueue);
    NSOperationQueue *(*originalCurrent)(id, SEL) = (NSOperationQueue *(*)(id, SEL))class_getMethodImplementation(object_getClass(queue), current);
    class_replaceMethod(object_getClass(queue), current, imp_implementationWithBlock(^NSOperationQueue *(id class_) {
        NSOperationQueue *found = [[NSThread currentThread] threadDictionary][CharonCurrentOperationQueueKey];
        return found ?: originalCurrent(class_, current);
    }), method_getTypeEncoding(class_getClassMethod(queue, current)));
}

@end
