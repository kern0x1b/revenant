#define CMTIMEBASE_USE_SOURCE_TERMINOLOGY 1
#include <CoreMedia/CoreMedia.h>
#include <pthread.h>

#define REVENANT_COREMEDIA_EXPORT __attribute__((visibility("default")))

extern OSStatus revenant_CMTimebaseCreateWithMasterClock(CFAllocatorRef allocator, CMClockRef masterClock, CMTimebaseRef *timebaseOut) __asm("_CMTimebaseCreateWithMasterClock");

static pthread_mutex_t sourcesLock = PTHREAD_MUTEX_INITIALIZER;
static CFMutableDictionaryRef sources = NULL;

static void CollectUnowned(const void *timebase, const void *source, void *context)
{
    if (CFGetRetainCount(timebase) == 1) {
        CFArrayAppendValue((CFMutableArrayRef)context, timebase);
    }
}

static void ForgetUnowned(void)
{
    CFMutableArrayRef unowned = CFArrayCreateMutable(kCFAllocatorDefault, 0, NULL);
    CFDictionaryApplyFunction(sources, CollectUnowned, unowned);
    for (CFIndex index = 0; index < CFArrayGetCount(unowned); index++) {
        CFDictionaryRemoveValue(sources, CFArrayGetValueAtIndex(unowned, index));
    }
    CFRelease(unowned);
}

REVENANT_COREMEDIA_EXPORT OSStatus CMTimebaseCreateWithSourceClock(CFAllocatorRef allocator, CMClockRef sourceClock, CMTimebaseRef *timebaseOut)
{
    OSStatus status = revenant_CMTimebaseCreateWithMasterClock(allocator, sourceClock, timebaseOut);
    if (status != noErr || !timebaseOut || !*timebaseOut || !sourceClock) {
        return status;
    }
    pthread_mutex_lock(&sourcesLock);
    if (!sources) {
        sources = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    }
    ForgetUnowned();
    CFDictionarySetValue(sources, *timebaseOut, sourceClock);
    pthread_mutex_unlock(&sourcesLock);
    return status;
}

REVENANT_COREMEDIA_EXPORT CMClockOrTimebaseRef CMTimebaseCopySource(CMTimebaseRef timebase)
{
    CMClockOrTimebaseRef source = NULL;
    pthread_mutex_lock(&sourcesLock);
    const void *recorded = (sources && timebase) ? CFDictionaryGetValue(sources, timebase) : NULL;
    if (recorded) {
        source = (CMClockOrTimebaseRef)CFRetain(recorded);
    }
    pthread_mutex_unlock(&sourcesLock);
    return source;
}
