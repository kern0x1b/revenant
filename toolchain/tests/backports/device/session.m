#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import "check.h"
#import "session-scenarios.h"

static BOOL selected(int argc, char **argv, const char *name)
{
    if (argc <= 3)
        return YES;
    for (int index = 3; index < argc; index++) {
        if (strcmp(argv[index], name) == 0)
            return YES;
    }
    return NO;
}

static NSString *image_of(Class class)
{
    const char *image = class ? class_getImageName(class) : NULL;
    return image ? @(image).lastPathComponent : @"?";
}

int main(int argc, char **argv)
{
    const char *name = argc > 1 ? argv[1] : "session";
    @autoreleasepool {
        SessionHarness *harness = [[SessionHarness alloc] init];
        harness.sessionClass = [NSURLSession class];
        harness.configurationClass = [NSURLSessionConfiguration class];
        harness.base = [NSString stringWithFormat:@"http://127.0.0.1:%s", argc > 2 ? argv[2] : "8080"];
        harness.tag = @"device";
        harness.patience = 120;
        for (NSString *className in @[@"NSURLSession", @"NSURLSessionConfiguration", @"NSURLSessionTask", @"NSURLSessionDataTask", @"NSURLSessionUploadTask", @"NSURLSessionDownloadTask"])
            CHECK_EQUAL(image_of(NSClassFromString(className)), @"libFoundationBackports.dylib", [[className stringByAppendingString:@" comes from the backports library"] UTF8String]);
        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
        CHECK(configuration.HTTPMaximumConnectionsPerHost == 4, "iOS default of four connections per host");
        CHECK(configuration.TLSMinimumSupportedProtocol == kSSLProtocol3 && configuration.TLSMaximumSupportedProtocol == kTLSProtocol12, "iOS 7 TLS protocol defaults");
        CHECK_EQUAL(configuration.protocolClasses, @[], "no built-in protocol classes are listed");
        CHECK_EQUAL(NSURLSessionDownloadTaskResumeData, @"NSURLSessionDownloadTaskResumeData", "resume data key");
        CHECK_EQUAL(NSURLErrorBackgroundTaskCancelledReasonKey, @"NSURLErrorBackgroundTaskCancelledReasonKey", "background cancel reason key");
        CHECK([[NSURLSession sharedSession] respondsToSelector:@selector(getAllTasksWithCompletionHandler:)], "9.0 category is attached");
        dispatch_semaphore_t invalid = dispatch_semaphore_create(0);
        __block NSError *invalidError = nil;
        NSURLSession *shared = [NSURLSession sharedSession];
        NSURLSessionDownloadTask *junk = [shared downloadTaskWithResumeData:[@"junk" dataUsingEncoding:NSUTF8StringEncoding] completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
            invalidError = error;
            dispatch_semaphore_signal(invalid);
        }];
        [junk resume];
        dispatch_semaphore_wait(invalid, dispatch_time(DISPATCH_TIME_NOW, 30 * NSEC_PER_SEC));
        CHECK(invalidError.code == NSURLErrorCannotOpenFile && [invalidError.domain isEqualToString:NSURLErrorDomain], "unusable resume data fails the task with NSURLErrorCannotOpenFile");
        NSDictionary *expected = session_expected_transcripts();
        for (size_t index = 0; index < session_scenario_count; index++) {
            const SessionScenarioEntry *entry = &session_scenarios[index];
            if (!selected(argc, argv, entry->name))
                continue;
            printf("scenario %s\n", entry->name);
            fflush(stdout);
            NSUInteger offQueue = session_off_queue_count();
            NSDate *start = [NSDate date];
            NSArray *transcript = entry->run(harness);
            printf("scenario %s took %.1fs\n", entry->name, -start.timeIntervalSinceNow);
            CHECK_EQUAL(transcript, expected[@(entry->name)], entry->name);
            CHECK(session_off_queue_count() == offQueue, "delegate callbacks run on the delegate queue");
        }
        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
        fflush(stdout);
        [@"" writeToFile:[NSString stringWithFormat:@"/private/var/backports/%s.done", name] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    }
    return charon_failures;
}
