#import <Foundation/Foundation.h>
#import <objc/runtime.h>

#import "CharonTaskDelegate15.h"

static char CharonTaskDelegateKey;

@implementation NSURLSessionTask (CharonTaskDelegate15)

- (id<NSURLSessionTaskDelegate>)delegate
{
    return objc_getAssociatedObject(self, &CharonTaskDelegateKey);
}

- (void)setDelegate:(id<NSURLSessionTaskDelegate>)delegate
{
    if (self.state != NSURLSessionTaskStateSuspended) {
        [NSException raise:NSGenericException
                    format:@"Cannot set task delegate after resumption"];
    }
    objc_setAssociatedObject(self, &CharonTaskDelegateKey, delegate, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)charon_resetTaskDelegate
{
    objc_setAssociatedObject(self, &CharonTaskDelegateKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
