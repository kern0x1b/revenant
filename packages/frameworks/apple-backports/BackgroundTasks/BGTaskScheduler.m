#import <UIKit/UIKit.h>
#import <BackgroundTasks/BackgroundTasks.h>

@interface BGTaskScheduler (RevenantScheduler)
- (instancetype)initRevenant;
@end

NSErrorDomain const BGTaskSchedulerErrorDomain = @"BGTaskSchedulerErrorDomain";

static BOOL revenant_launched;
static BGTaskScheduler *revenant_scheduler;

@implementation BGTaskScheduler {
    NSMutableDictionary *_handlers;
}

+ (void)load
{
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
        revenant_launched = YES;
    }];
}

+ (BGTaskScheduler *)sharedScheduler
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        revenant_scheduler = [[self alloc] initRevenant];
    });
    return revenant_scheduler;
}

- (instancetype)initRevenant
{
    if ((self = [super init]))
        _handlers = [NSMutableDictionary dictionary];
    return self;
}

static BOOL revenant_permitted(NSString *identifier)
{
    NSArray *permitted = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"BGTaskSchedulerPermittedIdentifiers"];
    return [permitted isKindOfClass:[NSArray class]] && [permitted containsObject:identifier];
}

static BOOL revenant_background_mode(NSString *mode)
{
    NSArray *modes = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"UIBackgroundModes"];
    return [modes isKindOfClass:[NSArray class]] && [modes containsObject:mode];
}

- (BOOL)registerForTaskWithIdentifier:(NSString *)identifier usingQueue:(dispatch_queue_t)queue launchHandler:(void (^)(__kindof BGTask *))launchHandler
{
    if (revenant_launched)
        [NSException raise:NSInternalInconsistencyException format:@"All launch handlers must be registered before application finishes launching"];
    if (!revenant_permitted(identifier))
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
    NSInteger code = revenant_permitted(taskRequest.identifier) && revenant_background_mode(mode) ? BGTaskSchedulerErrorCodeUnavailable : BGTaskSchedulerErrorCodeNotPermitted;
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
