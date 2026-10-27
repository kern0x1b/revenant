#import "../Foundation/check.h"
#import <CoreFoundation/CoreFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>
#import <VideoToolbox/VideoToolbox.h>

#import "VTDecompressionSessionHEVC.h"
#import "VTInterleave.h"

extern OSStatus RevenantVTDecompressionSessionDecodeFrame(VTDecompressionSessionRef session, CMSampleBufferRef sampleBuffer, VTDecodeFrameFlags decodeFlags, void *sourceFrameRefCon, VTDecodeInfoFlags *infoFlagsOut);
extern OSStatus RevenantVTDecompressionSessionFinishDelayedFrames(VTDecompressionSessionRef session);
extern void RevenantVTDecompressionSessionInvalidate(VTDecompressionSessionRef session);

@interface RevenantTestSample : NSObject
@property (nonatomic, strong) NSData *data;
@property (nonatomic) int64_t dts;
@property (nonatomic) int64_t pts;
@property (nonatomic) int64_t duration;
@end

@implementation RevenantTestSample
@end

@interface RevenantTestClip : NSObject
@property (nonatomic) int width;
@property (nonatomic) int height;
@property (nonatomic) int32_t timescale;
@property (nonatomic, strong) NSData *configuration;
@property (nonatomic, strong) NSArray<RevenantTestSample *> *samples;
@end

@implementation RevenantTestClip
@end

@interface RevenantTestFrame : NSObject
@property (nonatomic) int64_t pts;
@property (nonatomic) int width;
@property (nonatomic) int height;
@property (nonatomic) OSType format;
@property (nonatomic) uint64_t checksum;
@property (nonatomic) BOOL missing;
@end

@implementation RevenantTestFrame
@end

static uint32_t RevenantReadU32(const uint8_t *p)
{
    return (uint32_t)p[0] | (uint32_t)p[1] << 8 | (uint32_t)p[2] << 16 | (uint32_t)p[3] << 24;
}

static int64_t RevenantReadI64(const uint8_t *p)
{
    uint64_t value = 0;
    for (int i = 7; i >= 0; i--)
        value = value << 8 | p[i];
    return (int64_t)value;
}

static void RevenantExpect(BOOL ok, NSString *name, NSString *seen)
{
    revenant_check(ok != revenant_negative, [name UTF8String], seen);
}

static RevenantTestClip *RevenantLoadClip(NSString *path)
{
    NSData *file = [NSData dataWithContentsOfFile:path];
    if (!file || file.length < 24 || memcmp(file.bytes, "RVHEVC01", 8) != 0)
        return nil;
    const uint8_t *p = file.bytes;
    const uint8_t *end = p + file.length;
    RevenantTestClip *clip = [[RevenantTestClip alloc] init];
    clip.width = (int)RevenantReadU32(p + 8);
    clip.height = (int)RevenantReadU32(p + 12);
    clip.timescale = (int32_t)RevenantReadU32(p + 16);
    const uint32_t configurationSize = RevenantReadU32(p + 20);
    p += 24;
    if (p + configurationSize + 4 > end)
        return nil;
    clip.configuration = [NSData dataWithBytes:p length:configurationSize];
    p += configurationSize;
    const uint32_t count = RevenantReadU32(p);
    p += 4;
    NSMutableArray *samples = [NSMutableArray arrayWithCapacity:count];
    for (uint32_t index = 0; index < count; index++) {
        if (p + 28 > end)
            return nil;
        RevenantTestSample *sample = [[RevenantTestSample alloc] init];
        sample.dts = RevenantReadI64(p);
        sample.pts = RevenantReadI64(p + 8);
        sample.duration = RevenantReadI64(p + 16);
        const uint32_t size = RevenantReadU32(p + 24);
        p += 28;
        if (p + size > end)
            return nil;
        sample.data = [NSData dataWithBytes:p length:size];
        p += size;
        [samples addObject:sample];
    }
    clip.samples = samples;
    return clip;
}

