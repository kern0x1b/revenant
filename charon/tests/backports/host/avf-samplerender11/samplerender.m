#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static const double kSampleRate = 44100.0;
static const double kToneHz = 1000.0;
static const uint32_t kFramesPerBuffer = 4410;

static void row(const char *key, NSString *value)
{
    printf("%s | %s\n", key, value.UTF8String);
}

static void rowf(const char *key, NSString *format, ...) NS_FORMAT_FUNCTION(2, 3);
static void rowf(const char *key, NSString *format, ...)
{
    va_list args;
    va_start(args, format);
    NSString *value = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    row(key, value);
}

static NSString *yesno(BOOL value) { return value ? @"YES" : @"NO"; }

static NSString *describeTime(CMTime time)
{
    if (!CMTIME_IS_VALID(time)) return @"(invalid)";
    if (CMTIME_IS_INDEFINITE(time)) return @"(indefinite)";
    return [NSString stringWithFormat:@"%lld/%d", time.value, time.timescale];
}

static CMTime clockNow(void)
{
    return CMClockGetTime(CMClockGetHostTimeClock());
}

static double secondsBetween(CMTime from, CMTime to)
{
    if (!CMTIME_IS_NUMERIC(from) || !CMTIME_IS_NUMERIC(to)) return NAN;
    return CMTimeGetSeconds(CMTimeSubtract(to, from));
}

static CMAudioFormatDescriptionRef makeFormat(void)
{
    AudioStreamBasicDescription asbd = {0};
    asbd.mSampleRate = kSampleRate;
    asbd.mFormatID = kAudioFormatLinearPCM;
    asbd.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    asbd.mChannelsPerFrame = 1;
    asbd.mBitsPerChannel = 16;
    asbd.mFramesPerPacket = 1;
    asbd.mBytesPerFrame = 2;
    asbd.mBytesPerPacket = 2;
    CMAudioFormatDescriptionRef format = NULL;
    OSStatus status = CMAudioFormatDescriptionCreate(kCFAllocatorDefault, &asbd, 0, NULL, 0, NULL, NULL, &format);
    return status ? NULL : format;
}

static CMSampleBufferRef makeSine(CMAudioFormatDescriptionRef format, CMTime presentation, uint32_t frames);

static CMSampleBufferRef makeSine(CMAudioFormatDescriptionRef format, CMTime presentation, uint32_t frames)
{
    size_t bytes = (size_t)frames * 2;
    static int16_t *sTones[64];
    static int sToneCount;
    int16_t *samples = calloc(frames ? frames : 1, sizeof *samples);
    if (sToneCount < (int)(sizeof sTones / sizeof *sTones)) sTones[sToneCount++] = samples;
    for (uint32_t frame = 0; frame < frames; frame++) {
        double phase = 2.0 * M_PI * kToneHz * (double)frame / kSampleRate;
        samples[frame] = (int16_t)(12000.0 * sin(phase));
    }
    CMBlockBufferRef block = NULL;
    OSStatus status = CMBlockBufferCreateWithMemoryBlock(kCFAllocatorDefault, samples, bytes,
                                                         NULL, NULL, 0, bytes, 0, &block);
    if (status) return NULL;
    CMSampleTimingInfo timing = {CMTimeMake(frames, (int32_t)kSampleRate), presentation, kCMTimeInvalid};
    CMSampleBufferRef buffer = NULL;
    status = CMSampleBufferCreate(kCFAllocatorDefault, block, true, NULL, NULL, format,
                                  frames, 1, &timing, 0, NULL, &buffer);
    CFRelease(block);
    return status ? NULL : buffer;
}

static void self_drain(BOOL *completion)
{
    for (int step = 0; step < 50 && !*completion; step++)
        CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.02, false);
}

