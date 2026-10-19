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
