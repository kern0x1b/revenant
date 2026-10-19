#import <CoreMedia/CoreMedia.h>
#import <VideoToolbox/VideoToolbox.h>
#import "check.h"

// CMVideoFormatDescriptionCreateFromH264ParameterSets of iOS 7 feeding the release's own VTDecompressionSession, and
// VTCompressionSessionPrepareToEncodeFrames and the profile levels against the release's encoder
// (facts/VideoToolbox/H264Encoding.md). A process linked against the package built with avfoundation = true.
#import "h264decode-frames.h"

static int decoded;
static OSStatus decodedStatus;
static size_t decodedWidth, decodedHeight;
static uint8_t decodedLuma[2];

static void output(void *session, void *frame, OSStatus status, VTDecodeInfoFlags flags, CVImageBufferRef image, CMTime time, CMTime duration)
{
    decoded++;
    decodedStatus = status;
    if (image) {
        decodedWidth = CVPixelBufferGetWidth(image);
        decodedHeight = CVPixelBufferGetHeight(image);
        CVPixelBufferLockBaseAddress(image, kCVPixelBufferLock_ReadOnly);
        const uint8_t *luma = CVPixelBufferGetBaseAddressOfPlane(image, 0);
        size_t stride = CVPixelBufferGetBytesPerRowOfPlane(image, 0);
        decodedLuma[0] = luma[8 * stride + 8];
        decodedLuma[1] = luma[8 * stride + 24];
        CVPixelBufferUnlockBaseAddress(image, kCVPixelBufferLock_ReadOnly);
    }
}

static void decode(const char *name, const uint8_t *sps, size_t spsSize, const uint8_t *pps, size_t ppsSize, const uint8_t *frame, size_t frameSize, int width, int height)
{
    char label[128];
    const uint8_t *sets[2] = {sps, pps};
    size_t sizes[2] = {spsSize, ppsSize};
    CMFormatDescriptionRef description = NULL;
    OSStatus status = CMVideoFormatDescriptionCreateFromH264ParameterSets(NULL, 2, sets, sizes, 4, &description);
    snprintf(label, sizeof label, "%s: a description from the encoder's SPS and PPS", name);
    charon_check(status == noErr && description, label, [NSString stringWithFormat:@"status %d", (int)status]);
    if (!description)
        return;
    CMVideoDimensions dimensions = CMVideoFormatDescriptionGetDimensions(description);
    snprintf(label, sizeof label, "%s: its dimensions", name);
    charon_check(dimensions.width == width && dimensions.height == height, label, [NSString stringWithFormat:@"%dx%d", dimensions.width, dimensions.height]);
    const uint8_t *back = NULL;
    size_t backSize = 0, count = 0;
    status = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(description, 1, &back, &backSize, &count, NULL);
    snprintf(label, sizeof label, "%s: the PPS reads back out of it", name);
    charon_check(status == noErr && count == 2 && backSize == ppsSize && !memcmp(back, pps, ppsSize), label, [NSString stringWithFormat:@"status %d count %zu", (int)status, count]);

    VTDecompressionOutputCallbackRecord callback = {output, NULL};
    NSDictionary *attributes = @{(__bridge NSString *)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)};
    VTDecompressionSessionRef session = NULL;
    status = VTDecompressionSessionCreate(NULL, description, NULL, (__bridge CFDictionaryRef)attributes, &callback, &session);
    snprintf(label, sizeof label, "%s: the release's decoder takes the description", name);
    charon_check(status == noErr && session, label, [NSString stringWithFormat:@"status %d", (int)status]);
    if (!session) {
        CFRelease(description);
        return;
    }
    status = VTSessionSetProperty(session, kVTDecompressionPropertyKey_RealTime, kCFBooleanTrue);
    printf("measure %s: VTSessionSetProperty(kVTDecompressionPropertyKey_RealTime) = %d\n", name, (int)status);

    CMBlockBufferRef block = NULL;
    CMBlockBufferCreateWithMemoryBlock(NULL, (void *)frame, frameSize, kCFAllocatorNull, NULL, 0, frameSize, 0, &block);
    CMSampleBufferRef sample = NULL;
    CMSampleBufferCreate(NULL, block, true, NULL, NULL, description, 1, 0, NULL, 1, &frameSize, &sample);
    decoded = 0;
    decodedStatus = -1;
    decodedWidth = decodedHeight = 0;
    status = VTDecompressionSessionDecodeFrame(session, sample, 0, NULL, NULL);
    VTDecompressionSessionWaitForAsynchronousFrames(session);
    snprintf(label, sizeof label, "%s: the IDR frame decodes", name);
    charon_check(status == noErr && decoded == 1 && decodedStatus == noErr, label, [NSString stringWithFormat:@"decode %d, %d frames, frame status %d", (int)status, decoded, (int)decodedStatus]);
    snprintf(label, sizeof label, "%s: the decoded picture has the description's size", name);
    charon_check(decodedWidth == (size_t)width && decodedHeight == (size_t)height, label, [NSString stringWithFormat:@"%zux%zu", decodedWidth, decodedHeight]);
    snprintf(label, sizeof label, "%s: the checkerboard the host encoded comes back dark then light", name);
    charon_check(decodedLuma[0] < 90 && decodedLuma[1] > 150, label, [NSString stringWithFormat:@"%u %u", decodedLuma[0], decodedLuma[1]]);

    VTDecompressionSessionInvalidate(session);
    CFRelease(session);
    CFRelease(sample);
    CFRelease(block);
    CFRelease(description);
}

