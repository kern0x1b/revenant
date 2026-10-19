#import <Foundation/Foundation.h>

static int failures = 0;
static int checks = 0;

static void charon_check(int passed, const char *name, NSString *detail)
{
    checks++;
    if (!passed) {
        failures++;
        fprintf(stderr, "FAIL %s: %s\n", name, detail.UTF8String);
    }
}

@interface CharonBareDelegate : NSObject <NSURLSessionTaskDelegate>
@end
@implementation CharonBareDelegate
@end

@interface CharonOneDelegate : NSObject <NSURLSessionTaskDelegate>
@property (atomic, assign) NSUInteger completions;
@property (atomic, assign) NSUInteger bareCompletions;
@property (atomic, assign) NSUInteger events;
@end

@implementation CharonOneDelegate

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
    didCompleteWithError:(NSError *)error
{
    self.completions++;
    self.events++;
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
    didFinishCollectingMetrics:(NSURLSessionTaskMetrics *)metrics
{
    self.events++;
}

@end

@interface CharonSessionDelegate : NSObject <NSURLSessionDelegate, NSURLSessionTaskDelegate>
@property (atomic, assign) NSUInteger completions;
@property (atomic, assign) NSUInteger metrics;
@end

@implementation CharonSessionDelegate

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
    didCompleteWithError:(NSError *)error
{
    self.completions++;
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
    didFinishCollectingMetrics:(NSURLSessionTaskMetrics *)metrics
{
    self.metrics++;
}

@end

static NSURL *CharonUnreachable(void)
{
    return [NSURL URLWithString:@"http://127.0.0.1:1/"];
}

static void CharonRun(id<NSURLSessionTaskDelegate> taskDelegate, CharonSessionDelegate *sessionDelegate,
                      CharonOneDelegate *oneDelegate, BOOL setDelegate, BOOL *refused,
                      NSString **refusal, NSString **afterCompletion, BOOL *wasSet)
{
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    queue.maxConcurrentOperationCount = 1;
    NSURLSession *session = [NSURLSession sessionWithConfiguration:
                             [NSURLSessionConfiguration ephemeralSessionConfiguration]
                                                            delegate:sessionDelegate
                                                       delegateQueue:queue];
    NSURLSessionDataTask *task = [session dataTaskWithURL:CharonUnreachable()];
    if (setDelegate)
        [task setDelegate:taskDelegate];
    *wasSet = task.delegate == taskDelegate;
    [task resume];
    @try {
        [task setDelegate:taskDelegate];
        *refused = NO;
        *refusal = @"accepted";
    }
    @catch (NSException *exception) {
        *refused = YES;
        *refusal = [NSString stringWithFormat:@"%@: %@", exception.name, exception.reason];
    }
    [queue waitUntilAllOperationsAreFinished];
    NSCondition *done = [[NSCondition alloc] init];
    (void)done;
    for (NSUInteger spin = 0; spin < 400 && sessionDelegate.completions == 0 && oneDelegate.completions == 0; spin++) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    }
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
    *afterCompletion = task.delegate ? [NSString stringWithFormat:@"%@", [task.delegate class]]
                                     : @"(nil)";
    [session finishTasksAndInvalidate];
}

int main(void)
{
    @autoreleasepool {
        NSLog(@"[tasksession] host %@ %@ %@", NSProcessInfo.processInfo.operatingSystemVersionString,
              @(NSProcessInfo.processInfo.processorCount), @"");

        {
            NSURLSession *plain = [NSURLSession sessionWithConfiguration:
                                  [NSURLSessionConfiguration ephemeralSessionConfiguration]];
            NSURLSessionDataTask *task = [plain dataTaskWithURL:CharonUnreachable()];
            charon_check(task != nil, "control: a task is made",
                         @"dataTaskWithURL: answered nil");
            charon_check([task respondsToSelector:@selector(delegate)],
                         "control: the task answers -delegate", @"doesNotRecognizeSelector:");
            charon_check([task respondsToSelector:@selector(setDelegate:)],
                         "control: the task answers -setDelegate:", @"doesNotRecognizeSelector:");
            SEL completion = @selector(URLSession:task:didCompleteWithError:);
            charon_check([NSURLSessionTask class] != Nil, "control: NSURLSessionTask is present",
                         @"the class is nil");
            charon_check([(id<NSURLSessionTaskDelegate>)[[CharonOneDelegate alloc] init]
                          respondsToSelector:completion],
                         "control: the protocol selector is the one the header declares",
                         @"a delegate implementing it does not answer it");
            charon_check(task.delegate == nil, "control: a fresh task has no delegate of its own",
                         [NSString stringWithFormat:@"reads %@", task.delegate]);
            [plain finishTasksAndInvalidate];
        }

        {
            CharonBareDelegate *bare = [[CharonBareDelegate alloc] init];
            CharonOneDelegate *one = [[CharonOneDelegate alloc] init];
            CharonSessionDelegate *sessionDelegate = [[CharonSessionDelegate alloc] init];
            BOOL refused = NO, wasSet = NO;
            NSString *refusal = nil, *after = nil;
            CharonRun(bare, sessionDelegate, one, YES, &refused, &refusal, &after, &wasSet);
            printf("forwarding: the task's delegate implements nothing\n");
            printf("  the task's delegate was set and reads back: %s\n", wasSet ? "yes" : "no");
            printf("  setDelegate: after resume: %s\n", refusal.UTF8String);
            printf("  the session delegate heard didCompleteWithError: %lu time(s)\n",
                   (unsigned long)sessionDelegate.completions);
            printf("  delegate after completion: %s\n", after.UTF8String);
            fflush(stdout);
            charon_check(sessionDelegate.completions == 1,
                         "forwarding: a delegate implementing nothing still has the completion "
                         "forwarded to the session delegate",
                         [NSString stringWithFormat:@"the session delegate heard %lu",
                          (unsigned long)sessionDelegate.completions]);
            charon_check([after isEqualToString:@"(nil)"],
                         "lifetime: the delegate is reset to nil once the task has completed",
                         [NSString stringWithFormat:@"reads %@", after]);
        }

        {
            CharonOneDelegate *one = [[CharonOneDelegate alloc] init];
            CharonSessionDelegate *sessionDelegate = [[CharonSessionDelegate alloc] init];
            BOOL refused = NO, wasSet = NO;
            NSString *refusal = nil, *after = nil;
            CharonRun(one, sessionDelegate, one, YES, &refused, &refusal, &after, &wasSet);
            printf("partial: the task's delegate implements didCompleteWithError:\n");
            printf("  the task's delegate heard it: %lu time(s)\n", (unsigned long)one.completions);
            printf("  the session delegate heard it: %lu time(s)\n",
                   (unsigned long)sessionDelegate.completions);
            printf("  setDelegate: after resume: %s\n", refusal.UTF8String);
            printf("  delegate after completion: %s\n", after.UTF8String);
            fflush(stdout);
            charon_check(one.completions == 1,
                         "partial: the delegate that implements the selector is the one asked",
                         [NSString stringWithFormat:@"it heard %lu", (unsigned long)one.completions]);
            charon_check(sessionDelegate.completions == 0,
                         "partial: the session delegate is NOT asked when the task's delegate "
                         "implements the selector",
                         [NSString stringWithFormat:@"the session delegate heard %lu",
                          (unsigned long)sessionDelegate.completions]);
        }

        printf("tasksession: %d checks, %d failures\n", checks, failures);
        return failures != 0;
    }
}
