#import <Foundation/Foundation.h>
#import "RevenantMethodProem.h"

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

__attribute__((visibility("hidden")))
@interface RevenantProgressSubscriber : NSObject {
@package
    NSString *_path;
    NSProgressPublishingHandler _handler;
    NSMutableDictionary *_unpublishing;
}
@end

@implementation RevenantProgressSubscriber
@end

static NSMutableArray *revenant_published;
static NSMutableArray *revenant_subscribers;

static NSObject *revenant_progress_lock(void)
{
    static NSObject *lock;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        lock = [[NSObject alloc] init];
        revenant_published = [NSMutableArray array];
        revenant_subscribers = [NSMutableArray array];
    });
    return lock;
}

static NSString *revenant_progress_path(NSProgress *progress)
{
    NSURL *url = progress.userInfo[NSProgressFileURLKey];
    return url.isFileURL ? url.path.stringByStandardizingPath : nil;
}

static NSValue *revenant_progress_token(NSProgress *progress)
{
    return [NSValue valueWithNonretainedObject:progress];
}

static void revenant_progress_deliver(RevenantProgressSubscriber *subscriber, NSProgress *progress)
{
    NSProgressUnpublishingHandler unpublishing = subscriber->_handler(progress);
    if (unpublishing) {
        @synchronized (revenant_progress_lock()) {
            subscriber->_unpublishing[revenant_progress_token(progress)] = [unpublishing copy];
        }
    }
}

@implementation NSProgress (RevenantPublish7)

- (void)publish
{
    NSString *path = revenant_progress_path(self);
    if (!path)
        [NSException raise:NSInvalidArgumentException format:@"%@: a progress needs NSProgressFileURLKey in its user info to be published", revenant_method_proem(self, _cmd)];
    NSArray *matching;
    @synchronized (revenant_progress_lock()) {
        if ([revenant_published indexOfObjectIdenticalTo:self] != NSNotFound)
            return;
        [revenant_published addObject:self];
        matching = [revenant_subscribers filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(RevenantProgressSubscriber *subscriber, NSDictionary *bindings) {
            return [subscriber->_path isEqualToString:path];
        }]];
    }
    for (RevenantProgressSubscriber *subscriber in matching)
        revenant_progress_deliver(subscriber, self);
}

- (void)unpublish
{
    NSMutableArray *handlers = [NSMutableArray array];
    @synchronized (revenant_progress_lock()) {
        NSUInteger index = [revenant_published indexOfObjectIdenticalTo:self];
        if (index == NSNotFound)
            return;
        [revenant_published removeObjectAtIndex:index];
        for (RevenantProgressSubscriber *subscriber in revenant_subscribers) {
            NSValue *token = revenant_progress_token(self);
            id handler = subscriber->_unpublishing[token];
            if (handler) {
                [handlers addObject:handler];
                [subscriber->_unpublishing removeObjectForKey:token];
            }
        }
    }
    for (NSProgressUnpublishingHandler handler in handlers)
        handler();
}

+ (id)addSubscriberForFileURL:(NSURL *)url withPublishingHandler:(NSProgressPublishingHandler)publishingHandler
{
    RevenantProgressSubscriber *subscriber = [[RevenantProgressSubscriber alloc] init];
    subscriber->_path = url.isFileURL ? url.path.stringByStandardizingPath : url.absoluteString;
    subscriber->_handler = [publishingHandler copy];
    subscriber->_unpublishing = [NSMutableDictionary dictionary];
    NSArray *existing;
    @synchronized (revenant_progress_lock()) {
        [revenant_subscribers addObject:subscriber];
        existing = [revenant_published filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSProgress *progress, NSDictionary *bindings) {
            return [revenant_progress_path(progress) isEqualToString:subscriber->_path];
        }]];
    }
    for (NSProgress *progress in existing)
        revenant_progress_deliver(subscriber, progress);
    return subscriber;
}

+ (void)removeSubscriber:(id)subscriber
{
    @synchronized (revenant_progress_lock()) {
        [revenant_subscribers removeObjectIdenticalTo:subscriber];
    }
}

@end
