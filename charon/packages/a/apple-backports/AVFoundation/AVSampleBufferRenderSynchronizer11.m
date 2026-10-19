// AVSampleBufferRenderSynchronizer11.m - AVSampleBufferRenderSynchronizer as of 11.0.
//
// Neither the class nor a word of this surface is on 6.1.3, and the port brings all of it. The clock it
// runs on is CoreMedia's own, built the two-step way this release exports: the plain _CMTimebaseCreate
// is 0 in 6.1.3's CoreMedia export trie (1819 exports, 62 matching "Timebase") and
// CMTimebaseCreateWithMasterClock(kCFAllocatorDefault, CMClockGetHostTimeClock(), &timebase) is two
// symbols it does export, so that is the call. Every other member below is one CMTimebase operation the
// same trie exports, and the two observers are two more it exports, the dispatch-source pair
// _CMTimebaseAddTimerDispatchSource and _CMTimebaseSetTimerDispatchSourceNextFireTime.
//
// What the host answers for each of these members was measured on this Mac through the class the macOS
// SDK declares, which carries every 11.0 name this file implements, and every answer below is that one:
// tests/backports/host/avf-samplerender11 prints the two tables side by side. The measurements that
// shaped the code, and the one it could not make, are in facts/AVFoundation/SampleBufferRender11.md.
//
// ONE RELEASE PER OBJECT. Every symbol this file defines first appears in the 11.0 image: the class
// symbol (tools/cache-index/first-rung.lua _OBJC_CLASS_$_AVSampleBufferRenderSynchronizer answers 11.0)
// and nothing else. -currentTime is 12.0 and lives in AVSampleBufferRenderSynchronizer12.m;
// -setRate:time:atHostTime: is 14.5 and lives in AVSampleBufferRenderSynchronizer14.m.
//
// That split is why this file compiles with two warnings and no pragma: -currentTime and
// -setRate:time:atHostTime: are declared by the 16.4 header for 12.0 and 14.5, so the compiler asks where
// this object's @implementation answers them, and the answer is one object over. There is no
// #pragma clang diagnostic ignored in this file, and there is nothing else to write: the two members are
// implemented, by the objects that own their release.
#import "CharonAVSampleBufferRender.h"

#import <CoreMedia/CoreMedia.h>

// One time observer, and the token the client is handed. Its owner is unretained on purpose and cannot
// dangle: the synchronizer holds every live observer in -_observers and cancels them all in -dealloc,
// so an observer never outlives the synchronizer that made it.
@interface CharonAVSampleBufferTimeObserver : NSObject
{
@public
    AVSampleBufferRenderSynchronizer *owner;
    dispatch_source_t source;
    CMTime interval;                     // the periodic observer's interval; kCMTimeInvalid for a boundary one
    NSMutableArray *times;               // the boundary observer's times left, as NSValue-wrapped CMTimes
    void (^periodic)(CMTime time);
    void (^boundary)(void);
}
- (instancetype)initWithOwner:(AVSampleBufferRenderSynchronizer *)aSynchronizer
                        queue:(dispatch_queue_t)queue
                      interval:(CMTime)aInterval
                      periodic:(void (^)(CMTime time))aBlock;
- (instancetype)initWithOwner:(AVSampleBufferRenderSynchronizer *)aSynchronizer
                        queue:(dispatch_queue_t)queue
                        times:(NSArray *)aTimes
                     boundary:(void (^)(void))aBlock;
- (void)charon_armAt:(CMTime)time;
- (void)charon_cancel;
- (void)charon_fire;
@end

// A removal a client has scheduled for a time still ahead, kept so that a second scheduled removal of the
// same renderer can answer the first one with NO, which is the header's own rule. Its owner is
// unretained and cannot dangle: the synchronizer holds it in -_removals, so it dies with the
// synchronizer, and a client's handler is not called on the way out (the header's rule is about a removal
// that has not happened yet, and the client is releasing the synchronizer).
@interface CharonAVScheduledRemoval : NSObject
{
@public
    AVSampleBufferRenderSynchronizer *owner;
    id <AVQueuedSampleBufferRendering> renderer;
    CharonAVSampleBufferTimeObserver *token;
    void (^handler)(BOOL didRemoveRenderer);
}
- (void)charon_finishWithRemoved:(BOOL)removed;
@end

