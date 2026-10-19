#import <Foundation/Foundation.h>
#import <HealthKit/HealthKit.h>

#import "check.h"

static NSString *const results_folder = @"/private/var/backports";

static void run_checks(void)
{
    BOOL available = [HKHealthStore isHealthDataAvailable];
    CHECK(available, "health data is available on a device that has the hardware");
    NSLog(@"health: isHealthDataAvailable = %@", available ? @"YES" : @"NO");

    HKHealthStore *store = [[HKHealthStore alloc] init];
    HKCharacteristicType *biologicalSex = [HKObjectType characteristicTypeForIdentifier:HKCharacteristicTypeIdentifierBiologicalSex];
    CHECK(biologicalSex != nil, "the biological sex type exists");
    CHECK(([store authorizationStatusForType:biologicalSex] == HKAuthorizationStatusNotDetermined),
                 "a type nobody asked about is not determined");

    HKQuantityType *stepCount = [HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierStepCount];
    CHECK(stepCount != nil, "the step count type exists");
    CHECK(([store authorizationStatusForType:stepCount] == HKAuthorizationStatusNotDetermined),
                 "and so is a quantity type nobody asked about");

    CHECK(([store authorizationStatusForType:(HKObjectType *)@"not a type"] == HKAuthorizationStatusNotDetermined),
          "an object that is not a type is not determined");

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
    [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
    CHECK(called, "the query's handler is called");
    CHECK(refusal != nil, "and it is given an error, not an empty answer that looks like no samples");
    if (refusal) {
        CHECK([refusal.domain isEqualToString:HKErrorDomain], "the error is in HKErrorDomain");
        CHECK(refusal.code == HKErrorAuthorizationDenied, "and it is the documented refusal of an unauthorized read");
        NSLog(@"health: a query of a type the process may not read gives %@ %ld in %@", refusal.domain, (long)refusal.code,
              refusal.localizedDescription);
    }

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
        revenant_log_to(log);
        NSLog(@"health: starting");
        run_checks();
        fflush(stdout);
        NSString *written = [NSString stringWithContentsOfFile:log encoding:NSUTF8StringEncoding error:NULL];
        for (NSString *line in [written componentsSeparatedByString:@"\n"])
            if (line.length)
                NSLog(@"guest log: %@", line);
        revenant_log_to(nil);
        return revenant_failures == 0 ? 0 : 1;
    }
}
