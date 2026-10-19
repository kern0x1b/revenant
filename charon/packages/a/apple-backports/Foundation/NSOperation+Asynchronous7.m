#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <objc/runtime.h>

/* An operation's name, and whether it is asynchronous. The release's NSOperation has the getter of
   -isAsynchronous and no setter, and no name at all, so both are kept beside the operation: the name
   as the header says it is (a string that names the operation in a queue's and a control's list), and
   the flag as the flag is (an operation that runs on a queue of its own rather than in the queue's
   thread). The release's own -start and the queues read isAsynchronous, so a set value is what an
   operation queue sees when it decides how to run it. */

static char CharonOperationNameKey;
static char CharonOperationAsynchronousKey;

@implementation NSOperation (CharonAsynchronous)

- (NSString *)name
{
    return objc_getAssociatedObject(self, &CharonOperationNameKey);
}

- (void)setName:(NSString *)name
{
    objc_setAssociatedObject(self, &CharonOperationNameKey, [name copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)isAsynchronous
{
    NSNumber *stored = objc_getAssociatedObject(self, &CharonOperationAsynchronousKey);
    if (stored)
        return stored.boolValue;
    /* Nothing of ours is set, so the release's own flag is the answer; a category's [super] is
       NSObject, so the superclass's implementation is reached the way the runtime reaches it. */
    struct objc_super super = { .receiver = self, .super_class = [NSObject class] };
    return ((BOOL (*)(struct objc_super *, SEL))objc_msgSendSuper)(&super, @selector(isAsynchronous));
}

- (void)setAsynchronous:(BOOL)asynchronous
{
    objc_setAssociatedObject(self, &CharonOperationAsynchronousKey, @(asynchronous), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
