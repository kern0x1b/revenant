#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <stdio.h>

static NSString *answer(Class cls, SEL selector, BOOL allocate)
{
    @try {
        id made;
        if (allocate) {
            id allocated = ((id (*)(id, SEL))objc_msgSend)(cls, @selector(alloc));
            made = ((id (*)(id, SEL))objc_msgSend)(allocated, selector);
        } else {
            made = ((id (*)(id, SEL))objc_msgSend)(cls, selector);
        }
        NSString *name = made ? NSStringFromClass([made class]) : @"nil";
        return [@"ok " stringByAppendingString:[name stringByReplacingOccurrencesOfString:@"CharonHost" withString:@""]];
    } @catch (NSException *exception) {
        NSString *reason = [exception.reason stringByReplacingOccurrencesOfString:@"CharonHost" withString:@""];
        return [NSString stringWithFormat:@"raises %@ (%@)", exception.name, reason];
    }
}

static int failures = 0;

static void compare(NSString *name, SEL selector, BOOL allocate)
{
    Class host = NSClassFromString(name);
    Class port = NSClassFromString([@"CharonHost" stringByAppendingString:name]);
    if (!host || !port) {
        printf("FAIL %s: host=%s port=%s\n", name.UTF8String, host ? "yes" : "no", port ? "yes" : "no");
        failures++;
        return;
    }
    NSString *hostAnswer = answer(host, selector, allocate);
    NSString *portAnswer = answer(port, selector, allocate);
    BOOL same = [hostAnswer isEqualToString:portAnswer];
    if (!same)
        failures++;
    printf("%s %s %s host=%s port=%s\n", same ? "SAME" : "FAIL", name.UTF8String,
           NSStringFromSelector(selector).UTF8String, hostAnswer.UTF8String, portAnswer.UTF8String);
}

int main(void)
{
    setvbuf(stdout, NULL, _IOLBF, 0);
    NSArray<NSString *> *names = @[
        @"HKCategorySample", @"HKObject", @"HKObjectType", @"HKQuantity",
        @"HKSource", @"HKStatistics", @"HKStatisticsCollection", @"HKWorkoutEvent",
        @"HKSample", @"HKQuantitySample", @"HKWorkout", @"HKCorrelation", @"HKQuantityType", @"HKDeletedObject",
    ];
    for (NSString *name in names) {
        compare(name, @selector(init), YES);
        compare(name, @selector(new), NO);
    }

    Class statistics = NSClassFromString(@"CharonHostHKStatistics");
    id made = ((id (*)(id, SEL, NSArray *, NSUInteger))objc_msgSend)(statistics,
                  NSSelectorFromString(@"charon_statisticsForSamples:options:"), @[], 0);
    id copied = made ? ((id (*)(id, SEL))objc_msgSend)(made, @selector(copy)) : nil;
    BOOL statisticsOK = made && copied && [copied class] == statistics;
    printf("%s CharonHostHKStatistics copy made=%s copied=%s\n", statisticsOK ? "SAME" : "FAIL",
           made ? "yes" : "no", copied ? "yes" : "no");
    if (!statisticsOK)
        failures++;

    Class collectionClass = NSClassFromString(@"CharonHostHKStatisticsCollection");
    NSDateComponents *interval = [[NSDateComponents alloc] init];
    interval.day = 1;
    id collection = ((id (*)(id, SEL, NSDate *, NSUInteger, NSDateComponents *, NSArray *, NSCalendar *))objc_msgSend)(
        collectionClass, NSSelectorFromString(@"charon_collectionWithAnchorDate:options:intervalComponents:samples:calendar:"),
        [NSDate dateWithTimeIntervalSince1970:0], 0, interval, @[], [NSCalendar currentCalendar]);
    id collectionCopy = collection ? ((id (*)(id, SEL))objc_msgSend)(collection, @selector(copy)) : nil;
    BOOL collectionOK = collection && collectionCopy && [collectionCopy class] == collectionClass;
    printf("%s CharonHostHKStatisticsCollection copy made=%s copied=%s\n", collectionOK ? "SAME" : "FAIL",
           collection ? "yes" : "no", collectionCopy ? "yes" : "no");
    if (!collectionOK)
        failures++;

    printf("failures=%d\n", failures);
    return failures ? 1 : 0;
}
