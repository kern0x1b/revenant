#import <Foundation/Foundation.h>
#import <objc/message.h>

@interface NSXPCConnection (RevenantReleaseProxy)
- (id)synchronousRemoteObjectProxy;
@end

@implementation NSXPCConnection (RevenantBarrier)

- (id)synchronousRemoteObjectProxyWithErrorHandler:(void (^)(NSError *error))handler
{
    @try {
        return [self synchronousRemoteObjectProxy];
    } @catch (NSException *exception) {
        if (handler)
            handler([NSError errorWithDomain:@"NSXPCConnectionErrorDomain"
                                        code:1
                                    userInfo:@{NSLocalizedDescriptionKey: exception.reason ?: exception.name}]);
        return nil;
    }
}

- (void)scheduleSendBarrierBlock:(void (^)(void))block
{
    if (!block)
        return;
    dispatch_queue_t queue = nil;
    if ([self respondsToSelector:NSSelectorFromString(@"targetQueue")])
        queue = ((id (*)(id, SEL))objc_msgSend)(self, NSSelectorFromString(@"targetQueue"));
    if (queue)
        dispatch_async(queue, block);
    else
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), block);
}

@end
