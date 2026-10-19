// The activity classes of CoreMotion, asked one question per process: the host's own CoreMotion (Catalyst) when built
// without -DPORT, and the port's CMMotionActivity.m and CMMotionActivityManager.m when built with it. The two sides are
// separate processes because both define the same classes; in one process the second to load would win and the port
// would be compared with itself.
//
// Each case is one argv[1] value and prints a fixed set of lines, so run.sh can compare the two sides case by case and a
// crash of one side is attributed to that case alone. Nothing here calls a sensor: the host has none, and the port has
// none to call.
#import <Foundation/Foundation.h>
#import <CoreMotion/CoreMotion.h>
#import <objc/runtime.h>

static NSString *queueKind(NSOperationQueue *passed)
{
    if ([NSOperationQueue currentQueue] == passed)
        return @"passed-queue";
    if ([NSThread isMainThread])
        return @"main-thread";
    return @"other-thread";
}

// The pedometer and the altimeter hand their handlers no queue of their own, or only the one they were given: the thread
// that runs a handler is the thing to compare for those.
static NSString *threadKind(void)
{
    return [NSThread isMainThread] ? @"main-thread" : @"other-thread";
}

static NSString *show(id value)
{
    return value ? [NSString stringWithFormat:@"%@", value] : @"nil";
}

static NSString *errorText(NSError *e)
{
    return e ? [NSString stringWithFormat:@"%@/%ld", e.domain, (long)e.code] : @"none";
}