static CMVideoFormatDescriptionRef RevenantFormatOf(RevenantTestClip *clip, NSData *configuration)
{
    NSDictionary *atoms = @{@"hvcC": configuration};
    NSDictionary *extensions = @{(__bridge NSString *)kCMFormatDescriptionExtension_SampleDescriptionExtensionAtoms: atoms};
    CMVideoFormatDescriptionRef format = NULL;
    if (CMVideoFormatDescriptionCreate(kCFAllocatorDefault, kCMVideoCodecType_HEVC, clip.width, clip.height, (__bridge CFDictionaryRef)extensions, &format) != noErr)
        return NULL;
    return format;
}

static CMSampleBufferRef RevenantSampleOf(CMVideoFormatDescriptionRef format, RevenantTestClip *clip, RevenantTestSample *sample)
{
    CMBlockBufferRef block = NULL;
    const size_t length = sample.data.length;
    if (CMBlockBufferCreateWithMemoryBlock(kCFAllocatorDefault, NULL, length, kCFAllocatorDefault, NULL, 0, length, 0, &block) != kCMBlockBufferNoErr)
        return NULL;
    CMBlockBufferReplaceDataBytes(sample.data.bytes, block, 0, length);
    CMSampleTimingInfo timing = {CMTimeMake(sample.duration, clip.timescale), CMTimeMake(sample.pts, clip.timescale), CMTimeMake(sample.dts, clip.timescale)};
    size_t size = length;
    CMSampleBufferRef buffer = NULL;
    CMSampleBufferCreate(kCFAllocatorDefault, block, true, NULL, NULL, format, 1, 1, &timing, 1, &size, &buffer);
    CFRelease(block);
    return buffer;
}

static uint64_t RevenantChecksumOf(CVPixelBufferRef buffer)
{
    uint64_t hash = 1469598103934665603ULL;
    CVPixelBufferLockBaseAddress(buffer, kCVPixelBufferLock_ReadOnly);
    const size_t planes = CVPixelBufferGetPlaneCount(buffer);
    for (size_t plane = 0; plane < planes; plane++) {
        const uint8_t *base = CVPixelBufferGetBaseAddressOfPlane(buffer, plane);
        const size_t rows = CVPixelBufferGetHeightOfPlane(buffer, plane);
        const size_t stride = CVPixelBufferGetBytesPerRowOfPlane(buffer, plane);
        const size_t meaningful = CVPixelBufferGetWidthOfPlane(buffer, plane) * (plane == 0 ? 1 : 2);
        for (size_t row = 0; row < rows; row++)
            for (size_t column = 0; column < meaningful; column++)
                hash = (hash ^ base[row * stride + column]) * 1099511628211ULL;
    }
    CVPixelBufferUnlockBaseAddress(buffer, kCVPixelBufferLock_ReadOnly);
    return hash;
}

static NSDictionary *RevenantNV12Attributes(void)
{
    return @{(__bridge NSString *)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)};
}

static void RevenantCollect(void *refcon, void *sourceFrameRefCon, OSStatus status, VTDecodeInfoFlags infoFlags, CVImageBufferRef image, CMTime pts, CMTime duration)
{
    NSMutableArray<RevenantTestFrame *> *frames = (__bridge NSMutableArray<RevenantTestFrame *> *)refcon;
    RevenantTestFrame *frame = [[RevenantTestFrame alloc] init];
    frame.pts = pts.value;
    frame.missing = status != noErr || image == NULL;
    if (!frame.missing) {
        frame.checksum = RevenantChecksumOf(image);
        frame.width = (int)CVPixelBufferGetWidth(image);
        frame.height = (int)CVPixelBufferGetHeight(image);
        frame.format = CVPixelBufferGetPixelFormatType(image);
    }
    [frames addObject:frame];
}

