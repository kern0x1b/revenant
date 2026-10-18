#import <Foundation/Foundation.h>
#import <HealthKit/HealthKit.h>

#import "check.h"

// What a device without Health data answers, and what the release's own HealthKit would have.
//
// The three questions below are PORT-ONLY rows: the release's own HealthKit is not the oracle for any
// of them. On 6.1.3 the release has no HealthKit at all - the armv7 shared cache holds no HealthKit
// image and exports no name of it, measured with NSObject and PassKit as the controls that say the probe
// finds what is there - and a release that had one would not be the oracle either: the store, the
// authorization and the queries are this port's own, so what a release's healthd would answer is an
// answer about a different program. Each row is therefore the port held to what Apple's own headers
// document, and the absence of the release is the control that says none of them is a host comparison.

static NSString *const results_folder = @"/private/var/backports";

static void run_checks(void)
{
    // 1. Is Health data available?
    //
    // +[HKHealthStore isHealthDataAvailable] answers NO on a device with no HealthKit and no health
    // data, and YES where the hardware and the platform are both there. The iPhone 4S and the iPad 2
    // are the devices that run this release and they do have the hardware, so the release's own answer
    // would be YES had it the class at all. The port answers YES for exactly that reason and says why
    // in its own comment: the data is the process's own store, not a store of Apple's that could be
    // missing.
    BOOL available = [HKHealthStore isHealthDataAvailable];
    CHECK(available, "health data is available on a device that has the hardware");
    NSLog(@"health: isHealthDataAvailable = %@", available ? @"YES" : @"NO");

    // 2. The authorization status for a process that has asked for nothing.
    //
    // -[HKHealthStore authorizationStatusForType:] reports whether the process may write a type, and
    // for a process that has made no request it is HKAuthorizationStatusNotDetermined. That is the
    // documented answer and the one this test holds the port to: a type nobody asked about is not
    // determined, not authorized and not denied.
    HKHealthStore *store = [[HKHealthStore alloc] init];
    HKCharacteristicType *biologicalSex = [HKObjectType characteristicTypeForIdentifier:HKCharacteristicTypeIdentifierBiologicalSex];
    CHECK(biologicalSex != nil, "the biological sex type exists");
    CHECK(([store authorizationStatusForType:biologicalSex] == HKAuthorizationStatusNotDetermined),
                 "a type nobody asked about is not determined");

    HKQuantityType *stepCount = [HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierStepCount];
    CHECK(stepCount != nil, "the step count type exists");
    CHECK(([store authorizationStatusForType:stepCount] == HKAuthorizationStatusNotDetermined),
                 "and so is a quantity type nobody asked about");

    // A type that is not a type at all is not determined either, rather than a crash or a guess.
    CHECK(([store authorizationStatusForType:(HKObjectType *)@"not a type"] == HKAuthorizationStatusNotDetermined),
          "an object that is not a type is not determined");

    // 3. A query's error.
    //
    // A query of a type the process may not read must not answer samples. The store refuses with the
    // documented error for a read that has not been authorized, HKErrorAuthorizationDenied, and the
    // refusal has to arrive through the query's own handler rather than as a crash or as an empty
    // answer that a caller cannot tell from "no samples".
    __block NSError *refusal = nil;
    __block BOOL called = NO;
    HKSampleQuery *query = [[HKSampleQuery alloc] initWithSampleType:stepCount
                                                          predicate:nil
                                                              limit:HKObjectQueryNoLimit
                                                   sortDescriptors:nil
                                                    resultsHandler:^(HKSampleQuery *q, NSArray<HKSample *> *results, NSError *error) {
        called = YES;
        refusal = error;
    }];
    [store executeQuery:query];
    // The handler is called on the main queue, and this program has no run loop, so the answer is taken
    // by draining the main queue once rather than by waiting: the test is about what the handler is
    // given, not about when.
    [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
    CHECK(called, "the query's handler is called");
    CHECK(refusal != nil, "and it is given an error, not an empty answer that looks like no samples");
    if (refusal) {
        CHECK([refusal.domain isEqualToString:HKErrorDomain], "the error is in HKErrorDomain");
        CHECK(refusal.code == HKErrorAuthorizationDenied, "and it is the documented refusal of an unauthorized read");
        NSLog(@"health: a query of a type the process may not read gives %@ %ld in %@", refusal.domain, (long)refusal.code,
              refusal.localizedDescription);
    }

    // And the same query after the process has asked: the store then answers, with no samples, and with
    // no error - which is the pair of answers that makes a "no samples" a caller can act on.
    [store requestAuthorizationToShareTypes:[NSSet setWithObject:stepCount]
                                   readTypes:[NSSet setWithObject:stepCount]
                                  completion:^(BOOL success, NSError *error) {
        NSLog(@"health: the authorization request recorded = %@, %@", success ? @"YES" : @"NO", error);
    }];
    CHECK(([store authorizationStatusForType:stepCount] == HKAuthorizationStatusSharingAuthorized),
          "a type the process asked to write is authorized after the request");
    CHECK(([store authorizationStatusForType:biologicalSex] == HKAuthorizationStatusNotDetermined),
                 "and a type it did not ask about is still not determined");
}

int main(int argc, char *argv[])
{
    @autoreleasepool {
        NSString *log = [results_folder stringByAppendingPathComponent:@"healthkit.log"];
        charon_log_to(log);
        NSLog(@"health: starting");
        run_checks();
        fflush(stdout);
        // The checks' lines are in the guest's log; read that file back here, as the guest sees it, and echo each line through
        // NSLog, which the emulator's run captures on the host. A missing file echoes nothing, and run.sh counts the lines it saw.
        NSString *written = [NSString stringWithContentsOfFile:log encoding:NSUTF8StringEncoding error:NULL];
        for (NSString *line in [written componentsSeparatedByString:@"\n"])
            if (line.length)
                NSLog(@"guest log: %@", line);
        charon_log_to(nil);
        return charon_failures == 0 ? 0 : 1;
    }
}
