#import <Foundation/Foundation.h>

@interface NSFileAccessIntent (CharonAccess)
- (BOOL)charon_isRead;
- (NSFileCoordinatorReadingOptions)charon_readingOptions;
- (NSFileCoordinatorWritingOptions)charon_writingOptions;
- (void)charon_setURL:(NSURL *)URL;
@end

@implementation NSFileAccessIntent {
@private
    // 16.4/16.5's own header still declares an ivar block of its own for this class (@private NSURL *_url;
    // NSInteger _options; BOOL _isRead;) that 26.2's does not (see the const-qualify commit beside this one);
    // naming ours the same as the header's would collide there ("instance variable is already declared").
    // Prefixed instead, so this compiles unchanged whichever the SDK's own header carries.
    NSURL *_charonURL;
    NSInteger _charonOptions;
    BOOL _charonIsRead;
}

+ (instancetype)readingIntentWithURL:(NSURL *)url options:(NSFileCoordinatorReadingOptions)options
{
    NSFileAccessIntent *intent = [[self alloc] init];
    intent->_charonURL = [url copy];
    intent->_charonOptions = options;
    intent->_charonIsRead = YES;
    return intent;
}

+ (instancetype)writingIntentWithURL:(NSURL *)url options:(NSFileCoordinatorWritingOptions)options
{
    NSFileAccessIntent *intent = [[self alloc] init];
    intent->_charonURL = [url copy];
    intent->_charonOptions = options;
    intent->_charonIsRead = NO;
    return intent;
}

- (NSURL *)URL
{
    return _charonURL;
}

- (BOOL)charon_isRead
{
    return _charonIsRead;
}

- (NSFileCoordinatorReadingOptions)charon_readingOptions
{
    return (NSFileCoordinatorReadingOptions)_charonOptions;
}

- (NSFileCoordinatorWritingOptions)charon_writingOptions
{
    return (NSFileCoordinatorWritingOptions)_charonOptions;
}

- (void)charon_setURL:(NSURL *)URL
{
    _charonURL = [URL copy];
}

@end

@implementation NSFileCoordinator (CharonIntents)

- (void)charon_coordinateIntents:(NSArray<NSFileAccessIntent *> *)intents index:(NSUInteger)index queue:(NSOperationQueue *)queue accessor:(void (^)(NSError *))accessor
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
        [intent charon_setURL:coordinated];
        [self charon_coordinateIntents:intents index:index + 1 queue:queue accessor:accessor];
    };
    if ([intent charon_isRead])
        [self coordinateReadingItemAtURL:intent.URL options:[intent charon_readingOptions] error:&error byAccessor:inner];
    else
        [self coordinateWritingItemAtURL:intent.URL options:[intent charon_writingOptions] error:&error byAccessor:inner];
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
        [self charon_coordinateIntents:held index:0 queue:queue accessor:accessor];
    });
}

@end
