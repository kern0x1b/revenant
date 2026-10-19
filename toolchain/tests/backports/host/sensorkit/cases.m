#import <Foundation/Foundation.h>
#import <unistd.h>
#import <CoreFoundation/CoreFoundation.h>
#import <SensorKit/SensorKit.h>
#import "sensorkit-cases.h"

static void recordRelations(CertificateRecorder record, NSString *who)
{
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

    SRAbsoluteTime round = SRAbsoluteTimeFromCFAbsoluteTime(named);
    double drift = round - a;
    if (drift < 0) drift = -drift;
    record([NSString stringWithFormat:@"%@.roundTripWithinAMicrosecond", who], drift < 1e-6 ? @"1" : @"0");
    record([NSString stringWithFormat:@"%@.roundTripDrift", who], [NSString stringWithFormat:@"%.3e", drift]);

    SRAbsoluteTime fromNanos = SRAbsoluteTimeFromContinuousTime(1000000000ull);
    record([NSString stringWithFormat:@"%@.fromContinuousNonZero", who], fromNanos != 0 ? @"1" : @"0");
}


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
        record([NSString stringWithFormat:@"%@.categoryRoundTrip", who], @"not-asked");
        record([NSString stringWithFormat:@"%@.categoryAgreesWithClock", who], @"not-asked");
        record([NSString stringWithFormat:@"%@.categoryNeverBackwards", who], @"not-asked");
        return;
    }

    SRAbsoluteTime t = SRAbsoluteTimeGetCurrent();
    id made = [date performSelector:CharonSelWithDate() withObject:[NSNumber numberWithDouble:(double)t]];
    id read = CharonSendAbsolute(made);
    double drift = read ? fabs([read doubleValue] - (double)t) : 1e9;
    record([NSString stringWithFormat:@"%@.categoryRoundTrip", who], drift < 1e-6 ? @"1" : @"0");
    record([NSString stringWithFormat:@"%@.categoryRoundTripDrift", who],
           [NSString stringWithFormat:@"%.3e", drift]);

    CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
    CFAbsoluteTime named = SRAbsoluteTimeToCFAbsoluteTime(t);
    double gap = fabs(named - now);
    record([NSString stringWithFormat:@"%@.categoryAgreesWithClock", who], gap < 1.0 ? @"1" : @"0");
    record([NSString stringWithFormat:@"%@.categoryGapSeconds", who],
           [NSString stringWithFormat:@"%.6f", gap]);

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
