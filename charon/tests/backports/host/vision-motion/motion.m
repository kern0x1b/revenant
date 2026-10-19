/* motion.m - what the host answers for the two motion requests, on a fixed synthetic input. Each line is one answer that
 * the port would have to give: the observation class, the buffer format and size, and the first frame that yields a
 * trajectory. Values of the flow are not printed, because on these inputs they do not track the shift (facts/Vision/Motion.md). */
#import <Foundation/Foundation.h>
#import <Vision/Vision.h>
#import <CoreVideo/CoreVideo.h>
#import <CoreMedia/CoreMedia.h>

static CVPixelBufferRef frame(size_t ox, size_t side, uint8_t fill)
{
    CVPixelBufferRef b = NULL;
    CVPixelBufferCreate(kCFAllocatorDefault, 64, 64, kCVPixelFormatType_32BGRA, NULL, &b);
    CVPixelBufferLockBaseAddress(b, 0);
    uint8_t *p = CVPixelBufferGetBaseAddress(b);
    size_t s = CVPixelBufferGetBytesPerRow(b);
    for (size_t y = 0; y < 64; y++) for (size_t x = 0; x < 64; x++) {
        uint8_t v = (x >= 20 + ox && x < 20 + ox + side && y >= 20 && y < 20 + side) ? fill : 0;
        p[y * s + x * 4] = p[y * s + x * 4 + 1] = p[y * s + x * 4 + 2] = v; p[y * s + x * 4 + 3] = 255;
    }
    CVPixelBufferUnlockBaseAddress(b, 0);
    return b;
}

int main(void)
{
    @autoreleasepool {
        CVPixelBufferRef a = frame(0, 16, 255), b = frame(3, 16, 255);
        VNGenerateOpticalFlowRequest *flow = [[VNGenerateOpticalFlowRequest alloc] initWithTargetedCVPixelBuffer:b options:@{}];
        flow.computationAccuracy = VNGenerateOpticalFlowRequestComputationAccuracyHigh;
        VNImageRequestHandler *handler = [[VNImageRequestHandler alloc] initWithCVPixelBuffer:a options:@{}];
        BOOL ok = [handler performRequests:@[flow] error:NULL];
        VNPixelBufferObservation *o = flow.results.firstObject;
        CVPixelBufferRef pb = o.pixelBuffer;
        printf("flow: ok=%d results=%lu class=%s format=%u size=%zux%zu\n", ok, (unsigned long)flow.results.count,
               o ? object_getClassName(o) : "none", pb ? (unsigned)CVPixelBufferGetPixelFormatType(pb) : 0,
               pb ? CVPixelBufferGetWidth(pb) : 0, pb ? CVPixelBufferGetHeight(pb) : 0);
        CVPixelBufferRelease(a); CVPixelBufferRelease(b);

        VNDetectTrajectoriesRequest *traj = [[VNDetectTrajectoriesRequest alloc] initWithFrameAnalysisSpacing:CMTimeMake(1, 30) trajectoryLength:3 completionHandler:nil];
        VNSequenceRequestHandler *sequence = [[VNSequenceRequestHandler alloc] init];
        int first = -1;
        for (int i = 0; i < 12; i++) {
            CVPixelBufferRef f = frame(i, 16, 255);
            CMVideoFormatDescriptionRef fd = NULL;
            CMVideoFormatDescriptionCreateForImageBuffer(kCFAllocatorDefault, f, &fd);
            CMSampleTimingInfo t = {CMTimeMake(i, 30), CMTimeMake(i, 30), kCMTimeInvalid};
            CMSampleBufferRef sb = NULL;
            CMSampleBufferCreateReadyWithImageBuffer(kCFAllocatorDefault, f, fd, &t, &sb);
            [sequence performRequests:@[traj] onCMSampleBuffer:sb error:NULL];
            if (first < 0 && traj.results.count > 0) first = i;
            CFRelease(sb); CFRelease(fd); CVPixelBufferRelease(f);
        }
        printf("trajectories: requested length 3, reported length %lu, first result at frame %d, class %s\n",
               (unsigned long)traj.trajectoryLength, first, traj.results.firstObject ? object_getClassName(traj.results.firstObject) : "none");
    }
    return 0;
}
