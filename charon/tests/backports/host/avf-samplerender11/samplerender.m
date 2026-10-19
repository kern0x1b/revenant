// samplerender.m - the 11.0 sample-buffer render pair, one source, two builds.
//
// Compiled twice by run.sh: once with the real <AVFoundation/AVFoundation.h> and this machine's own
// AVFoundation - the ORACLE, from which every expectation in the join is read - and once with -I standin
// and the port's own AVFoundation/AVSampleBufferRenderSynchronizer11.m,
// AVSampleBufferAudioRenderer11.m, AVSampleBufferRenderSynchronizer12.m and
// AVSampleBufferRenderSynchronizer14.m linked in UNMODIFIED, against a stand-in release shaped like the
// one the port runs on: 6.1.3 carries no AVSampleBufferAudioRenderer, no
// AVSampleBufferRenderSynchronizer and no AVQueuedSampleBufferRendering protocol at all, which
// tools/corpus/objc-inventory.lua over the armv7 caches of 6.1.3 and 4.3 answers (the command, its
// output and the control - AVCaptureDevice with 100 instance selectors at 6.1.3 - are in
// packages/a/apple-backports/facts/AVFoundation/Release11.md).
//
// Every row is a question the header asks, asked through the SHARED selectors, on the same generated
// sample buffers: a 1 kHz sine at 44.1 kHz, 100 ms per buffer, each with a known output presentation
// timestamp. Nothing here asks a question only one build can answer: the two classes are constructed the
// same way on both sides, -init, because that is the construction both the 16.4 SDK and this Mac's SDK
// declare (the -initWithAudioFormatDescription:bufferCapacity: of 11.0 is in neither, and
// +sampleBufferAudioRenderer is a runtime factory no header here declares, so neither half may use it).
//
// The join is not "nothing differs". A row that both halves print must agree unless ALLOWANCES names it,
// a row the host prints and the port does not is always a failure, and a row only one side prints is
// always a failure. ALLOWANCES is a short list of differences that are in the PORT's build, each with the
// measurement that explains it.
//
// Timing rows are asked as booleans and buckets, never as raw instants: a row whose answer is a
// millisecond on one machine and a different millisecond on another is not a row, and the two tolerance
// rows below name the bound that was measured.
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static const double kSampleRate = 44100.0;
static const double kToneHz = 1000.0;
static const uint32_t kFramesPerBuffer = 4410;   // 100 ms

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

// The time the synchronizer's own clock reads, which is what every timing row below is measured against.
static CMTime clockNow(void)
{
    return CMClockGetTime(CMClockGetHostTimeClock());
}

static double secondsBetween(CMTime from, CMTime to)
{
    if (!CMTIME_IS_NUMERIC(from) || !CMTIME_IS_NUMERIC(to)) return NAN;
    return CMTimeGetSeconds(CMTimeSubtract(to, from));
}

// ---- the media both builds are handed: a 1 kHz sine, 100 ms, int16 mono at 44.1 kHz.
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
    // the tone is kept in a static table and never freed: this Mac's own renderer is given these buffers
    // and then stalls, and its own teardown of a stalled sample buffer frees the block's memory through a
    // callback CoreMedia cannot find (measured: BBufFinalize -> _xzm_free_not_found -> abort, on four runs
    // in five). Nothing in this file owns that memory's lifetime after the run, so it is not freed here.
    static int16_t *sTones[64];
    static int sToneCount;
    int16_t *samples = calloc(frames ? frames : 1, sizeof *samples);
    if (sToneCount < (int)(sizeof sTones / sizeof *sTones)) sTones[sToneCount++] = samples;
    for (uint32_t frame = 0; frame < frames; frame++) {
        double phase = 2.0 * M_PI * kToneHz * (double)frame / kSampleRate;
        samples[frame] = (int16_t)(12000.0 * sin(phase));
    }
    // NULL for the block allocator, so the block borrows this function's allocation and this function is
    // the only thing that frees it: kCFAllocatorDefault here would make the block own the memory AND
    // free() it, which is a double free the moment the block is released (measured: BBufFinalize,
    // __BUG_IN_CLIENT_OF_LIBMALLOC_POINTER_BEING_FREED_WAS_NOT_ALLOCATED, SIGABRT).
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

