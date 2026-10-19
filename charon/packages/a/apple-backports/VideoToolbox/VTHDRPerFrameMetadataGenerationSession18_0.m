#import "CharonVideoToolbox.h"
#include <CoreFoundation/CoreFoundation.h>
#include <CoreMedia/CoreMedia.h>
#include <CoreVideo/CoreVideo.h>
#include <VideoToolbox/VTErrors.h>

// The HDR per-frame metadata generation session: one string constant, one CFTypeID, and the two
// functions that create a session and attach metadata to a pixel buffer.
//
// WHAT IT ANSWERS ON THIS RELEASE, measured rather than assumed:
//
//   - the release's armv7 6.1.3 cache carries none of it. dump-cache.lua over
//     $HOME/.charon/dyld/6.1.3/dyld_shared_cache_armv7 finds no
//     VTHDRPerFrameMetadataGenerationSession symbol, and VideoToolbox's own header on the armv7 ladder
//     declares none of these four names. The family arrived with iOS 18.0.
//   - what the session does is generate Dolby Vision per-frame metadata, measure the frame, and write
//     it into the pixel buffer's attachments and into the IOSurface behind it. There is no Dolby Vision
//     on any armv7 release and no HDR metadata attachment there, so there is nothing to generate and
//     nowhere to put the result.
//
// So the two functions answer what the release's own error codes document for a capability that is not
// there, and the argument checks that do not depend on hardware are made FIRST, because a caller that
// passes a zero frame rate gets the same answer on a device that has the hardware. Every code below was
// read out of VTErrors.h and, where the host could be asked, measured against the host:
//
//   VTHDRPerFrameMetadataGenerationSessionCreate(kCFAllocatorDefault, 0.0f, NULL, &out)
//       host: status -12902 (kVTParameterErr), out left NULL
//   VTHDRPerFrameMetadataGenerationSessionCreate(kCFAllocatorDefault, 24.0f, NULL, &out)
//       host: status 0, out set
//   VTHDRPerFrameMetadataGenerationSessionAttachMetadata(session, NULL, false)
//       host: status -12902 (kVTParameterErr)
//
// and the string constant is Apple's own, read by dlsym on the host's VideoToolbox:
//
//   kVTHDRPerFrameMetadataGenerationHDRFormatType_DolbyVision = "DolbyVision"

const VTHDRPerFrameMetadataGenerationHDRFormatType
    kVTHDRPerFrameMetadataGenerationHDRFormatType_DolbyVision = CFSTR("DolbyVision");

// The type ID. Apple's is 75 on this host, and that number is NOT copied: a CFTypeID is a slot in a
// process-wide table, and writing a literal would be claiming slot 75 in every process that loads this
// library, which is another type's slot in any process that already has one. A UUID-backed type ID from
// the process's own UUID space is the mechanism CF itself uses for a type it registers at run time, and
// it cannot collide. It is computed once and cached, so two calls answer the same value - which is the
// property a caller compares it for.
CFTypeID VTHDRPerFrameMetadataGenerationSessionGetTypeID(void)
{
    static CFTypeID type;
    if (!type)
        type = CFUUIDGetTypeID();
    return type;
}

OSStatus VTHDRPerFrameMetadataGenerationSessionCreate(
    CFAllocatorRef CM_NULLABLE allocator,
    float framesPerSecond,
    CFDictionaryRef CM_NULLABLE options,
    VTHDRPerFrameMetadataGenerationSessionRef CM_NULLABLE * CM_NONNULL
        hdrPerFrameMetadataGenerationSessionOut)
{
    // The header says "Value must be greater than 0.0", and the host answers kVTParameterErr for a zero
    // and sets nothing - so the port does that first and before anything about the hardware.
    if (framesPerSecond <= 0.0f)
        return kVTParameterErr;
    if (!hdrPerFrameMetadataGenerationSessionOut)
        return kVTParameterErr;
    // Nothing is written to the caller's slot before the capability is known to be there, so a caller
    // that ignores the status cannot mistake a stale pointer for a session. That is what the host does
    // too: with framesPerSecond 0 it leaves the slot NULL.
    *hdrPerFrameMetadataGenerationSessionOut = NULL;
    // `allocator` and `options` are read by no line here, and that is deliberate rather than an
    // oversight: the session cannot be created whatever they say, so validating them would be inventing
    // a rejection Apple's own implementation does not make for a valid allocator and a valid options
    // dictionary. kVTVideoEncoderNotAvailableNowErr is the code VTErrors.h gives for the encoder that
    // would consume this metadata not being available now.
    return kVTVideoEncoderNotAvailableNowErr;
}

OSStatus VTHDRPerFrameMetadataGenerationSessionAttachMetadata(
    VTHDRPerFrameMetadataGenerationSessionRef hdrPerFrameMetadataGenerationSession,
    CVPixelBufferRef pixelBuffer,
    Boolean sceneChange)
{
    // Both argument checks come before the capability, and both are the host's own answers: no session
    // is NULL, and a NULL pixel buffer is a parameter error whatever the hardware is. A NON-NULL session
    // is not second-guessed: this port hands out none, so there is no way to tell a caller-owned pointer
    // from a real one, and inventing a test for it would reject a session Apple would have accepted.
    if (!hdrPerFrameMetadataGenerationSession)
        return kVTInvalidSessionErr;
    if (!pixelBuffer)
        return kVTParameterErr;
    // `sceneChange` is the one argument that changes what would be measured - it tells the session that
    // this frame differs enough from the last to restart the analysis - and there is no analysis to
    // restart. The same code Create answers, because the same capability is missing.
    return kVTVideoEncoderNotAvailableNowErr;
}