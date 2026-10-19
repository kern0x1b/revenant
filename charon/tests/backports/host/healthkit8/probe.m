// probe.m — what a caller of this port actually gets for the sixteen registry rows of
// registry/HealthKit/ios8.json that sit at `absent`, and what the system's own HealthKit answers for
// the same sixteen names, in one process.
//
// WHY THIS FILE EXISTS. Those sixteen rows each carry an `effect`, and eight of them said
// "the method is not there: respondsToSelector: answers NO" for a class's `-init`. Nothing in the tree
// checked that sentence. The port's classes inherit NSObject's `-init`, and an inherited method is not
// a symbol the port exports, so `nm -gU` cannot see it and the gate's own reader
// (`modules/apple/backports.lua`'s `backports.surface()`) does not see it either: it reads the
// library's own method lists, and NSObject's is another image's. This file is what sees it.
//
// TWO KINDS OF CHECK, and why they are not one.
//   The eight `-init` rows claim the method is NOT there. The system's own class is the oracle for
//   what a real HKObject is, so for these the port and the system must AGREE, and the interesting
//   failure is a port that answered differently from the class it is a backport of.
//   The other eight are `absent` by contract - the workout-session methods are watchOS's surface and
//   the states-of-mind predicates are of iOS 18 - so for these the port must NOT answer the selector,
//   and whatever the system answers is printed beside it as information rather than as the verdict.
//
// WHAT IS COMPARED, and what is deliberately not. Class shape only: does the class answer the
// selector, and for `-init` what an allocation through it comes back as. That is the property a
// registry row's `effect` describes. The store, the authorization and the queries are not in here: a
// host keeps its data in a healthd behind an entitlement and this port's is a SQLite database of its
// own, so neither side is an oracle for the other's data. Nothing is asked of anybody - a predicate
// factory is a pure function - so both halves run in one process without an entitlement.

#import <Foundation/Foundation.h>
#import <HealthKit/HealthKit.h>

#import <objc/runtime.h>

static NSUInteger failures = 0;
static NSUInteger checks = 0;

static void report(NSString *name, BOOL passed, NSString *detail)
{
    checks = checks + 1;
    if (!passed) {
        failures = failures + 1;
    }
    printf("%s %-58s %s\n", passed ? "ok  " : "FAIL", name.UTF8String, detail.UTF8String);
}

// What an allocation through -init comes back as, with whatever the class does when it is asked.
// The system's own class may refuse an init it marks unavailable, and that is an answer worth having,
// so the raise is caught and printed rather than left to end the run.
static NSString *allocation_of(Class cls)
{
    if (!cls) {
        return @"the class is not in this process";
    }
    @try {
        id object = [[cls alloc] init];
        return [NSString stringWithFormat:@"<%@:%p>", NSStringFromClass([object class]), object];
    } @catch (NSException *raised) {
        return [NSString stringWithFormat:@"raised %@: %@", raised.name, raised.reason];
    }
}

static void probe_init(NSString *api, Class host, Class port)
{
    if (!host || !port) {
        report(api, NO, [NSString stringWithFormat:@"host=%@ port=%@",
                                                   host ? @"present" : @"ABSENT",
                                                   port ? @"present" : @"ABSENT"]);
        return;
    }
    BOOL hostSays = [host instancesRespondToSelector:@selector(init)];
    BOOL portSays = [port instancesRespondToSelector:@selector(init)];
    report(api, hostSays == portSays,
           [NSString stringWithFormat:@"instancesRespondToSelector: host=%@ port=%@; alloc-init gives host %@ port %@",
                                      hostSays ? @"YES" : @"no", portSays ? @"YES" : @"no",
                                      allocation_of(host), allocation_of(port)]);
}