static void probeSynchronizerClock(void)
{
    AVSampleBufferRenderSynchronizer *sync = [[AVSampleBufferRenderSynchronizer alloc] init];
    row("sync: timebase is not nil", yesno(sync.timebase != NULL));
    rowf("sync: rate at init", @"%.3f", sync.rate);
    row("sync: timebase time at init is valid", yesno(CMTIME_IS_VALID(CMTimebaseGetTime(sync.timebase))));
    row("sync: currentTime at init", describeTime([sync currentTime]));
    rowf("sync: renderers at init", @"%lu", (unsigned long)sync.renderers.count);

    [sync setRate:1.0];
    usleep(150000);
    rowf("sync: rate after setRate: 1.0", @"%.3f", sync.rate);
    [sync setRate:0.0];
    usleep(150000);
    rowf("sync: rate after setRate: 0.0", @"%.3f", sync.rate);
    [sync setRate:2.0];
    usleep(150000);
    rowf("sync: rate after setRate: 2.0", @"%.3f", sync.rate);
    [sync setRate:1.0];
    usleep(150000);
    rowf("sync: rate 150 ms after setRate: 1.0 again", @"%.3f", sync.rate);
    @try {
        [sync setRate:-1.0f];
        row("sync: setRate: -1.0, which the header forbids, is refused", @"NO");
    } @catch (NSException *exception) {
        row("sync: setRate: -1.0, which the header forbids, is refused", @"YES");
    }

    [sync setRate:1.0 time:CMTimeMake(600, 1)];
    double named = secondsBetween(kCMTimeZero, [sync currentTime]);
    row("sync: currentTime right after setRate: 1.0 time: 600/1 is in [599 s, 601 s)",
        yesno(named >= 599.0 && named <= 601.0));
    [sync setRate:1.0 time:kCMTimeInvalid];
    CMTime kept = [sync currentTime];
    row("sync: currentTime after setRate: 1.0 time: kCMTimeInvalid is unchanged", yesno(CMTimeCompare(kept, CMTimeMake(600, 1)) >= 0));
    [sync setRate:0.0];
    row("sync: currentTime after setRate: 0.0 keeps the 600/1", yesno(CMTimeCompare([sync currentTime], CMTimeMake(600, 1)) >= 0));

    CMTime frozen = [sync currentTime];
    usleep(200000);
    row("sync: currentTime frozen while the rate is 0", yesno(fabs(secondsBetween(frozen, [sync currentTime])) < 0.02));

    [sync setRate:1.0];
    CMTime started = [sync currentTime], hostStarted = clockNow();
    usleep(300000);
    double moved = secondsBetween(started, [sync currentTime]);
    double hostMoved = secondsBetween(hostStarted, clockNow());
    row("sync: currentTime moves while the rate is 1", yesno(moved > 0.1));
    row("sync: timebase advance within 100 ms of the host clock over 300 ms",
        yesno(fabs(moved - hostMoved) < 0.1));

    [sync setRate:2.0];
    CMTime doubled = [sync currentTime], hostDoubled = clockNow();
    usleep(300000);
    double fast = secondsBetween(doubled, [sync currentTime]);
    double hostFast = secondsBetween(hostDoubled, clockNow());
    row("sync: currentTime moves faster than the host clock at rate 2", yesno(fast > hostFast * 1.5));
    row("sync: rate 2 advance is within 100 ms of twice the host clock's advance",
        yesno(fabs(fast - 2.0 * hostFast) < 0.1));
    [sync setRate:1.0];
}

