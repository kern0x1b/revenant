#import "RevenantVideoToolbox.h"
#include <CoreFoundation/CoreFoundation.h>
#include <CoreMedia/CoreMedia.h>
#include <VideoToolbox/VTDecompressionSession.h>
#include <VideoToolbox/VTErrors.h>

#import "VTDecompressionSessionHEVC.h"
#import "VTSystem.h"

typedef OSStatus (*RevenantVTDecodeWithOptionsFunction)(VTDecompressionSessionRef, CMSampleBufferRef, VTDecodeFrameFlags, CFDictionaryRef, void *, VTDecodeInfoFlags *);
typedef OSStatus (*RevenantVTDecodeWithOptionsHandlerFunction)(VTDecompressionSessionRef, CMSampleBufferRef, VTDecodeFrameFlags, CFDictionaryRef, VTDecodeInfoFlags *, VTDecompressionOutputHandler);

static BOOL RevenantVTHasFrameOptions(CFDictionaryRef frameOptions)
{
    return frameOptions && CFDictionaryGetCount(frameOptions) > 0;
}

OSStatus VTDecompressionSessionDecodeFrameWithOptions(
    VTDecompressionSessionRef CM_NONNULL session,
    CMSampleBufferRef CM_NONNULL sampleBuffer,
    VTDecodeFrameFlags decodeFlags,
    CFDictionaryRef CM_NULLABLE frameOptions,
    void * CM_NULLABLE sourceFrameRefCon,
    VTDecodeInfoFlags * CM_NULLABLE infoFlagsOut)
{
    if (RevenantVTSoftwareSessionOwns(session)) {
        if (RevenantVTHasFrameOptions(frameOptions))
            return kVTPropertyNotSupportedErr;
        return RevenantVTSoftwareSessionDecode(session, sampleBuffer, decodeFlags, sourceFrameRefCon, infoFlagsOut, nil);
    }
    RevenantVTDecodeWithOptionsFunction decode = (RevenantVTDecodeWithOptionsFunction)RevenantVTSystemSymbol("VTDecompressionSessionDecodeFrameWithOptions");
    if (decode)
        return decode(session, sampleBuffer, decodeFlags, frameOptions, sourceFrameRefCon, infoFlagsOut);
    if (RevenantVTHasFrameOptions(frameOptions))
        return kVTPropertyNotSupportedErr;
    return VTDecompressionSessionDecodeFrame(session, sampleBuffer, decodeFlags, sourceFrameRefCon, infoFlagsOut);
}

OSStatus VTDecompressionSessionDecodeFrameWithOptionsAndOutputHandler(
    VTDecompressionSessionRef CM_NONNULL session,
    CMSampleBufferRef CM_NONNULL sampleBuffer,
    VTDecodeFrameFlags decodeFlags,
    CFDictionaryRef CM_NULLABLE frameOptions,
    VTDecodeInfoFlags * CM_NULLABLE infoFlagsOut,
    VTDecompressionOutputHandler CM_NONNULL outputHandler)
{
    if (RevenantVTSoftwareSessionOwns(session)) {
        if (RevenantVTHasFrameOptions(frameOptions))
            return kVTPropertyNotSupportedErr;
        return RevenantVTSoftwareSessionDecode(session, sampleBuffer, decodeFlags, NULL, infoFlagsOut, ^(void *sourceFrameRefCon, OSStatus status, VTDecodeInfoFlags infoFlags, CVImageBufferRef imageBuffer, CMTime presentationTimeStamp, CMTime presentationDuration) {
            (void)sourceFrameRefCon;
            outputHandler(status, infoFlags, imageBuffer, presentationTimeStamp, presentationDuration);
        });
    }
    RevenantVTDecodeWithOptionsHandlerFunction decode = (RevenantVTDecodeWithOptionsHandlerFunction)RevenantVTSystemSymbol("VTDecompressionSessionDecodeFrameWithOptionsAndOutputHandler");
    return decode ? decode(session, sampleBuffer, decodeFlags, frameOptions, infoFlagsOut, outputHandler) : kVTVideoDecoderNotAvailableNowErr;
}