@implementation CharonAVScheduledRemoval

// The removal's handler is called exactly once, and the entry leaves the synchronizer's list as it does.
- (void)charon_finishWithRemoved:(BOOL)removed
{
    [owner charon_forgetRemoval:self];
    if (handler)
        handler(removed);
    owner = nil;
    token = nil;
}

@end

@interface AVSampleBufferRenderSynchronizer ()
{
@private
    CMTimebaseRef _timebase;
    NSMutableArray *_renderers;         // id<AVQueuedSampleBufferRendering>, in the order they were added
    NSMutableArray *_observers;         // the CharonAVSampleBufferTimeObserver tokens still live
    NSMutableArray *_removals;          // the CharonAVScheduledRemoval entries not yet reached
    dispatch_queue_t _observerQueue;    // where a block goes when the client named no queue
    dispatch_queue_t _anchorQueue;      // where the 14.5 anchor form's delayed start is applied
    float _rate;                        // the rate last asked for, which is what -rate answers
}
@end

@implementation AVSampleBufferRenderSynchronizer

- (instancetype)init
{
    if (!(self = [super init]))
        return nil;
    // The two-step create is the only one this release exports. Nothing else is set here, and that is what
    // makes the clock answer what this Mac's own synchronizer answers before it is asked anything: a rate
    // of 0 and a time of 0/1, both of which are what a fresh CMTimebase reads (measured).
    if (CMTimebaseCreateWithMasterClock(kCFAllocatorDefault, CMClockGetHostTimeClock(), &_timebase) != noErr)
        return nil;      // no clock, no synchronizer: the header's first member is the timebase
    _renderers = [[NSMutableArray alloc] init];
    _observers = [[NSMutableArray alloc] init];
    _removals = [[NSMutableArray alloc] init];
    _observerQueue = dispatch_queue_create("charon.samplebuffer.observer", DISPATCH_QUEUE_SERIAL);
    _anchorQueue = dispatch_queue_create("charon.samplebuffer.anchor", DISPATCH_QUEUE_SERIAL);
    return self;
}

- (void)dealloc
{
    // Every observer is cancelled here, and that is what makes the unretained owner pointer inside each of
    // them safe. A scheduled removal's handler is the client's, so it is not called: the client is
    // releasing the synchronizer, and the header's rule is about a removal that has not happened yet.
    for (CharonAVSampleBufferTimeObserver *observer in _observers)
        [observer charon_cancel];
}

// NOT BUILT IN THIS OBJECT, AND SAID SO RATHER THAN CLAIMED. clang synthesises an ivar and a pair of
// accessors for every property the SDK's @interface declares and this @implementation does not mention,
// whatever the property's API_AVAILABLE says: measured on this object's own code at the package's flags,
// `nm -a` over AVSampleBufferRenderSynchronizer11.o carries -delaysRateChangeUntilHasSufficientMediaData,
// -setDelaysRateChangeUntilHasSufficientMediaData: and the ivar behind them, identically at -target
// armv7-apple-ios6.0 and at -target armv7-apple-ios4.3. The property is 14.5 and its registry row answers
// absent, because the level it asks about is the preroll level
// AVSampleBufferAudioRenderer.hasSufficientMediaDataForReliablePlaybackStart answers and that is not
// measurable on this machine or derivable from the header. @dynamic leaves respondsToSelector: answering
// NO, which is the truth; the reason and the measurement are in AVSampleBufferAudioRenderer11.m, where the
// same thing happens to two properties, and the check asks all three.
@dynamic delaysRateChangeUntilHasSufficientMediaData;

#pragma mark - the clock

- (CMTimebaseRef)timebase
{
    return _timebase;
}

- (float)rate
{
    // The rate that was asked for, not the clock's own rate at this instant. The two are the same number in
    // every ordinary case, and they part company in exactly one, which is measured: after
    // -setRate:1.5 time:kCMTimeInvalid atHostTime:<five seconds ahead> this Mac's own synchronizer answers
    // 1.5 while its clock is held at zero until that host time arrives, which is what the header's "Indicates
    // the current rate of rendering" means to a client that set it.
    return _rate;
}

