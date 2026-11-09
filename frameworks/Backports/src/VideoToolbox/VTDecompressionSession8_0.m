#include "../revenant_impl.h"
#if defined(REVENANT_HOST_BUILD)
#define VTDecompressionSessionCreate __revenant_fb_VTDecompressionSessionCreate
#define VTDecompressionSessionDecodeFrame __revenant_fb_VTDecompressionSessionDecodeFrame
#define VTDecompressionSessionInvalidate __revenant_fb_VTDecompressionSessionInvalidate
#define VTDecompressionSessionCanAcceptFormatDescription __revenant_fb_VTDecompressionSessionCanAcceptFormatDescription
#define VTDecompressionSessionFinishDelayedFrames __revenant_fb_VTDecompressionSessionFinishDelayedFrames
#define VTDecompressionSessionWaitForAsynchronousFrames __revenant_fb_VTDecompressionSessionWaitForAsynchronousFrames
#define VTDecompressionSessionCopySupportedPropertyDictionary __revenant_fb_VTDecompressionSessionCopySupportedPropertyDictionary
#endif

#import <CoreFoundation/CoreFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <VideoToolbox/VideoToolbox.h>

#import "VTDecompressionSessionHEVC.h"
#import "VTSystem.h"

typedef OSStatus (*RevenantVTCreateFunction)(CFAllocatorRef, CMVideoFormatDescriptionRef, CFDictionaryRef, CFDictionaryRef, const VTDecompressionOutputCallbackRecord *, VTDecompressionSessionRef *);
typedef OSStatus (*RevenantVTDecodeFunction)(VTDecompressionSessionRef, CMSampleBufferRef, VTDecodeFrameFlags, void *, VTDecodeInfoFlags *);
typedef void (*RevenantVTInvalidateFunction)(VTDecompressionSessionRef);
typedef OSStatus (*RevenantVTStatusFunction)(VTDecompressionSessionRef);
typedef Boolean (*RevenantVTCanAcceptFunction)(VTDecompressionSessionRef, CMFormatDescriptionRef);
typedef OSStatus (*RevenantVTCopySupportedFunction)(VTDecompressionSessionRef, CFDictionaryRef *);

OSStatus BACKPORT_IMPL(VTDecompressionSessionCreate)(CFAllocatorRef allocator, CMVideoFormatDescriptionRef videoFormatDescription, CFDictionaryRef videoDecoderSpecification, CFDictionaryRef destinationImageBufferAttributes, const VTDecompressionOutputCallbackRecord *outputCallback, VTDecompressionSessionRef *decompressionSessionOut)
{
    RevenantVTCreateFunction create = (RevenantVTCreateFunction)RevenantVTSystemSymbol("VTDecompressionSessionCreate");
    OSStatus status = create ? create(allocator, videoFormatDescription, videoDecoderSpecification, destinationImageBufferAttributes, outputCallback, decompressionSessionOut) : kVTVideoDecoderNotAvailableNowErr;
    if (status == noErr || !RevenantVTSoftwareDecodes(videoFormatDescription, videoDecoderSpecification))
        return status;
    RevenantVTDecodeOutput output = nil;
    if (outputCallback && outputCallback->decompressionOutputCallback) {
        const VTDecompressionOutputCallbackRecord record = *outputCallback;
        output = ^(void *sourceFrameRefCon, OSStatus outputStatus, VTDecodeInfoFlags infoFlags, CVImageBufferRef imageBuffer, CMTime presentationTimeStamp, CMTime presentationDuration) {
            record.decompressionOutputCallback(record.decompressionOutputRefCon, sourceFrameRefCon, outputStatus, infoFlags, imageBuffer, presentationTimeStamp, presentationDuration);
        };
    }
    VTDecompressionSessionRef session = NULL;
    if (RevenantVTSoftwareSessionCreate(videoFormatDescription, destinationImageBufferAttributes, output, &session) != noErr)
        return status;
    *decompressionSessionOut = session;
    return noErr;
}

OSStatus BACKPORT_IMPL(VTDecompressionSessionDecodeFrame)(VTDecompressionSessionRef session, CMSampleBufferRef sampleBuffer, VTDecodeFrameFlags decodeFlags, void *sourceFrameRefCon, VTDecodeInfoFlags *infoFlagsOut)
{
    if (RevenantVTSoftwareSessionOwns(session))
        return RevenantVTSoftwareSessionDecode(session, sampleBuffer, decodeFlags, sourceFrameRefCon, infoFlagsOut, nil);
    RevenantVTDecodeFunction decode = (RevenantVTDecodeFunction)RevenantVTSystemSymbol("VTDecompressionSessionDecodeFrame");
    return decode ? decode(session, sampleBuffer, decodeFlags, sourceFrameRefCon, infoFlagsOut) : kVTVideoDecoderNotAvailableNowErr;
}

void BACKPORT_IMPL(VTDecompressionSessionInvalidate)(VTDecompressionSessionRef session)
{
    if (RevenantVTSoftwareSessionOwns(session)) {
        RevenantVTSoftwareSessionInvalidate(session);
        return;
    }
    RevenantVTInvalidateFunction invalidate = (RevenantVTInvalidateFunction)RevenantVTSystemSymbol("VTDecompressionSessionInvalidate");
    if (invalidate)
        invalidate(session);
}

OSStatus BACKPORT_IMPL(VTDecompressionSessionFinishDelayedFrames)(VTDecompressionSessionRef session)
{
    if (RevenantVTSoftwareSessionOwns(session))
        return RevenantVTSoftwareSessionFinish(session);
    RevenantVTStatusFunction finish = (RevenantVTStatusFunction)RevenantVTSystemSymbol("VTDecompressionSessionFinishDelayedFrames");
    return finish ? finish(session) : kVTVideoDecoderNotAvailableNowErr;
}

OSStatus BACKPORT_IMPL(VTDecompressionSessionWaitForAsynchronousFrames)(VTDecompressionSessionRef session)
{
    if (RevenantVTSoftwareSessionOwns(session))
        return RevenantVTSoftwareSessionWait(session);
    RevenantVTStatusFunction wait = (RevenantVTStatusFunction)RevenantVTSystemSymbol("VTDecompressionSessionWaitForAsynchronousFrames");
    return wait ? wait(session) : kVTVideoDecoderNotAvailableNowErr;
}

Boolean BACKPORT_IMPL(VTDecompressionSessionCanAcceptFormatDescription)(VTDecompressionSessionRef session, CMFormatDescriptionRef newFormatDesc)
{
    if (RevenantVTSoftwareSessionOwns(session))
        return RevenantVTSoftwareSessionCanAccept(session, newFormatDesc);
    RevenantVTCanAcceptFunction canAccept = (RevenantVTCanAcceptFunction)RevenantVTSystemSymbol("VTDecompressionSessionCanAcceptFormatDescription");
    return canAccept ? canAccept(session, newFormatDesc) : false;
}

OSStatus BACKPORT_IMPL(VTDecompressionSessionCopySupportedPropertyDictionary)(VTDecompressionSessionRef session, CFDictionaryRef *supportedPropertiesOut)
{
    if (!supportedPropertiesOut)
        return kVTParameterErr;
    if (RevenantVTSoftwareSessionOwns(session)) {
        *supportedPropertiesOut = RevenantVTSoftwareSessionCopySupportedProperties(session);
        return noErr;
    }
    RevenantVTCopySupportedFunction copy = (RevenantVTCopySupportedFunction)RevenantVTSystemSymbol("VTDecompressionSessionCopySupportedPropertyDictionary");
    return copy ? copy(session, supportedPropertiesOut) : kVTPropertyNotSupportedErr;
}
