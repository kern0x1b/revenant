#import <Foundation/Foundation.h>
#import <SensorKit/SRAbsoluteTime.h>
#import <mach/mach_time.h>

typedef struct {
    uint64_t continuous;
    CFAbsoluteTime absolute;
} CharonSensorKitClockAnchor;

static const CharonSensorKitClockAnchor *CharonSensorKitClockAnchorOf(void)
{
    static CharonSensorKitClockAnchor anchor;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        anchor.continuous = mach_absolute_time();
        anchor.absolute = CFAbsoluteTimeGetCurrent();
    });
    return &anchor;
}

static mach_timebase_info_data_t CharonSensorKitTimebase(void)
{
    mach_timebase_info_data_t info = {0, 0};
    mach_timebase_info(&info);
    return info;
}

static NSTimeInterval CharonSensorKitSecondsFromTicks(uint64_t ticks)
{
    mach_timebase_info_data_t info = CharonSensorKitTimebase();
    long double seconds = ((long double)ticks * (long double)info.numer) / (long double)info.denom / 1e9L;
    return (NSTimeInterval)seconds;
}

double CharonSensorKitMonotonicSeconds(void)
{
    static mach_timebase_info_data_t info = {0, 0};
    static dispatch_once_t once;
    dispatch_once(&once, ^{ mach_timebase_info(&info); });
    long double seconds = ((long double)mach_absolute_time() * (long double)info.numer) / (long double)info.denom / 1e9L;
    return (double)seconds;
}

SRAbsoluteTime SRAbsoluteTimeGetCurrent(void)
{
    const CharonSensorKitClockAnchor *anchor = CharonSensorKitClockAnchorOf();
    NSTimeInterval elapsed = CharonSensorKitSecondsFromTicks(mach_absolute_time() - anchor->continuous);
    return (SRAbsoluteTime)(anchor->absolute + elapsed);
}

SRAbsoluteTime SRAbsoluteTimeFromContinuousTime(uint64_t cont)
{
    const CharonSensorKitClockAnchor *anchor = CharonSensorKitClockAnchorOf();
    uint64_t sinceBoot = cont > anchor->continuous ? cont - anchor->continuous : 0;
    return (SRAbsoluteTime)(anchor->absolute + CharonSensorKitSecondsFromTicks(sinceBoot));
}

CFAbsoluteTime SRAbsoluteTimeToCFAbsoluteTime(SRAbsoluteTime sr)
{
    const CharonSensorKitClockAnchor *anchor = CharonSensorKitClockAnchorOf();
    return anchor->absolute + ((CFAbsoluteTime)sr - anchor->absolute);
}

SRAbsoluteTime SRAbsoluteTimeFromCFAbsoluteTime(CFAbsoluteTime cf)
{
    const CharonSensorKitClockAnchor *anchor = CharonSensorKitClockAnchorOf();
    return (SRAbsoluteTime)(anchor->absolute + (cf - anchor->absolute));
}