static void encoded(void *context, void *frame, OSStatus status, VTEncodeInfoFlags flags, CMSampleBufferRef sample)
{
    *(OSStatus *)context = sample ? status : (status ? status : -1);
}

static void encode(void)
{
    CHECK(VTCompressionSessionPrepareToEncodeFrames(NULL) == kVTParameterErr, "PrepareToEncodeFrames(NULL) answers kVTParameterErr");
    CFStringRef levels[] = {kVTProfileLevel_H264_Baseline_4_0, kVTProfileLevel_H264_Baseline_4_2, kVTProfileLevel_H264_Baseline_5_0, kVTProfileLevel_H264_Baseline_5_1,
                            kVTProfileLevel_H264_Baseline_5_2, kVTProfileLevel_H264_High_3_2, kVTProfileLevel_H264_High_4_2, kVTProfileLevel_H264_High_5_1,
                            kVTProfileLevel_H264_High_5_2, kVTProfileLevel_H264_Main_4_2, kVTProfileLevel_H264_Main_5_1, kVTProfileLevel_H264_Main_5_2,
                            kVTProfileLevel_H264_Baseline_3_1, kVTProfileLevel_H264_Main_AutoLevel};
    for (size_t i = 0; i < sizeof levels / sizeof *levels; i++) {
        OSStatus result = 1;
        VTCompressionSessionRef session = NULL;
        OSStatus status = VTCompressionSessionCreate(NULL, 320, 240, kCMVideoCodecType_H264, NULL, NULL, NULL, encoded, &result, &session);
        if (!session) {
            printf("measure VTCompressionSessionCreate = %d\n", (int)status);
            continue;
        }
        OSStatus set = VTSessionSetProperty(session, kVTCompressionPropertyKey_ProfileLevel, levels[i]);
        OSStatus prepared = VTCompressionSessionPrepareToEncodeFrames(session);
        CVPixelBufferRef pixels = NULL;
        CVPixelBufferCreate(NULL, 320, 240, kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange, (__bridge CFDictionaryRef)@{(__bridge NSString *)kCVPixelBufferIOSurfacePropertiesKey: @{}}, &pixels);
        OSStatus submitted = VTCompressionSessionEncodeFrame(session, pixels, CMTimeMake(0, 30), kCMTimeInvalid, NULL, NULL, NULL);
        VTCompressionSessionCompleteFrames(session, kCMTimeInvalid);
        printf("measure profile %s: set %d, prepare %d, encode %d, frame %d\n", [(__bridge NSString *)levels[i] UTF8String], (int)set, (int)prepared, (int)submitted, (int)result);
        CHECK(prepared == noErr, "PrepareToEncodeFrames on a live session answers noErr");
        CVPixelBufferRelease(pixels);
        VTCompressionSessionInvalidate(session);
        CFRelease(session);
    }
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        if (argc > 1)
            charon_log_to([NSString stringWithUTF8String:argv[1]]);
        decode("baseline 320x240", baseline_sps, sizeof baseline_sps, baseline_pps, sizeof baseline_pps, baseline_frame, sizeof baseline_frame, 320, 240);
        decode("high 640x480", high_sps, sizeof high_sps, high_pps, sizeof high_pps, high_frame, sizeof high_frame, 640, 480);
        encode();
        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
    }
    return charon_failures ? 1 : 0;
}
