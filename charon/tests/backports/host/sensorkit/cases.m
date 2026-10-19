#import <Foundation/Foundation.h>
#import <unistd.h>
#import <CoreFoundation/CoreFoundation.h>
#import <SensorKit/SensorKit.h>
#import "sensorkit-cases.h"

// The three relations the four functions must satisfy, asked of whichever build is under test.
//
// The host's SensorKit is a real implementation, and the port's is over the two clocks the release
// actually has. What can be compared is not the numbers - they are two different anchors - but the
// RELATIONS, and those are the header's own contract:
//
//   1. the round trip is exact: what goes into -SRAbsoluteTimeFromCFAbsoluteTime: comes back out of
//      -SRAbsoluteTimeToCFAbsoluteTime:, to the nanosecond the clocks carry;
//   2. the pair names the same instant as CFAbsoluteTimeGetCurrent, because that is what an
//      SRAbsoluteTime is on this platform - so the two differ by no more than a clock tick;
//   3. and two readings of -SRAbsoluteTimeGetCurrent differ and the second is the larger, because the
//      clock is monotonic. (It is NOT monotonic across a sleep on this release: mach_continuous_time,
//      which the header's wording needs, arrived in iOS 10. See facts/SensorKit/SensorKit.md.)

static void recordRelations(CertificateRecorder record, NSString *who)
{
    // Two readings in a row and a third after a nap. The second pair is not required to differ: an
    // SRAbsoluteTime is a CFTimeInterval, and a double near 8e8 cannot resolve better than about 120ns,
    // so two back-to-back calls may answer the same value - the HOST's does too, which is why the
    // relation is "never less" and not "greater". The third, after a nap, must be greater.
    SRAbsoluteTime a = SRAbsoluteTimeGetCurrent();
    SRAbsoluteTime b = SRAbsoluteTimeGetCurrent();
    usleep(2000);
    SRAbsoluteTime c = SRAbsoluteTimeGetCurrent();
    record([NSString stringWithFormat:@"%@.neverBackwards", who], (b >= a && c > b) ? @"1" : @"0");
    record([NSString stringWithFormat:@"%@.thirdReadingAdvances", who], c > b ? @"1" : @"0");
    record([NSString stringWithFormat:@"%@.notNull", who], (a != OS_SIGNPOST_ID_NULL && a != 0) ? @"1" : @"0");

    CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
    CFAbsoluteTime named = SRAbsoluteTimeToCFAbsoluteTime(a);
    CFAbsoluteTime gap = named - now;
    if (gap < 0) gap = -gap;
    record([NSString stringWithFormat:@"%@.agreesWithCFAbsoluteTime", who], gap < 1.0 ? @"1" : @"0");
    record([NSString stringWithFormat:@"%@.gapSeconds", who], [NSString stringWithFormat:@"%.6f", gap]);

    // The round trip, within the resolution the pair itself has. It is NOT bit-exact and the header
    // does not say it is: a CFTimeInterval near 8e8 resolves to about 120ns, so a value that comes back
    // within a microsecond came back exactly as far as these clocks can tell. The host's own drift is
    // recorded rather than assumed.
    SRAbsoluteTime round = SRAbsoluteTimeFromCFAbsoluteTime(named);
    double drift = round - a;
    if (drift < 0) drift = -drift;
    record([NSString stringWithFormat:@"%@.roundTripWithinAMicrosecond", who], drift < 1e-6 ? @"1" : @"0");
    record([NSString stringWithFormat:@"%@.roundTripDrift", who], [NSString stringWithFormat:@"%.3e", drift]);

    // the nanosecond form: the header says the argument is a continuous time in nanoseconds
    SRAbsoluteTime fromNanos = SRAbsoluteTimeFromContinuousTime(1000000000ull);
    record([NSString stringWithFormat:@"%@.fromContinuousNonZero", who], fromNanos != 0 ? @"1" : @"0");
}


// THE NSDate(SensorKit) CATEGORY'S RELATIONS, asked of whichever build is under test. The same three
// relations the time functions are held to, applied to the other side of the same clock pair, because
// the category is three wrappers over those conversions and nothing else:
//
//   1. the round trip through the two instance methods is exact, as the time functions' is;
//   2. a date and the clock agree - the SRAbsoluteTime a date names is the instant the date names;
//   3. and two dates made from two readings are never in the wrong order.
//
// THE THREE SELECTORS ARE SPELLED THE SDK'S WAY ON BOTH SIDES, and rename.lua renames them for the
// PORT'S half only - the same mechanism the four time functions use, and for the same reason: one binary
// carries this category and the host's own SensorKit, and neither may shadow the other. So the case file
// names one set and each build answers with its own, and a `#ifdef` is not needed anywhere.
static SEL CharonSelWithDate(void) { return @selector(dateWithSRAbsoluteTime:); }