- (void)setRate:(float)rate
{
    // "Must be greater than or equal to 0.0" (the header), and the host answers a negative rate by
    // raising rather than clamping (measured: NSInvalidArgumentException for -1.0).
    if (rate < 0.0f)
        [NSException raise:NSInvalidArgumentException
                    format:@"-[AVSampleBufferRenderSynchronizer setRate:] was given %f, and a rate must be greater than or equal to 0.0", (double)rate];
    [self charon_setRate:rate time:kCMTimeInvalid hostTime:kCMTimeInvalid];
}

- (void)setRate:(float)rate time:(CMTime)time
{
    if (rate < 0.0f)
        [NSException raise:NSInvalidArgumentException
                    format:@"-[AVSampleBufferRenderSynchronizer setRate:time:] was given %f, and a rate must be greater than or equal to 0.0", (double)rate];
    [self charon_setRate:rate time:time hostTime:kCMTimeInvalid];
}

// The one place a rate or a time changes, shared by -setRate:, -setRate:time: and the 14.5 anchor form,
// so that every attached renderer is told exactly once. It is declared in CharonAVSampleBufferRender.h
// because the 14.5 object calls it too.
- (void)charon_setRate:(float)rate time:(CMTime)time hostTime:(CMTime)hostTime
{
    if (CMTIME_IS_VALID(time))
        CMTimebaseSetTime(_timebase, time);
    if (CMTIME_IS_VALID(time) && CMTIME_IS_VALID(hostTime)
        && CMTimeCompare(hostTime, CMClockGetTime(CMClockGetHostTimeClock())) > 0) {
        // A host time still ahead, with a time to hold at. Measured on the host: the timebase holds the
        // named time and does not move until that host time arrives, and starts at the rate then - not the
        // "immediately start running from an earlier time" the header's paragraph describes. Holding it is
        // CMTimebaseSetRate(0) and the start is a timer on the host clock, which is the clock this
        // timebase is driven by.
        //
        // It takes a time to hold, and the host agrees: with kCMTimeInvalid for the time and a host time
        // five seconds ahead, the same call leaves the time where it was and applies the rate at once
        // (measured: 7.1551 before, 7.3877 150 ms after at a rate of 1.5). So an invalid time takes the
        // plain rate branch below, which is what that measurement is.
        CMTimebaseSetRate(_timebase, 0.0);
        _rate = rate;
        double delay = CMTimeGetSeconds(CMTimeSubtract(hostTime, CMClockGetTime(CMClockGetHostTimeClock())));
        if (delay < 0.0)
            delay = 0.0;
        dispatch_time_t when = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * (double)NSEC_PER_SEC));
        dispatch_after(when, _anchorQueue, ^{
            CMTimebaseSetRate(self->_timebase, rate);
            [self charon_clocksDidChange];
        });
        return;
    }
    if (CMTIME_IS_VALID(hostTime)) {
        // A host time already past: the header says the timebase is set so that the named time is what it
        // reads at the given host time (the header), so the time now is the named time plus what that rate
        // has run on since then - measured: 101.1051 at the first read after a 100/1 named one second ago at
        // rate 1, and 101.6221 six 100 ms steps later. CMTimebaseSetRateAndAnchorTime is the call that takes
        // a time and a rate together, and the elapsed part is arithmetic on the host clock it is anchored to.
        CMTime now = CMClockGetTime(CMClockGetHostTimeClock());
        double elapsed = CMTimeGetSeconds(CMTimeSubtract(now, hostTime));
        CMTime anchored = CMTIME_IS_VALID(time) ? time : CMTimebaseGetTime(_timebase);
        anchored = CMTimeAdd(anchored, CMTimeMakeWithSeconds(elapsed * (double)rate, 600));
        CMTimebaseSetRateAndAnchorTime(_timebase, rate, anchored, now);
    } else {
        CMTimebaseSetRate(_timebase, rate);
    }
    _rate = rate;
    [self charon_clocksDidChange];
}

