#define CMTIMEBASE_USE_SOURCE_TERMINOLOGY 1
#include <CoreMedia/CoreMedia.h>

extern OSStatus revenant_CMTimebaseCreateWithMasterClock(CFAllocatorRef allocator, CMClockRef masterClock, CMTimebaseRef *timebaseOut) __asm("_CMTimebaseCreateWithMasterClock");
extern CMClockRef revenant_CMTimebaseCopyMasterClock(CMTimebaseRef timebase) __asm("_CMTimebaseCopyMasterClock");

__attribute__((visibility("default"))) OSStatus CMTimebaseCreateWithSourceClock(CFAllocatorRef allocator, CMClockRef sourceClock, CMTimebaseRef *timebaseOut)
{
    return revenant_CMTimebaseCreateWithMasterClock(allocator, sourceClock, timebaseOut);
}

__attribute__((visibility("default"))) CMClockOrTimebaseRef CMTimebaseCopySource(CMTimebaseRef timebase)
{
    return (CMClockOrTimebaseRef)revenant_CMTimebaseCopyMasterClock(timebase);
}
