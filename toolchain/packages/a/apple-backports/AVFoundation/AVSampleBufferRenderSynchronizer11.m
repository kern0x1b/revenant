#import "CharonAVSampleBufferRender.h"

#import <CoreMedia/CoreMedia.h>

@interface CharonAVSampleBufferTimeObserver : NSObject
{
@public
    AVSampleBufferRenderSynchronizer *owner;
    dispatch_source_t source;
    CMTime interval;
    NSMutableArray *times;
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
    NSMutableArray *_renderers;
    NSMutableArray *_observers;
    NSMutableArray *_removals;
    dispatch_queue_t _observerQueue;
    dispatch_queue_t _anchorQueue;
    float _rate;
}
@end

@implementation AVSampleBufferRenderSynchronizer

- (instancetype)init
{
    if (!(self = [super init]))
        return nil;
    if (CMTimebaseCreateWithMasterClock(kCFAllocatorDefault, CMClockGetHostTimeClock(), &_timebase) != noErr)
        return nil;
    _renderers = [[NSMutableArray alloc] init];
    _observers = [[NSMutableArray alloc] init];
    _removals = [[NSMutableArray alloc] init];
    _observerQueue = dispatch_queue_create("charon.samplebuffer.observer", DISPATCH_QUEUE_SERIAL);
    _anchorQueue = dispatch_queue_create("charon.samplebuffer.anchor", DISPATCH_QUEUE_SERIAL);
    return self;
}

- (void)dealloc
{
    for (CharonAVSampleBufferTimeObserver *observer in _observers)
        [observer charon_cancel];
}

@dynamic delaysRateChangeUntilHasSufficientMediaData;

#pragma mark - the clock

- (CMTimebaseRef)timebase
{
    return _timebase;
}

- (float)rate
{
    return _rate;
}

- (void)setRate:(float)rate
{
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

- (void)charon_setRate:(float)rate time:(CMTime)time hostTime:(CMTime)hostTime
{
    if (CMTIME_IS_VALID(time))
        CMTimebaseSetTime(_timebase, time);
    if (CMTIME_IS_VALID(time) && CMTIME_IS_VALID(hostTime)
        && CMTimeCompare(hostTime, CMClockGetTime(CMClockGetHostTimeClock())) > 0) {
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
    return [_renderers copy];
}

- (void)addRenderer:(id <AVQueuedSampleBufferRendering>)renderer
{
    if ([_renderers containsObject:renderer])
        [NSException raise:NSInvalidArgumentException
                    format:@"-[AVSampleBufferRenderSynchronizer addRenderer:] cannot add the same renderer twice"];
    [_renderers addObject:renderer];
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
        if (completionHandler)
            completionHandler(NO);
        return;
    }
    if (!CMTIME_IS_NUMERIC(time) || CMTimeCompare(time, CMTimebaseGetTime(_timebase)) <= 0) {
        [self charon_removeRenderer:renderer];
        if (completionHandler)
            completionHandler(YES);
        return;
    }
    CharonAVScheduledRemoval *removal = [[CharonAVScheduledRemoval alloc] init];
    removal->owner = self;
    removal->renderer = renderer;
    removal->handler = completionHandler;
    [_removals addObject:removal];
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
    [token charon_armAt:CMTimebaseGetTime(_timebase)];
    return token;
}

- (id)addBoundaryTimeObserverForTimes:(NSArray *)times
                               queue:(dispatch_queue_t)queue
                           usingBlock:(void (^)(void))block
{
    if (!times.count)
        [NSException raise:NSInvalidArgumentException
                    format:@"-[AVSampleBufferRenderSynchronizer addBoundaryTimeObserverForTimes:queue:usingBlock:] needs at least one time"];
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
        [NSException raise:NSInvalidArgumentException
                    format:@"-[AVSampleBufferRenderSynchronizer removeTimeObserver:] was given %@, which is not a time observer", observer];
    if (![_observers containsObject:observer])
        return;
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
        [self charon_armAt:CMTimeAdd(now, self->interval)];
        return;
    }
    if (self->boundary) {
        void (^block)(void) = self->boundary;
        self->boundary = nil;
        block();
    }
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