static SEL CharonSelInitWithDate(void) { return @selector(initWithSRAbsoluteTime:); }

static SEL CharonSelAbsolute(void) { return @selector(srAbsoluteTime); }

static id CharonSendAbsolute(id date)
{
    if (![date respondsToSelector:CharonSelAbsolute()]) {
        return nil;
    }
    NSMethodSignature *signature = [date methodSignatureForSelector:CharonSelAbsolute()];
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
    invocation.selector = CharonSelAbsolute();
    [invocation invokeWithTarget:date];
    SRAbsoluteTime out = 0;
    [invocation getReturnValue:&out];
    return [NSNumber numberWithDouble:(double)out];
}

static void recordCategoryRelations(CertificateRecorder record, NSString *who)
{
    Class date = [NSDate class];
    record([NSString stringWithFormat:@"%@.categoryClassMethodPresent", who],
           [date respondsToSelector:CharonSelWithDate()] ? @"1" : @"0");
    record([NSString stringWithFormat:@"%@.categoryInitPresent", who],
           [date instancesRespondToSelector:CharonSelInitWithDate()] ? @"1" : @"0");
    record([NSString stringWithFormat:@"%@.categoryGetterPresent", who],
           [date instancesRespondToSelector:CharonSelAbsolute()] ? @"1" : @"0");
    if (![date respondsToSelector:CharonSelWithDate()] ||
        ![date instancesRespondToSelector:CharonSelInitWithDate()] ||
        ![date instancesRespondToSelector:CharonSelAbsolute()]) {
        // the host's own build has not got all three, and a relation that cannot be asked is recorded as
        // not asked rather than as passed
        record([NSString stringWithFormat:@"%@.categoryRoundTrip", who], @"not-asked");
        record([NSString stringWithFormat:@"%@.categoryAgreesWithClock", who], @"not-asked");
        record([NSString stringWithFormat:@"%@.categoryNeverBackwards", who], @"not-asked");
        return;
    }

    // 1. the round trip, through the two instance methods, within the resolution the pair has
    SRAbsoluteTime t = SRAbsoluteTimeGetCurrent();
    id made = [date performSelector:CharonSelWithDate() withObject:[NSNumber numberWithDouble:(double)t]];
    id read = CharonSendAbsolute(made);
    double drift = read ? fabs([read doubleValue] - (double)t) : 1e9;
    record([NSString stringWithFormat:@"%@.categoryRoundTrip", who], drift < 1e-6 ? @"1" : @"0");
    record([NSString stringWithFormat:@"%@.categoryRoundTripDrift", who],
           [NSString stringWithFormat:@"%.3e", drift]);

    // 2. the pair names the same instant as the wall clock, as the time functions' own relation does
    CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
    CFAbsoluteTime named = SRAbsoluteTimeToCFAbsoluteTime(t);
    double gap = fabs(named - now);
    record([NSString stringWithFormat:@"%@.categoryAgreesWithClock", who], gap < 1.0 ? @"1" : @"0");
    record([NSString stringWithFormat:@"%@.categoryGapSeconds", who],
           [NSString stringWithFormat:@"%.6f", gap]);

    // 3. two dates made from two readings, and the second is never the earlier
    SRAbsoluteTime first = SRAbsoluteTimeGetCurrent();
    usleep(2000);
    SRAbsoluteTime second = SRAbsoluteTimeGetCurrent();
    NSDate *one = [date performSelector:CharonSelWithDate() withObject:[NSNumber numberWithDouble:(double)first]];
    NSDate *two = [date performSelector:CharonSelWithDate() withObject:[NSNumber numberWithDouble:(double)second]];
    NSNumber *oneRead = CharonSendAbsolute(one);
    NSNumber *twoRead = CharonSendAbsolute(two);
    record([NSString stringWithFormat:@"%@.categoryNeverBackwards", who],
           (oneRead && twoRead && [twoRead doubleValue] >= [oneRead doubleValue]) ? @"1" : @"0");
}

void sensorkit_run(CertificateRecorder record)
{
    recordRelations(record, @"system");
    recordCategoryRelations(record, @"system");
#ifdef CHARON_SENSORKIT_PORT
    recordRelations(record, @"port");
    recordCategoryRelations(record, @"port");
#endif
}
