/* tasksession.m - what the host's own NSURLSession does with a task's delegate.

   The three things asked, about the task delegate property that SDK 16.4 NSURLSession.h declares at
   :296-304:

       a selector the task delegate does not implement is forwarded on to the session delegate;
       the delegate cannot change once the task has resumed, and a background session does not take one;
       the task holds the delegate strongly until it completes, and then clears it.

   Each is asked of the system's own Foundation, not of the port: the port's objects are armv7
   iOS 6.1.3 and this program is macOS. Nothing here reads the port.

   Four runs, in this order, and each is worthless if the control before it did not pass:

     1. control   - the reader can see the property, the protocol and a live task, and a task with
                    no delegate of its own reports nil. A reader that could not see them would
                    report every rule as "does not happen".
     2. forwarding- the task's delegate implements NOTHING, the session's implements
                    URLSession:task:didCompleteWithError:. Who hears the completion?
     3. partial   - the task's delegate implements exactly that one selector. Who hears it now?
     4. lifetime  - is -setDelegate: after -resume accepted or refused, and with what; and does
                    -delegate read nil once the task has completed.

   Nothing leaves the machine: every task is http://127.0.0.1:1/, which is refused by the loopback
   stack immediately, so the completion fires locally and no name is resolved. */

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

/* The delegate that implements NOTHING of the protocol. A class with no method at all is the
   strongest form of "not implemented on this delegate": nothing can be forwarded to it by
   accident. */
@interface CharonBareDelegate : NSObject <NSURLSessionTaskDelegate>
@end
@implementation CharonBareDelegate
@end

/* The delegate that implements exactly one task-scoped selector and nothing else. */
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

/* The session's delegate: it implements the two selectors and counts who was asked. */
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

/* One task, run to completion, and what the three delegates heard. */
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
    /* The FIRST rule the header states about -setDelegate: after -resume. The refusal, if there is
       one, is an exception and the question is which. */
    @try {
        [task setDelegate:taskDelegate];
        *refused = NO;
        *refusal = @"accepted";
    }
    @catch (NSException *exception) {
        *refused = YES;
        *refusal = [NSString stringWithFormat:@"%@: %@", exception.name, exception.reason];
    }
    /* Run the queue dry so the completion has been delivered before anything is read. */
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

        /* 1. the control: this reader can see the property, the protocol and a live task. */
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

        /* 2. the task's delegate implements NOTHING: this step checks that the completion is still
              forwarded to the session delegate. */
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

        /* 3. the task's delegate implements exactly that selector: it is asked, and the session's
              is not. */
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