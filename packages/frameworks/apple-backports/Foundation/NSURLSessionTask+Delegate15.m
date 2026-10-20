#import <Foundation/Foundation.h>
#import <objc/runtime.h>

#import "RevenantTaskDelegate15.h"

static char RevenantTaskDelegateKey;

@implementation NSURLSessionTask (RevenantTaskDelegate15)

- (id<NSURLSessionTaskDelegate>)delegate
{
    return objc_getAssociatedObject(self, &RevenantTaskDelegateKey);
}

- (void)setDelegate:(id<NSURLSessionTaskDelegate>)delegate
{
    if (self.state != NSURLSessionTaskStateSuspended) {
        [NSException raise:NSGenericException
                    format:@"Cannot set task delegate after resumption"];
    }
    objc_setAssociatedObject(self, &RevenantTaskDelegateKey, delegate, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)revenant_resetTaskDelegate
{
    objc_setAssociatedObject(self, &RevenantTaskDelegateKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