static NSArray<RevenantTestFrame *> *RevenantDecodeWithSystem(RevenantTestClip *clip, CMVideoFormatDescriptionRef format, OSStatus *statusOut)
{
    NSMutableArray<RevenantTestFrame *> *frames = [NSMutableArray array];
    VTDecompressionOutputCallbackRecord record = {RevenantCollect, (__bridge void *)frames};
    VTDecompressionSessionRef session = NULL;
    *statusOut = VTDecompressionSessionCreate(kCFAllocatorDefault, format, NULL, (__bridge CFDictionaryRef)RevenantNV12Attributes(), &record, &session);
    if (*statusOut != noErr)
        return nil;
    for (RevenantTestSample *sample in clip.samples) {
        CMSampleBufferRef buffer = RevenantSampleOf(format, clip, sample);
        if (!buffer)
            continue;
        VTDecompressionSessionDecodeFrame(session, buffer, kVTDecodeFrame_EnableTemporalProcessing, NULL, NULL);
        CFRelease(buffer);
    }
    VTDecompressionSessionFinishDelayedFrames(session);
    VTDecompressionSessionInvalidate(session);
    CFRelease(session);
    return frames;
}

static NSArray<RevenantTestFrame *> *RevenantDecodeWithBackport(RevenantTestClip *clip, CMVideoFormatDescriptionRef format, OSStatus *statusOut)
{
    NSMutableArray<RevenantTestFrame *> *frames = [NSMutableArray array];
    RevenantVTDecodeOutput output = ^(void *sourceFrameRefCon, OSStatus status, VTDecodeInfoFlags infoFlags, CVImageBufferRef image, CMTime pts, CMTime duration) {
        RevenantCollect((__bridge void *)frames, sourceFrameRefCon, status, infoFlags, image, pts, duration);
    };
    VTDecompressionSessionRef session = NULL;
    *statusOut = RevenantVTSoftwareSessionCreate(format, (__bridge CFDictionaryRef)RevenantNV12Attributes(), output, &session);
    if (*statusOut != noErr)
        return nil;
    for (RevenantTestSample *sample in clip.samples) {
        CMSampleBufferRef buffer = RevenantSampleOf(format, clip, sample);
        if (!buffer)
            continue;
        const OSStatus decoded = RevenantVTDecompressionSessionDecodeFrame(session, buffer, kVTDecodeFrame_EnableTemporalProcessing, NULL, NULL);
        CFRelease(buffer);
        if (decoded != noErr) {
            RevenantTestFrame *failure = [[RevenantTestFrame alloc] init];
            failure.pts = sample.pts;
            failure.missing = YES;
            [frames addObject:failure];
        }
    }
    RevenantVTDecompressionSessionFinishDelayedFrames(session);
    RevenantVTDecompressionSessionInvalidate(session);
    CFRelease(session);
    return frames;
}

static NSString *RevenantPTSList(NSArray<RevenantTestFrame *> *frames)
{
    NSMutableArray<NSString *> *values = [NSMutableArray arrayWithCapacity:frames.count];
    for (RevenantTestFrame *frame in frames)
        [values addObject:[NSString stringWithFormat:@"%lld", (long long)frame.pts]];
    return [values componentsJoinedByString:@","];
}

static NSArray<RevenantTestFrame *> *RevenantSortedByPTS(NSArray<RevenantTestFrame *> *frames)
{
    return [frames sortedArrayUsingComparator:^NSComparisonResult(RevenantTestFrame *a, RevenantTestFrame *b) {
        if (a.pts == b.pts)
            return NSOrderedSame;
        return a.pts < b.pts ? NSOrderedAscending : NSOrderedDescending;
    }];
}

static BOOL RevenantInPresentationOrder(NSArray<RevenantTestFrame *> *frames)
{
    for (NSUInteger index = 1; index < frames.count; index++)
        if (frames[index].pts < frames[index - 1].pts)
            return NO;
    return YES;
}