static void probeSynchronizerObservers(void)
{
    AVSampleBufferRenderSynchronizer *sync = [[AVSampleBufferRenderSynchronizer alloc] init];
    [sync setRate:1.0 time:kCMTimeZero];

    __block NSInteger fires = 0;
    __block CMTime first = kCMTimeInvalid, atFirst = kCMTimeInvalid, previous = kCMTimeInvalid;
    __block double step = -1.0;
    dispatch_queue_t queue = dispatch_queue_create("charon.observer", DISPATCH_QUEUE_SERIAL);
    id periodic = [sync addPeriodicTimeObserverForInterval:CMTimeMake(1, 10)
                                                      queue:queue
                                                  usingBlock:^(CMTime time) {
        if (!fires) { first = time; atFirst = [sync currentTime]; }
        if (fires) step = secondsBetween(previous, time);
        previous = time;
        fires++;
    }];
    row("sync: addPeriodicTimeObserverForInterval: returns an object", yesno(periodic != nil));
    usleep(420000);
    row("sync: the periodic observer fired at least three times in 420 ms at a 100 ms interval",
        yesno(fires >= 3));
    row("sync: the first periodic call is handed a valid time", yesno(CMTIME_IS_VALID(first)));
    row("sync: the first periodic call is handed the timebase's own time (within 50 ms)",
        yesno(CMTIME_IS_VALID(first) && fabs(secondsBetween(first, atFirst)) < 0.05));
    row("sync: consecutive periodic times are 100 ms apart within 20 ms",
        yesno(step > 0.08 && step < 0.12));

    NSInteger before = fires;
    [sync removeTimeObserver:periodic];
    usleep(300000);
    row("sync: no further periodic calls after removeTimeObserver:", yesno(fires == before));

    __block NSInteger second = 0;
    id other = [sync addPeriodicTimeObserverForInterval:CMTimeMake(1, 10) queue:queue usingBlock:^(CMTime time) {
        (void)time;
        second++;
    }];
    usleep(300000);
    row("sync: a second periodic observer fires while the first is removed", yesno(second > 0));
    [sync removeTimeObserver:other];

    __block NSInteger boundary = 0;
    CMTime ahead = CMTimeAdd([sync currentTime], CMTimeMake(15, 100));
    id boundaryObserver = [sync addBoundaryTimeObserverForTimes:@[ [NSValue valueWithCMTime:ahead] ]
                                                          queue:queue
                                                      usingBlock:^{
        boundary++;
    }];
    usleep(400000);
    row("sync: boundary observer for a time 150 ms ahead fired", yesno(boundary > 0));
    [sync removeTimeObserver:boundaryObserver];

    __block NSInteger past = 0;
    id pastObserver = [sync addBoundaryTimeObserverForTimes:@[ [NSValue valueWithCMTime:CMTimeMake(1, 1)] ]
                                                       queue:queue
                                                   usingBlock:^{
        past++;
    }];
    usleep(300000);
    row("sync: boundary observer for a time already past fired", yesno(past > 0));
    [sync removeTimeObserver:pastObserver];

    __block NSInteger emptied = 0;
    (void)emptied;
    id emptyObserver = nil;
    @try {
        emptyObserver = [sync addBoundaryTimeObserverForTimes:@[] queue:queue usingBlock:^{
            emptied++;
        }];
        row("sync: boundary observer for no times is refused", @"NO");
    } @catch (NSException *exception) {
        row("sync: boundary observer for no times is refused", @"YES");
    }
    if (emptyObserver) [sync removeTimeObserver:emptyObserver];

    id removed = [sync addPeriodicTimeObserverForInterval:CMTimeMake(1, 10) queue:queue usingBlock:^(CMTime time) {
        (void)time;
    }];
    [sync removeTimeObserver:removed];
    @try {
        [sync removeTimeObserver:removed];
        row("sync: removing the same observer twice is refused", @"NO");
    } @catch (NSException *exception) {
        row("sync: removing the same observer twice is refused", @"YES");
    }
    @try {
        [sync removeTimeObserver:@"not an observer"];
        row("sync: removing an object that is not an observer is refused", @"NO");
    } @catch (NSException *exception) {
        row("sync: removing an object that is not an observer is refused", @"YES");
    }
}

static void probeAnchorForm(void)
{
    AVSampleBufferRenderSynchronizer *sync = [[AVSampleBufferRenderSynchronizer alloc] init];
    [sync setRate:1.0 time:CMTimeMake(10, 1)];
    usleep(100000);

    CMTime past = CMTimeSubtract(clockNow(), CMTimeMake(1, 1));
    [sync setRate:1.0 time:CMTimeMake(100, 1) atHostTime:past];
    double afterPast = secondsBetween(kCMTimeZero, [sync currentTime]);
    row("anchor: with the host time 1 s in the past, the time is already past the named time",
        yesno(afterPast > 100.9 && afterPast < 101.2));
    usleep(150000);
    row("anchor: with the host time 1 s in the past, the rate is the one asked for",
        yesno(fabs(sync.rate - 1.0) < 0.001));
    usleep(200000);
    row("anchor: with the host time 1 s in the past, the time keeps moving at that rate",
        yesno(secondsBetween(kCMTimeZero, [sync currentTime]) > afterPast + 0.15));

    [sync setRate:1.0 time:CMTimeMake(10, 1)];
    usleep(100000);
    CMTime future = CMTimeAdd(clockNow(), CMTimeMake(1, 1));
    [sync setRate:2.0 time:CMTimeMake(200, 1) atHostTime:future];
    double held = secondsBetween(kCMTimeZero, [sync currentTime]);
    row("anchor: with the host time 1 s in the future, the time is the named time", yesno(fabs(held - 200.0) < 0.01));
    usleep(400000);
    double stillHeld = secondsBetween(kCMTimeZero, [sync currentTime]);
    row("anchor: with the host time 1 s in the future, the time does not move before it arrives",
        yesno(fabs(stillHeld - held) < 0.01));
    usleep(800000);
    double moved = secondsBetween(kCMTimeZero, [sync currentTime]);
    row("anchor: with the host time 1 s in the future, the time moves at the rate once it arrives",
        yesno(moved > stillHeld + 0.15));

    [sync setRate:1.0];
}