// Every change of this clock reaches every attached renderer, because a CMTimebase slaved to this one
// follows its master's TIMELINE and keeps its own rate and time: measured, a slave of a timebase reads
// the master's time only while the two run at the same rate from the same instant, and
// -CMTimebaseSetMasterTimebase leaves the slave's rate alone (both measured over
// CMTimebaseGetMasterTimebase / CMTimebaseGetTime / CMTimebaseGetRate). So the rate and the time are set
// here, which is what makes a renderer's clock read this one's - measured on the host as both clocks
// reading 5.2032 after this one's time is set to 5/1, which the differential found this way.
- (void)charon_clocksDidChange
{
    double rate = CMTimebaseGetRate(_timebase);
    CMTime time = CMTimebaseGetTime(_timebase);
    for (id <AVQueuedSampleBufferRendering> renderer in [_renderers copy]) {
        CMTimebaseSetTime(renderer.timebase, time);
        CMTimebaseSetRate(renderer.timebase, rate);
        if ([renderer respondsToSelector:@selector(charon_renderSynchronizerDidChangeRate)])
            [(id)renderer charon_renderSynchronizerDidChangeRate];
    }
}

#pragma mark - the renderers

- (NSArray *)renderers
{
    // The header notes that the list also holds renderers scheduled for removal that have not yet been
    // removed, so this hands back a snapshot rather than the live array.
    return [_renderers copy];
}

- (void)addRenderer:(id <AVQueuedSampleBufferRendering>)renderer
{
    if ([_renderers containsObject:renderer])
        // Measured: the host raises, with the reason "The SampleBufferRenderer cannot be added to a
        // Synchronizer more than once".
        [NSException raise:NSInvalidArgumentException
                    format:@"-[AVSampleBufferRenderSynchronizer addRenderer:] cannot add the same renderer twice"];
    [_renderers addObject:renderer];
    // The header says adding a renderer makes it run on the synchronizer's timebase. The renderer's
    // own timebase becomes a slave of this one, which is how the two clocks stay in step: measured, the
    // renderer's -timebase is a different object from the synchronizer's after -addRenderer:, the two read
    // the same time, and a rate of 0 on the synchronizer stops the renderer's clock as well.
    CMTimebaseSetMasterTimebase(renderer.timebase, _timebase);
    CMTimebaseSetRate(renderer.timebase, CMTimebaseGetRate(_timebase));
    if ([renderer respondsToSelector:@selector(charon_renderSynchronizerDidChangeRate)])
        [(id)renderer charon_renderSynchronizerDidChangeRate];
}

- (void)removeRenderer:(id <AVQueuedSampleBufferRendering>)renderer
                atTime:(CMTime)time
      completionHandler:(void (^)(BOOL didRemoveRenderer))completionHandler
{
    if (![_renderers containsObject:renderer]) {
        // The header says that when the renderer was never added, the completionHandler is still called and
        // didRemoveRenderer comes back NO (the header), and the host calls it before returning (measured).
        if (completionHandler)
            completionHandler(NO);
        return;
    }
    if (!CMTIME_IS_NUMERIC(time) || CMTimeCompare(time, CMTimebaseGetTime(_timebase)) <= 0) {
        // No time named, or one already reached: the removal is now.
        [self charon_removeRenderer:renderer];
        if (completionHandler)
            completionHandler(YES);
        return;
    }
    // A time still ahead is a boundary observation of this synchronizer's own clock, so the handler runs
    // from the timer: measured, at a time 120 ms ahead the handler runs within 300 ms of the call and not
    // before the time is reached.
    CharonAVScheduledRemoval *removal = [[CharonAVScheduledRemoval alloc] init];
    removal->owner = self;
    removal->renderer = renderer;
    removal->handler = completionHandler;
    [_removals addObject:removal];
    // A second scheduled removal of the same renderer answers the one before it with NO and replaces it,
    // which is the header's rule for two removals scheduled one after the other.
    for (CharonAVScheduledRemoval *earlier in [_removals copy]) {
        if (earlier == removal || earlier->renderer != renderer)
            continue;
        [earlier->token charon_cancel];
        [earlier charon_finishWithRemoved:NO];
    }
    CharonAVSampleBufferTimeObserver *token = [[CharonAVSampleBufferTimeObserver alloc] initWithOwner:self
                                                                                                queue:nil
                                                                                                times:@[ [NSValue valueWithCMTime:time] ]
                                                                                             boundary:^{
        [self charon_removeRenderer:renderer];
        [removal charon_finishWithRemoved:YES];
    }];
    removal->token = token;
    [token charon_armAt:time];
}