static BOOL RevenantSameFrames(NSArray<RevenantTestFrame *> *expected, NSArray<RevenantTestFrame *> *actual, NSString **detail)
{
    if (expected.count != actual.count) {
        *detail = [NSString stringWithFormat:@"%lu frames against %lu", (unsigned long)actual.count, (unsigned long)expected.count];
        return NO;
    }
    for (NSUInteger index = 0; index < expected.count; index++) {
        RevenantTestFrame *want = expected[index];
        RevenantTestFrame *got = actual[index];
        if (want.missing || got.missing || want.pts != got.pts || want.width != got.width || want.height != got.height || want.format != got.format || want.checksum != got.checksum) {
            *detail = [NSString stringWithFormat:@"frame %lu: pts %lld against %lld, %dx%d against %dx%d, checksum %016llx against %016llx; pts %@ against %@", (unsigned long)index, (long long)got.pts, (long long)want.pts, got.width, got.height, want.width, want.height, (unsigned long long)got.checksum, (unsigned long long)want.checksum, RevenantPTSList(actual), RevenantPTSList(expected)];
            return NO;
        }
    }
    return YES;
}

static void RevenantCheckInterleave(void)
{
    const size_t widths[] = {1, 15, 16, 17, 37, 427};
    BOOL same = YES;
    for (size_t index = 0; index < sizeof(widths) / sizeof(widths[0]); index++) {
        const size_t width = widths[index];
        const size_t height = 5;
        uint8_t blue[5 * 512], red[5 * 512];
        for (size_t i = 0; i < sizeof(blue); i++) {
            blue[i] = (uint8_t)(i * 37 + 11);
            red[i] = (uint8_t)(i * 91 + 3);
        }
        uint8_t scalar[5 * 1024] = {0}, neon[5 * 1024] = {0};
        RevenantVTInterleaveChromaScalar(scalar, 1024, blue, 512, red, 512, width, height);
        RevenantVTInterleaveChromaNEON(neon, 1024, blue, 512, red, 512, width, height);
        for (size_t row = 0; row < height; row++)
            if (memcmp(scalar + row * 1024, neon + row * 1024, 2 * width) != 0)
                same = NO;
    }
    RevenantExpect(same, @"the NEON chroma interleave matches the scalar one at every width", @"the NEON interleave differs from the scalar reference");
}

static void RevenantCheckRejectsBadConfiguration(RevenantTestClip *clip)
{
    NSMutableData *broken = [clip.configuration mutableCopy];
    ((uint8_t *)broken.mutableBytes)[0] = 0;
    CMVideoFormatDescriptionRef format = RevenantFormatOf(clip, broken);
    RevenantVTDecodeOutput output = ^(void *sourceFrameRefCon, OSStatus status, VTDecodeInfoFlags infoFlags, CVImageBufferRef image, CMTime pts, CMTime duration) {};
    VTDecompressionSessionRef session = NULL;
    const OSStatus status = format ? RevenantVTSoftwareSessionCreate(format, NULL, output, &session) : kVTParameterErr;
    RevenantExpect(status != noErr, @"a configuration whose version is not 1 is rejected", [NSString stringWithFormat:@"created with status %d", (int)status]);
    if (status == noErr && session) {
        RevenantVTDecompressionSessionInvalidate(session);
        CFRelease(session);
    }
    if (format)
        CFRelease(format);
}

static void RevenantCheckClip(NSString *leaf)
{
    NSString *path = [@REVENANT_VT_FIXTURE_DIR stringByAppendingPathComponent:leaf];
    RevenantTestClip *clip = RevenantLoadClip(path);
    RevenantExpect(clip != nil, [leaf stringByAppendingString:@" loads"], path);
    if (!clip)
        return;
    CMVideoFormatDescriptionRef format = RevenantFormatOf(clip, clip.configuration);
    RevenantExpect(format != NULL, [leaf stringByAppendingString:@" has an HEVC format description"], @"CMVideoFormatDescriptionCreate failed");
    if (!format)
        return;

    OSStatus referenceStatus = noErr;
    NSArray<RevenantTestFrame *> *reference = RevenantDecodeWithSystem(clip, format, &referenceStatus);
    RevenantExpect(reference != nil, [leaf stringByAppendingString:@": macOS VideoToolbox creates a session"], [NSString stringWithFormat:@"status %d", (int)referenceStatus]);
    if (reference)
        RevenantExpect(reference.count == clip.samples.count, [leaf stringByAppendingString:@": macOS returns every frame"], [NSString stringWithFormat:@"%lu of %lu", (unsigned long)reference.count, (unsigned long)clip.samples.count]);

    OSStatus backportStatus = noErr;
    NSArray<RevenantTestFrame *> *decoded = RevenantDecodeWithBackport(clip, format, &backportStatus);
    RevenantExpect(decoded != nil, [leaf stringByAppendingString:@": the software session is created"], [NSString stringWithFormat:@"status %d", (int)backportStatus]);
    if (reference && decoded) {
        RevenantExpect(RevenantInPresentationOrder(decoded), [leaf stringByAppendingString:@": the software session delivers frames in presentation order"], @"frames arrive out of pts order");
        NSString *detail = @"";
        const BOOL same = RevenantSameFrames(RevenantSortedByPTS(reference), RevenantSortedByPTS(decoded), &detail);
        RevenantExpect(same, [leaf stringByAppendingString:@": every frame, pts and pixels match macOS"], detail);
    }
    CFRelease(format);
}

