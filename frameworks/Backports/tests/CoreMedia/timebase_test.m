#define CMTIMEBASE_USE_SOURCE_TERMINOLOGY 1
#import "../Foundation/check.h"
#import <CoreMedia/CoreMedia.h>

extern OSStatus revenant_host_create_master(CFAllocatorRef allocator, CMClockRef masterClock, CMTimebaseRef *timebaseOut) __asm("_CMTimebaseCreateWithMasterClock");
extern CMClockRef revenant_host_copy_master(CMTimebaseRef timebase) __asm("_CMTimebaseCopyMasterClock");

int main(int argc, char **argv)
{
    revenant_read_arguments(argc, argv);
    CMClockRef clock = CMClockGetHostTimeClock();
    CMTimebaseRef timebase = NULL;
    OSStatus status = CMTimebaseCreateWithSourceClock(kCFAllocatorDefault, clock, &timebase);
    revenant_check(status == noErr && timebase != NULL, "CMTimebaseCreateWithSourceClock returns a timebase", @"no timebase");
    CMTimebaseRef oracle = NULL;
    OSStatus oracleStatus = revenant_host_create_master(kCFAllocatorDefault, clock, &oracle);
    revenant_check(oracleStatus == noErr && oracle != NULL, "the host creates the master-clock timebase", @"no oracle");
    Float64 rate = CMTimebaseGetRate(timebase);
    revenant_check(revenant_negative ? rate == 1.0 : rate == CMTimebaseGetRate(oracle), "a new timebase has the host's rate", @"rate differs");
    CMTime time = CMTimebaseGetTime(timebase);
    revenant_check(CMTimeCompare(time, CMTimebaseGetTime(oracle)) == 0, "a new timebase has the host's time", @"time differs");
    CMClockOrTimebaseRef source = CMTimebaseCopySource(timebase);
    revenant_check(source != NULL && CFEqual(source, clock), "CMTimebaseCopySource returns the clock the timebase was created with", @"other source");
    CMClockRef hostSource = revenant_host_copy_master(oracle);
    revenant_check(source != NULL && hostSource != NULL && CFEqual(source, hostSource), "the host returns the same clock as its source", @"host source differs");
    if (source) {
        CFRelease(source);
    }
    if (hostSource) {
        CFRelease(hostSource);
    }
    CMTimebaseRef released = NULL;
    OSStatus releasedStatus = CMTimebaseCreateWithSourceClock(kCFAllocatorDefault, clock, &released);
    revenant_check(releasedStatus == noErr && released != NULL, "a second timebase is created from the same clock", @"no second timebase");
    CFRelease(released);
    CMTimebaseRef later = NULL;
    OSStatus laterStatus = CMTimebaseCreateWithSourceClock(kCFAllocatorDefault, clock, &later);
    revenant_check(laterStatus == noErr && later != NULL, "a timebase is created after another was released", @"no later timebase");
    CMClockOrTimebaseRef laterSource = CMTimebaseCopySource(later);
    revenant_check(laterSource != NULL && CFEqual(laterSource, clock), "the timebase created after a release answers its clock", @"later source differs");
    CMClockOrTimebaseRef survivor = CMTimebaseCopySource(timebase);
    revenant_check(survivor != NULL && CFEqual(survivor, clock), "a live timebase keeps its source after another timebase is released", @"live source lost");
    if (laterSource) {
        CFRelease(laterSource);
    }
    if (survivor) {
        CFRelease(survivor);
    }
    CFRelease(later);
    CFRelease(oracle);
    CFRelease(timebase);
    return revenant_finish();
}
