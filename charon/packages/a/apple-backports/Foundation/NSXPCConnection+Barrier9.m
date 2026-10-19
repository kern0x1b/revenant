#import <Foundation/Foundation.h>
#import <objc/message.h>

/* The two NSXPCConnection members that need nothing the release does not have.

   -synchronousRemoteObjectProxyWithErrorHandler: is the release's own -synchronousRemoteObjectProxy
   with the failure handed to a block rather than raised: a proxy that cannot be made answers nil and
   the handler hears the error, which is what the header says and what the release's raise would
   otherwise become.

   -scheduleSendBarrierBlock: runs the block once everything queued on the connection before it has
   gone. The release's connection sends synchronously and offers no barrier of its own, so the block
   is put behind the connection's own target queue, which for a connection that sends as it is given
   a message is the same order. xpc_connection_send_barrier is exported by libxpc.dylib in 6.1.3
   (measured with tools/corpus/cache-value.lua), and the facts file says why the port does not reach
   it: the release's NSXPCConnection keeps its connection in an ivar no public API returns, and a
   private ivar is not what this port builds on. */

/* The release's own proxy, under the name its binary has carried since before the error handler
   spelling existed (measured: the selector is in the 6.1.3 cache's selector table). The modern header
   declares only the handler spelling, so the plain one is declared here. */
@interface NSXPCConnection (CharonReleaseProxy)
- (id)synchronousRemoteObjectProxy;
@end

@implementation NSXPCConnection (CharonBarrier)

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