// A completion handler may be called on the queue the release chose; this gives it the main run loop's
// slice of time, which is what a client on the main thread would have given it.
static void self_drain(BOOL *completion)
{
    for (int step = 0; step < 50 && !*completion; step++)
        CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.02, false);
}

// ---- the synchronizer: its own clock, its rate, its time, and the two observers.
static void probeSynchronizerClock(void)
{
    AVSampleBufferRenderSynchronizer *sync = [[AVSampleBufferRenderSynchronizer alloc] init];
    row("sync: timebase is not nil", yesno(sync.timebase != NULL));
    rowf("sync: rate at init", @"%.3f", sync.rate);
    row("sync: timebase time at init is valid", yesno(CMTIME_IS_VALID(CMTimebaseGetTime(sync.timebase))));
    row("sync: currentTime at init", describeTime([sync currentTime]));
    rowf("sync: renderers at init", @"%lu", (unsigned long)sync.renderers.count);

    // Every rate read here is taken after a settle, because this Mac applies a rate change through a
    // barrier and a read in the same breath can answer the rate from before the change: measured, a run of
    // four back-to-back -setRate: calls answered 1.000, 0.000, 0.000 and 1.000 for the rates 1, 0, 2 and 1,
    // and the same four answered 1.000, 0.000, 2.000 and 1.000 on another run. The port applies the change
    // in the call, so the rows below ask the settled question and the transient is recorded in
    // facts/AVFoundation/SampleBufferRender11.md rather than in a row that changes from run to run.
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

    // setRate:time: with a time the client names, and with kCMTimeInvalid, which the header says
    // leaves the time alone.
    [sync setRate:1.0 time:CMTimeMake(600, 1)];
    double named = secondsBetween(kCMTimeZero, [sync currentTime]);
    // the named time is 600 s, and the answer is asked as a bucket: the two builds return it in their own
    // timescale (measured on the host: 600000011125/1000000000), so the row is the second it names.
    row("sync: currentTime right after setRate: 1.0 time: 600/1 is in [599 s, 601 s)",
        yesno(named >= 599.0 && named <= 601.0));
    [sync setRate:1.0 time:kCMTimeInvalid];
    CMTime kept = [sync currentTime];
    row("sync: currentTime after setRate: 1.0 time: kCMTimeInvalid is unchanged", yesno(CMTimeCompare(kept, CMTimeMake(600, 1)) >= 0));
    [sync setRate:0.0];
    row("sync: currentTime after setRate: 0.0 keeps the 600/1", yesno(CMTimeCompare([sync currentTime], CMTimeMake(600, 1)) >= 0));

    // rate 0 is stopped: the time does not move. rate 1 moves it at the clock's own pace.
    CMTime frozen = [sync currentTime];
    usleep(200000);
    row("sync: currentTime frozen while the rate is 0", yesno(fabs(secondsBetween(frozen, [sync currentTime])) < 0.02));

    [sync setRate:1.0];
    CMTime started = [sync currentTime], hostStarted = clockNow();
    usleep(300000);
    double moved = secondsBetween(started, [sync currentTime]);
    double hostMoved = secondsBetween(hostStarted, clockNow());
    row("sync: currentTime moves while the rate is 1", yesno(moved > 0.1));
    // the bound the join names: a third of a second of sleep, and the timebase's own answer has to be
    // within a tenth of a second of the host clock's own advance.
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

    // The periodic observer. The two timing questions that do not depend on which machine runs this:
    // how many calls arrive in four intervals, and how far apart two consecutive reported times are.
    __block NSInteger fires = 0;
    __block CMTime first = kCMTimeInvalid, atFirst = kCMTimeInvalid, previous = kCMTimeInvalid;
    __block double step = -1.0;
    dispatch_queue_t queue = dispatch_queue_create("charon.observer", DISPATCH_QUEUE_SERIAL);
    id periodic = [sync addPeriodicTimeObserverForInterval:CMTimeMake(1, 10)
                                                      queue:queue
                                                  usingBlock:^(CMTime time) {
        // what the block is handed is read against the timebase inside the block: comparing it against a
        // time read after the fact would measure the harness's sleep instead of the observer.
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

    // a second observer on the same synchronizer, to show removal is per observer.
    __block NSInteger second = 0;
    id other = [sync addPeriodicTimeObserverForInterval:CMTimeMake(1, 10) queue:queue usingBlock:^(CMTime time) {
        (void)time;
        second++;
    }];
    usleep(300000);
    row("sync: a second periodic observer fires while the first is removed", yesno(second > 0));
    [sync removeTimeObserver:other];

    // the boundary observer: a time still ahead, a time already past, and no times at all.
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

    // an observer removed twice, and a token that is not one of ours: both are the header's "will not do
    // anything" cases, and a release answer of a raise is a row of its own.
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

// The 14.5 anchor form, whose whole content is what the timebase does either side of the host time the
// client named.
static void probeAnchorForm(void)
{
    AVSampleBufferRenderSynchronizer *sync = [[AVSampleBufferRenderSynchronizer alloc] init];
    [sync setRate:1.0 time:CMTimeMake(10, 1)];
    usleep(100000);

    // a host time one second in the PAST: the timebase is already past it, so it runs at the rate from
    // the named time and has moved on by the elapsed interval.
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

    // a host time one second in the FUTURE: the time is the named time and does not move until the host
    // time arrives.
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
    // 1.2 s in total, so the read is clear of the instant the anchor is reached rather than racing it.
    usleep(800000);
    double moved = secondsBetween(kCMTimeZero, [sync currentTime]);
    row("anchor: with the host time 1 s in the future, the time moves at the rate once it arrives",
        yesno(moved > stillHeld + 0.15));

    [sync setRate:1.0];
}

// The two invalid inputs, on a synchronizer of their own: what they answer does not depend on anything a
// previous call left behind, and both are read after a settle, because this Mac applies a rate change
// through a barrier and a read in the same breath can still see the rate before it (measured: a read
// straight after such a change answers the previous rate and the same read 150 ms later the new one).
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

    // removal at a time still ahead: the handler is called with YES, and only when the time is reached.
    __block BOOL removedAhead = NO;
    __block BOOL handlerRan = NO;
    // the removal time is a time on the synchronizer's own clock; the two instants it is compared with
    // are both read from the HOST clock, because that is the clock the call and the handler share.
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

    // removal of a renderer that was never added, which the header says answers NO.
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

// ---- the renderer against a synchronizer, and the media path.
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

    // The time as well as the rate: the synchronizer's clock is set to five seconds and the renderer's is
    // read again. Measured on the host, both read 5.2032 afterwards, which is what the header's remark about adding a renderer
    // to the synchronizer is about.
    [sync setRate:1.0 time:CMTimeMake(5, 1)];
    usleep(150000);
    row("attached: the renderer's clock reads the synchronizer's new time",
        yesno(fabs(secondsBetween(CMTimebaseGetTime(renderer.timebase), CMTimebaseGetTime(sync.timebase))) < 0.02));

    // And after a removal the renderer's clock is on its own again, at zero and stopped.
    [sync removeRenderer:renderer atTime:kCMTimeInvalid completionHandler:NULL];
    usleep(150000);
    row("attached: the renderer's clock is at zero after it is removed",
        yesno(fabs(secondsBetween(kCMTimeZero, CMTimebaseGetTime(renderer.timebase))) < 0.01));
    row("attached: the renderer's clock is stopped after it is removed",
        yesno(fabs(CMTimebaseGetRate(renderer.timebase)) < 0.001));
}

// Flush semantics, asked of a renderer that has been given NO media.
//
// Measured on this machine's own class: -flush and -flushFromSourceTime: both answer on a renderer that
// has never been given a buffer, for a time in the past and for a time in the future alike, and the
// status stays AVQueuedSampleBufferRenderingStatusUnknown. The same two calls ABORT on a renderer that
// has been given media on this machine, because there is no output device for the media to have been
// handed to (measured: probe over the macOS SDK's own AVSampleBufferAudioRenderer, SIGABRT, empty
// stderr), so the with-media case is not asked here and is written down in
// facts/AVFoundation/SampleBufferRender11.md.
// What the port does NOT carry, asked of the built classes. clang synthesises an ivar and a pair of
// accessors for every property an SDK @interface declares and an @implementation does not mention, whatever
// the property's API_AVAILABLE says, so a member the registry rows answer absent can still be answered by
// the class - and check_registry reads that as "listed as absent, but what is built answers it". Each of
// these four is a property of one of the two SDK @interfaces or of the protocol, and each must leave
// respondsToSelector: answering NO on the port. Apple's own classes answer YES for all four, because their
// surface is a later one, which is what the ALLOWANCES in run.sh say.
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

    // the media-data request, asked of a renderer that is ready for media data because it holds none.
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

// The media path: what a renderer answers once it has been handed sample buffers with known
// presentation timestamps.
static void probeRendererMedia(AVSampleBufferRenderSynchronizer *sync, AVSampleBufferAudioRenderer *renderer)
{
    CMAudioFormatDescriptionRef format = makeFormat();
    if (!format) { row("media: the audio format description", @"(could not be made)"); return; }
    [sync setRate:1.0];

    // a buffer stamped at the timebase's own time, and one stamped in the future: both are the
    // timestamps the header says the timebase interprets.
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

    // more media than the renderer can hold: the header says a client should stop when this is NO, and
    // that the value often changes back asynchronously.
    for (int i = 0; i < 8; i++) {
        CMSampleBufferRef more = makeSine(format, CMTimeAdd([sync currentTime], CMTimeMake(1, 4)), kFramesPerBuffer);
        [renderer enqueueSampleBuffer:more];
        CFRelease(more);
    }
    row("renderer: isReadyForMoreMediaData after nine enqueues", yesno(renderer.isReadyForMoreMediaData));
    rowf("renderer: status after nine enqueues", @"%ld", (long)renderer.status);
    row("renderer: error after nine enqueues is nil", yesno(renderer.error == nil));

    // a buffer that carries no audio at all, which is what an empty media segment looks like.
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

// A rate change is the one thing a synchronizer does that a renderer has to react to, and the header
// names the reaction: the notification the release posts when its media data is flushed for a reason
// other than -flush. Asked of a renderer that holds no media, because on this machine a rate change on
// a renderer that HAS been given media ABORTS (measured, empty stderr, SIGABRT) - there is no output
// device for the media to have been handed to. What was measured instead is in
// facts/AVFoundation/SampleBufferRender11.md.
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

// This Mac's own renderer ABORTS when a renderer that was given media and has never played it is
// released (measured: SIGABRT, empty stderr, from -dealloc on the release's own stalled renderer), so
// the one renderer of the run that is given media is held in a static and never released. A global is
// the whole of the mechanism: nothing in this file releases it, and the process is about to exit.
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

        // One renderer per state the run needs, because this machine's own class is only usable in some
        // of them: a renderer that has been given media is stalled for want of an output device and
        // ABORTS on a flush or a rate change, so the flush rows and the rate-change rows are asked of
        // renderers that hold no media at all.
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