int main(int argc, char **argv)
{
    setvbuf(stdout, NULL, _IOLBF, 0);
    int which = argc > 1 ? atoi(argv[1]) : -1;
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    __block int calls = 0;
    __block NSString *kind = @"never";
    __block NSError *error = nil;

    switch (which) {
    case 0:
        printf("isActivityAvailable=%d\n", [CMMotionActivityManager isActivityAvailable]);
        printf("authorizationStatus=%ld\n", (long)[CMMotionActivityManager authorizationStatus]);
        break;
    case 1: {
        CMMotionActivityManager *manager = [[CMMotionActivityManager alloc] init];
        [manager startActivityUpdatesToQueue:queue withHandler:^(CMMotionActivity *activity) {
            calls++;
            kind = queueKind(queue);
        }];
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:4.0]];
        [manager stopActivityUpdates];
        printf("startActivityUpdates: calls=%d queue=%s\n", calls, [kind UTF8String]);
        break;
    }
    case 2: {
        CMMotionActivityManager *manager = [[CMMotionActivityManager alloc] init];
        [manager queryActivityStartingFromDate:[NSDate dateWithTimeIntervalSinceNow:-3600] toDate:[NSDate date] toQueue:queue
            withHandler:^(NSArray<CMMotionActivity *> *activities, NSError *e) {
                calls++;
                error = e;
                kind = queueKind(queue);
            }];
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:4.0]];
        printf("queryActivity: calls=%d queue=%s error=%s\n", calls, [kind UTF8String],
               error ? [[NSString stringWithFormat:@"%@/%ld", error.domain, (long)error.code] UTF8String] : "none");
        break;
    }
    case 3: {
        CMMotionActivityManager *manager = [[CMMotionActivityManager alloc] init];
        [manager stopActivityUpdates];
        printf("stopActivityUpdates: returned\n");
        break;
    }
    case 4: {
        CMMotionActivity *activity = [[CMMotionActivity alloc] init];
        printf("startDate=%.1f\n", [activity.startDate timeIntervalSinceReferenceDate]);
        printf("confidence=%ld\n", (long)activity.confidence);
        printf("unknown=%d stationary=%d walking=%d running=%d automotive=%d cycling=%d\n", activity.unknown,
               activity.stationary, activity.walking, activity.running, activity.automotive, activity.cycling);
        break;
    }
    case 5:
        printf("CMMotionActivity supportsSecureCoding=%d\n", [CMMotionActivity supportsSecureCoding]);
        break;
    case 6: {
        CMMotionActivity *activity = [[CMMotionActivity alloc] init];
        CMMotionActivity *copy = [activity copy];
        printf("copy class=%s startDate=%.1f confidence=%ld unknown=%d\n", class_getName([copy class]),
               [copy.startDate timeIntervalSinceReferenceDate], (long)copy.confidence, copy.unknown);
        break;
    }
    case 7: {
        CMMotionActivity *activity = [[CMMotionActivity alloc] init];
        NSError *e = nil;
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:activity requiringSecureCoding:YES error:&e];
        CMMotionActivity *decoded = [NSKeyedUnarchiver unarchivedObjectOfClass:[CMMotionActivity class] fromData:data error:&e];
        printf("round trip class=%s unknown=%d confidence=%ld\n", decoded ? class_getName([decoded class]) : "nil",
               decoded.unknown, (long)decoded.confidence);
        break;
    }
    case 8:
        printf("isStepCountingAvailable=%d\n", [CMPedometer isStepCountingAvailable]);
        printf("isDistanceAvailable=%d\n", [CMPedometer isDistanceAvailable]);
        printf("isFloorCountingAvailable=%d\n", [CMPedometer isFloorCountingAvailable]);
        printf("isPaceAvailable=%d\n", [CMPedometer isPaceAvailable]);
        printf("isCadenceAvailable=%d\n", [CMPedometer isCadenceAvailable]);
        printf("isPedometerEventTrackingAvailable=%d\n", [CMPedometer isPedometerEventTrackingAvailable]);
        printf("authorizationStatus=%ld\n", (long)[CMPedometer authorizationStatus]);
        break;
    case 9: {
        CMPedometer *pedometer = [[CMPedometer alloc] init];
        [pedometer queryPedometerDataFromDate:[NSDate dateWithTimeIntervalSinceNow:-3600] toDate:[NSDate date]
            withHandler:^(CMPedometerData *data, NSError *e) {
                calls++;
                error = e;
                kind = threadKind();
            }];
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:4.0]];
        printf("queryPedometer: calls=%d thread=%s error=%s\n", calls, [kind UTF8String], [errorText(error) UTF8String]);
        break;
    }
    case 10: {
        CMPedometer *pedometer = [[CMPedometer alloc] init];
        [pedometer startPedometerUpdatesFromDate:[NSDate dateWithTimeIntervalSinceNow:-3600]
            withHandler:^(CMPedometerData *data, NSError *e) {
                calls++;
                error = e;
                kind = threadKind();
            }];
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:4.0]];
        [pedometer stopPedometerUpdates];
        printf("startPedometerUpdates: calls=%d thread=%s error=%s\n", calls, [kind UTF8String], [errorText(error) UTF8String]);
        break;
    }
    case 11: {
        CMPedometer *pedometer = [[CMPedometer alloc] init];
        [pedometer startPedometerEventUpdatesWithHandler:^(CMPedometerEvent *event, NSError *e) {
            calls++;
            error = e;
            kind = threadKind();
        }];
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:4.0]];
        [pedometer stopPedometerEventUpdates];
        printf("startPedometerEventUpdates: calls=%d thread=%s error=%s\n", calls, [kind UTF8String], [errorText(error) UTF8String]);
        break;
    }
    case 12: {
        CMPedometer *pedometer = [[CMPedometer alloc] init];
        [pedometer stopPedometerUpdates];
        [pedometer stopPedometerEventUpdates];
        printf("stopPedometer: returned\n");
        break;
    }
    case 13: {
        CMPedometerData *data = [[CMPedometerData alloc] init];
        printf("supportsSecureCoding=%d\n", [CMPedometerData supportsSecureCoding]);
        printf("startDate=%s endDate=%s numberOfSteps=%s\n", [show(data.startDate) UTF8String],
               [show(data.endDate) UTF8String], [show(data.numberOfSteps) UTF8String]);
        printf("distance=%s floorsAscended=%s floorsDescended=%s\n", [show(data.distance) UTF8String],
               [show(data.floorsAscended) UTF8String], [show(data.floorsDescended) UTF8String]);
        printf("currentPace=%s currentCadence=%s averageActivePace=%s\n", [show(data.currentPace) UTF8String],
               [show(data.currentCadence) UTF8String], [show(data.averageActivePace) UTF8String]);
        break;
    }
    case 14: {
        CMPedometerData *data = [[CMPedometerData alloc] init];
        CMPedometerData *copy = [data copy];
        printf("copy class=%s numberOfSteps=%s\n", class_getName([copy class]), [show(copy.numberOfSteps) UTF8String]);
        break;
    }
    case 15: {
        CMPedometerData *data = [[CMPedometerData alloc] init];
        NSError *e = nil;
        NSData *archive = [NSKeyedArchiver archivedDataWithRootObject:data requiringSecureCoding:YES error:&e];
        CMPedometerData *decoded = [NSKeyedUnarchiver unarchivedObjectOfClass:[CMPedometerData class] fromData:archive error:&e];
        printf("round trip archive=%s class=%s numberOfSteps=%s error=%s\n", archive ? "ok" : "failed",
               decoded ? class_getName([decoded class]) : "nil", [show(decoded.numberOfSteps) UTF8String],
               [errorText(e) UTF8String]);
        break;
    }
    case 16: {
        CMPedometerEvent *event = [[CMPedometerEvent alloc] init];
        printf("supportsSecureCoding=%d\n", [CMPedometerEvent supportsSecureCoding]);
        printf("date=%s type=%ld\n", [show(event.date) UTF8String], (long)event.type);
        break;
    }
    case 17: {
        CMPedometerEvent *event = [[CMPedometerEvent alloc] init];
        CMPedometerEvent *copy = [event copy];
        printf("copy class=%s date=%s type=%ld\n", class_getName([copy class]), [show(copy.date) UTF8String], (long)copy.type);
        break;
    }
    case 18: {
        CMPedometerEvent *event = [[CMPedometerEvent alloc] init];
        NSError *e = nil;
        NSData *archive = [NSKeyedArchiver archivedDataWithRootObject:event requiringSecureCoding:YES error:&e];
        CMPedometerEvent *decoded = [NSKeyedUnarchiver unarchivedObjectOfClass:[CMPedometerEvent class] fromData:archive error:&e];
        printf("round trip archive=%s class=%s date=%s type=%ld error=%s\n", archive ? "ok" : "failed",
               decoded ? class_getName([decoded class]) : "nil", [show(decoded.date) UTF8String], (long)decoded.type,
               [errorText(e) UTF8String]);
        break;
    }
    case 20:
        printf("isRelativeAltitudeAvailable=%d\n", [CMAltimeter isRelativeAltitudeAvailable]);
        printf("isAbsoluteAltitudeAvailable=%d\n", [CMAltimeter isAbsoluteAltitudeAvailable]);
        printf("authorizationStatus=%ld\n", (long)[CMAltimeter authorizationStatus]);
        break;
    case 21: {
        CMAltimeter *altimeter = [[CMAltimeter alloc] init];
        [altimeter startRelativeAltitudeUpdatesToQueue:queue withHandler:^(CMAltitudeData *data, NSError *e) {
            calls++;
            error = e;
            kind = queueKind(queue);
        }];
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:4.0]];
        [altimeter stopRelativeAltitudeUpdates];
        printf("startRelativeAltitudeUpdates: calls=%d queue=%s error=%s\n", calls, [kind UTF8String], [errorText(error) UTF8String]);
        break;
    }
    case 22: {
        CMAltimeter *altimeter = [[CMAltimeter alloc] init];
        [altimeter startAbsoluteAltitudeUpdatesToQueue:queue withHandler:^(CMAbsoluteAltitudeData *data, NSError *e) {
            calls++;
            error = e;
            kind = queueKind(queue);
        }];
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:4.0]];
        [altimeter stopAbsoluteAltitudeUpdates];
        printf("startAbsoluteAltitudeUpdates: calls=%d queue=%s error=%s\n", calls, [kind UTF8String], [errorText(error) UTF8String]);
        break;
    }
    case 23: {
        CMAltimeter *altimeter = [[CMAltimeter alloc] init];
        [altimeter stopRelativeAltitudeUpdates];
        [altimeter stopAbsoluteAltitudeUpdates];
        printf("stopAltimeter: returned\n");
        break;
    }
    case 24:
        printf("supportsSecureCoding=%d\n", [CMAltitudeData supportsSecureCoding]);
        break;
    case 25: {
        CMAltitudeData *data = [[CMAltitudeData alloc] init];
        printf("relativeAltitude=%s\n", [show(data.relativeAltitude) UTF8String]);
        printf("pressure=%s\n", [show(data.pressure) UTF8String]);
        break;
    }
    case 26: {
        CMAltitudeData *data = [[CMAltitudeData alloc] init];
        CMAltitudeData *copy = [data copy];
        printf("copy class=%s relativeAltitude=%s pressure=%s\n", class_getName([copy class]),
               [show(copy.relativeAltitude) UTF8String], [show(copy.pressure) UTF8String]);
        break;
    }
    case 27: {
        CMAltitudeData *data = [[CMAltitudeData alloc] init];
        NSError *e = nil;
        NSData *archive = [NSKeyedArchiver archivedDataWithRootObject:data requiringSecureCoding:YES error:&e];
        CMAltitudeData *decoded = [NSKeyedUnarchiver unarchivedObjectOfClass:[CMAltitudeData class] fromData:archive error:&e];
        printf("round trip archive=%s class=%s error=%s\n", archive ? "ok" : "failed",
               decoded ? class_getName([decoded class]) : "nil", [errorText(e) UTF8String]);
        break;
    }
    case 28: {
        CMAbsoluteAltitudeData *data = [[CMAbsoluteAltitudeData alloc] init];
        printf("supportsSecureCoding=%d\n", [CMAbsoluteAltitudeData supportsSecureCoding]);
        printf("altitude=%.1f accuracy=%.1f precision=%.1f\n", data.altitude, data.accuracy, data.precision);
        break;
    }
    case 29: {
        CMAbsoluteAltitudeData *data = [[CMAbsoluteAltitudeData alloc] init];
        CMAbsoluteAltitudeData *copy = [data copy];
        printf("copy class=%s altitude=%.1f accuracy=%.1f precision=%.1f\n", class_getName([copy class]),
               copy.altitude, copy.accuracy, copy.precision);
        break;
    }
    case 30: {
        CMAbsoluteAltitudeData *data = [[CMAbsoluteAltitudeData alloc] init];
        NSError *e = nil;
        NSData *archive = [NSKeyedArchiver archivedDataWithRootObject:data requiringSecureCoding:YES error:&e];
        CMAbsoluteAltitudeData *decoded = [NSKeyedUnarchiver unarchivedObjectOfClass:[CMAbsoluteAltitudeData class] fromData:archive error:&e];
        printf("round trip archive=%s class=%s altitude=%.1f error=%s\n", archive ? "ok" : "failed",
               decoded ? class_getName([decoded class]) : "nil", decoded.altitude, [errorText(e) UTF8String]);
        break;
    }
    default:
        printf("no such case %d\n", which);
        return 2;
    }
    return 0;
}