- (void)charon_removeRenderer:(id <AVQueuedSampleBufferRendering>)renderer
{
    if (![_renderers containsObject:renderer])
        return;
    [_renderers removeObject:renderer];
    // Measured on the host after a removal: the renderer's clock reads a rate of 0 and a time of 0, and it
    // is on the host clock again rather than on a synchronizer that is no longer driving it.
    CMTimebaseRef rendererTimebase = renderer.timebase;
    if (rendererTimebase) {
        CMTimebaseSetRate(rendererTimebase, 0.0);
        CMTimebaseSetTime(rendererTimebase, kCMTimeZero);
        CMTimebaseSetMasterClock(rendererTimebase, CMClockGetHostTimeClock());
    }
}

#pragma mark - the time observers

- (id)addPeriodicTimeObserverForInterval:(CMTime)interval
                                  queue:(dispatch_queue_t)queue
                              usingBlock:(void (^)(CMTime time))block
{
    CharonAVSampleBufferTimeObserver *token = [[CharonAVSampleBufferTimeObserver alloc] initWithOwner:self
                                                                                                queue:queue
                                                                                            interval:interval
                                                                                            periodic:block];
    // Armed at the clock's own time, which is what the host answers for the first call: it arrives at
    // once and the next ones one interval apart (measured, a first call 0.1 ms after registration on an
    // idle queue and consecutive reported times 100 ms apart at a 100 ms interval).
    [token charon_armAt:CMTimebaseGetTime(_timebase)];
    return token;
}

- (id)addBoundaryTimeObserverForTimes:(NSArray *)times
                               queue:(dispatch_queue_t)queue
                           usingBlock:(void (^)(void))block
{
    if (!times.count)
        // Measured: the host raises NSInvalidArgumentException with the reason
        // "-[AVOccasionalTimebaseObserver initWithTimebase:times:queue:block:] invalid parameter not
        // satisfying: [times count] > 0".
        [NSException raise:NSInvalidArgumentException
                    format:@"-[AVSampleBufferRenderSynchronizer addBoundaryTimeObserverForTimes:queue:usingBlock:] needs at least one time"];
    // A time already reached never arrives, which is what the host answers (measured: a boundary at one
    // second on a clock already past it does not fire). The comparison is against this clock, because the
    // times on this API are times on this synchronizer's clock.
    NSMutableArray *ahead = [NSMutableArray array];
    CMTime now = CMTimebaseGetTime(_timebase);
    CMTime first = kCMTimeInvalid;
    for (NSValue *value in times) {
        CMTime time = [value CMTimeValue];
        if (!CMTIME_IS_NUMERIC(time) || CMTimeCompare(time, now) <= 0)
            continue;
        [ahead addObject:value];
        if (!CMTIME_IS_VALID(first) || CMTimeCompare(time, first) < 0)
            first = time;
    }
    CharonAVSampleBufferTimeObserver *token = [[CharonAVSampleBufferTimeObserver alloc] initWithOwner:self
                                                                                                queue:queue
                                                                                                times:ahead
                                                                                             boundary:block];
    if (CMTIME_IS_VALID(first))
        [token charon_armAt:first];
    return token;
}

- (void)removeTimeObserver:(id)observer
{
    if (![observer isKindOfClass:[CharonAVSampleBufferTimeObserver class]])
        // Measured: the host raises for anything that is not one of its own tokens.
        [NSException raise:NSInvalidArgumentException
                    format:@"-[AVSampleBufferRenderSynchronizer removeTimeObserver:] was given %@, which is not a time observer", observer];
    if (![_observers containsObject:observer])
        return;      // measured: removing the same token twice is accepted and does nothing
    [_observers removeObject:observer];
    [(CharonAVSampleBufferTimeObserver *)observer charon_cancel];
}

- (void)charon_addObserver:(id)observer
{
    [_observers addObject:observer];
}

- (void)charon_forgetRemoval:(id)removal
{
    [_removals removeObject:removal];
}

