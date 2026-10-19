#import <CoreMedia/CoreMedia.h>
#include <CoreVideo/CoreVideo.h>
#include <AudioToolbox/AudioToolbox.h>

static OSStatus charon_ready(CMSampleBufferMakeDataReadyHandler handler, CMSampleBufferRef buffer, Boolean dataReady)
{
    if (dataReady)
        return 0;
    if (!handler)
        return kCMSampleBufferError_BufferNotReady;
    return handler(buffer);
}

OSStatus CMSampleBufferCreateWithMakeDataReadyHandler(CFAllocatorRef allocator, CMBlockBufferRef dataBuffer, Boolean dataReady,
                                                      CMFormatDescriptionRef formatDescription, CMItemCount numSamples,
                                                      CMItemCount numSampleTimingEntries, const CMSampleTimingInfo *sampleTimingArray,
                                                      CMItemCount numSampleSizeEntries, const size_t *sampleSizeArray,
                                                      CMSampleBufferRef *sampleBufferOut, CMSampleBufferMakeDataReadyHandler makeDataReadyHandler)
{
    if (!sampleBufferOut)
        return kCMSampleBufferError_RequiredParameterMissing;
    *sampleBufferOut = NULL;
    OSStatus status = CMSampleBufferCreate(allocator, dataBuffer, dataReady, NULL, NULL, formatDescription, numSamples, numSampleTimingEntries,
                                           sampleTimingArray, numSampleSizeEntries, sampleSizeArray, sampleBufferOut);
    if (status == 0 && !dataReady) {
        status = charon_ready(makeDataReadyHandler, *sampleBufferOut, NO);
        if (status) {
            CFRelease(*sampleBufferOut);
            *sampleBufferOut = NULL;
        }
    }
    return status;
}

OSStatus CMSampleBufferCreateForImageBufferWithMakeDataReadyHandler(CFAllocatorRef allocator, CVImageBufferRef imageBuffer, Boolean dataReady,
                                                                    CMVideoFormatDescriptionRef formatDescription, const CMSampleTimingInfo *sampleTiming,
                                                                    CMSampleBufferRef *sampleBufferOut, CMSampleBufferMakeDataReadyHandler makeDataReadyHandler)
{
    if (!sampleBufferOut)
        return kCMSampleBufferError_RequiredParameterMissing;
    *sampleBufferOut = NULL;
    OSStatus status = CMSampleBufferCreateForImageBuffer(allocator, imageBuffer, dataReady, NULL, NULL, formatDescription, sampleTiming, sampleBufferOut);
    if (status == 0 && !dataReady) {
        status = charon_ready(makeDataReadyHandler, *sampleBufferOut, NO);
        if (status) {
            CFRelease(*sampleBufferOut);
            *sampleBufferOut = NULL;
        }
    }
    return status;
}
