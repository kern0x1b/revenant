#import <Foundation/Foundation.h>

@interface NSFileAccessIntent (RevenantAccess)
- (BOOL)revenant_isRead;
- (NSFileCoordinatorReadingOptions)revenant_readingOptions;
- (NSFileCoordinatorWritingOptions)revenant_writingOptions;
- (void)revenant_setURL:(NSURL *)URL;
@end

@implementation NSFileAccessIntent {
@private
    NSURL *_revenantURL;
    NSInteger _revenantOptions;
    BOOL _revenantIsRead;
}

+ (instancetype)readingIntentWithURL:(NSURL *)url options:(NSFileCoordinatorReadingOptions)options
{
    NSFileAccessIntent *intent = [[self alloc] init];
    intent->_revenantURL = [url copy];
    intent->_revenantOptions = options;
    intent->_revenantIsRead = YES;
    return intent;
}

+ (instancetype)writingIntentWithURL:(NSURL *)url options:(NSFileCoordinatorWritingOptions)options
{
    NSFileAccessIntent *intent = [[self alloc] init];
    intent->_revenantURL = [url copy];
    intent->_revenantOptions = options;
    intent->_revenantIsRead = NO;
    return intent;
}

- (NSURL *)URL
{
    return _revenantURL;
}

- (BOOL)revenant_isRead
{
    return _revenantIsRead;
}

- (NSFileCoordinatorReadingOptions)revenant_readingOptions
{
    return (NSFileCoordinatorReadingOptions)_revenantOptions;
}

- (NSFileCoordinatorWritingOptions)revenant_writingOptions
{
    return (NSFileCoordinatorWritingOptions)_revenantOptions;
}

- (void)revenant_setURL:(NSURL *)URL
{
    _revenantURL = [URL copy];
}

@end

@implementation NSFileCoordinator (RevenantIntents)

- (void)revenant_coordinateIntents:(NSArray<NSFileAccessIntent *> *)intents index:(NSUInteger)index queue:(NSOperationQueue *)queue accessor:(void (^)(NSError *))accessor
{
    if (index == intents.count) {
        dispatch_semaphore_t finished = dispatch_semaphore_create(0);
        [queue addOperationWithBlock:^{
            accessor(nil);
            dispatch_semaphore_signal(finished);
        }];
        dispatch_semaphore_wait(finished, DISPATCH_TIME_FOREVER);
        return;
    }
    NSFileAccessIntent *intent = intents[index];
    NSError *error = nil;
    __block BOOL entered = NO;
    void (^inner)(NSURL *) = ^(NSURL *coordinated) {
        entered = YES;
        [intent revenant_setURL:coordinated];
        [self revenant_coordinateIntents:intents index:index + 1 queue:queue accessor:accessor];
    };
    if ([intent revenant_isRead])
        [self coordinateReadingItemAtURL:intent.URL options:[intent revenant_readingOptions] error:&error byAccessor:inner];
    else
        [self coordinateWritingItemAtURL:intent.URL options:[intent revenant_writingOptions] error:&error byAccessor:inner];
    if (!entered) {
        [queue addOperationWithBlock:^{
            accessor(error);
        }];
    }
}

- (void)coordinateAccessWithIntents:(NSArray<NSFileAccessIntent *> *)intents queue:(NSOperationQueue *)queue byAccessor:(void (^)(NSError *))accessor
{
    NSArray *held = [intents copy];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self revenant_coordinateIntents:held index:0 queue:queue accessor:accessor];
    });
}

@end