// A selector the row says the port does not answer. The system's own answer is printed beside the
// verdict because it is what says which group the method belongs to: a system that answers it and a
// port that does not is the row's whole claim, and a system that does not answer it either is the
// watchOS case.
static void probe_not_answered(NSString *api, Class host, Class port, BOOL class_method, SEL selector)
{
    if (!host || !port) {
        report(api, NO, [NSString stringWithFormat:@"host=%@ port=%@",
                                                   host ? @"present" : @"ABSENT",
                                                   port ? @"present" : @"ABSENT"]);
        return;
    }
    BOOL hostSays = class_method ? [host respondsToSelector:selector]
                                 : [host instancesRespondToSelector:selector];
    BOOL portSays = class_method ? [port respondsToSelector:selector]
                                 : [port instancesRespondToSelector:selector];
    report(api, !portSays,
           [NSString stringWithFormat:@"%@ respondsToSelector: host=%@ port=%@",
                                      class_method ? @"+" : @"-", hostSays ? @"YES" : @"no",
                                      portSays ? @"YES" : @"no"]);
}

int main(void)
{
    @autoreleasepool {
        printf("stage: the sixteen rows of registry/HealthKit/ios8.json that sit at absent, asked of both halves\n");

        // The eight -init rows: the port must answer what the system's own class answers.
        probe_init(@"-[HKCategorySample init]", [HKCategorySample class],
                   NSClassFromString(@"CharonHostHKCategorySample"));
        probe_init(@"-[HKObject init]", [HKObject class], NSClassFromString(@"CharonHostHKObject"));
        probe_init(@"-[HKObjectType init]", [HKObjectType class],
                   NSClassFromString(@"CharonHostHKObjectType"));
        probe_init(@"-[HKQuantity init]", [HKQuantity class], NSClassFromString(@"CharonHostHKQuantity"));
        probe_init(@"-[HKSource init]", [HKSource class], NSClassFromString(@"CharonHostHKSource"));
        probe_init(@"-[HKStatistics init]", [HKStatistics class], NSClassFromString(@"CharonHostHKStatistics"));
        probe_init(@"-[HKStatisticsCollection init]", [HKStatisticsCollection class],
                   NSClassFromString(@"CharonHostHKStatisticsCollection"));
        probe_init(@"-[HKWorkoutEvent init]", [HKWorkoutEvent class],
                   NSClassFromString(@"CharonHostHKWorkoutEvent"));

        // The four workout-session methods of HKHealthStore: the watchOS surface of the class.
        Class hostStore = [HKHealthStore class];
        Class portStore = NSClassFromString(@"CharonHostHKHealthStore");
        probe_not_answered(@"-[HKHealthStore startWorkoutSession:]", hostStore, portStore, NO,
                           @selector(startWorkoutSession:));
        probe_not_answered(@"-[HKHealthStore endWorkoutSession:]", hostStore, portStore, NO,
                           @selector(endWorkoutSession:));
        probe_not_answered(@"-[HKHealthStore pauseWorkoutSession:]", hostStore, portStore, NO,
                           @selector(pauseWorkoutSession:));
        probe_not_answered(@"-[HKHealthStore resumeWorkoutSession:]", hostStore, portStore, NO,
                           @selector(resumeWorkoutSession:));

        // The four states-of-mind predicates of HKQuery: of iOS 18, so named with sel_registerName
        // rather than written as @selector, which this host's header may not declare.
        Class hostQuery = [HKQuery class];
        Class portQuery = NSClassFromString(@"CharonHostHKQuery");
        probe_not_answered(@"+[HKQuery predicateForStatesOfMindWithAssociation:]", hostQuery, portQuery,
                           YES, sel_registerName("predicateForStatesOfMindWithAssociation:"));
        probe_not_answered(@"+[HKQuery predicateForStatesOfMindWithKind:]", hostQuery, portQuery, YES,
                           sel_registerName("predicateForStatesOfMindWithKind:"));
        probe_not_answered(@"+[HKQuery predicateForStatesOfMindWithLabel:]", hostQuery, portQuery, YES,
                           sel_registerName("predicateForStatesOfMindWithLabel:"));
        probe_not_answered(@"+[HKQuery predicateForStatesOfMindWithValence:operatorType:]", hostQuery,
                           portQuery, YES,
                           sel_registerName("predicateForStatesOfMindWithValence:operatorType:"));

        printf("checks=%lu failures=%lu\n", (unsigned long)checks, (unsigned long)failures);
    }
    return failures == 0 ? 0 : 1;
}
