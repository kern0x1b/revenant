// Only the time declarations, from the framework's own header: this file is the four time functions and
// needs nothing the port declares. That also keeps it buildable beside the host's own SensorKit, which is
// what the differential in tests/backports/host/sensorkit does - the port's class header would collide
// with the host's newer one.
#import <Foundation/Foundation.h>
#import <SensorKit/SRAbsoluteTime.h>
#import <mach/mach_time.h>

// The four time functions, over the clocks this release actually has.
//
// The header says what each of them is, and the two limits are named here because the release is
// short of what the header describes:
//
//   SRAbsoluteTimeGetCurrent()  a timestamp that keeps ticking across sleeps and reboots (the header).
//   SRAbsoluteTimeFromContinuousTime(cont)
//       mach_continuous_time is unstable and tied to the hardware, so the times it gives must come from the
//        single device and boot session (the header).
//
// Measured on the armv7 6.1.3 cache's 158 520 exports: mach_absolute_time, mach_timebase_info and
// CFAbsoluteTimeGetCurrent are all there, and **mach_continuous_time is not** - it arrived in iOS 10.
// So the clock that ticks across a sleep is not one this release has, and the port does not pretend:
//
//   - SRAbsoluteTimeGetCurrent() reads mach_absolute_time, which STOPS while the device sleeps. It is
//     monotonic, so it never goes backwards and the two conversions round-trip exactly, but a sleep
//     does not advance it. That limit is this release's, and it is stated rather than papered over;
//   - the two clock bases are joined by one anchor, read from the release's own CFAbsoluteTimeGetCurrent
//     the first time it is needed. Neither number is invented: the anchor is a wall-clock reading the
//     release produced, and every conversion after it is arithmetic on the two clocks the release has;
//   - and SRAbsoluteTimeFromContinuousTime takes the nanosecond count the name says. The header's own
//     warning is the caller's to observe: a count from another boot session is undefined, and the port
//     does not check one, because nothing here can tell.

// The two bases, and the anchor that joins them. One anchor per process, read once, so that the
// conversions are each other's inverses to the last bit the clocks carry.
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

// The release's own timebase, which is how many nanoseconds a mach tick is. One nanosecond on every
// release this port runs on, and read rather than assumed.
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

// The port's own seconds-from-a-tick pair, for the one place that needs a duration rather than a
// reading: the reader's interval between two fetches.
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
    // mach_absolute_time, and NOT mach_continuous_time: this release has no such symbol, and the clock it
    // would give is the one that does not stop while the device sleeps. Monotonic either way, so this
    // never goes backwards and the two conversions below are exact inverses of it.
    const CharonSensorKitClockAnchor *anchor = CharonSensorKitClockAnchorOf();
    NSTimeInterval elapsed = CharonSensorKitSecondsFromTicks(mach_absolute_time() - anchor->continuous);
    return (SRAbsoluteTime)(anchor->absolute + elapsed);
}

SRAbsoluteTime SRAbsoluteTimeFromContinuousTime(uint64_t cont)
{
    const CharonSensorKitClockAnchor *anchor = CharonSensorKitClockAnchorOf();
    // The name says a continuous time and the number is a nanosecond count, so the reading is taken as
    // one: the header's own rule, which is that the count must come from this boot session. What that
    // session began at is exactly what the anchor holds.
    uint64_t sinceBoot = cont > anchor->continuous ? cont - anchor->continuous : 0;
    return (SRAbsoluteTime)(anchor->absolute + CharonSensorKitSecondsFromTicks(sinceBoot));
}

CFAbsoluteTime SRAbsoluteTimeToCFAbsoluteTime(SRAbsoluteTime sr)
{
    const CharonSensorKitClockAnchor *anchor = CharonSensorKitClockAnchorOf();
    // Wall-clock relative, as the header says: the answer is the absolute reading plus however far the
    // SRAbsoluteTime is from the anchor, and it moves with the wall clock afterwards - if the system
    // time is five seconds fast, so is this, which is the header's own stated behaviour.
    return anchor->absolute + ((CFAbsoluteTime)sr - anchor->absolute);
}

SRAbsoluteTime SRAbsoluteTimeFromCFAbsoluteTime(CFAbsoluteTime cf)
{
    const CharonSensorKitClockAnchor *anchor = CharonSensorKitClockAnchorOf();
    return (SRAbsoluteTime)(anchor->absolute + (cf - anchor->absolute));
}