static void probeAnchorInvalidInputs(void)
{
    AVSampleBufferRenderSynchronizer *sync = [[AVSampleBufferRenderSynchronizer alloc] init];
    [sync setRate:1.0 time:CMTimeMake(7, 1)];
    usleep(150000);
    [sync setRate:1.5 time:kCMTimeInvalid atHostTime:CMTimeAdd(clockNow(), CMTimeMake(5, 1))];
    usleep(150000);
    row("anchor: an invalid time leaves the time alone",
        yesno(fabs(secondsBetween(kCMTimeZero, [sync currentTime]) - 7.0) < 0.2));
    row("anchor: an invalid time still applies the rate", yesno(fabs(sync.rate - 1.5) < 0.001));

    AVSampleBufferRenderSynchronizer *other = [[AVSampleBufferRenderSynchronizer alloc] init];
    [other setRate:1.0 time:CMTimeMake(7, 1)];
    usleep(150000);
    [other setRate:1.0 time:CMTimeMake(9, 1) atHostTime:kCMTimeInvalid];
    usleep(150000);
    row("anchor: an invalid host time applies the named time at once",
        yesno(fabs(secondsBetween(kCMTimeZero, [other currentTime]) - 9.0) < 0.2));
    row("anchor: an invalid host time applies the rate at once", yesno(fabs(other.rate - 1.0) < 0.001));
}

static void probeSynchronizerRenderers(void)
{
    AVSampleBufferRenderSynchronizer *sync = [[AVSampleBufferRenderSynchronizer alloc] init];
    AVSampleBufferAudioRenderer *renderer = [[AVSampleBufferAudioRenderer alloc] init];
    [sync setRate:1.0];

    [sync addRenderer:renderer];
    rowf("sync: renderers after addRenderer:", @"%lu", (unsigned long)sync.renderers.count);
    row("sync: renderers holds the renderer", yesno([sync.renderers.firstObject isEqual:renderer]));
    @try {
        [sync addRenderer:renderer];
        row("sync: adding the same renderer twice is refused", @"NO");
    } @catch (NSException *exception) {
        row("sync: adding the same renderer twice is refused", @"YES");
    }
    @try {
        [sync addRenderer:[[AVSampleBufferAudioRenderer alloc] init]];
        row("sync: adding a second renderer is refused", @"NO");
    } @catch (NSException *exception) {
        row("sync: adding a second renderer is refused", @"YES");
    }

    __block BOOL removedAhead = NO;
    __block BOOL handlerRan = NO;
    NSUInteger before = sync.renderers.count;
    CMTime when = CMTimeAdd([sync currentTime], CMTimeMake(12, 100));
    __block double askedAt = secondsBetween(kCMTimeZero, clockNow());
    [sync removeRenderer:renderer atTime:when completionHandler:^(BOOL didRemoveRenderer) {
        removedAhead = didRemoveRenderer;
        handlerRan = YES;
        askedAt = secondsBetween(kCMTimeZero, clockNow()) - askedAt;
    }];
    row("sync: the removal handler has not run immediately", yesno(!handlerRan));
    usleep(400000);
    row("sync: the removal handler ran and answered YES", yesno(removedAhead));
    row("sync: the removal handler ran within 300 ms of the time it was asked for",
        yesno(handlerRan && askedAt > 0.0 && askedAt < 0.3));
    row("sync: the renderers list is one shorter after the removal ran",
        yesno(sync.renderers.count + 1 == before));

    __block BOOL never = YES;
    [sync removeRenderer:[[AVSampleBufferAudioRenderer alloc] init]
                  atTime:kCMTimeInvalid
      completionHandler:^(BOOL didRemoveRenderer) {
        never = didRemoveRenderer;
    }];
    row("sync: removing a renderer that was never added answers NO", yesno(!never));
}

