#if defined(REVENANT_HOST_BUILD)
#define VTIsHardwareDecodeSupported RevenantVTIsHardwareDecodeSupported
#endif

#import <CoreMedia/CoreMedia.h>
#import <VideoToolbox/VideoToolbox.h>

static const uint8_t RevenantVTH264AVCC[] = {
    0x01, 0x64, 0x00, 0x0d, 0xff, 0xe1, 0x00, 0x0a, 0x27, 0x64, 0x00, 0x0d, 0xac, 0x56, 0x50, 0x50, 0x7e, 0x40,
    0x01, 0x00, 0x04, 0x28, 0xee, 0x3c, 0xb0, 0xfd, 0xf8, 0xf8, 0x00,
};

static void RevenantVTIgnoreFrame(void *refcon, void *frameRefcon, OSStatus status, VTDecodeInfoFlags flags, CVImageBufferRef image, CMTime presentationTime, CMTime duration)
{
}

Boolean VTIsHardwareDecodeSupported(CMVideoCodecType codecType)
{
    if (codecType != kCMVideoCodecType_H264)
        return false;

    NSData *avcC = [NSData dataWithBytes:RevenantVTH264AVCC length:sizeof(RevenantVTH264AVCC)];
    NSDictionary *extensions = @{@"SampleDescriptionExtensionAtoms": @{@"avcC": avcC}};
    CMVideoFormatDescriptionRef description = NULL;
    if (CMVideoFormatDescriptionCreate(kCFAllocatorDefault, kCMVideoCodecType_H264, 320, 240, (__bridge CFDictionaryRef)extensions, &description) != noErr)
        return false;

    NSDictionary *specification = @{(__bridge NSString *)kVTVideoDecoderSpecification_RequireHardwareAcceleratedVideoDecoder: @YES};
    VTDecompressionOutputCallbackRecord record = {RevenantVTIgnoreFrame, NULL};
    VTDecompressionSessionRef session = NULL;
    const OSStatus status = VTDecompressionSessionCreate(kCFAllocatorDefault, description, (__bridge CFDictionaryRef)specification, NULL, &record, &session);
    if (session) {
        VTDecompressionSessionInvalidate(session);
        CFRelease(session);
    }
    CFRelease(description);
    return status == noErr;
}
