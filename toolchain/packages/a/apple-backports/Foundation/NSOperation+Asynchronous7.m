#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <objc/runtime.h>

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
    struct objc_super super = { .receiver = self, .super_class = [NSObject class] };
    return ((BOOL (*)(struct objc_super *, SEL))objc_msgSendSuper)(&super, @selector(isAsynchronous));
}

- (void)setAsynchronous:(BOOL)asynchronous
{
    objc_setAssociatedObject(self, &CharonOperationAsynchronousKey, @(asynchronous), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