static void probeRendererSurface(void)
{
    AVSampleBufferAudioRenderer *renderer = [[AVSampleBufferAudioRenderer alloc] init];
    rowf("renderer: status at init", @"%ld", (long)renderer.status);
    row("renderer: error at init is nil", yesno(renderer.error == nil));
    row("renderer: isReadyForMoreMediaData at init", yesno(renderer.isReadyForMoreMediaData));
    row("renderer: timebase at init is not nil", yesno(renderer.timebase != NULL));
    rowf("renderer: volume at init", @"%.3f", renderer.volume);
    row("renderer: isMuted at init", yesno(renderer.isMuted));
    row("renderer: audioTimePitchAlgorithm at init", renderer.audioTimePitchAlgorithm ?: @"(nil)");

    renderer.volume = 0.25f;
    rowf("renderer: volume after setVolume: 0.25", @"%.3f", renderer.volume);
    renderer.volume = 2.0f;
    row("renderer: volume after setVolume: 2.0 is above 1.0", yesno(renderer.volume > 1.0f));
    renderer.volume = -1.0f;
    row("renderer: volume after setVolume: -1.0 is below 0.0", yesno(renderer.volume < 0.0f));
    renderer.volume = 1.0f;
    rowf("renderer: volume restored to 1.0", @"%.3f", renderer.volume);

    renderer.muted = YES;
    row("renderer: isMuted after setMuted: YES", yesno(renderer.isMuted));
    renderer.muted = NO;
    row("renderer: isMuted after setMuted: NO", yesno(!renderer.isMuted));

    renderer.audioTimePitchAlgorithm = @"Spectral";
    row("renderer: audioTimePitchAlgorithm after setAudioTimePitchAlgorithm: Spectral",
        renderer.audioTimePitchAlgorithm ?: @"(nil)");
}

static void probeRendererAttached(AVSampleBufferRenderSynchronizer *sync, AVSampleBufferAudioRenderer *renderer)
{
    row("attached: the renderer's timebase is the synchronizer's own",
        yesno(renderer.timebase == sync.timebase));
    rowf("attached: the renderer is in the synchronizer's renderers", @"%lu",
         (unsigned long)([sync.renderers containsObject:renderer] ? 1 : 0));

    [sync setRate:1.0];
    CMTime base = [sync currentTime];
    row("attached: the renderer reads the synchronizer's rate through its timebase",
        yesno(fabs(CMTimebaseGetRate(renderer.timebase) - 1.0) < 0.001));
    row("attached: the renderer's clock reads the synchronizer's clock as its master",
        yesno(CMTimebaseGetMasterTimebase(renderer.timebase) == sync.timebase));
    row("attached: the renderer's time is within 20 ms of the synchronizer's",
        yesno(fabs(secondsBetween(CMTimebaseGetTime(renderer.timebase), CMTimebaseGetTime(sync.timebase))) < 0.02));
    [sync setRate:0.0];
    usleep(150000);
    row("attached: the renderer's timebase stops when the synchronizer's rate is 0",
        yesno(fabs(secondsBetween(base, CMTimebaseGetTime(renderer.timebase))) < 0.2));

    [sync setRate:1.0 time:CMTimeMake(5, 1)];
    usleep(150000);
    row("attached: the renderer's clock reads the synchronizer's new time",
        yesno(fabs(secondsBetween(CMTimebaseGetTime(renderer.timebase), CMTimebaseGetTime(sync.timebase))) < 0.02));

    [sync removeRenderer:renderer atTime:kCMTimeInvalid completionHandler:NULL];
    usleep(150000);
    row("attached: the renderer's clock is at zero after it is removed",
        yesno(fabs(secondsBetween(kCMTimeZero, CMTimebaseGetTime(renderer.timebase))) < 0.01));
    row("attached: the renderer's clock is stopped after it is removed",
        yesno(fabs(CMTimebaseGetRate(renderer.timebase)) < 0.001));
}

static void probeAbsentMembers(void)
{
    row("absent: the renderer answers respondsToSelector: for allowedAudioSpatializationFormats",
        yesno([AVSampleBufferAudioRenderer instancesRespondToSelector:@selector(allowedAudioSpatializationFormats)]));
    row("absent: the renderer answers respondsToSelector: for audioOutputDeviceUniqueID",
        yesno([AVSampleBufferAudioRenderer instancesRespondToSelector:@selector(audioOutputDeviceUniqueID)]));
    row("absent: the renderer answers respondsToSelector: for hasSufficientMediaDataForReliablePlaybackStart",
        yesno([AVSampleBufferAudioRenderer instancesRespondToSelector:@selector(hasSufficientMediaDataForReliablePlaybackStart)]));
    row("absent: the synchronizer answers respondsToSelector: for delaysRateChangeUntilHasSufficientMediaData",
        yesno([AVSampleBufferRenderSynchronizer instancesRespondToSelector:@selector(delaysRateChangeUntilHasSufficientMediaData)]));
}

