#import "RevenantCoreHapticsPrivate.h"
#include <math.h>

@implementation RevenantCHHapticPatternPlayer
{
    __weak CHHapticEngine *_engine;
    CHHapticPattern *_pattern;
    dispatch_queue_t _queue;
    BOOL _running;
    BOOL _isMuted;
    NSUInteger _generation;
}

@synthesize isMuted = _isMuted;

- (instancetype)initWithEngine:(CHHapticEngine *)engine pattern:(CHHapticPattern *)pattern
{
    self = [super init];
    if (self) {
        _engine = engine;
        _pattern = pattern;
        _queue = dispatch_queue_create("space.kern0x1b.backports.corehaptics", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (float)revenant_intensityOf:(CHHapticEvent *)event
{
    float intensity = 1.0f;
    for (CHHapticEventParameter *parameter in event.eventParameters) {
        if ([parameter.parameterID isEqualToString:CHHapticEventParameterIDHapticIntensity])
            intensity = parameter.value;
    }
    float control = 1.0f;
    NSTimeInterval latest = -1.0;
    for (CHHapticDynamicParameter *parameter in _pattern.revenant_parameters) {
        if (![parameter.parameterID isEqualToString:CHHapticDynamicParameterIDHapticIntensityControl])
            continue;
        if (parameter.relativeTime > event.relativeTime)
            continue;
        if (parameter.relativeTime < latest)
            continue;
        latest = parameter.relativeTime;
        control = parameter.value;
    }
    return MIN(1.0f, MAX(0.0f, intensity * control));
}

- (int)revenant_millisecondsOf:(CHHapticEvent *)event
{
    if ([event.type isEqualToString:CHHapticEventTypeHapticContinuous])
        return (int)llround(event.duration * 1000.0);
    if (event.duration > 0.0)
        return (int)llround(event.duration * 1000.0);
    return REVENANT_HAPTIC_TRANSIENT_MS;
}

- (NSUInteger)revenant_scheduleFrom:(NSTimeInterval)start generation:(NSUInteger)generation
{
    NSUInteger scheduled = 0;
    NSTimeInterval now = [NSProcessInfo processInfo].systemUptime;
    for (CHHapticEvent *event in _pattern.revenant_events) {
        float intensity = [self revenant_intensityOf:event];
        if (intensity < REVENANT_HAPTIC_INTENSITY_FLOOR)
            continue;
        int milliseconds = [self revenant_millisecondsOf:event];
        if (milliseconds <= 0)
            continue;
        NSTimeInterval delay = start + event.relativeTime - now;
        if (delay < 0.0)
            delay = 0.0;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), _queue, ^{
            @synchronized (self) {
                if (!_running || _generation != generation || _isMuted)
                    return;
            }
            RevenantVibratorPlay(intensity, &milliseconds, 1);
        });
        scheduled++;
    }
    return scheduled;
}

- (BOOL)startAtTime:(NSTimeInterval)time error:(NSError **)outError
{
    CHHapticEngine *engine = _engine;
    if (!engine || ![engine revenant_isRunning]) {
        if (outError)
            *outError = revenant_corehaptics_error(CHHapticErrorCodeEngineNotRunning);
        return NO;
    }
    if (!isfinite(time) || time < 0.0) {
        if (outError)
            *outError = revenant_corehaptics_error(CHHapticErrorCodeInvalidTime);
        return NO;
    }
    NSTimeInterval now = [NSProcessInfo processInfo].systemUptime;
    NSTimeInterval start = time == CHHapticTimeImmediate ? now : time;
    NSUInteger generation;
    @synchronized (self) {
        _generation++;
        generation = _generation;
        _running = YES;
    }
    [engine revenant_addPlayer:self];
    [self revenant_scheduleFrom:start generation:generation];
    NSTimeInterval finish = start + _pattern.duration - now;
    if (finish < 0.0)
        finish = 0.0;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(finish * NSEC_PER_SEC)), _queue, ^{
        BOOL done = NO;
        @synchronized (self) {
            if (_running && _generation == generation) {
                _running = NO;
                done = YES;
            }
        }
        if (done)
            [engine revenant_playerDidFinish:self];
    });
    if (outError)
        *outError = nil;
    return YES;
}

- (BOOL)stopAtTime:(NSTimeInterval)time error:(NSError **)outError
{
    if (!isfinite(time) || time < 0.0) {
        if (outError)
            *outError = revenant_corehaptics_error(CHHapticErrorCodeInvalidTime);
        return NO;
    }
    NSTimeInterval now = [NSProcessInfo processInfo].systemUptime;
    NSTimeInterval delay = time == CHHapticTimeImmediate ? 0.0 : time - now;
    if (delay <= 0.0) {
        [self revenant_cancel];
    } else {
        NSUInteger generation;
        @synchronized (self) {
            generation = _generation;
        }
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), _queue, ^{
            @synchronized (self) {
                if (_generation != generation || !_running)
                    return;
            }
            [self revenant_cancel];
        });
    }
    if (outError)
        *outError = nil;
    return YES;
}

- (BOOL)sendParameters:(NSArray<CHHapticDynamicParameter *> *)parameters
               atTime:(NSTimeInterval)time
                error:(NSError **)outError
{
    if (!isfinite(time) || time < 0.0) {
        if (outError)
            *outError = revenant_corehaptics_error(CHHapticErrorCodeInvalidTime);
        return NO;
    }
    if (outError)
        *outError = revenant_corehaptics_error(CHHapticErrorCodeOperationNotPermitted);
    return NO;
}

- (BOOL)scheduleParameterCurve:(CHHapticParameterCurve *)parameterCurve
                        atTime:(NSTimeInterval)time
                         error:(NSError **)outError
{
    if (!isfinite(time) || time < 0.0) {
        if (outError)
            *outError = revenant_corehaptics_error(CHHapticErrorCodeInvalidTime);
        return NO;
    }
    if (outError)
        *outError = revenant_corehaptics_error(CHHapticErrorCodeOperationNotPermitted);
    return NO;
}

- (BOOL)cancelAndReturnError:(NSError **)outError
{
    [self revenant_cancel];
    if (outError)
        *outError = nil;
    return YES;
}

- (void)revenant_cancel
{
    BOOL wasRunning;
    @synchronized (self) {
        wasRunning = _running;
        _running = NO;
        _generation++;
    }
    if (wasRunning) {
        RevenantVibratorStop();
        [_engine revenant_playerDidFinish:self];
    }
}

@end