static void RevenantCheckReentrancy(RevenantTestClip *clip)
{
    CMVideoFormatDescriptionRef format = RevenantFormatOf(clip, clip.configuration);
    if (!format)
        return;
    __block VTDecompressionSessionRef session = NULL;
    __block OSStatus reentrantDecode = noErr;
    __block OSStatus reentrantFinish = noErr;
    __block int callbacks = 0;
    RevenantVTDecodeOutput output = ^(void *sourceFrameRefCon, OSStatus status, VTDecodeInfoFlags infoFlags, CVImageBufferRef image, CMTime pts, CMTime duration) {
        callbacks++;
        if (callbacks > 1)
            return;
        CMSampleBufferRef buffer = RevenantSampleOf(format, clip, clip.samples[1]);
        reentrantDecode = RevenantVTDecompressionSessionDecodeFrame(session, buffer, 0, NULL, NULL);
        CFRelease(buffer);
        reentrantFinish = RevenantVTDecompressionSessionFinishDelayedFrames(session);
        RevenantVTDecompressionSessionInvalidate(session);
    };
    const OSStatus status = RevenantVTSoftwareSessionCreate(format, NULL, output, &session);
    RevenantExpect(status == noErr, @"the software session for the re-entrancy check is created", [NSString stringWithFormat:@"status %d", (int)status]);
    if (status == noErr) {
        for (RevenantTestSample *sample in clip.samples) {
            CMSampleBufferRef buffer = RevenantSampleOf(format, clip, sample);
            if (buffer) {
                RevenantVTDecompressionSessionDecodeFrame(session, buffer, 0, NULL, NULL);
                CFRelease(buffer);
            }
        }
        RevenantVTDecompressionSessionFinishDelayedFrames(session);
        RevenantVTDecompressionSessionInvalidate(session);
        CFRelease(session);
        RevenantExpect(reentrantDecode == kVTVideoDecoderNotAvailableNowErr, @"a decode from inside an output callback is refused while the decoder is busy", [NSString stringWithFormat:@"status %d", (int)reentrantDecode]);
        RevenantExpect(reentrantFinish == kVTVideoDecoderNotAvailableNowErr, @"a finish from inside an output callback is refused while the decoder is busy", [NSString stringWithFormat:@"status %d", (int)reentrantFinish]);
        RevenantExpect(callbacks == 1, @"invalidating from an output callback stops the frames of the decode in progress", [NSString stringWithFormat:@"%d callbacks", callbacks]);
    }
    CFRelease(format);
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        revenant_read_arguments(argc, argv);
        RevenantCheckInterleave();
        RevenantCheckClip(@"clip-480p.rvhevc");
        RevenantCheckClip(@"clip-720p.rvhevc");
        RevenantTestClip *clip = RevenantLoadClip([@REVENANT_VT_FIXTURE_DIR stringByAppendingPathComponent:@"clip-480p.rvhevc"]);
        if (clip) {
            RevenantCheckRejectsBadConfiguration(clip);
            RevenantCheckReentrancy(clip);
        }
        return revenant_finish();
    }
}