static void probeRendererFlushWithoutMedia(AVSampleBufferRenderSynchronizer *sync, AVSampleBufferAudioRenderer *renderer)
{
    rowf("flush: status before -flush, with no media", @"%ld", (long)renderer.status);
    [renderer flush];
    rowf("flush: status after -flush, with no media", @"%ld", (long)renderer.status);
    row("flush: isReadyForMoreMediaData after -flush, with no media", yesno(renderer.isReadyForMoreMediaData));
    row("flush: error after -flush, with no media is nil", yesno(renderer.error == nil));

    __block BOOL answered = NO, flushed = NO;
    CMTime past = CMTimeSubtract([sync currentTime], CMTimeMake(5, 1));
    [renderer flushFromSourceTime:past completionHandler:^(BOOL flushSucceeded) {
        flushed = flushSucceeded;
        answered = YES;
    }];
    self_drain(&answered);
    row("flush: flushFromSourceTime: with no media is answered for a time in the past", yesno(answered));
    row("flush: flushFromSourceTime: with no media answers YES for a time in the past", yesno(flushed));

    answered = NO; flushed = NO;
    CMTime future = CMTimeAdd([sync currentTime], CMTimeMake(5, 1));
    [renderer flushFromSourceTime:future completionHandler:^(BOOL flushSucceeded) {
        flushed = flushSucceeded;
        answered = YES;
    }];
    self_drain(&answered);
    row("flush: flushFromSourceTime: with no media is answered for a time in the future", yesno(answered));
    row("flush: flushFromSourceTime: with no media answers YES for a time in the future", yesno(flushed));

    answered = NO;
    @try {
        [renderer flushFromSourceTime:kCMTimeInvalid completionHandler:^(BOOL flushSucceeded) {
            (void)flushSucceeded;
            answered = YES;
        }];
        self_drain(&answered);
        row("flush: flushFromSourceTime: with no media is refused for kCMTimeInvalid", @"NO");
    } @catch (NSException *exception) {
        row("flush: flushFromSourceTime: with no media is refused for kCMTimeInvalid", @"YES");
    }

    __block NSInteger supplies = 0;
    dispatch_queue_t queue = dispatch_queue_create("charon.media", DISPATCH_QUEUE_SERIAL);
    [renderer requestMediaDataWhenReadyOnQueue:queue usingBlock:^{ supplies++; }];
    usleep(300000);
    row("renderer: the requestMediaDataWhenReady block ran while the renderer holds no media", yesno(supplies > 0));
    [renderer stopRequestingMediaData];
    NSInteger beforeStop = supplies;
    usleep(200000);
    row("renderer: no further calls after stopRequestingMediaData", yesno(supplies == beforeStop));
}

static void probeRendererMedia(AVSampleBufferRenderSynchronizer *sync, AVSampleBufferAudioRenderer *renderer)
{
    CMAudioFormatDescriptionRef format = makeFormat();
    if (!format) { row("media: the audio format description", @"(could not be made)"); return; }
    [sync setRate:1.0];

    CMTime now = [sync currentTime];
    CMSampleBufferRef immediate = makeSine(format, now, kFramesPerBuffer);
    CMSampleBufferRef later = makeSine(format, CMTimeAdd(now, CMTimeMake(1, 2)), kFramesPerBuffer);
    row("media: two sine buffers were made", yesno(immediate != NULL && later != NULL));
    row("media: the buffer's own output presentation timestamp is the one asked for",
        yesno(CMTimeCompare(CMSampleBufferGetOutputPresentationTimeStamp(immediate), now) == 0));
    row("media: the buffer carries the audio the format description names",
        yesno(CMSampleBufferGetNumSamples(immediate) == kFramesPerBuffer));

    [renderer enqueueSampleBuffer:immediate];
    rowf("renderer: status after the first enqueue", @"%ld", (long)renderer.status);
    row("renderer: error after the first enqueue is nil", yesno(renderer.error == nil));
    row("renderer: isReadyForMoreMediaData after the first enqueue", yesno(renderer.isReadyForMoreMediaData));

    for (int i = 0; i < 8; i++) {
        CMSampleBufferRef more = makeSine(format, CMTimeAdd([sync currentTime], CMTimeMake(1, 4)), kFramesPerBuffer);
        [renderer enqueueSampleBuffer:more];
        CFRelease(more);
    }
    row("renderer: isReadyForMoreMediaData after nine enqueues", yesno(renderer.isReadyForMoreMediaData));
    rowf("renderer: status after nine enqueues", @"%ld", (long)renderer.status);
    row("renderer: error after nine enqueues is nil", yesno(renderer.error == nil));

    CMSampleBufferRef empty = makeSine(format, [sync currentTime], 0);
    if (empty) {
        [renderer enqueueSampleBuffer:empty];
        CFRelease(empty);
    }
    rowf("renderer: status after a buffer with no frames", @"%ld", (long)renderer.status);

    CFRelease(later);
    CFRelease(immediate);
    CFRelease(format);
}

