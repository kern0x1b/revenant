#import <UIKit/UIKit.h>
#import <BackgroundTasks/BackgroundTasks.h>

@interface BGTaskScheduler (CharonScheduler)
- (instancetype)initCharon;
@end

NSErrorDomain const BGTaskSchedulerErrorDomain = @"BGTaskSchedulerErrorDomain";

static BOOL charon_launched;
static BGTaskScheduler *charon_scheduler;

@implementation BGTaskScheduler {
    NSMutableDictionary *_handlers;
}

+ (void)load
{
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
        charon_launched = YES;
    }];
}

+ (BGTaskScheduler *)sharedScheduler
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        charon_scheduler = [[self alloc] initCharon];
    });
    return charon_scheduler;
}

- (instancetype)initCharon
{
    if ((self = [super init]))
        _handlers = [NSMutableDictionary dictionary];
    return self;
}

static BOOL charon_permitted(NSString *identifier)
{
    NSArray *permitted = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"BGTaskSchedulerPermittedIdentifiers"];
    return [permitted isKindOfClass:[NSArray class]] && [permitted containsObject:identifier];
}

static BOOL charon_background_mode(NSString *mode)
{
    NSArray *modes = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"UIBackgroundModes"];
    return [modes isKindOfClass:[NSArray class]] && [modes containsObject:mode];
}

- (BOOL)registerForTaskWithIdentifier:(NSString *)identifier usingQueue:(dispatch_queue_t)queue launchHandler:(void (^)(__kindof BGTask *))launchHandler
{
    if (charon_launched)
        [NSException raise:NSInternalInconsistencyException format:@"All launch handlers must be registered before application finishes launching"];
    if (!charon_permitted(identifier))
        return NO;
    @synchronized (self) {
        if (_handlers[identifier])
            [NSException raise:NSInternalInconsistencyException format:@"Launch handler for task with identifier %@ has already been registered", identifier];
        _handlers[identifier] = [launchHandler copy];
    }
    return YES;
}

- (BOOL)submitTaskRequest:(BGTaskRequest *)taskRequest error:(NSError **)error
{
    NSString *mode = [taskRequest isKindOfClass:[BGProcessingTaskRequest class]] ? @"processing" : @"fetch";
    NSInteger code = charon_permitted(taskRequest.identifier) && charon_background_mode(mode) ? BGTaskSchedulerErrorCodeUnavailable : BGTaskSchedulerErrorCodeNotPermitted;
    if (error)
        *error = [NSError errorWithDomain:BGTaskSchedulerErrorDomain code:code userInfo:nil];
    return NO;
}

- (void)cancelTaskRequestWithIdentifier:(NSString *)identifier
{
}

- (void)cancelAllTaskRequests
{
}

- (void)getPendingTaskRequestsWithCompletionHandler:(void (^)(NSArray<BGTaskRequest *> *))completionHandler
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        completionHandler(@[]);
    });
}

@end