- (dispatch_queue_t)charon_queueFor:(dispatch_queue_t)queue
{
    // A NULL queue means an arbitrary one (the header), and a private serial queue per synchronizer is
    // that: the observer's own order is the timebase's.
    return queue ? queue : _observerQueue;
}

@end

#pragma mark - the observer

@implementation CharonAVSampleBufferTimeObserver

- (instancetype)initWithOwner:(AVSampleBufferRenderSynchronizer *)aSynchronizer
                        queue:(dispatch_queue_t)queue
                      interval:(CMTime)aInterval
                      periodic:(void (^)(CMTime time))aBlock
{
    if (!(self = [super init]))
        return nil;
    self->owner = aSynchronizer;
    self->interval = aInterval;
    self->periodic = aBlock;
    self->source = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, [aSynchronizer charon_queueFor:queue]);
    dispatch_resume(self->source);
    dispatch_source_set_event_handler(self->source, ^{
        [self charon_fire];
    });
    // The source goes onto the clock before it is armed, and both are CoreMedia's own: the two exports
    // this release carries for a timer on a timebase, measured in 6.1.3's CoreMedia export trie.
    CMTimebaseAddTimerDispatchSource(aSynchronizer.timebase, self->source);
    [aSynchronizer charon_addObserver:self];
    return self;
}

- (instancetype)initWithOwner:(AVSampleBufferRenderSynchronizer *)aSynchronizer
                        queue:(dispatch_queue_t)queue
                        times:(NSArray *)aTimes
                     boundary:(void (^)(void))aBlock
{
    if (!(self = [super init]))
        return nil;
    self->owner = aSynchronizer;
    self->interval = kCMTimeInvalid;
    self->times = [aTimes mutableCopy];
    self->boundary = aBlock;
    self->source = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, [aSynchronizer charon_queueFor:queue]);
    dispatch_resume(self->source);
    dispatch_source_set_event_handler(self->source, ^{
        [self charon_fire];
    });
    CMTimebaseAddTimerDispatchSource(aSynchronizer.timebase, self->source);
    [aSynchronizer charon_addObserver:self];
    return self;
}

- (void)charon_armAt:(CMTime)time
{
    CMTimebaseSetTimerDispatchSourceNextFireTime(self->owner.timebase, self->source, time, 0);
}

- (void)charon_cancel
{
    if (!self->source)
        return;
    CMTimebaseRemoveTimerDispatchSource(self->owner.timebase, self->source);

    dispatch_source_cancel(self->source);
    // The handler holds this object and the object holds the source, so the cycle is broken here rather
    // than at release: a cancelled source with no handler goes when the last reference does.
    dispatch_source_set_event_handler(self->source, NULL);
    self->source = NULL;
    self->owner = nil;
    self->periodic = nil;
    self->boundary = nil;
    self->times = nil;
}

- (void)charon_fire
{
    AVSampleBufferRenderSynchronizer *clock = self->owner;
    if (!clock)
        return;
    CMTime now = CMTimebaseGetTime(clock.timebase);
    if (CMTIME_IS_VALID(self->interval)) {
        if (self->periodic)
            self->periodic(now);
        // A periodic observer re-arms itself one interval on, which is what makes the times it reports one
        // interval apart (measured on the host: 100 ms apart at a 100 ms interval).
        [self charon_armAt:CMTimeAdd(now, self->interval)];
        return;
    }
    if (self->boundary) {
        // The block is taken out of the token before it runs: a boundary observer has one firing per time,
        // and the token letting go of it here is also what breaks the cycle the block holds through its
        // own removal entry.
        void (^block)(void) = self->boundary;
        self->boundary = nil;
        block();
    }
    // One boundary time per firing: the ones at or before this firing are done, and the next one arms the
    // timer again.
    CMTime next = kCMTimeInvalid;
    for (NSValue *value in self->times) {
        CMTime time = [value CMTimeValue];
        if (CMTimeCompare(time, now) > 0 && (!CMTIME_IS_VALID(next) || CMTimeCompare(time, next) < 0))
            next = time;
    }
    if (CMTIME_IS_VALID(next))
        [self charon_armAt:next];
}

@end