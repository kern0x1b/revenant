#include "../revenant_impl.h"
#import "RevenantVideoToolbox.h"
#include <CoreFoundation/CoreFoundation.h>
#include <CoreMedia/CoreMedia.h>
#include <CoreVideo/CoreVideo.h>
#include <VideoToolbox/VTCompressionSession.h>
#include <VideoToolbox/VTDecompressionSession.h>
#include <VideoToolbox/VTErrors.h>
#include <VideoToolbox/VTSession.h>

static Boolean session_has_multi_pass_storage(VTCompressionSessionRef session)
{
    CFTypeRef storage = NULL;
    if (VTSessionCopyProperty(session, kVTCompressionPropertyKey_MultiPassStorage, NULL, &storage) != noErr)
        return false;
    Boolean enabled = storage != NULL;
    if (storage)
        CFRelease(storage);
    return enabled;
}

OSStatus BACKPORT_IMPL(VTCompressionSessionBeginPass)(VTCompressionSessionRef session,
                                       VTCompressionSessionOptionFlags beginPassFlags,
                                       uint32_t * CM_NULLABLE reserved)
{
    if (!session_has_multi_pass_storage(session))
        return kVTParameterErr;
    return kVTVideoEncoderNotAvailableNowErr;
}

OSStatus BACKPORT_IMPL(VTCompressionSessionEndPass)(VTCompressionSessionRef session,
                                     Boolean * CM_NULLABLE furtherPassesRequestedOut,
                                     uint32_t * CM_NULLABLE reserved)
{
    if (!session_has_multi_pass_storage(session))
        return kVTParameterErr;
    return kVTVideoEncoderNotAvailableNowErr;
}

OSStatus BACKPORT_IMPL(VTCompressionSessionGetTimeRangesForNextPass)(VTCompressionSessionRef session,
                                                     CMItemCount * CM_NONNULL timeRangeCountOut,
                                                     const CMTimeRange * CM_NULLABLE * CM_NONNULL timeRangeArrayOut)
{
    if (!session_has_multi_pass_storage(session))
        return kVTParameterErr;
    return kVTParameterErr;
}
