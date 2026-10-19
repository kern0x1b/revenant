#import <Foundation/Foundation.h>
#import "check.h"
#import "session-scenarios.h"

static BOOL selected(int argc, char **argv, const char *name)
{
    if (argc <= 2)
        return YES;
    for (int index = 1; index < argc - 1; index++) {
        if (strcmp(argv[index], name) == 0)
            return YES;
    }
    return NO;
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        if (argc < 2) {
            fprintf(stderr, "usage: %s [scenario...] port\n", argv[0]);
            return 2;
        }
        NSString *base = [NSString stringWithFormat:@"http://127.0.0.1:%s", argv[argc - 1]];
        SessionHarness *system = [[SessionHarness alloc] init];
        system.sessionClass = [NSURLSession class];
        system.configurationClass = [NSURLSessionConfiguration class];
        system.base = base;
        system.tag = @"system";
        system.patience = 30;
        SessionHarness *charon = [[SessionHarness alloc] init];
        charon.sessionClass = NSClassFromString(@"CharonHostNSURLSession");
        charon.configurationClass = NSClassFromString(@"CharonHostNSURLSessionConfiguration");
        charon.base = base;
        charon.tag = @"charon";
        charon.prefix = @"CharonHost";
        charon.patience = 30;
        CHECK(charon.sessionClass && charon.configurationClass, "renamed classes are linked");
        NSDictionary *expected = session_expected_transcripts();
        for (size_t index = 0; index < session_scenario_count; index++) {
            const SessionScenarioEntry *entry = &session_scenarios[index];
            if (!selected(argc, argv, entry->name))
                continue;
            NSString *name = @(entry->name);
            NSUInteger offQueue = session_off_queue_count();
            NSArray *mine = entry->run(charon);
            CHECK(session_off_queue_count() == offQueue, [[name stringByAppendingString:@": charon calls the delegate on its delegate queue"] UTF8String]);
            NSArray *reference = expected[name];
            if (!reference || ![mine isEqual:reference])
                printf("charon %s:\n%s", entry->name, session_transcript_text(mine).UTF8String);
            NSArray *theirs = session_normalize_host_system(entry->run(system));
            if (!reference || ![theirs isEqual:reference])
                printf("system %s:\n%s", entry->name, session_transcript_text(theirs).UTF8String);
            CHECK_EQUAL(theirs, reference, [[name stringByAppendingString:@": system matches expected"] UTF8String]);
            CHECK_EQUAL(mine, reference, [[name stringByAppendingString:@": charon matches expected"] UTF8String]);
        }
    }
    printf("checks=%d failures=%d\n", charon_checks, charon_failures);
    return charon_failures;
}