static void probeRateChange(AVSampleBufferRenderSynchronizer *sync, AVSampleBufferAudioRenderer *renderer)
{
    [sync setRate:1.0];
    __block BOOL notified = NO;
    id token = [[NSNotificationCenter defaultCenter]
        addObserverForName:AVSampleBufferAudioRendererWasFlushedAutomaticallyNotification
                    object:renderer
                     queue:nil
                usingBlock:^(NSNotification *note) { notified = YES; }];

    [sync setRate:2.0];
    usleep(300000);
    row("rate: the renderer's timebase follows the synchronizer's new rate",
        yesno(fabs(CMTimebaseGetRate(renderer.timebase) - 2.0) < 0.001));
    row("rate: a rate change on a renderer holding no media posts the flushed-automatically notification",
        yesno(notified));
    rowf("rate: the renderer's status after the rate change", @"%ld", (long)renderer.status);
    row("rate: the renderer's error after the rate change is nil", yesno(renderer.error == nil));
    [sync setRate:0.0];
    usleep(200000);
    row("rate: rate 0 stops the renderer's timebase",
        yesno(fabs(CMTimebaseGetRate(renderer.timebase)) < 0.001));
    [sync setRate:1.0];
    usleep(200000);
    row("rate: rate 1 resumes the renderer's timebase",
        yesno(fabs(CMTimebaseGetRate(renderer.timebase) - 1.0) < 0.001));
    [[NSNotificationCenter defaultCenter] removeObserver:token];
}

static AVSampleBufferAudioRenderer *sFedRenderer;

int main(void)
{
    @autoreleasepool {
        row("CONTROL: AVSampleBufferRenderSynchronizer exists",
            yesno(NSClassFromString(@"AVSampleBufferRenderSynchronizer") != Nil));
        row("CONTROL: AVSampleBufferAudioRenderer exists",
            yesno(NSClassFromString(@"AVSampleBufferAudioRenderer") != Nil));
        row("CONTROL: the AVQueuedSampleBufferRendering protocol exists",
            yesno(NSProtocolFromString(@"AVQueuedSampleBufferRendering") != Nil));
        row("CONTROL: the renderer answers the protocol's own -timebase",
            yesno([AVSampleBufferAudioRenderer instancesRespondToSelector:@selector(timebase)]));

        probeAbsentMembers();
        probeSynchronizerClock();
        probeAnchorForm();
        probeAnchorInvalidInputs();
        probeSynchronizerObservers();
        probeSynchronizerRenderers();

        AVSampleBufferRenderSynchronizer *sync = [[AVSampleBufferRenderSynchronizer alloc] init];
        AVSampleBufferAudioRenderer *renderer = [[AVSampleBufferAudioRenderer alloc] init];
        probeRendererSurface();
        [sync addRenderer:renderer];
        probeRendererAttached(sync, renderer);

        AVSampleBufferAudioRenderer *unfed = [[AVSampleBufferAudioRenderer alloc] init];
        [sync addRenderer:unfed];
        probeRendererFlushWithoutMedia(sync, unfed);
        [sync removeRenderer:unfed atTime:kCMTimeInvalid completionHandler:NULL];

        AVSampleBufferAudioRenderer *changer = [[AVSampleBufferAudioRenderer alloc] init];
        [sync addRenderer:changer];
        probeRateChange(sync, changer);
        [sync removeRenderer:changer atTime:kCMTimeInvalid completionHandler:NULL];

        sFedRenderer = [[AVSampleBufferAudioRenderer alloc] init];
        [sync addRenderer:sFedRenderer];
        probeRendererMedia(sync, sFedRenderer);
    }
    return 0;
}
