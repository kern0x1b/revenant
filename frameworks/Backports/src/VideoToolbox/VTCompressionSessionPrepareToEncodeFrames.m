#include "../revenant_impl.h"
#import <VideoToolbox/VideoToolbox.h>

OSStatus BACKPORT_IMPL(VTCompressionSessionPrepareToEncodeFrames)(VTCompressionSessionRef session)
{
    return session ? noErr : kVTParameterErr;
}
