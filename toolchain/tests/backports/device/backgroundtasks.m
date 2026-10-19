#import <UIKit/UIKit.h>
#import <BackgroundTasks/BackgroundTasks.h>
#include <dlfcn.h>
#import "check.h"

static NSString *const results_folder = @"/private/var/backports";

static BOOL registered_refresh, registered_other, registered_processing;
static NSString *duplicate_raised;

@interface CharonBackgroundDelegate : UIResponder <UIApplicationDelegate>
@end

@implementation CharonBackgroundDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options
{
    charon_log_to([results_folder stringByAppendingPathComponent:@"backgroundtasks.log"]);
    BGTaskScheduler *scheduler = [BGTaskScheduler sharedScheduler];
    registered_refresh = [scheduler registerForTaskWithIdentifier:@"local.charon.refresh" usingQueue:nil launchHandler:^(BGTask *task) {}];
    registered_processing = [scheduler registerForTaskWithIdentifier:@"local.charon.processing" usingQueue:dispatch_get_main_queue() launchHandler:^(BGTask *task) {}];
    registered_other = [scheduler registerForTaskWithIdentifier:@"local.charon.unlisted" usingQueue:nil launchHandler:^(BGTask *task) {}];
    @try {
        [scheduler registerForTaskWithIdentifier:@"local.charon.refresh" usingQueue:nil launchHandler:^(BGTask *task) {}];
    } @catch (NSException *exception) {
        duplicate_raised = exception.name;
    }
    [self performSelector:@selector(runAndReport) withObject:nil afterDelay:0.5];
    return YES;
}

- (void)runAndReport
{
    @try {
        [self run];
    } @catch (NSException *exception) {
        charon_check(NO, "the checks raise no exception", [NSString stringWithFormat:@"%@: %@", exception.name, exception.reason]);
    }
    NSString *summary = [NSString stringWithFormat:@"%@ checks=%d failures=%d\n", charon_failures ? @"FAIL" : @"ok", charon_checks, charon_failures];
    [summary writeToFile:[results_folder stringByAppendingPathComponent:@"backgroundtasks.done"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
}

- (void)run
{
    Dl_info info;
    CHECK(dladdr((__bridge const void *)[BGTaskScheduler class], &info) && !strcmp(strrchr(info.dli_fname, '/') + 1, "libBackgroundTasksBackports.dylib"), "BGTaskScheduler comes from the BackgroundTasks library");
    BGTaskScheduler *scheduler = [BGTaskScheduler sharedScheduler];
    CHECK(scheduler == [BGTaskScheduler sharedScheduler], "there is one scheduler");
    CHECK(registered_refresh && registered_processing, "identifiers the Info.plist lists are registered");
    CHECK(!registered_other, "one it does not list is not");
    CHECK_EQUAL(duplicate_raised, NSInternalInconsistencyException, "a second handler for an identifier raises");
    BOOL late = NO;
    @try {
        [scheduler registerForTaskWithIdentifier:@"local.charon.processing2" usingQueue:nil launchHandler:^(BGTask *task) {}];
    } @catch (NSException *exception) {
        late = [exception.name isEqual:NSInternalInconsistencyException];
    }
    CHECK(late, "registering after the application has launched raises");
    BGAppRefreshTaskRequest *refresh = [[BGAppRefreshTaskRequest alloc] initWithIdentifier:@"local.charon.refresh"];
    refresh.earliestBeginDate = [NSDate dateWithTimeIntervalSinceNow:3600];
    NSError *error = nil;
    CHECK(![scheduler submitTaskRequest:refresh error:&error], "a refresh request is not accepted");
    CHECK([error.domain isEqual:BGTaskSchedulerErrorDomain] && error.code == BGTaskSchedulerErrorCodeUnavailable, "scheduling is unavailable");
    BGProcessingTaskRequest *processing = [[BGProcessingTaskRequest alloc] initWithIdentifier:@"local.charon.processing"];
    processing.requiresNetworkConnectivity = YES;
    processing.requiresExternalPower = YES;
    error = nil;
    CHECK(![scheduler submitTaskRequest:processing error:&error] && error.code == BGTaskSchedulerErrorCodeUnavailable, "so is a processing request");
    BGProcessingTaskRequest *copy = [processing copy];
    CHECK([copy.identifier isEqual:@"local.charon.processing"] && copy.requiresNetworkConnectivity && copy.requiresExternalPower && copy != processing, "a request copies with its switches");
    CHECK(refresh.earliestBeginDate != nil && [[refresh copy] earliestBeginDate] != nil, "and its date");
    BGAppRefreshTaskRequest *unlisted = [[BGAppRefreshTaskRequest alloc] initWithIdentifier:@"local.charon.unlisted"];
    error = nil;
    CHECK(![scheduler submitTaskRequest:unlisted error:&error] && error.code == BGTaskSchedulerErrorCodeNotPermitted, "a request for an identifier the Info.plist does not list is not permitted");
    __block NSArray *pending = nil;
    dispatch_semaphore_t done = dispatch_semaphore_create(0);
    [scheduler getPendingTaskRequestsWithCompletionHandler:^(NSArray *requests) {
        pending = requests;
        dispatch_semaphore_signal(done);
    }];
    CHECK(dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC)) == 0 && pending.count == 0, "nothing is pending");
    [scheduler cancelAllTaskRequests];
    [scheduler cancelTaskRequestWithIdentifier:@"local.charon.refresh"];
    CHECK(YES, "cancelling nothing does nothing");
}

@end

int main(int argc, char *argv[])
{
    @autoreleasepool {
        [[NSFileManager defaultManager] createDirectoryAtPath:results_folder withIntermediateDirectories:YES attributes:nil error:NULL];
        return UIApplicationMain(argc, argv, nil, @"CharonBackgroundDelegate");
    }
}
